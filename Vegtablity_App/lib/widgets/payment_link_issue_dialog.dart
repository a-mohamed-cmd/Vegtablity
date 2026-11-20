import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localization/app_localizations.dart';
import '../models/integration_models.dart';
import '../services/integrations/integration_service.dart';
import '../services/printer_service.dart';

/// Displays the consolidated/single payment link issuance dialog (matching POS & Issue Link page)
/// with preloaded customer name, customer phone, selected invoices list, and total amount.
Future<PaymentLinkRecordModel?> showConsolidatedPaymentLinkDialog({
  required BuildContext context,
  required List<IntegrationProviderModel> configuredGateways,
  required IntegrationProviderModel initialGateway,
  required int partnerId,
  required String customerName,
  required String customerPhone,
  required List<Map<String, dynamic>> allocations, // [{'InvID': int, 'Amount': double, ...}]
  String? initialNotes,
  int? shiftId,
  int createdByUserId = 1,
}) async {
  if (configuredGateways.isEmpty || allocations.isEmpty) return null;

  IntegrationProviderModel selectedGateway = configuredGateways.firstWhere(
    (g) => g.providerId == initialGateway.providerId,
    orElse: () => initialGateway,
  );

  final bool isAr = Localizations.localeOf(context).languageCode == 'ar';
  String providerLabel(IntegrationProviderModel p) {
    if (isAr) {
      return p.providerNameAr.isNotEmpty ? p.providerNameAr : p.providerCode;
    }
    return p.providerNameEn.isNotEmpty ? p.providerNameEn : p.providerCode;
  }

  final int primaryInvId = (allocations.first['InvID'] as num).toInt();
  final double totalAmount = allocations.fold<double>(
    0.0,
    (sum, item) => sum + ((item['Amount'] as num?)?.toDouble() ?? 0.0),
  );
  final bool isConsolidated = allocations.length > 1;
  final String consolidatedCsv = allocations
      .map((e) => '${(e['InvID'] as num).toInt()}:${((e['Amount'] as num).toDouble()).toStringAsFixed(3)}')
      .join(',');
  final String invNumbersSummary =
      allocations.map((e) => '#${(e['InvID'] as num).toInt()}').join(', ');

  final defaultCust = context.tr('pos_gw_default_customer');
  final nameCtrl = TextEditingController(
    text: customerName.trim().isNotEmpty ? customerName.trim() : defaultCust,
  );
  final phoneCtrl = TextEditingController(text: customerPhone.trim());
  final notesCtrl = TextEditingController(
    text: (initialNotes != null && initialNotes.trim().isNotEmpty)
        ? initialNotes.trim()
        : (isAr
            ? 'تحصيل مجمع للفواتير: $invNumbersSummary'
            : 'Consolidated collection for invoices: $invNumbersSummary'),
  );

  bool sendWhatsApp = selectedGateway.autoSendWhatsApp;
  bool isCreating = false;
  String statusMsg = '';
  bool isError = false;
  PaymentLinkRecordModel? createdLink;

  String cleanWaPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.length == 8) return '965$digits';
    return digits;
  }

  Future<void> launchWhatsAppUrl(
      String phone, String custName, String url) async {
    final clean = cleanWaPhone(phone);
    if (clean.isEmpty) return;
    final curr = isAr ? 'د.ك' : selectedGateway.defaultCurrency;
    final text = isAr
        ? 'مرحباً $custName،\n'
            'يرجى سداد الفواتير ($invNumbersSummary) بإجمالي ${totalAmount.toStringAsFixed(3)} $curr عبر رابط الدفع الآمن:\n'
            '$url\n'
            'شكراً لتعاملكم معنا.'
        : 'Hello $custName,\n'
            'Please pay invoices ($invNumbersSummary) totaling ${totalAmount.toStringAsFixed(3)} $curr via the secure payment link:\n'
            '$url\n'
            'Thank you for your business.';
    final waUri =
        Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(text)}');
    try {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  return showDialog<PaymentLinkRecordModel?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> generateLink() async {
            if (isCreating) return;
            setDialogState(() {
              isCreating = true;
              isError = false;
              statusMsg =
                  '${context.tr('pos_gw_connecting_prefix')}${providerLabel(selectedGateway)}${context.tr('pos_gw_connecting_suffix')}';
            });

            final paperMode =
                Provider.of<PrinterService>(context, listen: false).paperSize ==
                        58
                    ? '58mm'
                    : '80mm';

            final res =
                await IntegrationPosService().createPaymentLinkWithFeedback(
              invId: primaryInvId,
              partnerId: partnerId,
              providerId: selectedGateway.providerId,
              providerCode: selectedGateway.providerCode,
              providerConfig: selectedGateway,
              amount: totalAmount,
              currencyCode: selectedGateway.defaultCurrency,
              customerName: nameCtrl.text.trim().isEmpty
                  ? defaultCust
                  : nameCtrl.text.trim(),
              customerPhone: phoneCtrl.text.trim(),
              sendViaWhatsApp: sendWhatsApp,
              sendViaSms: selectedGateway.autoSendSms,
              printQrMode: paperMode,
              shiftId: shiftId,
              createdByUserId: createdByUserId,
              notes: notesCtrl.text.trim(),
              isConsolidated: isConsolidated,
              consolidatedInvoicesCsv: isConsolidated ? consolidatedCsv : null,
              isAr: isAr,
            );

            if (!ctx.mounted) return;
            final link = res.data;
            if (res.success && link != null && link.paymentUrl.isNotEmpty) {
              setDialogState(() {
                isCreating = false;
                createdLink = link;
                isError = false;
                statusMsg = context.tr('pos_gw_created_ok');
              });
              if (sendWhatsApp && phoneCtrl.text.trim().isNotEmpty) {
                await launchWhatsAppUrl(
                  phoneCtrl.text.trim(),
                  nameCtrl.text.trim(),
                  link.paymentUrl,
                );
              }
            } else {
              setDialogState(() {
                isCreating = false;
                isError = true;
                final msg = res.localizedMessage(isAr);
                statusMsg =
                    msg.isNotEmpty ? msg : context.tr('pos_gw_create_failed');
              });
            }
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_link, color: Colors.teal, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConsolidated
                        ? (isAr
                            ? 'إصدار رابط دفع مجمع (${allocations.length} فواتير)'
                            : 'Issue Consolidated Link (${allocations.length} invoices)')
                        : '${context.tr('pos_gw_dlg_title_paid')}$primaryInvId',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.tr('pos_gw_amount_due'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                '${totalAmount.toStringAsFixed(3)} ${isAr ? 'د.ك' : selectedGateway.defaultCurrency}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: allocations.map((item) {
                              final id = (item['InvID'] as num).toInt();
                              final amt =
                                  (item['Amount'] as num?)?.toDouble() ?? 0.0;
                              return Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '#$id: ${amt.toStringAsFixed(3)}',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (configuredGateways.length > 1) ...[
                      DropdownButtonFormField<IntegrationProviderModel>(
                        value: selectedGateway,
                        decoration: InputDecoration(
                          labelText: context.tr('pos_gw_gateway_label'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: configuredGateways
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(
                                      '${providerLabel(g)} (${g.connectionStatus.contains("Sandbox") ? "Sandbox" : "Live"})'),
                                ))
                            .toList(),
                        onChanged: createdLink != null
                            ? null
                            : (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedGateway = val;
                                    sendWhatsApp = val.autoSendWhatsApp;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: nameCtrl,
                      readOnly: createdLink != null,
                      decoration: InputDecoration(
                        labelText: context.tr('pos_gw_customer_name'),
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      readOnly: createdLink != null,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('pos_gw_customer_phone'),
                        hintText: context.tr('pos_gw_customer_phone_hint'),
                        prefixIcon: const Icon(Icons.phone_android),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      readOnly: createdLink != null,
                      decoration: InputDecoration(
                        labelText: isAr ? 'ملاحظات الرابط' : 'Link Notes',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(context.tr('pos_gw_auto_whatsapp')),
                      value: sendWhatsApp,
                      onChanged: createdLink != null
                          ? null
                          : (v) =>
                              setDialogState(() => sendWhatsApp = v ?? false),
                    ),
                    if (statusMsg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red.withValues(alpha: 0.1)
                              : (createdLink != null
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (isCreating) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                statusMsg,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isError
                                      ? Colors.red[800]
                                      : (createdLink != null
                                          ? Colors.green[800]
                                          : Colors.blue[800]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (createdLink != null &&
                        createdLink!.paymentUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: QrImageView(
                                  data: createdLink!.paymentUrl,
                                  version: QrVersions.auto,
                                  size: 165,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr('pos_gw_qr_scan_hint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              createdLink!.paymentUrl,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                        text: createdLink!.paymentUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              context.tr('pos_gw_copied'))),
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: Text(context.tr('pos_gw_copy_btn')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final uri =
                                        Uri.tryParse(createdLink!.paymentUrl);
                                    if (uri != null) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: Text(isAr ? 'فتح الرابط' : 'Open'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (phoneCtrl.text.trim().isEmpty) {
                                      setDialogState(() {
                                        isError = true;
                                        statusMsg = context
                                            .tr('pos_gw_enter_phone_first');
                                      });
                                      return;
                                    }
                                    launchWhatsAppUrl(
                                      phoneCtrl.text.trim(),
                                      nameCtrl.text.trim(),
                                      createdLink!.paymentUrl,
                                    );
                                  },
                                  icon: const Icon(Icons.share, size: 16),
                                  label: Text(context.tr('pos_gw_send_wa_btn')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (createdLink == null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isCreating ? null : generateLink,
                  icon: const Icon(Icons.bolt),
                  label: Text(context.tr('pos_gw_generate_now')),
                ),
              TextButton(
                onPressed: isCreating
                    ? null
                    : () => Navigator.of(ctx).pop(createdLink),
                child: Text(
                  createdLink != null
                      ? (isAr ? 'تم وإغلاق' : 'Done')
                      : context.tr('rv_cancel'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
