import '../services/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../viewmodels/language_viewmodel.dart';
import '../core/localization/app_localizations.dart';
import '../models/language_model.dart';
import 'login_screen.dart';
import 'pos_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadHomeLayout();
    
    // Refresh offline cache in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VoucherProvider>(context, listen: false).refreshCache();
      Provider.of<AccountProvider>(context, listen: false).fetchGeneralPartnerId();
      Provider.of<SettingsProvider>(context, listen: false).fetchSettings();
    });
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
        _isLoadingLayout = false;
      });
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
    final int unsyncedCount = posProvider.offlineInvoicesCount;
    final int unsyncedVouchers = voucherProv.offlineVouchersCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('home_title')),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
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
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(context.tr('home_server_status'),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
                const SizedBox(width: 4),
                Icon(
                  Icons.circle,
                  size: 14,
                  color: unsyncedCount > 0 ? Colors.orange : Colors.greenAccent,
                ),
              ],
            ),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Vegtablity POS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${context.tr('home_welcome')}${authProvider.username ?? ''}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(context.tr('home_developed_by'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.settings_applications, color: Colors.teal),
              title: Text(context.tr('settings')),
              onTap: _navigateToSettings,
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.teal),
              title: Text(context.tr('home_printer_settings')),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PrinterSettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: Colors.green),
              title: Text(context.tr('home_open_cash_drawer')),
              onTap: () async {
                Navigator.pop(context); // Close drawer
                final printerService = Provider.of<PrinterService>(context, listen: false);
                final success = await printerService.openCashDrawer();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? context.tr('cd_open_success') : context.tr('cd_open_failed'),
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: Colors.teal),
              title: Text(context.tr('home_daily_invoices')),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DailyInvoicesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_clock, color: Colors.redAccent),
              title: Text(
                context.tr('home_close_shift'),
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CloseShiftScreen()),
                );
              },
            ),
            const Divider(),
            // ─── سندات القبض والصرف (مباشر) ────────────────────────
            ListTile(
              leading: const Icon(Icons.arrow_circle_down, color: Colors.greenAccent),
              title: Text(context.tr('home_receipt_voucher'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(context.tr('home_receipt_voucher_sub'), style: const TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GeneralReceiptVoucherScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_circle_up, color: Colors.orangeAccent),
              title: Text(context.tr('home_payment_voucher'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(context.tr('home_payment_voucher_sub'), style: const TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GeneralPaymentVoucherScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.inventory_outlined, color: Colors.teal),
              title: const Text('جرد المخزون (مسودة)', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const StockTakeScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.teal),
              title: const Text('إهلاك بضاعة (الهالك)', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const WastageScreen()));
              },
            ),
            if (Provider.of<SettingsProvider>(context).isProductionMode)
              ListTile(
                leading: const Icon(Icons.restaurant_menu, color: Colors.teal),
                title: const Text('وصفات المنتجات والتصنيع', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RecipeManagementScreen()));
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: Text(context.tr('home_logout')),
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
      body: _isLoadingLayout
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                // Banner for offline pending invoices
                if (unsyncedCount > 0)
                  Container(
                    color: Colors.orange[100],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${context.tr('home_offline_invoices_1')}$unsyncedCount${context.tr('home_offline_invoices_2')}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: posProvider.isLoading
                              ? null
                              : () async {
                                  final success =
                                      await posProvider.syncOfflineInvoices();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? (posProvider.successMessage ??
                                                  context.tr('home_sync_success'))
                                              : (posProvider.errorMessage ??
                                                  context.tr('home_sync_failed')),
                                          textAlign: TextAlign.right,
                                        ),
                                        backgroundColor:
                                            success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: posProvider.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync),
                          label: Text(context.tr('home_sync_now')),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                // Banner for offline pending vouchers
                if (unsyncedVouchers > 0)
                  Container(
                    color: Colors.blue[100],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_problem, color: Colors.blue, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${context.tr('home_offline_invoices_1')}$unsyncedVouchers${context.tr('home_offline_vouchers_2')}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: voucherProv.isLoading
                              ? null
                              : () async {
                                  final success = await voucherProv.syncOfflineVouchers();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(voucherProv.successMessage ?? voucherProv.errorMessage ?? '', textDirection: TextDirection.rtl),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: voucherProv.isLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.sync),
                          label: Text(context.tr('home_sync')),
                        ),
                      ],
                    ),
                  ),

                // Active Home Screen Layout Design
                Expanded(
                  child: _buildClassicLayout(context),
                ),
              ],
            ),
    );
  }

  // Layout 1: The Classic Grid Layout
  Widget _buildClassicLayout(BuildContext context) {
    final List<Widget> cards = [];

    // 1. Sales & POS group
    if (_showNewInvoice) {
      cards.add(_buildActionCard(
          context, context.tr('home_classic_new_invoice'), Icons.point_of_sale, Colors.blue,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PartnerSelectionScreen(type: 'Sales')));
      }));
    }
    if (_showCustomerSales) {
      cards.add(_buildActionCard(
          context, context.tr('home_premium_customer_sales'), Icons.local_offer, Colors.indigo,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PartnerOffersScreen(type: 'Sales')));
      }));
    }

    // 2. Purchases group
    if (_showNewPurchase) {
      cards.add(_buildActionCard(
          context, context.tr('home_classic_new_purchase'), Icons.shopping_basket, Colors.orange[800]!,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PartnerSelectionScreen(type: 'Purchase')));
      }));
    }
    if (_showSupplierPurchases) {
      cards.add(_buildActionCard(
          context, context.tr('home_premium_supplier_purchases'), Icons.local_offer_outlined, Colors.deepOrange,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PartnerOffersScreen(type: 'Purchases')));
      }));
    }

    // 3. Treasury / Vouchers group
    if (_showCustomerReceipts) {
      cards.add(_buildActionCard(
          context, context.tr('home_premium_customer_receipts'), Icons.arrow_circle_down_rounded, Colors.green[700]!,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReceiptVoucherScreen()));
      }));
    }
    if (_showSupplierPayments) {
      cards.add(_buildActionCard(
          context, context.tr('home_premium_supplier_payments'), Icons.arrow_circle_up_rounded, Colors.red[700]!,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PaymentVoucherScreen()));
      }));
    }

    // 4. Inventory group
    if (_showStockTake) {
      cards.add(_buildActionCard(
          context, context.tr('home_classic_stocktake'), Icons.inventory, Colors.teal,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const StockTakeScreen()));
      }));
    }
    if (_showWastage) {
      cards.add(_buildActionCard(
          context, context.tr('home_classic_wastage'), Icons.delete_sweep, Colors.amber[800]!,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const WastageScreen()));
      }));
    }
    final enableDailyOrders = Provider.of<SettingsProvider>(context).enableDailyOrders;
    if (_showDailyOrders && enableDailyOrders) {
      cards.add(_buildActionCard(
          context, context.tr('home_daily_orders'), Icons.local_shipping, Colors.purple,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const DailyOrdersScreen()));
      }));
    }
    final isProductionMode = Provider.of<SettingsProvider>(context).isProductionMode;
    if (_showRecipes && isProductionMode) {
      cards.add(_buildActionCard(
          context, 'وصفات المنتجات', Icons.restaurant_menu, Colors.green[700]!,
          () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const RecipeManagementScreen()));
      }));
    }

    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                context.tr('home_no_enabled_cards_warn'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
        children: cards,
      ),
    );
  }

  // Classic Action Card Builder
  Widget _buildActionCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
