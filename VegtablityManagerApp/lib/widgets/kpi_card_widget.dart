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
  final VoidCallback? onTap;

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
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currency = auth.companySettings?.currencySymbol ?? 'ر.س';
    final effectiveSuffix = isCurrency ? (suffix ?? currency) : suffix;

    final currencyFormat = NumberFormat('#,##0.00', 'ar');
    final countFormat = NumberFormat('#,###', 'ar');
    final displayVal = isCurrency ? currencyFormat.format(value) : countFormat.format(value.toInt());
    final isClickable = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: color.withValues(alpha: 0.06),
        splashColor: color.withValues(alpha: 0.12),
        mouseCursor: isClickable ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isClickable ? 0.35 : 0.25),
              width: isClickable ? 1.4 : 1.2,
            ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    )
                  else
                    const Spacer(),
                  if (isClickable) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "تفاصيل",
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 9),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
