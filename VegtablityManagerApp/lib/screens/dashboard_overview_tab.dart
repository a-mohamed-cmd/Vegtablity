import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/kpi_card_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/profit_bar_chart_widget.dart';

class DashboardOverviewTab extends StatelessWidget {
  const DashboardOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final summary = provider.dashboardSummary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final isCompact = screenWidth < 400;

    if (summary == null && provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    final currencyFormat = NumberFormat('#,##0.00', 'ar');

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1150 ? 4 : (width > 650 ? 2 : 1);
              final aspectRatio = width > 1150 ? 1.7 : (width > 650 ? 2.1 : (width > 420 ? 2.4 : 2.1));

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: aspectRatio,
                children: [
                  KpiCardWidget(
                    title: "إجمالي المبيعات",
                    value: summary?.totalSales ?? 0.0,
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFF06B6D4),
                    subtitle: "من قيود اليومية المحاسبية",
                  ),
                  KpiCardWidget(
                    title: "صافي الأرباح المحققة",
                    value: summary?.totalProfit ?? 0.0,
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF10B981),
                    subtitle: "هامش ربح: ${summary?.profitMarginPercent.toStringAsFixed(1) ?? '0.0'}%",
                  ),
                  KpiCardWidget(
                    title: "عدد الفواتير المنفذة",
                    value: (summary?.totalInvoices ?? 0).toDouble(),
                    isCurrency: false,
                    suffix: "فاتورة",
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFF59E0B),
                    subtitle: "متوسط الفاتورة: ${summary?.averageTicket.toStringAsFixed(2) ?? '0.0'}",
                  ),
                  KpiCardWidget(
                    title: "الذمم والديون المتبقية",
                    value: summary?.totalReceivables ?? 0.0,
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFEF4444),
                    subtitle: "مستحقات آجلة لدى العملاء",
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Charts Section (Sales Line + Top Profitable Bar)
          if (isMobile) ...[
            SalesChartWidget(salesTrends: provider.salesTrends),
            const SizedBox(height: 16),
            ProfitBarChartWidget(items: provider.productProfits),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SalesChartWidget(salesTrends: provider.salesTrends),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ProfitBarChartWidget(items: provider.productProfits),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Top Customers Summary Snippet
          if (provider.topCustomers.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(isCompact ? 14 : 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "أعلى العملاء نشاطاً ومشتريات 🌟",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => provider.setSelectedTabIndex(4),
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.amber, size: 16),
                        label: const Text("عرض التقرير الكامل", style: TextStyle(color: Colors.amber, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.topCustomers.take(4).length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (ctx, idx) {
                      final cust = provider.topCustomers[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.amber.withValues(alpha: 0.15),
                          child: Text("${idx + 1}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text(
                          cust.partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text("عدد الفواتير: ${cust.invoiceCount}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        trailing: Text(
                          "${currencyFormat.format(cust.totalSales)} $currency",
                          style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
