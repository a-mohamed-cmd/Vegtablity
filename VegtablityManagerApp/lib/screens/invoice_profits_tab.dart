import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report_models.dart';

class InvoiceProfitsTab extends StatelessWidget {
  const InvoiceProfitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final invoices = provider.invoiceProfits;

    double sumNet = 0;
    double sumProfit = 0;
    for (var inv in invoices) {
      sumNet += inv.netTotal;
      sumProfit += inv.totalProfit;
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
                _buildHeaderPill("إجمالي الفواتير", "${invoices.length}", Colors.white70),
                const SizedBox(width: 8),
                _buildHeaderPill("صافي المبيعات", "${currencyFormat.format(sumNet)} $currency", const Color(0xFF06B6D4)),
                const SizedBox(width: 8),
                _buildHeaderPill("صافي الأرباح", "${currencyFormat.format(sumProfit)} $currency", const Color(0xFF10B981)),
              ],
            ),
          ),
        ),

        // Invoices List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : invoices.isEmpty
                  ? const Center(child: Text("لا توجد فواتير في هذه الفترة", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final inv = invoices[idx];
                        return _buildInvoiceCard(inv, currencyFormat, currency);
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

  Widget _buildInvoiceCard(InvoiceProfitModel inv, NumberFormat fmt, String currency) {
    final marginColor = inv.profitMargin >= 25
        ? const Color(0xFF10B981)
        : (inv.profitMargin >= 10 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

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
              Row(
                children: [
                  const Icon(Icons.receipt_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "#${inv.invoiceNumber}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: marginColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "هامش: ${inv.profitMargin.toStringAsFixed(1)}%",
                  style: TextStyle(color: marginColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "العميل: ${inv.customerName.isNotEmpty ? inv.customerName : 'عميل نقدي'}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              if (inv.cashierName.isNotEmpty)
                Text(
                  "الكاشير: ${inv.cashierName}",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text("الإجمالي: ${fmt.format(inv.netTotal)} $currency", style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12)),
              Text("التكلفة: ${fmt.format(inv.totalCost)} $currency", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text("الربح: ${fmt.format(inv.totalProfit)} $currency", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
