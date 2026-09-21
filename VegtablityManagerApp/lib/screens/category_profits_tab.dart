import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class CategoryProfitsTab extends StatelessWidget {
  const CategoryProfitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currency = authProvider.companySettings?.currencySymbol ?? 'ر.س';
    final categories = reportsProvider.categoryProfits;
    final fmt = NumberFormat('#,##0.00');

    if (reportsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'لا توجد بيانات أرباح تصنيفات في هذه الفترة',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final totalSales = categories.fold(0.0, (s, c) => s + c.totalSales);
    final totalProfit = categories.fold(0.0, (s, c) => s + c.netProfit);
    final overallMargin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header KPI summary card
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: isSmall
                    ? Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('إجمالي المبيعات', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('${fmt.format(totalSales)} $currency', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('صافي الأرباح', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('${fmt.format(totalProfit)} $currency', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Colors.white12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('متوسط هامش الربح:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('${overallMargin.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('إجمالي مبيعات التصنيفات', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('${fmt.format(totalSales)} $currency', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.white24),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('صافي أرباح التصنيفات', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('${fmt.format(totalProfit)} $currency', style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1, height: 40, color: Colors.white24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('متوسط هامش الربح', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('${overallMargin.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 20),

          Text('قائمة التصنيفات الأكثر ربحية (${categories.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final profitRatio = totalProfit > 0 ? (cat.netProfit / totalProfit) * 100 : 0.0;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                            child: const Icon(Icons.category, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('عدد الأصناف: ${cat.productCount} • الكمية المباعة: ${fmt.format(cat.quantitySold)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${fmt.format(cat.netProfit)} $currency', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('هامش: ${cat.profitMargin.toStringAsFixed(1)}%', style: TextStyle(color: cat.profitMargin >= 0 ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المبيعات: ${fmt.format(cat.totalSales)} $currency', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('التكلفة: ${fmt.format(cat.totalCost)} $currency', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('مساهمة بالربح: ${profitRatio.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
