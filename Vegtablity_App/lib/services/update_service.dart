import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

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
  final ApiService _apiService = ApiService();

  String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows_flutter';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'android';
  }

  String getAppFlavor() {
    // appFlavor is provided by Flutter when running with --flavor
    if (appFlavor != null && appFlavor!.isNotEmpty) {
      return appFlavor!.toLowerCase();
    }
    return 'washa';
  }

  /// فحص توفر إصدار أحدث من السيرفر
  Future<UpdateInfoModel> checkForUpdate() async {
    final platform = getPlatformName();
    final flavor = getAppFlavor();

    String currentVer = "1.0.0";
    int currentCode = 1;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVer = packageInfo.version;
      currentCode = int.tryParse(packageInfo.buildNumber) ?? 1;
    } catch (e) {
      debugPrint('Error getting package info: $e');
    }

    try {
      final response = await _apiService.get(
        '/updates/check',
        queryParameters: {
          'platform': platform,
          'flavor': flavor,
          'current_version': currentVer,
          'version_code': currentCode,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return UpdateInfoModel.fromJson(response.data as Map<String, dynamic>, currentVer);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }

    return UpdateInfoModel(
      hasUpdate: false,
      currentVersion: currentVer,
      latestVersion: currentVer,
    );
  }

  /// تنزيل حزمة التحديث وفتحها للتثبيت
  Future<bool> downloadAndInstall({
    required UpdateInfoModel updateInfo,
    required Function(double progress) onProgress,
  }) async {
    if (updateInfo.downloadUrl == null || updateInfo.downloadUrl!.isEmpty) {
      return false;
    }

    String downloadUrl = updateInfo.downloadUrl!;
    if (!downloadUrl.startsWith('http')) {
      final baseUrl = _apiService.baseUrl.replaceAll('/api/v1', '');
      downloadUrl = '$baseUrl${downloadUrl.startsWith('/') ? '' : '/'}$downloadUrl';
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = downloadUrl.split('/').last.split('?').first;
      final savePath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      onProgress(1.0);

      // فتح ملف التثبيت مع تحديد الـ MIME Type لنظام Android
      final result = await OpenFilex.open(
        savePath,
        type: Platform.isAndroid ? 'application/vnd.android.package-archive' : null,
      );

      debugPrint('OpenFilex install result: ${result.type} - ${result.message}');
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error downloading and installing update: $e');
      return false;
    }
  }
}
