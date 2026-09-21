import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class ShiftsAnalyticsTab extends StatelessWidget {
  const ShiftsAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currency = authProvider.companySettings?.currencySymbol ?? 'ر.س';
    final shifts = reportsProvider.shiftsAnalytics;
    final fmt = NumberFormat('#,##0.00');

    if (reportsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'لا توجد ورديات مسجلة في هذه الفترة',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = shifts[index];
        final isOpen = s.status.toLowerCase() == 'open';

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isOpen ? Colors.green.shade50 : Colors.blueGrey.shade50,
                      child: Icon(
                        isOpen ? Icons.access_time_filled : Icons.check_circle_outline,
                        color: isOpen ? Colors.green : Colors.blueGrey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('وردية #${s.shiftID} - ${s.cashierName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('البدء: ${s.startTime}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOpen ? 'مفتوحة الآن' : 'مغلقة',
                        style: TextStyle(color: isOpen ? Colors.green.shade800 : Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _buildShiftCol('رصيد الافتتاح', '${fmt.format(s.startingCash)} $currency'),
                    _buildShiftCol('المبيعات', '${fmt.format(s.totalSales)} $currency', color: const Color(0xFF10B981)),
                    _buildShiftCol('المقبوضات', '${fmt.format(s.totalPaidCollected)} $currency', color: Colors.indigo),
                    _buildShiftCol('رصيد الإغلاق', '${fmt.format(s.endingCash)} $currency'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShiftCol(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color ?? Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
