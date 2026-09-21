import 'package:flutter/foundation.dart';

class CompanyInfoModel {
  final String id;
  final String name;
  final String code;
  final String iconName;
  final String colorHex;
  final String description;
  final int apiPort;

  const CompanyInfoModel({
    required this.id,
    required this.name,
    required this.code,
    required this.iconName,
    required this.colorHex,
    required this.description,
    required this.apiPort,
  });
}

class AppConfig {
  static const List<CompanyInfoModel> companies = [
    CompanyInfoModel(
      id: "WashaDB",
      name: "مغسلة وشا (Washa)",
      code: "washa",
      iconName: "local_car_wash",
      colorHex: "#06B6D4",
      description: "نظام مغاسل السيارات ونقاط البيع",
      apiPort: 8000,
    ),
    CompanyInfoModel(
      id: "JawharaDB",
      name: "شركة الجوهرة (Jawhara)",
      code: "jawhara",
      iconName: "diamond",
      colorHex: "#8B5CF6",
      description: "النظام التجاري والمخازن",
      apiPort: 8001,
    ),
    CompanyInfoModel(
      id: "VegtablityDB",
      name: "نظام الخضار والفواكه (Vegtablity)",
      code: "veg",
      iconName: "eco",
      colorHex: "#10B981",
      description: "نقاط بيع التجزئة والخضار",
      apiPort: 8002,
    ),
    CompanyInfoModel(
      id: "zatterDB",
      name: "مطاعم زعتر (Zatter)",
      code: "zatter",
      iconName: "restaurant",
      colorHex: "#F59E0B",
      description: "نظام المطاعم والكافيهات",
      apiPort: 8003,
    ),
    CompanyInfoModel(
      id: "OmanCustmerDB",
      name: "فرع سلطنة عمان (Oman)",
      code: "oman",
      iconName: "public",
      colorHex: "#EC4899",
      description: "الفرع الإقليمي لسلطنة عمان",
      apiPort: 8004,
    ),
  ];

  static String getBaseApiUrl() {
    final defaultComp = detectDefaultCompany();
    if (kIsWeb) {
      final uri = Uri.base;
      // إذا كان الدومين vegtablity.cc أو vigtablity.cc أو أي دومين فرعي، يوجه تلقائياً إلى الرابط الحالي
      if (uri.host.contains('vegtablity.cc') ||
          uri.host.contains('vigtablity.cc')) {
        return '${uri.scheme}://${uri.host}';
      }
      if (uri.port != 80 && uri.port != 443 && uri.port != 0) {
        return '${uri.scheme}://${uri.host}:${uri.port}';
      }
      return '${uri.scheme}://${uri.host}';
    }
    // في بيئة التطوير أو الاتصال المباشر بالـ IP
    return 'http://185.216.203.50:${defaultComp.apiPort}';
  }

  static CompanyInfoModel detectDefaultCompany() {
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.contains('washa')) {
        return companies.firstWhere((c) => c.code == 'washa');
      } else if (host.contains('jawhara')) {
        return companies.firstWhere((c) => c.code == 'jawhara');
      } else if (host.contains('zatter')) {
        return companies.firstWhere((c) => c.code == 'zatter');
      } else if (host.contains('oman')) {
        return companies.firstWhere((c) => c.code == 'oman');
      } else if (host.contains('veg')) {
        return companies.firstWhere((c) => c.code == 'veg');
      }
    }
    return companies.firstWhere((c) => c.code == 'veg',
        orElse: () => companies.first);
  }
}
