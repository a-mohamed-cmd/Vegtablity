import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/app_snackbar.dart';
import '../models/integration_models.dart';
import '../providers/auth_provider.dart';
import '../providers/shift_provider.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../viewmodels/payment_gateway_viewmodel.dart';

class PaymentGatewayInvoicesScreen extends StatefulWidget {
  const PaymentGatewayInvoicesScreen({super.key});

  @override
  State<PaymentGatewayInvoicesScreen> createState() =>
      _PaymentGatewayInvoicesScreenState();
}

class _PaymentGatewayInvoicesScreenState
    extends State<PaymentGatewayInvoicesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _invIdCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // Consolidated item entry controllers
  final TextEditingController _consInvIdCtrl = TextEditingController();
  final TextEditingController _consAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshCurrentUserPermissions();
      final vm = Provider.of<PaymentGatewayViewModel>(context, listen: false);
      vm.initialize();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _invIdCtrl.dispose();
    _amountCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    _consInvIdCtrl.dispose();
    _consAmountCtrl.dispose();
    super.dispose();
  }

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  String _providerDisplayName(
    PaymentGatewayViewModel vm,
    PaymentLinkRecordModel item,
  ) {
    final cfg = vm.findProviderForRecord(item);
    if (_isAr) {
      return item.providerNameAr.isNotEmpty
          ? item.providerNameAr
          : item.providerCode;
    }
    if (cfg != null && cfg.providerNameEn.isNotEmpty) {
      return cfg.providerNameEn;
    }
    switch (item.providerCode.toUpperCase()) {
      case 'TAP':
        return 'Tap Payments';
      case 'MYFATOORAH':
        return 'MyFatoorah';
      case 'UPAYMENTS':
        return 'UPayments';
      default:
        return item.providerCode.isNotEmpty
            ? item.providerCode
            : item.providerNameAr;
    }
  }

  void _showSnack(String message, {Color color = Colors.teal}) {
    if (!mounted) return;
    final cleanMsg = DbErrorHelper.format(message, isArabic: _isAr);
    if (color == Colors.red || color.toARGB32() == Colors.red.shade700.toARGB32()) {
      AppSnackBar.show(context, cleanMsg, isError: true);
    } else if (color == Colors.orange) {
      AppSnackBar.show(context, cleanMsg, isWarning: true);
    } else {
      AppSnackBar.show(context, cleanMsg, isError: false);
    }
  }

  String _cleanWaPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.length == 8) return '965$digits';
    return digits;
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<void> _sendWhatsApp(PaymentLinkRecordModel item) async {
    final phone = _cleanWaPhone(item.customerPhone);
    if (phone.isEmpty) {
      _showSnack(context.tr('pgw_err_no_customer_phone'), color: Colors.orange);
      return;
    }
    final targetDesc = item.isConsolidated
        ? context.tr('pgw_wa_pay_consolidated')
        : context.tr('pgw_wa_pay_single');
    final text = '${context.tr('pgw_wa_greeting')} ${item.customerName},\n'
        '$targetDesc ${context.tr('pgw_wa_pay_number')}#${item.invId} '
        '${context.tr('pgw_wa_pay_amount')} ${item.amount.toStringAsFixed(3)} ${item.currencyCode} '
        '${context.tr('pgw_wa_pay_link')}\n'
        '${item.paymentUrl}\n'
        '${context.tr('pgw_wa_thanks')}';
    final encodedText = Uri.encodeComponent(text);
    final waNativeUri =
        Uri.parse('whatsapp://send?phone=$phone&text=$encodedText');
    final waWebUri =
        Uri.parse('https://wa.me/$phone?text=$encodedText');
    try {
      bool opened = false;
      try {
        if (await canLaunchUrl(waNativeUri)) {
          opened = await launchUrl(
            waNativeUri,
            mode: LaunchMode.externalApplication,
          );
        }
      } catch (_) {}

      if (!opened) {
        opened = await launchUrl(
          waWebUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!opened && mounted) {
        _showSnack(context.tr('pgw_err_whatsapp_open'), color: Colors.red);
      }
    } catch (_) {
      if (mounted) {
        _showSnack(context.tr('pgw_err_whatsapp_open'), color: Colors.red);
      }
    }
  }

  Future<void> _showQrPopup(
      PaymentGatewayViewModel vm, PaymentLinkRecordModel item) async {
    if (item.paymentUrl.trim().isEmpty) return;
    final providerTitle = _providerDisplayName(vm, item);
    bool isPrinting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${context.tr('pgw_invoice_prefix')} #${item.invId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      providerTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: item.paymentUrl,
                    version: QrVersions.auto,
                    size: 210,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${item.amount.toStringAsFixed(3)} ${item.currencyCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.customerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: item.paymentUrl));
                    if (!mounted) return;
                    _showSnack(context.tr('pgw_link_copied'));
                  },
                  child: Text(
                    item.paymentUrl,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.indigo.shade600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Printer icon-only button (no text) for printing the invoice of this link
                Material(
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    iconSize: 28,
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    onPressed: isPrinting
                        ? null
                        : () async {
                            setDlgState(() => isPrinting = true);
                            try {
                              await _printLinkQrReceipt(vm, item);
                            } finally {
                              if (ctx.mounted) {
                                setDlgState(() => isPrinting = false);
                              }
                            }
                          },
                    icon: isPrinting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printLinkQrReceipt(
      PaymentGatewayViewModel vm, PaymentLinkRecordModel item) async {
    final printer = Provider.of<PrinterService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final fallbackItemLabel = item.isConsolidated
        ? '${context.tr('pgw_receipt_consolidated_item')} (#${item.invId})'
        : '${context.tr('pgw_receipt_single_item')} #${item.invId}';
    final providerCfg = vm.findProviderForRecord(item);
    final bool allowQr = providerCfg == null
        ? true
        : (printer.paperSize == 58
            ? providerCfg.printQrOnPos58mm
            : providerCfg.printQrOnPos80mm);
    final providerDisplayName = _providerDisplayName(vm, item);

    Map<String, dynamic>? receiptPayload;
    if (item.invId > 0 && !item.isConsolidated) {
      try {
        final resp = await apiService.getInvoiceDetails(item.invId);
        if (resp.statusCode == 200 && resp.data is Map) {
          final data = Map<String, dynamic>.from(resp.data as Map);
          final List<dynamic> dbDetails =
              (data['Details'] as List<dynamic>?) ?? const [];
          if (dbDetails.isNotEmpty) {
            receiptPayload = {
              'InvID': data['InvID'] ?? item.invId,
              'id': data['InvID'] ?? item.invId,
              'PartnerName': data['PartnerName'] ?? item.customerName,
              'type': data['InvType'] ?? 'Sales',
              'created_at': data['InvDate'] ??
                  data['CreatedAt'] ??
                  item.createdAt,
              'total_amount': _parseNum(data['NetAmount']),
              'paid_amount': _parseNum(data['PaidAmount']),
              'voucher_paid_amount': _parseNum(data['VoucherPaidAmount']),
              'remainder': _parseNum(data['Remainder']),
              'PaymentSplits':
                  data['PaymentSplits'] ?? data['payment_splits'] ?? [],
              'PaymentAccountName': data['PaymentAccountName'] ??
                  data['payment_account_name'] ??
                  data['AccountName'] ??
                  providerDisplayName,
              'temp_customer_name':
                  data['TempCustomerName'] ?? data['temp_customer_name'],
              'temp_phone': data['TempPhone'] ?? data['temp_phone'],
              'temp_address': data['TempAddress'] ?? data['temp_address'],
              'temp_delivery_date':
                  data['TempDeliveryDate'] ?? data['temp_delivery_date'],
              'temp_delivery_time':
                  data['TempDeliveryTime'] ?? data['temp_delivery_time'],
              'PaymentUrl': item.paymentUrl,
              'payment_url': item.paymentUrl,
              'AllowPrintQr': allowQr,
              'items': dbDetails
                  .map((d) => {
                        'name': d['ProductName'] ?? '',
                        'product_name': d['ProductName'] ?? '',
                        'price': _parseNum(d['UnitPrice']),
                        'quantity': _parseNum(d['Quantity']),
                        'total': _parseNum(d['TotalPrice']),
                        'UnitName': d['UnitName'] ??
                            d['unitName'] ??
                            d['unit_name'] ??
                            d['unit'] ??
                            d['Unit'] ??
                            '',
                      })
                  .toList(),
            };
          }
        }
      } catch (_) {}
    }

    receiptPayload ??= {
      'InvID': item.invId,
      'id': item.invId,
      'type': 'Sales',
      'InvDate': item.createdAt,
      'PartnerName': item.customerName,
      'total_amount': item.amount,
      'paid_amount': item.linkStatus.toLowerCase() == 'paid' ? item.amount : 0.0,
      'remainder':
          item.linkStatus.toLowerCase() == 'paid' ? 0.0 : item.amount,
      'PaymentAccountName': providerDisplayName,
      'PaymentUrl': item.paymentUrl,
      'payment_url': item.paymentUrl,
      'AllowPrintQr': allowQr,
      'items': [
        {
          'product_name': fallbackItemLabel,
          'quantity': 1,
          'price': item.amount,
          'unit_name': item.currencyCode,
        }
      ],
    };

    final ok = await printer.printReceipt(receiptPayload, isReprint: true);
    if (!mounted) return;
    if (ok) {
      _showSnack(context.tr('pgw_print_sent_ok'), color: Colors.green);
    } else if (printer.connectionType == 'None') {
      _showSnack(context.tr('pgw_print_none_mode'), color: Colors.blueGrey);
    } else {
      _showSnack(context.tr('pgw_print_failed'), color: Colors.orange);
    }
  }

  Future<void> _handleLookupSingleInvoice(PaymentGatewayViewModel vm) async {
    final invId = int.tryParse(_invIdCtrl.text.trim()) ?? 0;
    if (invId <= 0) {
      _showSnack(context.tr('pgw_err_enter_valid_inv'), color: Colors.orange);
      return;
    }
    final info = await vm.lookupInvoiceQuickInfo(invId);
    if (!mounted) return;
    if (info == null) {
      _showSnack('${context.tr('pgw_err_inv_not_found')} #$invId.',
          color: Colors.orange);
      return;
    }
    final suggestedAmt = info.remainder > 0 ? info.remainder : info.netAmount;
    setState(() {
      _amountCtrl.text = suggestedAmt.toStringAsFixed(3);
      if (info.partnerName.trim().isNotEmpty) {
        _customerNameCtrl.text = info.partnerName.trim();
      }
      if (info.phone.trim().isNotEmpty) {
        _customerPhoneCtrl.text = info.phone.trim();
      }
    });
    _showSnack(
        '${context.tr('pgw_info_inv_loaded')} #$invId (${suggestedAmt.toStringAsFixed(3)})',
        color: Colors.teal);
  }

  Future<void> _handleLookupConsolidatedInvoice(
      PaymentGatewayViewModel vm) async {
    final invId = int.tryParse(_consInvIdCtrl.text.trim()) ?? 0;
    if (invId <= 0) {
      _showSnack(context.tr('pgw_err_enter_valid_inv_add'),
          color: Colors.orange);
      return;
    }
    final info = await vm.lookupInvoiceQuickInfo(invId);
    if (!mounted) return;
    if (info == null) {
      _showSnack('${context.tr('pgw_err_inv_not_found')} #$invId.',
          color: Colors.orange);
      return;
    }
    final suggestedAmt = info.remainder > 0 ? info.remainder : info.netAmount;
    setState(() {
      _consAmountCtrl.text = suggestedAmt.toStringAsFixed(3);
      if (_customerNameCtrl.text.trim().isEmpty &&
          info.partnerName.trim().isNotEmpty) {
        _customerNameCtrl.text = info.partnerName.trim();
      }
      if (_customerPhoneCtrl.text.trim().isEmpty &&
          info.phone.trim().isNotEmpty) {
        _customerPhoneCtrl.text = info.phone.trim();
      }
    });
  }

  void _handleAddConsolidatedRow(PaymentGatewayViewModel vm) {
    final invId = int.tryParse(_consInvIdCtrl.text.trim()) ?? 0;
    final amt = double.tryParse(_consAmountCtrl.text.trim()) ?? 0.0;
    if (invId <= 0 || amt <= 0) {
      _showSnack(context.tr('pgw_err_add_consolidated_valid'),
          color: Colors.orange);
      return;
    }
    vm.addConsolidatedInvoice(invId, amt);
    _consInvIdCtrl.clear();
    _consAmountCtrl.clear();
  }

  Future<void> _handleCreateLink(PaymentGatewayViewModel vm) async {
    if (vm.selectedCreateProvider == null) {
      _showSnack(context.tr('pgw_no_gateway_warning'), color: Colors.orange);
      return;
    }
    final int invId = int.tryParse(_invIdCtrl.text.trim()) ?? 0;
    final double amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (vm.isConsolidatedMode) {
      if (vm.consolidatedItems.isEmpty) {
        _showSnack(context.tr('pgw_err_add_at_least_one_inv'),
            color: Colors.orange);
        return;
      }
    } else {
      if (invId <= 0) {
        _showSnack(context.tr('pgw_err_enter_valid_inv'), color: Colors.orange);
        return;
      }
      if (amount <= 0) {
        _showSnack(context.tr('pgw_err_amount_gt_zero'), color: Colors.orange);
        return;
      }
    }

    final shiftId = Provider.of<ShiftProvider>(context, listen: false).shiftId;
    final paperSize =
        Provider.of<PrinterService>(context, listen: false).paperSize;
    final userId = Provider.of<AuthProvider>(context, listen: false).userId ?? 1;
    final defaultCustName = context.tr('pgw_default_cash_customer');

    final res = await vm.createPaymentLink(
      invId: invId,
      amount: amount,
      customerName: _customerNameCtrl.text,
      customerPhone: _customerPhoneCtrl.text,
      notes: _notesCtrl.text,
      createdByUserId: userId,
      shiftId: shiftId,
      paperSize: paperSize,
      defaultCustomerName: defaultCustName,
      isAr: _isAr,
    );

    if (!mounted) return;
    if (res.success && res.data != null) {
      _invIdCtrl.clear();
      _amountCtrl.clear();
      _notesCtrl.clear();
      _showSnack(res.localizedMessage(_isAr), color: Colors.green);
    } else {
      _showSnack(res.localizedMessage(_isAr), color: Colors.red);
    }
  }

  Future<void> _handleRefreshStatus(
      PaymentGatewayViewModel vm, PaymentLinkRecordModel item) async {
    final res = await vm.refreshLinkStatus(item);
    if (!mounted) return;
    if (res.success) {
      final isUpdated = res.messageAr.contains('✅');
      _showSnack(res.localizedMessage(_isAr),
          color: isUpdated ? Colors.green : Colors.blueGrey);
    } else {
      _showSnack(res.localizedMessage(_isAr), color: Colors.red);
    }
  }

  Future<void> _showRefundDialog(
      PaymentGatewayViewModel vm, PaymentLinkRecordModel item) async {
    final auth = context.read<AuthProvider>();
    if (!auth.canRefundPaymentGateway) {
      _showSnack(
        context.tr('pgw_refund_permission_denied'),
        color: Colors.red,
      );
      return;
    }

    final amountCtrl =
        TextEditingController(text: item.remainingRefundable.toStringAsFixed(3));
    final reasonCtrl =
        TextEditingController(text: context.tr('pgw_refund_default_reason'));
    bool isSubmitting = false;
    final providerCfg = vm.findProviderForRecord(item);
    final providerLabel = _isAr
        ? (item.providerNameAr.isNotEmpty
            ? item.providerNameAr
            : item.providerCode)
        : (providerCfg?.providerNameEn.isNotEmpty == true
            ? providerCfg!.providerNameEn
            : item.providerCode);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${context.tr('pgw_refund_dialog_title')} $providerLabel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.tr('pgw_invoice_prefix')}: #${item.invId} | ${context.tr('pgw_refund_max_available')} ${item.remainingRefundable.toStringAsFixed(3)} ${item.currencyCode}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                enabled: item.allowPartialRefunds && !isSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.tr('pgw_refund_amount_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  labelText: context.tr('pgw_refund_reason_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(context.tr('pgw_cancel_btn')),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final val =
                          double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (val <= 0 || val > item.remainingRefundable) {
                        _showSnack(context.tr('pgw_refund_invalid_amount'),
                            color: Colors.orange);
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      final res = await vm.refundLink(
                        item: item,
                        refundAmount: val,
                        reason: reasonCtrl.text.trim().isEmpty
                            ? 'Customer Request'
                            : reasonCtrl.text.trim(),
                        userId: auth.userId ?? 1,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        _showSnack(
                          res.localizedMessage(_isAr),
                          color: res.success ? Colors.green : Colors.red,
                        );
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.undo),
              label: Text(context.tr('pgw_refund_confirm_btn')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCustomerPicker(PaymentGatewayViewModel vm) async {
    final searchCtrl = TextEditingController();
    final picked = await showDialog<GatewayCustomerModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = vm.customers.where((c) {
            if (q.isEmpty) return true;
            return c.partnerName.toLowerCase().contains(q) ||
                c.phone.toLowerCase().contains(q);
          }).toList();
          return AlertDialog(
            title: Text(context.tr('pgw_pick_customer_title')),
            content: SizedBox(
              width: 380,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('pgw_pick_customer_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(context.tr('pgw_pick_customer_empty')))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 16,
                                  child: Icon(Icons.person, size: 18),
                                ),
                                title: Text(c.partnerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(c.phone.isEmpty
                                    ? context.tr('pgw_no_phone')
                                    : c.phone),
                                onTap: () => Navigator.pop(ctx, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  vm.setSelectedCustomer(null);
                  Navigator.pop(ctx);
                },
                child: Text(context.tr('pgw_walkin_customer_btn')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('pgw_close_btn')),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null && mounted) {
      vm.setSelectedCustomer(picked);
      setState(() {
        _customerNameCtrl.text = picked.partnerName;
        _customerPhoneCtrl.text = picked.phone;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partiallyrefunded':
        return Colors.deepOrange;
      case 'refunded':
        return Colors.red;
      case 'failed':
      case 'expired':
      case 'cancelled':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return context.tr('pgw_status_paid');
      case 'partiallyrefunded':
        return context.tr('pgw_status_partially_refunded');
      case 'refunded':
        return context.tr('pgw_status_refunded');
      case 'failed':
        return context.tr('pgw_status_failed');
      case 'expired':
        return context.tr('pgw_status_expired');
      case 'cancelled':
        return context.tr('pgw_status_cancelled');
      default:
        return context.tr('pgw_status_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentGatewayViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text(context.tr('pgw_title')),
            backgroundColor: Colors.indigo.shade800,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: vm.isCreateCardExpanded
                    ? context.tr('pgw_tooltip_collapse_create')
                    : context.tr('pgw_tooltip_expand_create'),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: vm.isCreateCardExpanded
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(vm.isCreateCardExpanded
                      ? Icons.link_off
                      : Icons.add_link),
                ),
                onPressed: vm.toggleCreateCard,
              ),
              IconButton(
                tooltip: vm.isFilterCardExpanded
                    ? context.tr('pgw_tooltip_collapse_filter')
                    : context.tr('pgw_tooltip_expand_filter'),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: vm.isFilterCardExpanded
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(vm.isFilterCardExpanded
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined),
                ),
                onPressed: vm.toggleFilterCard,
              ),
              IconButton(
                tooltip: context.tr('pgw_tooltip_refresh_list'),
                icon: const Icon(Icons.refresh),
                onPressed: vm.isLoading ? null : () => vm.loadLinks(),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildKpiBar(vm),
              _buildCollapsibleCreateCard(vm),
              _buildCollapsibleFilterCard(vm),
              Expanded(
                child: vm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : vm.links.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => vm.loadLinks(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 8, 12, 12),
                              itemCount: vm.links.length,
                              itemBuilder: (_, idx) =>
                                  _buildLinkCard(vm, vm.links[idx]),
                            ),
                          ),
              ),
              _buildPaginationBar(vm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiBar(PaymentGatewayViewModel vm) {
    final curr = context.tr('pgw_currency_kwd');
    return Container(
      color: Colors.indigo.shade800,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 680;
          final items = [
            _kpiTile(context.tr('pgw_kpi_paid'),
                '${vm.summaryPaid.toStringAsFixed(3)} $curr',
                Icons.check_circle_outline, Colors.greenAccent.shade200),
            _kpiTile(context.tr('pgw_kpi_pending'),
                '${vm.summaryPending.toStringAsFixed(3)} $curr',
                Icons.hourglass_bottom, Colors.amberAccent.shade200),
            _kpiTile(context.tr('pgw_kpi_refunded'),
                '${vm.summaryRefunded.toStringAsFixed(3)} $curr',
                Icons.undo, Colors.redAccent.shade100),
            _kpiTile(context.tr('pgw_kpi_links_count'), '${vm.totalCount}',
                Icons.receipt_long_outlined, Colors.lightBlueAccent.shade100),
          ];
          if (isWide) {
            return Row(
              children: items
                  .map((w) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: w,
                        ),
                      ))
                  .toList(),
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((w) => SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: w,
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _kpiTile(String title, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleCreateCard(PaymentGatewayViewModel vm) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: vm.isCreateCardExpanded ? 1.0 : 0.0,
        child: vm.isCreateCardExpanded
            ? Card(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: vm.toggleCreateCard,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.indigo.shade50,
                              child: Icon(Icons.add_link,
                                  color: Colors.indigo.shade700, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('pgw_create_card_title'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_up),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: vm.configuredGateways.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                context.tr('pgw_no_gateway_warning'),
                                style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w600),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Divider(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: Center(
                                            child: Text(context.tr('pgw_mode_single'))),
                                        selected: !vm.isConsolidatedMode,
                                        onSelected: (_) =>
                                            vm.setConsolidatedMode(false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: Center(
                                            child: Text(context.tr('pgw_mode_consolidated'))),
                                        selected: vm.isConsolidatedMode,
                                        onSelected: (_) =>
                                            vm.setConsolidatedMode(true),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<int>(
                                  value:
                                      vm.selectedCreateProvider?.providerId,
                                  decoration: InputDecoration(
                                    labelText: context.tr('pgw_label_gateway'),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: vm.configuredGateways
                                      .map(
                                        (g) {
                                          final gName = _isAr
                                              ? g.providerNameAr
                                              : (g.providerNameEn.isNotEmpty
                                                  ? g.providerNameEn
                                                  : g.providerNameAr);
                                          return DropdownMenuItem<int>(
                                            value: g.providerId,
                                            child: Text('$gName (${g.providerCode})'),
                                          );
                                        },
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    for (final g in vm.configuredGateways) {
                                      if (g.providerId == val) {
                                        vm.setCreateProvider(g);
                                        break;
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _customerNameCtrl,
                                        decoration: InputDecoration(
                                          labelText:
                                              context.tr('pgw_label_customer_name'),
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                          suffixIcon: IconButton(
                                            tooltip: context.tr('pgw_tooltip_pick_customer'),
                                            icon: const Icon(
                                                Icons.person_search_outlined),
                                            onPressed: () =>
                                                _openCustomerPicker(vm),
                                          ),
                                        ),
                                        onChanged: (_) {
                                          if (vm.selectedCustomer != null) {
                                            vm.setSelectedCustomer(null);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _customerPhoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: context.tr('pgw_label_phone'),
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (!vm.isConsolidatedMode)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _invIdCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: context.tr('pgw_label_inv_id'),
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                            suffixIcon: vm.isLookingUpInvoice
                                                ? const Padding(
                                                    padding: EdgeInsets.all(10),
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    ),
                                                  )
                                                : IconButton(
                                                    tooltip:
                                                        context.tr('pgw_tooltip_lookup_inv'),
                                                    icon: const Icon(Icons
                                                        .manage_search_rounded),
                                                    onPressed: () =>
                                                        _handleLookupSingleInvoice(
                                                            vm),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _amountCtrl,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                  decimal: true),
                                          decoration: InputDecoration(
                                            labelText: context.tr('pgw_label_required_amount'),
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50
                                          .withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.indigo.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _consInvIdCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: context.tr('pgw_label_inv_id'),
                                                  border:
                                                      const OutlineInputBorder(),
                                                  isDense: true,
                                                  suffixIcon: IconButton(
                                                    tooltip: context.tr('pgw_tooltip_lookup_rem'),
                                                    icon: const Icon(
                                                        Icons.search,
                                                        size: 18),
                                                    onPressed: () =>
                                                        _handleLookupConsolidatedInvoice(
                                                            vm),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: TextField(
                                                controller: _consAmountCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                  labelText: context.tr('pgw_label_amount'),
                                                  border: const OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton.filled(
                                              onPressed: () =>
                                                  _handleAddConsolidatedRow(vm),
                                              icon: const Icon(Icons.add),
                                              tooltip: context.tr('pgw_tooltip_add_to_list'),
                                            ),
                                          ],
                                        ),
                                        if (vm.consolidatedItems
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: List.generate(
                                              vm.consolidatedItems.length,
                                              (i) {
                                                final row =
                                                    vm.consolidatedItems[i];
                                                return Chip(
                                                  label: Text(
                                                    '#${row.invId}: ${row.amount.toStringAsFixed(3)}',
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                  onDeleted: () =>
                                                      vm.removeConsolidatedInvoice(
                                                          i),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${context.tr('pgw_consolidated_total')}: ${vm.consolidatedTotalAmount.toStringAsFixed(3)} ${vm.selectedCreateProvider?.defaultCurrency ?? context.tr('pgw_currency_kwd')}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo.shade800,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _notesCtrl,
                                  decoration: InputDecoration(
                                    labelText: context.tr('pgw_label_notes'),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  onPressed: vm.isCreatingLink
                                      ? null
                                      : () => _handleCreateLink(vm),
                                  icon: vm.isCreatingLink
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Icon(Icons.send_rounded),
                                  label: Text(
                                    vm.isCreatingLink
                                        ? context.tr('pgw_btn_creating')
                                        : context.tr('pgw_btn_create_now'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _buildCollapsibleFilterCard(PaymentGatewayViewModel vm) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: vm.isFilterCardExpanded ? 1.0 : 0.0,
        child: vm.isFilterCardExpanded
            ? Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: vm.toggleFilterCard,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list,
                                color: Colors.indigo.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('pgw_filter_title'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_up),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: context.tr('pgw_search_hint'),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        vm.setSearchText('');
                                        vm.loadLinks(goToPage: 1);
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              setState(() {});
                              vm.setSearchText(v);
                            },
                            onSubmitted: (_) => vm.loadLinks(goToPage: 1),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: vm.filterProviderCode,
                                  decoration: InputDecoration(
                                    labelText: context.tr('pgw_filter_gateway'),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                        value: 'ALL',
                                        child: Text(context.tr('pgw_filter_all_gateways'))),
                                    const DropdownMenuItem(
                                        value: 'TAP',
                                        child: Text('Tap Payments')),
                                    const DropdownMenuItem(
                                        value: 'MYFATOORAH',
                                        child: Text('MyFatoorah')),
                                    const DropdownMenuItem(
                                        value: 'UPAYMENTS',
                                        child: Text('UPayments')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) vm.setFilterProviderCode(v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: vm.filterStatus,
                                  decoration: InputDecoration(
                                    labelText: context.tr('pgw_filter_status'),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                        value: 'ALL',
                                        child: Text(context.tr('pgw_filter_all_statuses'))),
                                    DropdownMenuItem(
                                        value: 'Pending',
                                        child: Text(context.tr('pgw_status_pending'))),
                                    DropdownMenuItem(
                                        value: 'Paid',
                                        child: Text(context.tr('pgw_status_paid'))),
                                    DropdownMenuItem(
                                        value: 'PartiallyRefunded',
                                        child: Text(context.tr('pgw_status_partially_refunded'))),
                                    DropdownMenuItem(
                                        value: 'Refunded',
                                        child: Text(context.tr('pgw_status_refunded'))),
                                    DropdownMenuItem(
                                        value: 'Failed',
                                        child: Text(context.tr('pgw_status_failed'))),
                                    DropdownMenuItem(
                                        value: 'Expired',
                                        child: Text(context.tr('pgw_status_expired'))),
                                    DropdownMenuItem(
                                        value: 'Cancelled',
                                        child: Text(context.tr('pgw_status_cancelled'))),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) vm.setFilterStatus(v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 13),
                                ),
                                onPressed: () => vm.loadLinks(goToPage: 1),
                                child: const Icon(Icons.search),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            context.tr('pgw_empty_links'),
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(
      PaymentGatewayViewModel vm, PaymentLinkRecordModel item) {
    final sColor = _statusColor(item.linkStatus);
    final isBusy = vm.isLinkBusy(item.linkId);
    final canUserRefund = context.watch<AuthProvider>().canRefundPaymentGateway;
    final providerTitle = _providerDisplayName(vm, item);
    final displayCustName =
        (item.customerName == 'عميل نقدي' && !_isAr)
            ? context.tr('pgw_default_cash_customer')
            : item.customerName;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${context.tr('pgw_invoice_prefix')} #${item.invId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15.5),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${item.linkId}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
                if (item.isConsolidated) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.tr('pgw_badge_consolidated'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      providerTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${context.tr('pgw_customer_prefix')} $displayCustName${item.customerPhone.isNotEmpty ? ' • ${item.customerPhone}' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.amount.toStringAsFixed(3)} ${item.currencyCode}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                      color: Colors.teal),
                ),
              ],
            ),
            if (item.refundedAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${context.tr('pgw_refunded_label')} ${item.refundedAmount.toStringAsFixed(3)} ${item.currencyCode} | ${context.tr('pgw_net_collected_label')} ${item.remainingRefundable.toStringAsFixed(3)} ${item.currencyCode}',
                style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600),
              ),
            ],
            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const Divider(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: item.paymentUrl.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                              ClipboardData(text: item.paymentUrl));
                          if (!mounted) return;
                          _showSnack(context.tr('pgw_link_copied'));
                        },
                  icon: const Icon(Icons.copy, size: 17),
                  label: Text(context.tr('pgw_btn_copy')),
                ),
                TextButton.icon(
                  onPressed: item.paymentUrl.isEmpty
                      ? null
                      : () => _sendWhatsApp(item),
                  icon: const Icon(Icons.chat, size: 17, color: Colors.green),
                  label: Text(context.tr('pgw_btn_whatsapp'),
                      style: const TextStyle(color: Colors.green)),
                ),
                TextButton.icon(
                  onPressed: item.paymentUrl.isEmpty || isBusy
                      ? null
                      : () => _showQrPopup(vm, item),
                  icon: const Icon(Icons.qr_code_2,
                      size: 18, color: Colors.deepPurple),
                  label: Text(context.tr('pgw_btn_print_qr'),
                      style: const TextStyle(color: Colors.deepPurple)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _statusLabel(context, item.linkStatus),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: sColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.canRefund && canUserRefund)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed:
                            isBusy ? null : () => _showRefundDialog(vm, item),
                        icon: const Icon(Icons.undo, size: 17),
                        label: Text(context.tr('pgw_btn_refund')),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed:
                          isBusy ? null : () => _handleRefreshStatus(vm, item),
                      icon: isBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 17),
                      label: Text(context.tr('pgw_btn_check_status')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(PaymentGatewayViewModel vm) {
    final perPage = context.tr('pgw_per_page');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          DropdownButton<int>(
            value: vm.pageSize,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 10, child: Text('10 / $perPage')),
              DropdownMenuItem(value: 15, child: Text('15 / $perPage')),
              DropdownMenuItem(value: 25, child: Text('25 / $perPage')),
              DropdownMenuItem(value: 50, child: Text('50 / $perPage')),
            ],
            onChanged: (v) {
              if (v != null) vm.setPageSize(v);
            },
          ),
          const Spacer(),
          IconButton(
            tooltip: context.tr('pgw_prev_page'),
            onPressed: (vm.hasPrevPage && !vm.isLoading) ? vm.prevPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${context.tr('pgw_page_word')} ${vm.pageNumber} ${context.tr('pgw_of_word')} ${vm.totalPages} (${vm.totalCount})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          IconButton(
            tooltip: context.tr('pgw_next_page'),
            onPressed: (vm.hasNextPage && !vm.isLoading) ? vm.nextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
