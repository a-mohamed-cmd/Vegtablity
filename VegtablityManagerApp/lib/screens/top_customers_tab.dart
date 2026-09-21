import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report_models.dart';

class TopCustomersTab extends StatelessWidget {
  const TopCustomersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final customers = provider.topCustomers;

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
                _buildHeaderPill("أهم العملاء", "${customers.length}", Colors.white70),
                const SizedBox(width: 8),
                const Text(
                  "مرتبة حسب إجمالي المشتريات 🌟",
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),

        // Customers List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : customers.isEmpty
                  ? const Center(child: Text("لا توجد بيانات عملاء في هذه الفترة", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: customers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final cust = customers[idx];
                        return _buildCustomerCard(cust, idx + 1, currencyFormat, currency);
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

  Widget _buildCustomerCard(TopCustomerModel cust, int rank, NumberFormat fmt, String currency) {
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                      child: Text("$rank", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cust.partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              if (cust.partnerPhone.isNotEmpty)
                Text(
                  cust.partnerPhone,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text("الفواتير: ${cust.invoiceCount}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text("المبيعات: ${fmt.format(cust.totalSales)} $currency", style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12)),
              Text("المدفوع: ${fmt.format(cust.totalPaid)} $currency", style: const TextStyle(color: Color(0xFF10B981), fontSize: 11)),
              if (cust.remainingDebt > 0)
                Text(
                  "المتبقي: ${fmt.format(cust.remainingDebt)} $currency",
                  style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
