import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';

class DeviceLicenseResult {
  final bool isLicensed;
  final bool isActive;
  final bool isExpired;
  final String? expiryDate;
  final String? errorMessage;

  DeviceLicenseResult({
    required this.isLicensed,
    required this.isActive,
    required this.isExpired,
    this.expiryDate,
    this.errorMessage,
  });
}

class DeviceLicenseService {
  final ApiClient _client = ApiClient();

  /// Generates a standard 16-character uppercase Hex HWID
  /// identical to the format used across the Vegtablity POS Ecosystem
  /// e.g. '4A8F2C1D9E0B3F7A'
  static String generateStandardHWID() {
    final random = Random.secure();
    const chars = '0123456789ABCDEF';
    return List.generate(16, (index) => chars[random.nextInt(16)]).join();
  }

  /// Retrieves or creates a persistent standard 16-character Hex HWID.
  /// Automatically detects and replaces any legacy formats like 'HWID_1788471040355'.
  static Future<String> getOrCreateHWID() async {
    final prefs = await SharedPreferences.getInstance();
    String? hwid = prefs.getString('machine_hwid');

    final bool isInvalid = hwid == null ||
        hwid.isEmpty ||
        hwid.startsWith('HWID_') ||
        hwid.length != 16 ||
        !RegExp(r'^[0-9A-Fa-f]{16}$').hasMatch(hwid);

    if (isInvalid) {
      hwid = generateStandardHWID();
      await prefs.setString('machine_hwid', hwid);
    }

    return hwid.toUpperCase();
  }

  /// Checks license validity with backend API
  Future<DeviceLicenseResult> checkLicense(String hwid) async {
    try {
      final response = await _client.dio.post(
        '/security/check-license',
        data: {
          'MachineHWID': hwid,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          final isLicensed = (data['IsLicensed'] == true) ||
              (data['isLicensed'] == true) ||
              (data['IsLicensed'] == 1);
          final isActive = (data['IsActive'] == true) ||
              (data['isActive'] == true) ||
              (data['IsActive'] == 1);
          final isExpired = (data['IsExpired'] == true) ||
              (data['isExpired'] == true) ||
              (data['IsExpired'] == 1);
          final expiryDate = data['ExpiryDate']?.toString();

          return DeviceLicenseResult(
            isLicensed: isLicensed,
            isActive: isActive,
            isExpired: isExpired,
            expiryDate: expiryDate,
          );
        }
      }

      return DeviceLicenseResult(
        isLicensed: false,
        isActive: false,
        isExpired: false,
        errorMessage: 'فشل التحقق من الترخيص بالخادم',
      );
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      return DeviceLicenseResult(
        isLicensed: false,
        isActive: false,
        isExpired: false,
        errorMessage: detail ?? 'تعذر الاتصال بخادم التراخيص',
      );
    } catch (e) {
      return DeviceLicenseResult(
        isLicensed: false,
        isActive: false,
        isExpired: false,
        errorMessage: 'خطأ غير متوقع: $e',
      );
    }
  }
}
