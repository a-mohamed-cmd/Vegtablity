import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report_models.dart';

class ProductProfitsTab extends StatefulWidget {
  const ProductProfitsTab({super.key});

  @override
  State<ProductProfitsTab> createState() => _ProductProfitsTabState();
}

class _ProductProfitsTabState extends State<ProductProfitsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');

    final items = provider.productProfits.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.productCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.categoryName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    double sumSales = 0;
    double sumCost = 0;
    double sumProfit = 0;
    for (var i in items) {
      sumSales += i.totalSales;
      sumCost += i.totalCost;
      sumProfit += i.totalProfit;
    }
    final avgMargin = sumSales > 0 ? (sumProfit / sumSales) * 100 : 0.0;

    return Column(
      children: [
        // Summary & Search Toolbar
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: "بحث باسم الصنف، الباركود، أو التصنيف...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.amber, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 10),
              // Summary Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPill("عدد الأصناف", "${items.length}", Colors.white70),
                    const SizedBox(width: 8),
                    _buildPill("المبيعات", "${currencyFormat.format(sumSales)} $currency", const Color(0xFF06B6D4)),
                    const SizedBox(width: 8),
                    _buildPill("التكلفة", "${currencyFormat.format(sumCost)} $currency", Colors.grey),
                    const SizedBox(width: 8),
                    _buildPill("صافي الربح", "${currencyFormat.format(sumProfit)} $currency", const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _buildPill("متوسط الهامش", "${avgMargin.toStringAsFixed(1)}%", Colors.amber),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : items.isEmpty
                  ? const Center(child: Text("لا توجد أصناف مباعة في هذه الفترة", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final it = items[idx];
                        return _buildProductCard(it, currencyFormat, currency);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPill(String label, String value, Color color) {
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

  Widget _buildProductCard(ProductProfitModel it, NumberFormat fmt, String currency) {
    final marginColor = it.profitMargin >= 25
        ? const Color(0xFF10B981)
        : (it.profitMargin >= 10 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: marginColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "هامش: ${it.profitMargin.toStringAsFixed(1)}%",
                  style: TextStyle(color: marginColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text("الكمية: ${it.quantitySold.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text("المبيعات: ${fmt.format(it.totalSales)} $currency", style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold)),
              Text("التكلفة: ${fmt.format(it.totalCost)} $currency", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text("الربح: ${fmt.format(it.totalProfit)} $currency", style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
