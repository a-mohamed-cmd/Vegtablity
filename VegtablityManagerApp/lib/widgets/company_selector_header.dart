import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';

class CompanySelectorHeader extends StatelessWidget {
  const CompanySelectorHeader({super.key});

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll("#", "");
      return Color(int.parse("0xFF$clean"));
    } catch (_) {
      return Colors.amber;
    }
  }

  IconData _getCompanyIcon(String iconName) {
    switch (iconName) {
      case "local_car_wash":
        return Icons.local_car_wash_rounded;
      case "diamond":
        return Icons.diamond_rounded;
      case "eco":
        return Icons.eco_rounded;
      case "restaurant":
        return Icons.restaurant_rounded;
      case "public":
        return Icons.public_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final activeCompany = reportsProvider.selectedCompany;
    final brandColor = _parseColor(activeCompany.colorHex);
    final compIcon = _getCompanyIcon(activeCompany.iconName);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 650;
    final isUltraCompact = screenWidth < 400;

    final liveSettings = authProvider.companySettings;
    final displayName = (liveSettings != null && liveSettings.companyName.isNotEmpty)
        ? liveSettings.companyName
        : activeCompany.name;
    final logoBytes = liveSettings?.logoBytes;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isUltraCompact ? 6 : (isCompact ? 10 : 16),
        vertical: isUltraCompact ? 4 : (isCompact ? 5 : 8),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandColor.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Company Database Logo Badge
          Container(
            width: isCompact ? 36 : 44,
            height: isCompact ? 36 : 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: brandColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (logoBytes != null && logoBytes.isNotEmpty)
                  ? Image.memory(
                      logoBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(compIcon, color: brandColor, size: isCompact ? 20 : 24),
                    )
                  : Icon(compIcon, color: brandColor, size: isCompact ? 20 : 24),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isUltraCompact ? 85 : (isCompact ? 115 : 180)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isCompact ? 14 : 17,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: brandColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "بوابة معتمدة",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: isCompact ? 10 : 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
