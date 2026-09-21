import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Use dart:html conditionally for web WhatsApp launch
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../providers/device_license_provider.dart';

class DeviceLicenseScreen extends StatelessWidget {
  const DeviceLicenseScreen({super.key});

  void _copyToClipboard(BuildContext context, String hwid) {
    Clipboard.setData(ClipboardData(text: hwid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text(
              "تم نسخ بصمة الجهاز بنجاح!",
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _sendViaWhatsApp(BuildContext context, String hwid) {
    final message = Uri.encodeComponent(
      'السلام عليكم، أرغب في ترخيص جهاز لوحة الإدارة Vegtablity Manager.\nرقم بصمة الجهاز (HWID) هو: $hwid',
    );
    final url = 'https://wa.me/96555381505?text=$message';

    if (kIsWeb) {
      try {
        html.window.open(url, '_blank');
      } catch (e) {
        _copyToClipboard(context, hwid);
      }
    } else {
      _copyToClipboard(context, hwid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      try {
        final loader = html.document.getElementById('loading');
        if (loader != null) {
          loader.style.opacity = '0';
          loader.style.pointerEvents = 'none';
          Future.delayed(const Duration(milliseconds: 200), () {
            try {
              loader.remove();
            } catch (_) {}
          });
        }
      } catch (_) {}
    }
    final license = Provider.of<DeviceLicenseProvider>(context);
    final hwid = license.hwid ?? "----------------";
    final isExpired = license.isExpired;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0F1D),
          gradient: RadialGradient(
            center: Alignment(0.0, -0.4),
            radius: 1.2,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0A0F1D),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 560,
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 20 : 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D31),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isExpired
                          ? Colors.orange.withValues(alpha: 0.5)
                          : Colors.redAccent.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isExpired ? Colors.orange : Colors.redAccent)
                            .withValues(alpha: 0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Badge
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isExpired ? Colors.orange : Colors.amber,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/lettuce.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.security_rounded,
                              color: Colors.amber,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        isExpired
                            ? "انتهت صلاحية ترخيص الجهاز"
                            : "الجهاز غير مسجل بنظام التراخيص",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isExpired ? Colors.orange : Colors.redAccent,
                          fontSize: isMobile ? 20 : 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        isExpired
                            ? "انتهت صلاحية ترخيص هذا الجهاز بتاريخ ${license.expiryDate ?? ''}.\nيرجى التواصل مع الدعم الفني لتجديد الاشتراك."
                            : "هذا المتصفح / الجهاز غير معتمد لتشغيل لوحة الإدارة.\nيرجى تزويد الدعم الفني برقم بصمة الجهاز (HWID) لتفعيله فوراً.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Standard HWID Display Box (16-char Hex)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.fingerprint_rounded,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "بصمة الجهاز المعتمدة (HWID)",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "16-HEX",
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131D31),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      color: Colors.greenAccent,
                                      size: 20,
                                    ),
                                    tooltip: "نسخ البصمة",
                                    onPressed: () => _copyToClipboard(context, hwid),
                                  ),
                                  Expanded(
                                    child: SelectableText(
                                      hwid,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: isMobile ? 17 : 20,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        letterSpacing: 2.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // WhatsApp Support Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _sendViaWhatsApp(context, hwid),
                          icon: const Icon(
                            Icons.chat_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            "إرسال البصمة للدعم الفني (واتساب)",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFF22C55E).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Retry / Recheck Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: license.isChecking
                              ? null
                              : () => license.verifyLicense(),
                          icon: license.isChecking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amber,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                          label: Text(
                            license.isChecking ? "جاري إعادة الفحص..." : "إعادة التحقق من الترخيص",
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.amber.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      if (license.errorMessage != null &&
                          license.errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          license.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
