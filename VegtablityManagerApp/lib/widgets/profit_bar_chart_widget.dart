import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/report_models.dart';

class ProfitBarChartWidget extends StatelessWidget {
  final List<ProductProfitModel> items;
  final String title;

  const ProfitBarChartWidget({
    super.key,
    required this.items,
    this.title = "أعلى الأصناف تحقيقاً للأرباح 🏆",
  });

  @override
  Widget build(BuildContext context) {
    final topItems = items.take(6).toList();

    if (topItems.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text("لا توجد بيانات كافية", style: TextStyle(color: Colors.grey)),
      );
    }

    final currencyFormat = NumberFormat('#,##0', 'ar');

    double maxVal = 0;
    for (var it in topItems) {
      if (it.totalProfit > maxVal) maxVal = it.totalProfit;
    }
    if (maxVal == 0) maxVal = 100;
    maxVal = maxVal * 1.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxVal,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = topItems[group.x.toInt()];
                      return BarTooltipItem(
                        "${item.productName}\nربح: ${currencyFormat.format(item.totalProfit)}",
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (val, meta) => Text(
                        currencyFormat.format(val),
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < topItems.length) {
                          final name = topItems[idx].productName;
                          final shortName = name.length > 8 ? name.substring(0, 7) + ".." : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortName,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => const FlLine(
                    color: Color(0xFF334155),
                    strokeWidth: 0.8,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(topItems.length, (idx) {
                  final it = topItems[idx];
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: it.totalProfit,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
