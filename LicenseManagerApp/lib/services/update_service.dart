import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows_flutter';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'android';
  }

  Future<UpdateInfoModel> checkForUpdate({String? currentVer, int? currentCode}) async {
    final platform = getPlatformName();

    String resolvedVer = currentVer ?? "1.0.1";
    int resolvedCode = currentCode ?? 2;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      resolvedVer = packageInfo.version;
      resolvedCode = int.tryParse(packageInfo.buildNumber) ?? resolvedCode;
    } catch (e) {
      debugPrint('Error getting package info in LicenseManagerApp: $e');
    }

    try {
      final response = await _dio.get(
        '/updates/check',
        queryParameters: {
          'platform': platform,
          'flavor': 'license_manager',
          'current_version': resolvedVer,
          'version_code': resolvedCode,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return UpdateInfoModel.fromJson(response.data as Map<String, dynamic>, resolvedVer);
      }
    } catch (e) {
      debugPrint('Error checking for updates in LicenseManagerApp: $e');
    }

    return UpdateInfoModel(
      hasUpdate: false,
      currentVersion: resolvedVer,
      latestVersion: resolvedVer,
    );
  }

  /// تنزيل حزمة التحديث (APK / Installer) وفتحها للتثبيت الفوري
  /// يعيد (نجاح العملية, رسالة الخطأ إن وجدت)
  Future<(bool, String)> downloadAndInstall({
    required UpdateInfoModel updateInfo,
    required Function(double progress) onProgress,
  }) async {
    if (updateInfo.downloadUrl == null || updateInfo.downloadUrl!.isEmpty) {
      return (false, 'رابط التحديث غير متوفر في بيانات السيرفر.');
    }

    String downloadUrl = updateInfo.downloadUrl!;
    if (!downloadUrl.startsWith('http')) {
      downloadUrl = '$baseUrl${downloadUrl.startsWith('/') ? '' : '/'}$downloadUrl';
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final rawFileName = downloadUrl.split('/').last.split('?').first;
      final fileName = rawFileName.isNotEmpty ? rawFileName : 'LicenseManager_Update.apk';
      final savePath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      onProgress(1.0);

      final result = await OpenFilex.open(
        savePath,
        type: (!kIsWeb && Platform.isAndroid) ? 'application/vnd.android.package-archive' : null,
      );

      debugPrint('LicenseManagerApp OpenFilex result: ${result.type} - ${result.message}');
      if (result.type == ResultType.done) {
        return (true, '');
      } else if (result.type == ResultType.permissionDenied) {
        return (false, 'يرجى السماح بصلاحية تثبيت التطبيقات غير المعروفة من إعدادات الهاتف.');
      } else {
        return (false, 'تعذر فتح ملف التثبيت: ${result.message}');
      }
    } on DioException catch (dioErr) {
      debugPrint('Dio error downloading update in LicenseManagerApp: $dioErr');
      if (dioErr.response?.statusCode == 404) {
        return (false, 'ملف التحديث غير مرفوع على السيرفر بعد (خطأ 404):\n$downloadUrl');
      }
      return (false, 'فشل تنزيل التحديث من السيرفر (${dioErr.response?.statusCode ?? dioErr.type.name}).');
    } catch (e) {
      debugPrint('Error downloading and installing update in LicenseManagerApp: $e');
      return (false, 'حدث خطأ أثناء التنزيل أو التثبيت: $e');
    }
  }

  static void showUpdateDialog(BuildContext context, UpdateInfoModel updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (ctx) => _LicenseUpdateDialog(updateInfo: updateInfo),
    );
  }
}

class _LicenseUpdateDialog extends StatefulWidget {
  final UpdateInfoModel updateInfo;

  const _LicenseUpdateDialog({required this.updateInfo});

  @override
  State<_LicenseUpdateDialog> createState() => _LicenseUpdateDialogState();
}

class _LicenseUpdateDialogState extends State<_LicenseUpdateDialog> {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = 'جاري الاتصال بالخادم وبدء تنزيل التحديث...';
    });

    final (success, errorMsg) = await _updateService.downloadAndInstall(
      updateInfo: widget.updateInfo,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            if (progress >= 1.0) {
              _statusText = 'اكتمل التنزيل! جاري فتح معالج التثبيت...';
            } else {
              _statusText = 'جاري تنزيل التحديث... ${(progress * 100).toInt()}%';
            }
          });
        }
      },
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isDownloading = false;
        _statusText = 'تم فتح مثبت الحزم بنجاح ✅';
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } else {
      setState(() {
        _isDownloading = false;
        _statusText = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(errorMsg),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = widget.updateInfo;
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
              if (_isDownloading || _statusText.isNotEmpty) ...[
                const SizedBox(height: 16),
                if (_isDownloading)
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(6),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _isDownloading
            ? []
            : [
                if (!updateInfo.isMandatory)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("لاحقاً", style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: const Color(0xFF1E1E2E),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _startDownloadAndInstall,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text("تحديث الآن ⚡", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
      ),
    );
  }
}
