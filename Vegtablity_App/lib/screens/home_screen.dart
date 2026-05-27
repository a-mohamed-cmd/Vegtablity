import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _homeLayout = 'classic';
  bool _isLoadingLayout = true;

  @override
  void initState() {
    super.initState();
    _loadHomeLayout();
    
    // Refresh offline cache in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<VoucherProvider>(context, listen: false).refreshCache();
    });
  }

  Future<void> _loadHomeLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _homeLayout = prefs.getString('pref_home_layout') ?? 'classic';
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
        title: const Text('نظام الكاشير الذكي (POS)'),
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
          // Connection Status Indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('حالة السيرفر: ',
                    style: TextStyle(fontSize: 14, color: Colors.white)),
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
                  Text('مرحباً: ${authProvider.username ?? ''}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Devlope by Mohamed Ragab',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.settings_applications, color: Colors.teal),
              title: const Text('الإعدادات العامة'),
              onTap: _navigateToSettings,
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.teal),
              title: const Text('إعدادات الطابعة الحرارية'),
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
              leading: const Icon(Icons.analytics_outlined, color: Colors.teal),
              title: const Text('تقرير الفواتير اليومية'),
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
              title: const Text(
                'إغلاق الوردية',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
              title: const Text('سند قبض', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('تحصيل إيرادات (مباشر)', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GeneralReceiptVoucherScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_circle_up, color: Colors.orangeAccent),
              title: const Text('سند صرف', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('سداد مصروفات (مباشر)', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GeneralPaymentVoucherScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text('تسجيل الخروج'),
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
                            'لديك $unsyncedCount فاتورة/فواتير محفوظة محلياً (Offline) بانتظار المزامنة.',
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
                                                  'تمت المزامنة')
                                              : (posProvider.errorMessage ??
                                                  'فشلت المزامنة'),
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
                          label: const Text('مزامنة الآن'),
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
                            'لديك $unsyncedVouchers سند/سندات محفوظة محلياً بانتظار المزامنة.',
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
                          label: const Text('مزامنة'),
                        ),
                      ],
                    ),
                  ),

                // Active Home Screen Layout Design
                Expanded(
                  child: _homeLayout == 'partners_offers'
                      ? _buildPartnersOffersLayout(context)
                      : _buildClassicLayout(context),
                ),
              ],
            ),
    );
  }

  // Layout 1: The Classic Grid Layout
  Widget _buildClassicLayout(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          _buildActionCard(
              context, 'فاتورة مبيعات جديدة', Icons.point_of_sale, Colors.blue,
              () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PosScreen(type: 'Sales')));
          }),
          _buildActionCard(context, 'إدارة الموردين/العملاء', Icons.people,
              Colors.orange, () {}),
          _buildActionCard(
              context, 'استدعاء عرض مبيعات', Icons.receipt_long, Colors.purple,
              () {
            // Action for sales quotes
          }),
        ],
      ),
    );
  }

  // Layout 2: The New Premium Partners Offers Layout (Fully Independent UI)
  Widget _buildPartnersOffersLayout(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Two Beautiful, Massive Modern Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Sales Card (Customer Offers)
                  Expanded(
                    child: _buildGlowCard(
                      context,
                      title: 'مبيعات العملاء',
                      subtitle: '',
                      icon: Icons.point_of_sale_rounded,
                      color1: Colors.blue[700]!,
                      color2: Colors.teal[500]!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PartnerOffersScreen(type: 'Sales'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),

                  // 2. Purchases Card (Supplier Offers)
                  Expanded(
                    child: _buildGlowCard(
                      context,
                      title: 'مشتريات الموردين',
                      subtitle: '',
                      icon: Icons.shopping_basket_rounded,
                      color1: Colors.orange[700]!,
                      color2: Colors.deepOrange[400]!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PartnerOffersScreen(type: 'Purchases'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Second Row of Cards (Receipts & Payments)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 3. Receipts (Customer Collection)
                  Expanded(
                    child: _buildGlowCard(
                      context,
                      title: 'تحصيل العملاء',
                      subtitle: 'سندات قبض',
                      icon: Icons.arrow_circle_down_rounded,
                      color1: Colors.green[700]!,
                      color2: Colors.lightGreen[500]!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReceiptVoucherScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),

                  // 4. Payments (Supplier Payment)
                  Expanded(
                    child: _buildGlowCard(
                      context,
                      title: 'دفع الموردين',
                      subtitle: 'سندات صرف',
                      icon: Icons.arrow_circle_up_rounded,
                      color1: Colors.red[700]!,
                      color2: Colors.orangeAccent[400]!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PaymentVoucherScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        child: Container(
          width: 200,
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: color),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // Glow Card for Partners Offers Layout
  Widget _buildGlowCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
