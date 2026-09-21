import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class PaymentMethodsTab extends StatelessWidget {
  const PaymentMethodsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currency = authProvider.companySettings?.currencySymbol ?? 'ر.س';
    final methods = reportsProvider.paymentMethods;
    final fmt = NumberFormat('#,##0.00');

    if (reportsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (methods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'لا توجد بيانات طرق دفع مسجلة في هذه الفترة',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final totalCollected = methods.fold(0.0, (s, m) => s + m.totalCollected);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: methods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final m = methods[index];
        final ratio = totalCollected > 0 ? (m.totalCollected / totalCollected) * 100 : 0.0;

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
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFF8B5CF6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.paymentMethodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('عدد الفواتير: ${m.invoiceCount}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${fmt.format(m.totalCollected)} $currency', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${ratio.toStringAsFixed(1)}% من الإجمالي', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: totalCollected > 0 ? (m.totalCollected / totalCollected) : 0,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF8B5CF6),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
