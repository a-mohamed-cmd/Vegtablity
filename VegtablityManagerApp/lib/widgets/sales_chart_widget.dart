import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/report_models.dart';

class SalesChartWidget extends StatelessWidget {
  final List<SalesTrendModel> salesTrends;
  final String title;

  const SalesChartWidget({
    super.key,
    required this.salesTrends,
    this.title = "منحنى المبيعات والأرباح اليومية",
  });

  @override
  Widget build(BuildContext context) {
    if (salesTrends.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text("لا توجد بيانات مبيعات كافية للرسم البياني", style: TextStyle(color: Colors.grey)),
      );
    }

    final currencyFormat = NumberFormat('#,##0', 'ar');

    // Prepare spots for sales
    final List<FlSpot> salesSpots = [];
    final List<FlSpot> profitSpots = [];

    for (int i = 0; i < salesTrends.length; i++) {
      salesSpots.add(FlSpot(i.toDouble(), salesTrends[i].totalSales));
      profitSpots.add(FlSpot(i.toDouble(), salesTrends[i].totalProfit));
    }

    double maxY = 0.0;
    for (var s in salesTrends) {
      if (s.totalSales > maxY) maxY = s.totalSales;
    }
    if (maxY == 0) maxY = 1000;
    maxY = maxY * 1.15; // padding top

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegend(color: const Color(0xFF06B6D4), label: "المبيعات"),
                  const SizedBox(width: 12),
                  _buildLegend(color: const Color(0xFF10B981), label: "الأرباح"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (salesTrends.length - 1).toDouble().clamp(0, 100),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFF334155),
                    strokeWidth: 0.8,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const Text("");
                        return Text(
                          currencyFormat.format(val),
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (salesTrends.length / 6).clamp(1, 10),
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < salesTrends.length) {
                          final p = salesTrends[idx].period;
                          final short = p.length > 5 ? p.substring(p.length - 5) : p;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(short, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          );
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Sales Line (Cyan)
                  LineChartBarData(
                    spots: salesSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF06B6D4),
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF06B6D4).withValues(alpha: 0.35),
                          const Color(0xFF06B6D4).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Profit Line (Green)
                  LineChartBarData(
                    spots: profitSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981).withValues(alpha: 0.25),
                          const Color(0xFF10B981).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
