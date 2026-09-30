import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/kpi_card_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/profit_bar_chart_widget.dart';
import '../widgets/metric_detail_sheet.dart';
import '../models/dashboard_summary_model.dart';

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
          // KPI Cards Grid (All Clickable with Deep Details Drill-Down)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1150 ? 4 : (width > 650 ? 2 : 1);
              final aspectRatio = width > 1150 ? 1.7 : (width > 650 ? 2.1 : (width > 420 ? 2.4 : 2.1));
              final effectiveSummary = summary ?? DashboardSummaryModel.empty(provider.selectedCompany.id);

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
                    value: effectiveSummary.totalSales,
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFF06B6D4),
                    subtitle: "فواتير معتمدة للفترة المحددة",
                    onTap: () => MetricDetailSheet.show(
                      context: context,
                      type: MetricType.sales,
                      summary: effectiveSummary,
                    ),
                  ),
                  KpiCardWidget(
                    title: "صافي الأرباح المحققة",
                    value: effectiveSummary.totalProfit,
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF10B981),
                    subtitle: "هامش ربح: ${effectiveSummary.profitMarginPercent.toStringAsFixed(1)}%",
                    onTap: () => MetricDetailSheet.show(
                      context: context,
                      type: MetricType.profit,
                      summary: effectiveSummary,
                    ),
                  ),
                  KpiCardWidget(
                    title: "عدد الفواتير المنفذة",
                    value: effectiveSummary.totalInvoices.toDouble(),
                    isCurrency: false,
                    suffix: "فاتورة",
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFF59E0B),
                    subtitle: "متوسط الفاتورة: ${effectiveSummary.averageTicket.toStringAsFixed(2)}",
                    onTap: () => MetricDetailSheet.show(
                      context: context,
                      type: MetricType.invoices,
                      summary: effectiveSummary,
                    ),
                  ),
                  KpiCardWidget(
                    title: "الذمم والديون المتبقية",
                    value: effectiveSummary.totalReceivables,
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFEF4444),
                    subtitle: "مستحقات آجلة لدى العملاء",
                    onTap: () => MetricDetailSheet.show(
                      context: context,
                      type: MetricType.receivables,
                      summary: effectiveSummary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Charts Section with Fast Tab Navigation
          if (isMobile) ...[
            SalesChartWidget(
              salesTrends: provider.salesTrends,
              onHeaderTap: () => provider.setSelectedTabIndex(6),
            ),
            const SizedBox(height: 16),
            ProfitBarChartWidget(
              items: provider.productProfits,
              onHeaderTap: () => provider.setSelectedTabIndex(1),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SalesChartWidget(
                    salesTrends: provider.salesTrends,
                    onHeaderTap: () => provider.setSelectedTabIndex(6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ProfitBarChartWidget(
                    items: provider.productProfits,
                    onHeaderTap: () => provider.setSelectedTabIndex(1),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Top Customers Summary Snippet (Fully Clickable for Details)
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
                        "أعلى العملاء نشاطاً ومشتريات 🌟 (اضغط على العميل لعرض التفاصيل)",
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => provider.setSelectedTabIndex(7), // Corrected to Tab 7 (Top Customers)
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
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => CustomerDetailSheet.show(
                            context: context,
                            customer: cust,
                            rank: idx + 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          hoverColor: Colors.amber.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                  child: Text(
                                    "${idx + 1}",
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cust.partnerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "عدد الفواتير: ${cust.invoiceCount}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${currencyFormat.format(cust.totalSales)} $currency",
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("تفاصيل", style: TextStyle(color: Colors.amber, fontSize: 10)),
                                        SizedBox(width: 2),
                                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 9),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
