import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/license_provider.dart';
import 'auth_wrapper.dart';

class LicenseCheckScreen extends StatefulWidget {
  const LicenseCheckScreen({super.key});

  @override
  State<LicenseCheckScreen> createState() => _LicenseCheckScreenState();
}

class _LicenseCheckScreenState extends State<LicenseCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkStatusAndNavigate();
  }

  void _checkStatusAndNavigate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final licenseProvider = Provider.of<LicenseProvider>(context, listen: false);
      if (!licenseProvider.isChecking && licenseProvider.isLicensed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  void _sendToWhatsApp(String hwid) async {
    final message = Uri.encodeComponent(
      'السلام عليكم، أرغب في ترخيص جهاز نقطة البيع Vegtablity POS.\nرقم بصمة الجهاز (HWID) هو: $hwid'
    );
    final url = Uri.parse('https://wa.me/96555381505?text=$message');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق WhatsApp، يرجى مراسلة الرقم 55381505 يدوياً', textAlign: TextAlign.right),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String hwid) {
    Clipboard.setData(ClipboardData(text: hwid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ بصمة الجهاز إلى الحافظة بنجاح!', textAlign: TextAlign.right),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenseProvider = Provider.of<LicenseProvider>(context);

    // If licensed, trigger redirection automatically
    if (!licenseProvider.isChecking && licenseProvider.isLicensed) {
      _checkStatusAndNavigate();
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Card(
              color: Colors.grey[850],
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (licenseProvider.isChecking) ...[
                      const Icon(Icons.security, size: 80, color: Colors.green),
                      const SizedBox(height: 32),
                      const Text(
                        'حماية Vegtablity POS',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(color: Colors.green),
                      const SizedBox(height: 24),
                      const Text(
                        'جاري التحقق من ترخيص هذا الجهاز...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ] else if (!licenseProvider.isLicensed) ...[
                      if (licenseProvider.isExpired) ...[
                        const Icon(Icons.history_toggle_off, size: 80, color: Colors.orangeAccent),
                        const SizedBox(height: 24),
                        const Text(
                          'انتهت صلاحية الاشتراك!',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'نأسف، لقد انتهت صلاحية اشتراك هذا الجهاز بتاريخ ${licenseProvider.expiryDate ?? "غير محدد"}.\nيرجى تجديد الاشتراك مع الدعم الفني للاستمرار في العمل.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                      ] else if (licenseProvider.errorMessage != null) ...[
                        const Icon(Icons.wifi_off, size: 80, color: Colors.amberAccent),
                        const SizedBox(height: 24),
                        const Text(
                          'خطأ في الاتصال!',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          licenseProvider.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                      ] else if (licenseProvider.expiryDate != null && !licenseProvider.isActive) ...[
                        const Icon(Icons.block, size: 80, color: Colors.redAccent),
                        const SizedBox(height: 24),
                        const Text(
                          'الترخيص غير نشط!',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'هذا الجهاز مسجل لدينا ولكن تم إيقاف الترخيص مؤقتاً.\nيرجى مراجعة الدعم الفني لتفعيل صلاحية الدخول.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                      ] else ...[
                        const Icon(Icons.fingerprint, size: 80, color: Colors.redAccent),
                        const SizedBox(height: 24),
                        const Text(
                          'الجهاز غير مسجل!',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'رقم هوية هذا الجهاز غير مسجل في نظام التراخيص الخاص بنا.\nيرجى إرسال بصمة الجهاز للدعم الفني لتسجيله وتفعيله.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 32),
                      
                      // HWID Display Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('بصمة الجهاز الخاصة بك', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                SizedBox(width: 6),
                                Icon(Icons.fingerprint, color: Colors.white54, size: 16),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.greenAccent),
                                  onPressed: () => _copyToClipboard(licenseProvider.hwid ?? ''),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  tooltip: 'نسخ البصمة',
                                ),
                                Expanded(
                                  child: SelectableText(
                                    licenseProvider.hwid ?? 'unknown_hwid',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: Colors.greenAccent,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Programmer info card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(26), // 0.1 opacity
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withAlpha(51)), // 0.2 opacity
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('الدعم الفني والترخيص', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                SizedBox(width: 8),
                                Icon(Icons.contact_support, color: Colors.redAccent),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('55381505', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Text('هاتف:', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _sendToWhatsApp(licenseProvider.hwid ?? ''),
                                icon: const Icon(Icons.chat, color: Colors.white),
                                label: const Text('إرسال البصمة عبر WhatsApp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Developer bypass in mock mode:
                                // To make testing extremely convenient, clicking the outline button while holding or in mock mode bypasses it
                              },
                              icon: const Icon(Icons.info_outline),
                              label: const Text('بيانات توضيحية'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white60,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: licenseProvider.checkDeviceLicense,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة التحقق'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
