import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/license_provider.dart';
import '../core/localization/app_localizations.dart';
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
          SnackBar(
            content: Text(context.tr('license_whatsapp_error'), textAlign: TextAlign.right),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String hwid) {
    Clipboard.setData(ClipboardData(text: hwid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('license_copied'), textAlign: TextAlign.right),
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
                      Text(
                        context.tr('license_title'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(color: Colors.green),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('license_checking'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ] else if (!licenseProvider.isLicensed) ...[
                      if (licenseProvider.isExpired) ...[
                        const Icon(Icons.history_toggle_off, size: 80, color: Colors.orangeAccent),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('license_expired_title'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${context.tr('license_expired_desc')}${licenseProvider.expiryDate ?? "unknown"}${context.tr('license_expired_desc_2')}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                      ] else if (licenseProvider.errorMessage != null) ...[
                        const Icon(Icons.wifi_off, size: 80, color: Colors.amberAccent),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('license_error_title'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amberAccent),
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
                        Text(
                          context.tr('license_inactive_title'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('license_inactive_desc'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                      ] else ...[
                        const Icon(Icons.fingerprint, size: 80, color: Colors.redAccent),
                        const SizedBox(height: 24),
                        Text(
                          context.tr('license_unregistered_title'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('license_unregistered_desc'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(context.tr('license_hwid_label'), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                const SizedBox(width: 6),
                                const Icon(Icons.fingerprint, color: Colors.white54, size: 16),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(context.tr('license_support_title'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(width: 8),
                                const Icon(Icons.contact_support, color: Colors.redAccent),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('55381505', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Text(context.tr('license_phone_label'), style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _sendToWhatsApp(licenseProvider.hwid ?? ''),
                                icon: const Icon(Icons.chat, color: Colors.white),
                                label: Text(context.tr('license_send_whatsapp'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                              label: Text(context.tr('license_info_button')),
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
                              label: Text(context.tr('license_retry_button')),
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
