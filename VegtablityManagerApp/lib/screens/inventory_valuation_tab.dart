import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report_models.dart';

class InventoryValuationTab extends StatelessWidget {
  const InventoryValuationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final items = provider.inventoryValuation;

    double totalCost = 0;
    double totalSale = 0;
    for (var it in items) {
      totalCost += it.totalCostValue;
      totalSale += it.totalSaleValue;
    }
    final potentialProfit = totalSale - totalCost;

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
                _buildHeaderPill("الأصناف", "${items.length}", Colors.white70),
                const SizedBox(width: 8),
                _buildHeaderPill("قيمة التكلفة", "${currencyFormat.format(totalCost)} $currency", const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildHeaderPill("قيمة البيع", "${currencyFormat.format(totalSale)} $currency", const Color(0xFF06B6D4)),
                const SizedBox(width: 8),
                _buildHeaderPill("الأرباح المتوقعة", "${currencyFormat.format(potentialProfit)} $currency", const Color(0xFF10B981)),
              ],
            ),
          ),
        ),

        // Items List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : items.isEmpty
                  ? const Center(child: Text("لا توجد بيانات مخزون متاحة", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final it = items[idx];
                        return _buildItemCard(it, currencyFormat, currency);
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

  Widget _buildItemCard(InventoryValuationModel it, NumberFormat fmt, String currency) {
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
                  color: Colors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "المخزون: ${it.currentStock.toStringAsFixed(1)}",
                  style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "المستودع: ${it.warehouseName} | الكود: ${it.productCode}",
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const Divider(color: Colors.white10, height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text("سعر التكلفة: ${fmt.format(it.purchasePrice)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text("سعر البيع: ${fmt.format(it.sellingPrice)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text("إجمالي التكلفة: ${fmt.format(it.totalCostValue)} $currency", style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
              Text("إجمالي البيع: ${fmt.format(it.totalSaleValue)} $currency", style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
