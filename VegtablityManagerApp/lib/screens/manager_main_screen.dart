import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import '../widgets/company_selector_header.dart';
import '../widgets/date_range_filter_bar.dart';

import 'dashboard_overview_tab.dart';
import 'product_profits_tab.dart';
import 'invoice_profits_tab.dart';
import 'sales_trends_tab.dart';
import 'top_customers_tab.dart';
import 'aging_debt_tab.dart';
import 'inventory_valuation_tab.dart';
import 'slow_moving_tab.dart';
import 'expenses_analysis_tab.dart';
import 'category_profits_tab.dart';
import 'executive_pnl_tab.dart';
import 'customer_profitability_tab.dart';
import 'cashier_performance_tab.dart';
import 'payment_methods_tab.dart';
import 'wastage_analysis_tab.dart';
import 'shifts_analytics_tab.dart';
import 'login_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  const ManagerMainScreen({super.key});

  static const List<Map<String, dynamic>> tabs = [
    {"title": "لوحة المؤشرات", "icon": Icons.dashboard_rounded},
    {"title": "أرباح الأصناف", "icon": Icons.bar_chart_rounded},
    {"title": "أرباح الفواتير", "icon": Icons.receipt_long_rounded},
    {"title": "أرباح التصنيفات", "icon": Icons.category_rounded},
    {"title": "قائمة الأرباح P&L", "icon": Icons.account_balance_rounded},
    {"title": "ربحية العملاء", "icon": Icons.person_search_rounded},
    {"title": "حركة المبيعات", "icon": Icons.show_chart_rounded},
    {"title": "كبار العملاء", "icon": Icons.people_alt_rounded},
    {"title": "أعمار الديون", "icon": Icons.pending_actions_rounded},
    {"title": "تقييم المخزون", "icon": Icons.inventory_2_rounded},
    {"title": "الأصناف الراكدة", "icon": Icons.hourglass_bottom_rounded},
    {"title": "تحليل المصروفات", "icon": Icons.account_balance_wallet_rounded},
    {"title": "أداء الكاشير", "icon": Icons.badge_rounded},
    {"title": "طرق الدفع", "icon": Icons.payment_rounded},
    {"title": "الهالك والتوالف", "icon": Icons.delete_sweep_rounded},
    {"title": "حركة الورديات", "icon": Icons.schedule_rounded},
  ];

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarCollapsed = true; // الوضع الافتراضي هو الإغلاق (Closed by default)

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 10),
            Text("تسجيل الخروج", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "هل أنت متأكد من رغبتك في تسجيل الخروج من لوحة الإدارة؟",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("تسجيل الخروج"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isMobile = screenWidth < 600;
    final isCompact = screenWidth < 500;
    final selectedTab = provider.selectedTabIndex;
    final currentUser = authProvider.currentUser;
    final liveSettings = authProvider.companySettings;
    final companyDisplayName = (liveSettings != null && liveSettings.companyName.trim().isNotEmpty)
        ? liveSettings.companyName
        : provider.selectedCompany.name;

    final Widget bodyContent;
    switch (selectedTab) {
      case 0:
        bodyContent = const DashboardOverviewTab();
        break;
      case 1:
        bodyContent = const ProductProfitsTab();
        break;
      case 2:
        bodyContent = const InvoiceProfitsTab();
        break;
      case 3:
        bodyContent = const CategoryProfitsTab();
        break;
      case 4:
        bodyContent = const ExecutivePnLTab();
        break;
      case 5:
        bodyContent = const CustomerProfitabilityTab();
        break;
      case 6:
        bodyContent = const SalesTrendsTab();
        break;
      case 7:
        bodyContent = const TopCustomersTab();
        break;
      case 8:
        bodyContent = const AgingDebtTab();
        break;
      case 9:
        bodyContent = const InventoryValuationTab();
        break;
      case 10:
        bodyContent = const SlowMovingTab();
        break;
      case 11:
        bodyContent = const ExpensesAnalysisTab();
        break;
      case 12:
        bodyContent = const CashierPerformanceTab();
        break;
      case 13:
        bodyContent = const PaymentMethodsTab();
        break;
      case 14:
        bodyContent = const WastageAnalysisTab();
        break;
      case 15:
        bodyContent = const ShiftsAnalyticsTab();
        break;
      default:
        bodyContent = const DashboardOverviewTab();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
      drawer: isDesktop
          ? null
          : _buildMobileDrawer(
              context,
              provider,
              authProvider,
              selectedTab,
              companyDisplayName,
              currentUser,
            ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: isDesktop ? 12 : 4,
        leading: isDesktop
            ? null
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.amber, size: 26),
                tooltip: "القائمة الرئيسية",
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: Row(
          children: [
            Container(
              width: isMobile ? 36 : 44,
              height: isMobile ? 36 : 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/lettuce.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: Colors.green, size: 24),
                ),
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "لوحة الإدارة - $companyDisplayName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 13.5 : 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${ManagerMainScreen.tabs[selectedTab]["title"]}",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          currentUser != null && currentUser.username.isNotEmpty
                              ? currentUser.username
                              : "مدير النظام",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const CompanySelectorHeader(),
          SizedBox(width: isMobile ? 6 : 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(54),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DateRangeFilterBar(),
          ),
        ),
      ),
      body: isDesktop
          ? Row(
              children: [
                _buildDesktopSidebar(context, provider, selectedTab, isCompact),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    ReportsProvider provider,
    AuthProvider authProvider,
    int selectedTab,
    String companyDisplayName,
    dynamic currentUser,
  ) {
    return Drawer(
      backgroundColor: const Color(0xFF1E293B),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF131D31),
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/lettuce.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, color: Colors.green, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Colors.amber, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              currentUser != null && currentUser.username.isNotEmpty
                                  ? currentUser.username
                                  : "مدير النظام",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Navigation Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: ManagerMainScreen.tabs.length,
                itemBuilder: (ctx, idx) {
                  final tab = ManagerMainScreen.tabs[idx];
                  final isSelected = selectedTab == idx;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      tileColor: isSelected ? Colors.amber.withValues(alpha: 0.18) : Colors.transparent,
                      leading: Icon(
                        tab["icon"] as IconData,
                        color: isSelected ? Colors.amber : Colors.white70,
                        size: 21,
                      ),
                      title: Text(
                        tab["title"] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.arrow_back_ios_rounded, color: Colors.amber, size: 14)
                          : null,
                      onTap: () {
                        provider.setSelectedTabIndex(idx);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Logout Button
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                tileColor: Colors.red.withValues(alpha: 0.12),
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 21),
                title: const Text(
                  "تسجيل الخروج",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    ReportsProvider provider,
    int selectedTab,
    bool isCompact,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: _isSidebarCollapsed ? (isCompact ? 54 : 64) : (isCompact ? 200 : 230),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Collapse / Expand Toggle Button Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Tooltip(
              message: _isSidebarCollapsed ? "إظهار وتوسيع القائمة الرئيسية" : "إخفاء وتصغير القائمة",
              waitDuration: const Duration(milliseconds: 150),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isSidebarCollapsed ? 4 : 10,
                      vertical: _isSidebarCollapsed ? 8 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.15),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: _isSidebarCollapsed
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_open_rounded,
                                color: Colors.amber,
                                size: 22,
                              ),
                              SizedBox(height: 3),
                              Text(
                                "إظهار",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_rounded, color: Colors.amber, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "القائمة الرئيسية",
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    "إخفاء",
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 12),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: ManagerMainScreen.tabs.length,
              itemBuilder: (ctx, idx) {
                final tab = ManagerMainScreen.tabs[idx];
                final isSelected = selectedTab == idx;
                return Tooltip(
                  message: _isSidebarCollapsed ? (tab["title"] as String) : "",
                  waitDuration: const Duration(milliseconds: 250),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _isSidebarCollapsed ? 8 : 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      tileColor: isSelected ? Colors.amber.withValues(alpha: 0.18) : Colors.transparent,
                      leading: Icon(
                        tab["icon"] as IconData,
                        color: isSelected ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      title: _isSidebarCollapsed
                          ? null
                          : Text(
                              tab["title"] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12.5,
                              ),
                            ),
                      onTap: () => provider.setSelectedTabIndex(idx),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Logout Button at Bottom of Sidebar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: Tooltip(
              message: _isSidebarCollapsed ? "تسجيل الخروج" : "",
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 8 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                tileColor: Colors.red.withValues(alpha: 0.12),
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                title: _isSidebarCollapsed
                    ? null
                    : const Text(
                        "تسجيل الخروج",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                onTap: () => _confirmLogout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
