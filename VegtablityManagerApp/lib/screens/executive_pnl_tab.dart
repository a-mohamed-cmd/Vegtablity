import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class ExecutivePnLTab extends StatelessWidget {
  const ExecutivePnLTab({super.key});

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currency = authProvider.companySettings?.currencySymbol ?? 'ر.س';
    final pnl = reportsProvider.executivePnL;
    final fmt = NumberFormat('#,##0.00');

    if (reportsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Summary Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: pnl.netOperatingProfit >= 0
                    ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                    : [const Color(0xFF7F1D1D), const Color(0xFFB91C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                const Text('صافي الربح التشغيلي للفترة (Net Operating Profit)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${fmt.format(pnl.netOperatingProfit)} $currency',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'هامش صافي الربح: ${pnl.netProfitMargin.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // PnL Statement Breakdown Table
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('قائمة الأرباح والخسائر التفصيلية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPnLRow('إجمالي الإيرادات (Gross Sales)', pnl.grossRevenue, currency, fmt, isHeader: false, color: Colors.blue.shade700),
                  _buildPnLRow('(-) الخصومات والتخفيضات (Discounts)', -pnl.totalDiscounts, currency, fmt, isNegative: true),
                  const Divider(height: 24),
                  _buildPnLRow('(=) صافي الإيرادات (Net Revenue)', pnl.netRevenue, currency, fmt, isBold: true, color: Colors.black87),
                  _buildPnLRow('(-) تكلفة البضاعة المباعة (COGS)', -pnl.costOfGoodsSold, currency, fmt, isNegative: true),
                  const Divider(height: 24),
                  _buildPnLRow(
                    '(=) مجمل الربح (Gross Profit)',
                    pnl.grossProfit,
                    currency,
                    fmt,
                    isBold: true,
                    subtitle: 'هامش مجمل الربح: ${pnl.grossProfitMargin.toStringAsFixed(1)}%',
                    color: const Color(0xFF10B981),
                  ),
                  const Divider(height: 24),
                  _buildPnLRow('(-) المصروفات التشغيلية (Operating Expenses)', -pnl.operatingExpenses, currency, fmt, isNegative: true),
                  _buildPnLRow('(-) خسائر الهالك والتوالف (Wastage Losses)', -pnl.wastageLoss, currency, fmt, isNegative: true),
                  const Divider(height: 28, thickness: 2),
                  _buildPnLRow(
                    '(=) صافي الربح النهائي (Net Profit)',
                    pnl.netOperatingProfit,
                    currency,
                    fmt,
                    isBold: true,
                    isHighlight: true,
                    color: pnl.netOperatingProfit >= 0 ? const Color(0xFF10B981) : Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnLRow(
    String title,
    double amount,
    String currency,
    NumberFormat fmt, {
    bool isBold = false,
    bool isHeader = false,
    bool isNegative = false,
    bool isHighlight = false,
    String? subtitle,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.w500,
                    fontSize: isHighlight ? 16 : (isBold ? 15 : 14),
                    color: isHighlight ? color : (isNegative ? Colors.red.shade700 : Colors.black87),
                  ),
                ),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '${isNegative && amount > 0 ? '-' : ''}${fmt.format(amount.abs())} $currency',
            style: TextStyle(
              fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.w600,
              fontSize: isHighlight ? 17 : (isBold ? 15 : 14),
              color: isHighlight ? color : (isNegative ? Colors.red.shade700 : (color ?? Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }
}
