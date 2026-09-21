import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class KpiCardWidget extends StatelessWidget {
  final String title;
  final double value;
  final String? prefix;
  final String? suffix;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool isCurrency;

  const KpiCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.prefix,
    this.suffix,
    required this.icon,
    required this.color,
    this.subtitle,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final effectiveSuffix = isCurrency ? (suffix ?? currency) : suffix;

    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final countFormat = NumberFormat('#,###', 'ar');
    final displayVal = isCurrency ? currencyFormat.format(value) : countFormat.format(value.toInt());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (prefix != null)
                  Text(
                    "$prefix ",
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                Text(
                  displayVal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                if (effectiveSuffix != null)
                  Text(
                    " $effectiveSuffix",
                    style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
