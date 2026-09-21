import 'dart:convert';
import 'dart:typed_data';

class CompanySettingsModel {
  final int settingId;
  final String companyName;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoBase64;
  final String currencySymbol;

  CompanySettingsModel({
    required this.settingId,
    required this.companyName,
    this.address,
    this.phone,
    this.email,
    this.logoBase64,
    this.currencySymbol = 'د.ك',
  });

  factory CompanySettingsModel.fromJson(Map<String, dynamic> json) {
    return CompanySettingsModel(
      settingId: json['SettingID'] is int ? json['SettingID'] : (int.tryParse(json['SettingID']?.toString() ?? '0') ?? 0),
      companyName: json['CompanyName']?.toString() ?? '',
      address: json['Address']?.toString(),
      phone: json['Phone']?.toString(),
      email: json['Email']?.toString(),
      logoBase64: json['Logo']?.toString(),
      currencySymbol: json['CurrencySymbol']?.toString() ?? 'د.ك',
    );
  }

  Uint8List? get logoBytes {
    if (logoBase64 != null && logoBase64!.trim().isNotEmpty) {
      try {
        return base64Decode(logoBase64!.trim());
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
