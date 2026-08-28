import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UpdateInfoModel {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final int? versionCode;
  final String? downloadUrl;
  final double? fileSizeMb;
  final String releaseNotes;
  final bool isMandatory;

  UpdateInfoModel({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.versionCode,
    this.downloadUrl,
    this.fileSizeMb,
    this.releaseNotes = '',
    this.isMandatory = false,
  });

  factory UpdateInfoModel.fromJson(Map<String, dynamic> json, String currentVer) {
    return UpdateInfoModel(
      hasUpdate: json['has_update'] == true,
      currentVersion: currentVer,
      latestVersion: json['latest_version']?.toString() ?? currentVer,
      versionCode: json['version_code'] is num ? (json['version_code'] as num).toInt() : null,
      downloadUrl: json['download_url']?.toString(),
      fileSizeMb: (json['file_size_mb'] is num) ? (json['file_size_mb'] as num).toDouble() : null,
      releaseNotes: json['release_notes']?.toString() ?? '',
      isMandatory: json['is_mandatory'] == true,
    );
  }
}

class UpdateService {
  static const String baseUrl = 'http://185.216.203.50:8000';
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));

  String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows_flutter';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'android';
  }

  Future<UpdateInfoModel> checkForUpdate({String currentVer = "1.0.0", int currentCode = 1}) async {
    final platform = getPlatformName();
    try {
      final response = await _dio.get(
        '/updates/check',
        queryParameters: {
          'platform': platform,
          'flavor': 'license_manager',
          'current_version': currentVer,
          'version_code': currentCode,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return UpdateInfoModel.fromJson(response.data as Map<String, dynamic>, currentVer);
      }
    } catch (e) {
      debugPrint('Error checking for updates in LicenseManagerApp: $e');
    }

    return UpdateInfoModel(
      hasUpdate: false,
      currentVersion: currentVer,
      latestVersion: currentVer,
    );
  }

  static void showUpdateDialog(BuildContext context, UpdateInfoModel updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF252538),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.amber, width: 1.5),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_rounded, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "تحديث جديد متاح 🚀",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "الإصدار الحالي: v${updateInfo.currentVersion}",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Text(
                          "الإصدار الجديد: v${updateInfo.latestVersion}",
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (updateInfo.fileSizeMb != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "حجم التحديث: ${updateInfo.fileSizeMb!.toStringAsFixed(1)} ميجابايت",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    "أبرز التحديثات والمميزات:",
                    style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      updateInfo.releaseNotes.isNotEmpty
                          ? updateInfo.releaseNotes
                          : "تحسينات عامة واستقرار الأداء ونظام التراخيص.",
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!updateInfo.isMandatory)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("لاحقاً", style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: const Color(0xFF1E1E2E),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      content: Text("رابط التنزيل: ${updateInfo.downloadUrl ?? 'جاري التجهيز'}"),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text("تحديث الآن ⚡", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        );
      },
    );
  }
}
