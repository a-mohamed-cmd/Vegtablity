import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_summary_model.dart';
import '../models/report_models.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

enum MetricType {
  sales,
  profit,
  invoices,
  receivables,
}

class MetricDetailSheet {
  static void show({
    required BuildContext context,
    required MetricType type,
    required DashboardSummaryModel summary,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildSheetContent(ctx, type, summary, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _buildSheetContent(ctx, type, summary, isDialog: false),
        ),
      );
    }
  }

  static Widget _buildSheetContent(
    BuildContext context,
    MetricType type,
    DashboardSummaryModel summary, {
    required bool isDialog,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final fmt = NumberFormat('#,##0.00', 'ar');

    final String title;
    final IconData icon;
    final Color color;
    final String mainValue;
    final String subtitle;
    final List<_MetricItem> items;
    final List<_ActionNav> actions;

    switch (type) {
      case MetricType.sales:
        title = "تفاصيل إجمالي المبيعات";
        icon = Icons.point_of_sale_rounded;
        color = const Color(0xFF06B6D4);
        mainValue = "${fmt.format(summary.totalSales)} $currency";
        subtitle = "من قيود اليومية المحاسبية للفترة المحددة";

        final cashPercent = summary.totalSales > 0 ? (summary.totalPaid / summary.totalSales) * 100 : 0.0;
        final creditPercent = summary.totalSales > 0 ? (summary.totalCredit / summary.totalSales) * 100 : 0.0;

        items = [
          _MetricItem(
            label: "المقبوضات النقدية (الكاش)",
            value: "${fmt.format(summary.totalPaid)} $currency",
            note: "نسبة التحصيل: ${cashPercent.toStringAsFixed(1)}%",
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
            progress: (cashPercent / 100).clamp(0.0, 1.0),
          ),
          _MetricItem(
            label: "المبيعات الآجلة (ذمم عملاء)",
            value: "${fmt.format(summary.totalCredit)} $currency",
            note: "نسبة الآجل: ${creditPercent.toStringAsFixed(1)}%",
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF59E0B),
            progress: (creditPercent / 100).clamp(0.0, 1.0),
          ),
          _MetricItem(
            label: "إجمالي الخصومات الممنوحة",
            value: "${fmt.format(summary.totalDiscounts)} $currency",
            note: "خصومات الفواتير والترويج",
            icon: Icons.discount_rounded,
            color: Colors.purpleAccent,
          ),
          _MetricItem(
            label: "عدد الفواتير المنفذة",
            value: "${summary.totalInvoices} فاتورة",
            note: "متوسط الفاتورة: ${fmt.format(summary.averageTicket)} $currency",
            icon: Icons.pin_rounded,
            color: Colors.white70,
          ),
        ];

        actions = [
          _ActionNav(
            title: "عرض حركة المبيعات اليومية",
            icon: Icons.show_chart_rounded,
            tabIndex: 6,
          ),
          _ActionNav(
            title: "استعراض أرباح الفواتير",
            icon: Icons.receipt_long_rounded,
            tabIndex: 2,
          ),
        ];
        break;

      case MetricType.profit:
        title = "تفاصيل صافي الأرباح المحققة";
        icon = Icons.trending_up_rounded;
        color = const Color(0xFF10B981);
        mainValue = "${fmt.format(summary.totalProfit)} $currency";
        subtitle = "هامش الربح الصافي: ${summary.profitMarginPercent.toStringAsFixed(1)}%";

        items = [
          _MetricItem(
            label: "إجمالي حجم المبيعات",
            value: "${fmt.format(summary.totalSales)} $currency",
            note: "أساس حساب الإيراد",
            icon: Icons.sell_rounded,
            color: const Color(0xFF06B6D4),
          ),
          _MetricItem(
            label: "الربح الإجمالي (Gross Profit)",
            value: "${fmt.format(summary.grossProfit)} $currency",
            note: "الإيرادات ناقص تكلفة البضاعة المباعة",
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF10B981),
          ),
          _MetricItem(
            label: "المصروفات التشغيلية المخصومة",
            value: "${fmt.format(summary.totalExpenses)} $currency",
            note: "من قيود حسابات المصروفات",
            icon: Icons.money_off_rounded,
            color: const Color(0xFFEF4444),
          ),
          _MetricItem(
            label: "صافي الأرباح التشغيلية",
            value: "${fmt.format(summary.totalProfit)} $currency",
            note: "الربح النهائي بعد خصم المصروفات",
            icon: Icons.stars_rounded,
            color: Colors.amber,
          ),
        ];

        actions = [
          _ActionNav(
            title: "قائمة الأرباح والخسائر P&L",
            icon: Icons.account_balance_rounded,
            tabIndex: 4,
          ),
          _ActionNav(
            title: "أرباح الأصناف وهوامشها",
            icon: Icons.bar_chart_rounded,
            tabIndex: 1,
          ),
        ];
        break;

      case MetricType.invoices:
        title = "تفاصيل حركة وعدد الفواتير";
        icon = Icons.receipt_long_rounded;
        color = const Color(0xFFF59E0B);
        mainValue = "${summary.totalInvoices} فاتورة";
        subtitle = "متوسط الفاتورة: ${fmt.format(summary.averageTicket)} $currency";

        items = [
          _MetricItem(
            label: "متوسط سلة المشتريات / الفاتورة",
            value: "${fmt.format(summary.averageTicket)} $currency",
            note: "معدل إنفاق العميل لكل فاتورة",
            icon: Icons.shopping_bag_rounded,
            color: const Color(0xFFF59E0B),
          ),
          _MetricItem(
            label: "إجمالي قيمة الفواتير",
            value: "${fmt.format(summary.totalSales)} $currency",
            note: "قيمة المبيعات المحققة",
            icon: Icons.point_of_sale_rounded,
            color: const Color(0xFF06B6D4),
          ),
          _MetricItem(
            label: "المقبوضات النقدية المباشرة",
            value: "${fmt.format(summary.totalPaid)} $currency",
            note: "تحصيل فوري عند البيع",
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
          ),
          _MetricItem(
            label: "المبيعات الآجلة على الحساب",
            value: "${fmt.format(summary.totalCredit)} $currency",
            note: "فواتير لم تسدد بالكامل",
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFEF4444),
          ),
        ];

        actions = [
          _ActionNav(
            title: "استعراض تفاصيل أرباح الفواتير",
            icon: Icons.receipt_long_rounded,
            tabIndex: 2,
          ),
          _ActionNav(
            title: "تقرير أداء ومبيعات الكاشير",
            icon: Icons.badge_rounded,
            tabIndex: 12,
          ),
        ];
        break;

      case MetricType.receivables:
        title = "تفاصيل الذمم والديون المتبقية";
        icon = Icons.pending_actions_rounded;
        color = const Color(0xFFEF4444);
        mainValue = "${fmt.format(summary.totalReceivables)} $currency";
        final debtRatio = summary.totalSales > 0 ? (summary.totalReceivables / summary.totalSales) * 100 : 0.0;
        subtitle = "نسبة الديون من مبيعات الفترة: ${debtRatio.toStringAsFixed(1)}%";

        items = [
          _MetricItem(
            label: "إجمالي الذمم والديون القائمة",
            value: "${fmt.format(summary.totalReceivables)} $currency",
            note: "مستحقات على العملاء قيد التحصيل",
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444),
          ),
          _MetricItem(
            label: "مبيعات الفترة الآجلة",
            value: "${fmt.format(summary.totalCredit)} $currency",
            note: "فواتير آجلة صادرة خلال الفترة",
            icon: Icons.credit_card_rounded,
            color: const Color(0xFFF59E0B),
          ),
          _MetricItem(
            label: "إجمالي التحصيلات النقدية",
            value: "${fmt.format(summary.totalPaid)} $currency",
            note: "سداد نقدي تم إيداعه",
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
          ),
        ];

        actions = [
          _ActionNav(
            title: "تقرير أعمار الديون والمطالبات",
            icon: Icons.pending_actions_rounded,
            tabIndex: 8,
          ),
          _ActionNav(
            title: "أرصدة ومشتريات كبار العملاء",
            icon: Icons.people_alt_rounded,
            tabIndex: 7,
          ),
        ];
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(24),
          bottom: isDialog ? const Radius.circular(24) : Radius.zero,
        ),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle for bottom sheet
          if (!isDialog)
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Big Number Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "القيمة الإجمالية:",
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  mainValue,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Breakdown List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 14),
              itemBuilder: (ctx, idx) {
                final it = items[idx];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(it.icon, color: it.color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            it.label,
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ),
                        Text(
                          it.value,
                          style: TextStyle(color: it.color, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    if (it.note != null) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Text(
                          it.note!,
                          style: const TextStyle(color: Colors.grey, fontSize: 10.5),
                        ),
                      ),
                    ],
                    if (it.progress != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: it.progress,
                            minHeight: 5,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(it.color),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Action Navigation Buttons
          Row(
            children: actions.map((act) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.amber,
                      elevation: 0,
                      side: const BorderSide(color: Colors.amber, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      reportsProvider.setSelectedTabIndex(act.tabIndex);
                    },
                    icon: Icon(act.icon, size: 16),
                    label: Text(
                      act.title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class CustomerDetailSheet {
  static void show({
    required BuildContext context,
    required TopCustomerModel customer,
    required int rank,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _buildCustomerContent(ctx, customer, rank, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _buildCustomerContent(ctx, customer, rank, isDialog: false),
        ),
      );
    }
  }

  static Widget _buildCustomerContent(
    BuildContext context,
    TopCustomerModel customer,
    int rank, {
    required bool isDialog,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final fmt = NumberFormat('#,##0.00', 'ar');

    final payPercent = customer.totalSales > 0 ? (customer.totalPaid / customer.totalSales) * 100 : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(24),
          bottom: isDialog ? const Radius.circular(24) : Radius.zero,
        ),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDialog)
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                child: Text(
                  "#$rank",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.partnerName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.partnerPhone.isNotEmpty ? "هاتف: ${customer.partnerPhone}" : "عميل مسجل",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Purchases & Payment Highlights
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("إجمالي المشتريات:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      "${fmt.format(customer.totalSales)} $currency",
                      style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المسدد نقداً:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      "${fmt.format(customer.totalPaid)} $currency",
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المديونية المتبقية:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      "${fmt.format(customer.remainingDebt)} $currency",
                      style: TextStyle(
                        color: customer.remainingDebt > 0 ? const Color(0xFFEF4444) : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (payPercent / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "نسبة السداد: ${payPercent.toStringAsFixed(1)}%",
                    style: const TextStyle(color: Colors.grey, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Invoices badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  "عدد الفواتير الصادرة للعميل: ${customer.invoiceCount} فاتورة",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    reportsProvider.setSelectedTabIndex(7); // Top Customers Tab
                  },
                  icon: const Icon(Icons.people_alt_rounded, size: 16),
                  label: const Text("تقرير كبار العملاء", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    reportsProvider.setSelectedTabIndex(5); // Customer Profitability Tab
                  },
                  icon: const Icon(Icons.query_stats_rounded, size: 16),
                  label: const Text("ربحية العملاء", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final String? note;
  final IconData icon;
  final Color color;
  final double? progress;

  _MetricItem({
    required this.label,
    required this.value,
    this.note,
    required this.icon,
    required this.color,
    this.progress,
  });
}

class _ActionNav {
  final String title;
  final IconData icon;
  final int tabIndex;

  _ActionNav({
    required this.title,
    required this.icon,
    required this.tabIndex,
  });
}
