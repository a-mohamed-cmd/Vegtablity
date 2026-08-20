import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../core/localization/app_localizations.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfoModel updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> showIfAvailable(BuildContext context, {bool showNoUpdateToast = false}) async {
    final updateService = UpdateService();
    final info = await updateService.checkForUpdate();

    if (info.hasUpdate && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: !info.isMandatory,
        builder: (ctx) => UpdateDialog(updateInfo: info),
      );
    } else if (showNoUpdateToast && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('update_already_latest')),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = context.tr('update_downloading_connecting');
    });

    final success = await _updateService.downloadAndInstall(
      updateInfo: widget.updateInfo,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            if (progress >= 1.0) {
              _statusText = context.tr('update_download_completed');
            } else {
              _statusText = '${context.tr('update_downloading_progress')} ${(progress * 100).toInt()}%';
            }
          });
        }
      },
    );

    if (mounted) {
      if (success) {
        setState(() {
          _isDownloading = false;
          _statusText = context.tr('update_installer_opened');
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        setState(() {
          _isDownloading = false;
          _statusText = context.tr('update_install_failed');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('update_install_permission_warn')),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: Color(0xFF38BDF8), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('update_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr('update_version_label')} ${widget.updateInfo.latestVersion} (${context.tr('update_current_label')} ${widget.updateInfo.currentVersion})',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release Notes
            Text(
              context.tr('update_whats_new'),
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.updateInfo.releaseNotes.isNotEmpty
                      ? widget.updateInfo.releaseNotes
                      : context.tr('update_default_notes'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress bar
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                borderRadius: BorderRadius.circular(6),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (!_isDownloading)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: Text(context.tr('update_now_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (!widget.updateInfo.isMandatory) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.tr('update_later_btn'), style: const TextStyle(color: Colors.white54)),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
