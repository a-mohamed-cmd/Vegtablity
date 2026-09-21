import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';

class SlowMovingTab extends StatelessWidget {
  const SlowMovingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final items = provider.slowMovingStock;

    double stagnantCost = 0;
    for (var it in items) {
      stagnantCost += it.totalCostValue;
    }

    return Column(
      children: [
        // Summary Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF1E293B),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHeaderPill("الأصناف الراكدة", "${items.length}", Colors.white70),
                const SizedBox(width: 8),
                _buildHeaderPill("إجمالي رأس المال المجمد", "${currencyFormat.format(stagnantCost)} $currency", const Color(0xFFEF4444)),
              ],
            ),
          ),
        ),

        // List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : items.isEmpty
                  ? const Center(child: Text("لا توجد أصناف راكدة - حركة المبيعات ممتازة 👍", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final it = items[idx];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      it.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "راكد منذ: ${it.daysInactive} يوم",
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Text("الكمية المتوفرة: ${it.currentStock.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text("سعر الشراء: ${currencyFormat.format(it.purchasePrice)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text(
                                    "القيمة المجمدة: ${currencyFormat.format(it.totalCostValue)} $currency",
                                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildHeaderPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
