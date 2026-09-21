import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';

class ExpensesAnalysisTab extends StatelessWidget {
  const ExpensesAnalysisTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final expenses = provider.expensesAnalysis;

    double totalExp = 0;
    for (var ex in expenses) {
      totalExp += ex.totalAmount;
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
                _buildHeaderPill("بنود المصروفات", "${expenses.length}", Colors.white70),
                const SizedBox(width: 8),
                _buildHeaderPill("إجمالي المصروفات التشغيلية", "${currencyFormat.format(totalExp)} $currency", const Color(0xFFEF4444)),
              ],
            ),
          ),
        ),

        // List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : expenses.isEmpty
                  ? const Center(child: Text("لا توجد قيود مصروفات مسجلة في هذه الفترة", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final ex = expenses[idx];
                        final pct = totalExp > 0 ? (ex.totalAmount / totalExp) * 100 : 0.0;

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
                                      ex.accountName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${currencyFormat.format(ex.totalAmount)} $currency",
                                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("كود الحساب: ${ex.accountCode}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text("النسبة: ${pct.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (pct / 100).clamp(0.0, 1.0),
                                  backgroundColor: const Color(0xFF0F172A),
                                  color: Colors.redAccent,
                                  minHeight: 5,
                                ),
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
