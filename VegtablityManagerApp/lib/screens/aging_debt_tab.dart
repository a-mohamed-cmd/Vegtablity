import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report_models.dart';

class AgingDebtTab extends StatelessWidget {
  const AgingDebtTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final debts = provider.agingDebts;

    double bucket030 = 0;
    double bucket3160 = 0;
    double bucket6190 = 0;
    double bucket90Plus = 0;
    double totalDebt = 0;

    for (var d in debts) {
      totalDebt += d.remainingAmount;
      if (d.daysOverdue > 90) {
        bucket90Plus += d.remainingAmount;
      } else if (d.daysOverdue > 60) {
        bucket6190 += d.remainingAmount;
      } else if (d.daysOverdue > 30) {
        bucket3160 += d.remainingAmount;
      } else {
        bucket030 += d.remainingAmount;
      }
    }

    return Column(
      children: [
        // Buckets Overview Card
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF1E293B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "إجمالي الديون والذمم:",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${currencyFormat.format(totalDebt)} $currency",
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBucketCard("0 - 30 يوم", bucket030, const Color(0xFF10B981), currencyFormat, currency),
                    const SizedBox(width: 8),
                    _buildBucketCard("31 - 60 يوم", bucket3160, const Color(0xFFF59E0B), currencyFormat, currency),
                    const SizedBox(width: 8),
                    _buildBucketCard("61 - 90 يوم", bucket6190, const Color(0xFFF97316), currencyFormat, currency),
                    const SizedBox(width: 8),
                    _buildBucketCard("أكثر من 90 يوم ⚠️", bucket90Plus, const Color(0xFFEF4444), currencyFormat, currency),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Debts List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber))
              : debts.isEmpty
                  ? const Center(child: Text("لا توجد فواتير متأخرة أو ديون قائمة 🎉", style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: debts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final d = debts[idx];
                        return _buildDebtCard(d, currencyFormat, currency);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBucketCard(String title, double amount, Color color, NumberFormat fmt, String currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            "${fmt.format(amount)} $currency",
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(AgingDebtModel d, NumberFormat fmt, String currency) {
    final isDanger = d.daysOverdue > 60;
    final badgeColor = d.daysOverdue > 90
        ? const Color(0xFFEF4444)
        : (d.daysOverdue > 60 ? const Color(0xFFF97316) : (d.daysOverdue > 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDanger ? Colors.red.withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  d.partnerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "تأخير: ${d.daysOverdue} يوم",
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
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
              Text("فاتورة #${d.invoiceNumber}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text("التاريخ: ${d.invoiceDate.split('T').first}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              Text(
                "المبلغ المتبقي: ${fmt.format(d.remainingAmount)} $currency",
                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
