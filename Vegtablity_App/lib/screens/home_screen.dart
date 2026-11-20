import '../services/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shift_provider.dart';
import '../core/localization/app_localizations.dart';
import 'login_screen.dart';
import 'printer_settings_screen.dart';
import 'settings_screen.dart';
import 'partner_offers_screen.dart';
import 'daily_invoices_screen.dart';
import 'close_shift_screen.dart';
import 'receipt_voucher_screen.dart';
import 'payment_voucher_screen.dart';
import 'general_receipt_voucher_screen.dart';
import 'general_payment_voucher_screen.dart';
import 'inventory/stocktake_screen.dart';
import 'inventory/wastage_screen.dart';
import 'supplier_selection_screen.dart';
import 'daily_orders_screen.dart';
import 'recipe_management_screen.dart';
import 'invoice_lookup_screen.dart';
import 'barcode_print_screen.dart';
import 'payment_gateway_invoices_screen.dart';
import 'talabat_orders_screen.dart';
import '../services/integrations/integration_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../widgets/sync_progress_widgets.dart';
import 'sync_center_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _homeLayout = 'classic';
  bool _isLoadingLayout = true;

  bool _showNewInvoice = true;
  bool _showNewPurchase = true;
  bool _showCustomerSales = true;
  bool _showSupplierPurchases = true;
  bool _showCustomerReceipts = true;
  bool _showSupplierPayments = true;
  bool _showStockTake = true;
  bool _showWastage = true;
  bool _showDailyOrders = true;
  bool _showRecipes = true;
  bool _showBarcodePrinting = true;
  bool _showPaymentGatewayInvoices = true;
  bool _showTalabatOrders = true;
  bool _isTalabatConfiguredOnServer = false;
  bool _hasAvailableUpdate = false;
  bool _isCheckingUpdate = false;
  UpdateInfoModel? _latestUpdateInfo;

  @override
  void initState() {
    super.initState();
    _loadHomeLayout();
    
    // Refresh offline cache and live permissions in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).refreshCurrentUserPermissions();
      Provider.of<VoucherProvider>(context, listen: false).refreshCache();
      Provider.of<AccountProvider>(context, listen: false).fetchGeneralPartnerId();
      Provider.of<SettingsProvider>(context, listen: false).fetchSettings();
      Provider.of<ShiftProvider>(context, listen: false).checkActiveShiftStatus();
      Provider.of<SyncViewModel>(context, listen: false).loadAllQueues();

      // Silent Auto-Update Check on Startup
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _checkForAppUpdate(openDialog: true, showNoUpdateToast: false);
        }
      });
    });
  }

  Future<void> _checkForAppUpdate({
    bool openDialog = true,
    bool showNoUpdateToast = true,
  }) async {
    if (_isCheckingUpdate) return;
    if (mounted) {
      setState(() => _isCheckingUpdate = true);
    }

    try {
      final info = await UpdateService().checkForUpdate();
      if (!mounted) return;
      setState(() {
        _latestUpdateInfo = info;
        _hasAvailableUpdate = info.hasUpdate;
        _isCheckingUpdate = false;
      });

      if (info.hasUpdate && openDialog) {
        await showDialog(
          context: context,
          barrierDismissible: !info.isMandatory,
          builder: (ctx) => UpdateDialog(updateInfo: info),
        );
      } else if (!info.hasUpdate && showNoUpdateToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('update_already_latest')),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _loadHomeLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _homeLayout = prefs.getString('pref_home_layout') ?? 'classic';
        _showNewInvoice = prefs.getBool('show_new_invoice') ?? true;
        _showNewPurchase = prefs.getBool('show_new_purchase') ?? true;
        _showCustomerSales = prefs.getBool('show_customer_sales') ?? true;
        _showSupplierPurchases = prefs.getBool('show_supplier_purchases') ?? true;
        _showCustomerReceipts = prefs.getBool('show_customer_receipts') ?? true;
        _showSupplierPayments = prefs.getBool('show_supplier_payments') ?? true;
        _showStockTake = prefs.getBool('show_stocktake') ?? true;
        _showWastage = prefs.getBool('show_wastage') ?? true;
        _showDailyOrders = prefs.getBool('show_daily_orders') ?? true;
        _showRecipes = prefs.getBool('show_recipes') ?? true;
        _showBarcodePrinting = prefs.getBool('show_barcode_printing') ?? true;
        _showPaymentGatewayInvoices = prefs.getBool('show_payment_gateway_invoices') ?? true;
        _showTalabatOrders = prefs.getBool('show_talabat_orders') ?? true;
        _isLoadingLayout = false;
      });
      final summary = await IntegrationPosService().fetchProvidersSummary();
      if (mounted) {
        setState(() {
          _isTalabatConfiguredOnServer = summary['isTalabatConfigured'] == true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLayout = false;
      });
    }
  }

  Future<void> _navigateToSettings() async {
    Navigator.pop(context); // Close drawer
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GeneralSettingsScreen()),
    );
    // Reload layout when returning from settings
    _loadHomeLayout();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final posProvider = Provider.of<PosProvider>(context);
    final voucherProv = Provider.of<VoucherProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final int unsyncedCount = posProvider.offlineInvoicesCount;
    final int unsyncedVouchers = voucherProv.offlineVouchersCount;
    final int totalUnsynced = unsyncedCount + unsyncedVouchers;

    final rawCompanyName = settingsProvider.companyName.trim();
    final String appTitle = rawCompanyName.isNotEmpty ? '$rawCompanyName POS' : 'Vegtablity POS';

    final bool isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          context.tr('home_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Check for Updates Icon Button (Icon only, highlighted when update is available)
          Tooltip(
            message: context.tr('settings_check_updates'),
            child: IconButton(
              onPressed: _isCheckingUpdate
                  ? null
                  : () async {
                      if (_hasAvailableUpdate && _latestUpdateInfo != null) {
                        await showDialog(
                          context: context,
                          barrierDismissible: !_latestUpdateInfo!.isMandatory,
                          builder: (ctx) => UpdateDialog(updateInfo: _latestUpdateInfo!),
                        );
                        // Re-check quietly in case user refreshed or dismissed
                        if (mounted) {
                          _checkForAppUpdate(openDialog: false, showNoUpdateToast: false);
                        }
                      } else {
                        await _checkForAppUpdate(openDialog: true, showNoUpdateToast: true);
                      }
                    },
              icon: _isCheckingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: _hasAvailableUpdate ? const EdgeInsets.all(5) : EdgeInsets.zero,
                          decoration: _hasAvailableUpdate
                              ? BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                                )
                              : null,
                          child: Icon(
                            Icons.system_update_rounded,
                            color: _hasAvailableUpdate ? Colors.amberAccent : Colors.white,
                            size: _hasAvailableUpdate ? 22 : 24,
                          ),
                        ),
                        if (_hasAvailableUpdate)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          // Global Reprint Button for Last Added Document
          Consumer<PrinterService>(
            builder: (context, printerService, child) {
              final hasLastDoc = printerService.lastAddedDocument != null;
              return Tooltip(
                message: 'طباعة أحدث إضافة بالنظام (نسخة إضافية)',
                child: IconButton(
                  icon: Icon(
                    Icons.print,
                    color: hasLastDoc ? Colors.white : Colors.white60,
                  ),
                  onPressed: () async {
                    if (!hasLastDoc) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يوجد مستند سابق مضاف حالياً لطباعته', textAlign: TextAlign.right),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final success = await printerService.printLastAddedDocument();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? 'تمت طباعة أحدث إضافة بنجاح' : 'فشلت عملية طباعة أحدث إضافة',
                            textAlign: TextAlign.right,
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
          // Connection Status Indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: totalUnsynced > 0 ? Colors.amberAccent : const Color(0xFF6EE7B7),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('home_server_status'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.of(context).padding.top + 18,
                18,
                18,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${context.tr('home_welcome')}${authProvider.username ?? ''}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: shiftProvider.isShiftOpen
                            ? const Color(0xFF6EE7B7).withValues(alpha: 0.55)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 14,
                          color: shiftProvider.isShiftOpen
                              ? const Color(0xFF6EE7B7)
                              : Colors.amberAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          shiftProvider.isShiftOpen &&
                                  shiftProvider.shiftId != null
                              ? '${context.tr('home_active_shift')}${shiftProvider.shiftId}'
                              : context.tr('home_no_active_shift'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('home_developed_by'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: [
                  if (authProvider.isAdmin) ...[
                    _buildDrawerTile(
                      icon: Icons.settings_applications_rounded,
                      color: const Color(0xFF0D9488),
                      title: context.tr('settings'),
                      onTap: _navigateToSettings,
                    ),
                    _buildDrawerTile(
                      icon: Icons.print_rounded,
                      color: const Color(0xFF0D9488),
                      title: context.tr('home_printer_settings'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const PrinterSettingsScreen()),
                        );
                      },
                    ),
                  ],
                  _buildDrawerTile(
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFF059669),
                    title: context.tr('home_open_cash_drawer'),
                    onTap: () async {
                      Navigator.pop(context);
                      final printerService =
                          Provider.of<PrinterService>(context, listen: false);
                      final success = await printerService.openCashDrawer();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? context.tr('cd_open_success')
                                  : context.tr('cd_open_failed'),
                            ),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFF0D9488),
                    title: context.tr('home_daily_invoices'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DailyInvoicesScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.search_rounded,
                    color: const Color(0xFF2563EB),
                    title: context.tr('home_invoice_lookup'),
                    subtitle: context.tr('home_invoice_lookup_sub'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const InvoiceLookupScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.lock_clock_rounded,
                    color: const Color(0xFFE11D48),
                    title: context.tr('home_close_shift'),
                    titleColor: const Color(0xFFBE123C),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CloseShiftScreen()),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _buildDrawerTile(
                    icon: Icons.arrow_circle_down_rounded,
                    color: const Color(0xFF059669),
                    title: context.tr('home_receipt_voucher'),
                    subtitle: context.tr('home_receipt_voucher_sub'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const GeneralReceiptVoucherScreen()));
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.arrow_circle_up_rounded,
                    color: const Color(0xFFD97706),
                    title: context.tr('home_payment_voucher'),
                    subtitle: context.tr('home_payment_voucher_sub'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const GeneralPaymentVoucherScreen()));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _buildDrawerTile(
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF0D9488),
                    title: context.tr('home_drawer_stocktake'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const StockTakeScreen()));
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.delete_sweep_outlined,
                    color: const Color(0xFFB45309),
                    title: context.tr('home_drawer_wastage'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const WastageScreen()));
                    },
                  ),
                  if (Provider.of<SettingsProvider>(context).isProductionMode)
                    _buildDrawerTile(
                      icon: Icons.restaurant_menu_rounded,
                      color: const Color(0xFF15803D),
                      title: context.tr('home_drawer_recipes'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const RecipeManagementScreen()));
                      },
                    ),
                  if (_showBarcodePrinting)
                    _buildDrawerTile(
                      icon: Icons.qr_code_2_rounded,
                      color: const Color(0xFF4F46E5),
                      title: context.tr('home_barcode_print'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const BarcodePrintScreen()),
                        );
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _buildDrawerTile(
                    icon: Icons.cloud_sync_rounded,
                    color: const Color(0xFF0284C7),
                    title: context.tr('home_sync_drawer_title'),
                    subtitle: context.tr('home_sync_drawer_sub'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SyncCenterScreen()),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    icon: Icons.exit_to_app_rounded,
                    color: const Color(0xFFE11D48),
                    title: context.tr('home_logout'),
                    titleColor: const Color(0xFFBE123C),
                    onTap: () async {
                      await Provider.of<AuthProvider>(context, listen: false)
                          .logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoadingLayout
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : Column(
              children: [
                // Compact Welcome & Active Shift Header Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _buildTopSummaryCard(
                    context: context,
                    username: authProvider.username ?? '',
                    shiftProvider: shiftProvider,
                    isAr: isAr,
                  ),
                ),
                // Banner for offline pending invoices
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: HomeSyncBannerWidget(),
                ),
                // Active Home Screen Layout Design
                Expanded(
                  child: _buildClassicLayout(context),
                ),
              ],
            ),
    );
  }

  Widget _buildTopSummaryCard({
    required BuildContext context,
    required String username,
    required ShiftProvider shiftProvider,
    required bool isAr,
  }) {
    final bool hasShift =
        shiftProvider.isShiftOpen && shiftProvider.shiftId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('home_welcome')}$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasShift
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasShift
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasShift
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 13,
                            color: hasShift
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasShift
                                ? '${context.tr('home_active_shift')}${shiftProvider.shiftId}'
                                : context.tr('home_no_active_shift'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: hasShift
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DailyInvoicesScreen()),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 16, color: Color(0xFF0F766E)),
                    const SizedBox(width: 5),
                    Text(
                      isAr ? 'اليومية' : 'Daily',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Categorized Executive Grid Layout
  Widget _buildClassicLayout(BuildContext context) {
    final bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    final settingsProv = Provider.of<SettingsProvider>(context);
    final bool enableDailyOrders = settingsProv.enableDailyOrders;
    final bool isProductionMode = settingsProv.isProductionMode;

    final List<_HomeMenuCardItem> salesCards = [];
    final List<_HomeMenuCardItem> purchaseAndTreasuryCards = [];
    final List<_HomeMenuCardItem> operationsAndGatewayCards = [];

    // 1. Sales & Collections
    if (_showNewInvoice) {
      salesCards.add(_HomeMenuCardItem(
        title: context.tr('home_classic_new_invoice'),
        subtitle: isAr ? 'نقطة البيع وإصدار فواتير العملاء' : 'POS & customer sales billing',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF2563EB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const PartnerSelectionScreen(type: 'Sales')),
        ),
      ));
    }
    if (_showCustomerSales) {
      salesCards.add(_HomeMenuCardItem(
        title: context.tr('home_premium_customer_sales'),
        subtitle: isAr ? 'تنفيذ الطلبات من عروض الأسعار' : 'Bill from customer price quotes',
        icon: Icons.local_offer_rounded,
        color: const Color(0xFF4F46E5),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const PartnerOffersScreen(type: 'Sales')),
        ),
      ));
    }
    if (_showCustomerReceipts) {
      salesCards.add(_HomeMenuCardItem(
        title: context.tr('home_premium_customer_receipts'),
        subtitle: isAr ? 'سندات القبض والروابط المجمعة' : 'Receipts & consolidated links',
        icon: Icons.arrow_circle_down_rounded,
        color: const Color(0xFF059669),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReceiptVoucherScreen()),
        ),
      ));
    }

    // 2. Purchases & Payments
    if (_showNewPurchase) {
      purchaseAndTreasuryCards.add(_HomeMenuCardItem(
        title: context.tr('home_classic_new_purchase'),
        subtitle: isAr ? 'إدخال فواتير المشتريات والموردين' : 'Record supplier purchase bills',
        icon: Icons.shopping_basket_rounded,
        color: const Color(0xFFD97706),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const PartnerSelectionScreen(type: 'Purchase')),
        ),
      ));
    }
    if (_showSupplierPurchases) {
      purchaseAndTreasuryCards.add(_HomeMenuCardItem(
        title: context.tr('home_premium_supplier_purchases'),
        subtitle: isAr ? 'الشراء وفق عروض الموردين' : 'Purchase via supplier quotes',
        icon: Icons.receipt_rounded,
        color: const Color(0xFFEA580C),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const PartnerOffersScreen(type: 'Purchases')),
        ),
      ));
    }
    if (_showSupplierPayments) {
      purchaseAndTreasuryCards.add(_HomeMenuCardItem(
        title: context.tr('home_premium_supplier_payments'),
        subtitle: isAr ? 'سداد مستحقات وفواتير الموردين' : 'Settle supplier dues & bills',
        icon: Icons.arrow_circle_up_rounded,
        color: const Color(0xFFE11D48),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PaymentVoucherScreen()),
        ),
      ));
    }

    // 3. Inventory, Operations & Integrations
    if (_showStockTake) {
      operationsAndGatewayCards.add(_HomeMenuCardItem(
        title: context.tr('home_classic_stocktake'),
        subtitle: isAr ? 'مراجعة وجرد كميات المستودع' : 'Count & reconcile warehouse stock',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF0D9488),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StockTakeScreen()),
        ),
      ));
    }
    if (_showWastage) {
      operationsAndGatewayCards.add(_HomeMenuCardItem(
        title: context.tr('home_classic_wastage'),
        subtitle: isAr ? 'تسجيل التالف والفاقد المخزني' : 'Log damaged or expired stock',
        icon: Icons.delete_sweep_rounded,
        color: const Color(0xFFB45309),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WastageScreen()),
        ),
      ));
    }
    if (_showDailyOrders && enableDailyOrders) {
      operationsAndGatewayCards.add(_HomeMenuCardItem(
        title: context.tr('home_daily_orders'),
        subtitle: isAr ? 'متابعة وتجهيز الطلبات اليومية' : 'Track daily customer dispatches',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DailyOrdersScreen()),
        ),
      ));
    }
    if (_showRecipes && isProductionMode) {
      operationsAndGatewayCards.add(_HomeMenuCardItem(
        title: context.tr('home_classic_recipes'),
        subtitle: isAr ? 'إدارة المكونات ووصفات الإنتاج' : 'Manage recipes & production BOM',
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFF15803D),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const RecipeManagementScreen()),
        ),
      ));
    }
    if (_showPaymentGatewayInvoices &&
        settingsProv.hasAnyPaymentGatewayEnabled) {
      operationsAndGatewayCards.add(_HomeMenuCardItem(
        title: context.tr('home_payment_gateways'),
        subtitle: isAr ? 'إصدار ومتابعة واسترداد اللينكات' : 'Issue, track & refund payment links',
        icon: Icons.add_link_rounded,
        color: const Color(0xFF0284C7),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const PaymentGatewayInvoicesScreen()),
        ),
      ));
    }
    if (_showTalabatOrders &&
        settingsProv.enableTalabatIntegration &&
        _isTalabatConfiguredOnServer) {
      operationsAndGatewayCards.add(_HomeMenuCardItem(
        title: context.tr('home_talabat_orders'),
        subtitle: isAr ? 'استقبال وتأكيد طلبات طلبات' : 'Accept & process Talabat orders',
        icon: Icons.delivery_dining_rounded,
        color: const Color(0xFFF97316),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TalabatOrdersScreen()),
        ),
      ));
    }

    final int totalVisible = salesCards.length +
        purchaseAndTreasuryCards.length +
        operationsAndGatewayCards.length;

    if (totalVisible == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dashboard_customize_outlined,
                    size: 56, color: Color(0xFF94A3B8)),
                const SizedBox(height: 14),
                Text(
                  context.tr('home_no_enabled_cards_warn'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth >= 960
        ? 4
        : (screenWidth >= 600 ? 3 : 2);
    final double aspectRatio = screenWidth >= 600 ? 1.28 : 1.08;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (salesCards.isNotEmpty) ...[
            _buildSectionHeader(
              title: isAr ? 'المبيعات والتحصيلات' : 'Sales & Collections',
              icon: Icons.trending_up_rounded,
              accentColor: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 10),
            _buildCardsGrid(salesCards, crossAxisCount, aspectRatio),
            const SizedBox(height: 20),
          ],
          if (purchaseAndTreasuryCards.isNotEmpty) ...[
            _buildSectionHeader(
              title: isAr ? 'المشتريات وسداد الموردين' : 'Purchases & Suppliers',
              icon: Icons.shopping_bag_outlined,
              accentColor: const Color(0xFFD97706),
            ),
            const SizedBox(height: 10),
            _buildCardsGrid(
                purchaseAndTreasuryCards, crossAxisCount, aspectRatio),
            const SizedBox(height: 20),
          ],
          if (operationsAndGatewayCards.isNotEmpty) ...[
            _buildSectionHeader(
              title: isAr ? 'المخزون والربط الإلكتروني' : 'Inventory & Integrations',
              icon: Icons.hub_outlined,
              accentColor: const Color(0xFF0284C7),
            ),
            const SizedBox(height: 10),
            _buildCardsGrid(
                operationsAndGatewayCards, crossAxisCount, aspectRatio),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 17, color: accentColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildCardsGrid(
    List<_HomeMenuCardItem> items,
    int crossAxisCount,
    double aspectRatio,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) => _buildActionCard(context, items[index]),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withValues(alpha: 0.1),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor ?? const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern Eye-Friendly Executive Card Builder
  Widget _buildActionCard(BuildContext context, _HomeMenuCardItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.color.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: item.color.withValues(alpha: 0.10),
          highlightColor: item.color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item.color.withValues(alpha: 0.16),
                            item.color.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(item.icon, size: 25, color: item.color),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMenuCardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeMenuCardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
