import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../widgets/sales_chart_widget.dart';

class SalesTrendsTab extends StatelessWidget {
  const SalesTrendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final trends = provider.salesTrends;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Chart
          SalesChartWidget(salesTrends: trends, title: "تحليل حركة المبيعات وتدفق الأرباح 📈"),
          const SizedBox(height: 20),

          const Text(
            "تفاصيل المبيعات حسب اليوم / الفترة",
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : trends.isEmpty
                  ? const Center(child: Text("لا توجد بيانات للفترة المحددة", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: trends.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final t = trends[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    t.period,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    "عدد الفواتير: ${t.invoiceCount}",
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 14,
                                runSpacing: 6,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  _buildMiniMetric("نقد", "${currencyFormat.format(t.cashTotal)}", Colors.amber),
                                  if (t.cardTotal > 0)
                                    _buildMiniMetric("شبكة", "${currencyFormat.format(t.cardTotal)}", const Color(0xFF06B6D4)),
                                  if (t.creditTotal > 0)
                                    _buildMiniMetric("آجل", "${currencyFormat.format(t.creditTotal)}", const Color(0xFFEF4444)),
                                  _buildMiniMetric("المبيعات", "${currencyFormat.format(t.totalSales)}", Colors.white),
                                  _buildMiniMetric("الأرباح", "${currencyFormat.format(t.totalProfit)}", const Color(0xFF10B981)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
