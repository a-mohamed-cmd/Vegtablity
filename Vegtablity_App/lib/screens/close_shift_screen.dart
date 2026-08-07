import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/shift_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import 'shift_screen.dart';
import '../core/localization/app_localizations.dart';

double _parseD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _cashController = TextEditingController();
  bool _isLoadingSummary = true;
  bool _isClosing = false;
  bool _isPrinting = false;
  String _errorMessage = '';
  Map<String, dynamic>? _summary;
  List<dynamic> _salesInvoices = [];
  List<dynamic> _purchaseInvoices = [];

  double get _endingCash => double.tryParse(_cashController.text.trim()) ?? 0.0;
  double get _startingCash => _parseD(_summary?['StartingCash']);
  double get _totalPaidSales => _parseD(_summary?['TotalPaidSales']);
  double get _totalPaidPurchases => _parseD(_summary?['TotalPaidPurchases']);
  double get _totalReceiptVouchers => _parseD(_summary?['TotalReceiptVouchers']);
  double get _totalPaymentVouchers => _parseD(_summary?['TotalPaymentVouchers']);
  // معادلة الكاش: عهدة الافتتاح + مبيعات مسددة - مشتريات مسددة + سندات قبض - سندات صرف
  double get _expectedCash => _startingCash + _totalPaidSales - _totalPaidPurchases
      + _totalReceiptVouchers - _totalPaymentVouchers;
  double get _difference => _endingCash - _expectedCash;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _errorMessage = '';
    });
    try {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      // جلب ملخص الوردية
      final summaryData = await shiftProvider.fetchShiftSummary();
      if (summaryData == null) {
        setState(() {
          _errorMessage = context.tr('cs_summary_fetch_error');
          _isLoadingSummary = false;
        });
        return;
      }

      // جلب قوائم الفواتير للطباعة
      final shiftId = shiftProvider.shiftId;

      final results = await Future.wait<Response>([
        apiService.getInvoices(type: 'Sales', shiftId: shiftId),
        apiService.getInvoices(type: 'Purchase', shiftId: shiftId),
      ]);

      setState(() {
        _summary = summaryData;
        _salesInvoices = (results[0].statusCode == 200) ? (results[0].data ?? []) : [];
        _purchaseInvoices = (results[1].statusCode == 200) ? (results[1].data ?? []) : [];
        _isLoadingSummary = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = context.tr('cs_data_load_error').replaceAll('{error}', e.toString());
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _confirmAndClose() async {
    final endingCash = _endingCash;
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final shiftId = shiftProvider.shiftId;

    if (shiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('cs_no_open_shift')), backgroundColor: Colors.red),
      );
      return;
    }

    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    
    final offlineInvoices = posProvider.offlineInvoicesCount;
    final offlineVouchers = voucherProvider.offlineVouchersCount;

    if (offlineInvoices > 0 || offlineVouchers > 0) {
      final syncConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2A38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            context.tr('cs_unsynced_data_title'),
            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: Text(
            context.tr('cs_unsynced_data_msg')
                .replaceAll('{invoices}', offlineInvoices.toString())
                .replaceAll('{vouchers}', offlineVouchers.toString()),
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cs_cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: Text(context.tr('cs_sync_now')),
            ),
          ],
        ),
      );

      if (syncConfirmed == true) {
        setState(() => _isClosing = true);
        
        bool successInvoices = true;
        if (offlineInvoices > 0) {
          successInvoices = await posProvider.syncOfflineInvoices();
        }
        
        bool successVouchers = true;
        if (offlineVouchers > 0) {
          successVouchers = await voucherProvider.syncOfflineVouchers();
        }
        
        setState(() => _isClosing = false);
        
        if (!successInvoices || !successVouchers || posProvider.offlineInvoicesCount > 0 || voucherProvider.offlineVouchersCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('cs_sync_failed'), textAlign: TextAlign.right),
              backgroundColor: Colors.redAccent,
            ),
          );
          return; // Abort closure
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('cs_sync_success'), textAlign: TextAlign.right),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        return; // Abort closure if they don't want to sync
      }
    }

    // Dialog تأكيد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('cs_confirm_close_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.tr('cs_entered_cash').replaceAll('{amount}', endingCash.toStringAsFixed(3)),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('cs_expected_cash_msg').replaceAll('{amount}', _expectedCash.toStringAsFixed(3)),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('cs_difference_msg').replaceAll('{amount}', _difference.toStringAsFixed(3)),
                style: TextStyle(
                  color: _difference.abs() < 0.001 ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('cs_confirm_close_with_print_msg'),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cs_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('cs_yes_close_shift')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 1. طباعة تقرير اليومية
    setState(() => _isPrinting = true);
    try {
      final printerService = Provider.of<PrinterService>(context, listen: false);
      await printerService.printDailyReport(
        summary: _summary!,
        salesInvoices: _salesInvoices,
        purchaseInvoices: _purchaseInvoices,
        endingCash: endingCash,
      );
    } catch (e) {
      // لا نوقف الإغلاق إذا فشلت الطباعة
      debugPrint('فشل طباعة التقرير: $e');
    }
    setState(() => _isPrinting = false);

    // 2. إغلاق الوردية
    setState(() => _isClosing = true);
    try {
      await shiftProvider.closeShift(shiftId, endingCash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('cs_close_success_msg')} ✓', textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
        // الانتقال لشاشة فتح وردية جديدة
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ShiftScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isClosing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('cs_close_error_msg').replaceAll('{error}', e.toString()), textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(dynamic dt) {
    if (dt == null) return '--';
    try {
      final parsed = DateTime.parse(dt.toString()).toLocal();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}  '
          '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt.toString();
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.white,
                )),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(label,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child, Color? titleColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: titleColor ?? Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = _isClosing || _isPrinting;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        title: Text(context.tr('cs_screen_title')),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E2A38),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingSummary
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(context.tr('cs_loading_summary'),
                      style: const TextStyle(color: Colors.white60)),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_errorMessage,
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadSummary,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.tr('cs_retry')),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // بطاقة معلومات الوردية
                      _buildCard(
                        title: context.tr('cs_shift_info'),
                        child: Column(
                          children: [
                            _buildInfoRow(context.tr('cs_cashier'), _summary?['UserName'] ?? '-'),
                            _buildInfoRow(context.tr('cs_open_time'), _formatDateTime(_summary?['StartTime'])),
                            _buildInfoRow(context.tr('cs_status'), _summary?['Status'] ?? '-',
                                valueColor: Colors.greenAccent),
                          ],
                        ),
                      ),

                      // بطاقة المبيعات
                      _buildCard(
                        title: context.tr('cs_sales_summary'),
                        titleColor: Colors.blue[300],
                        child: Column(
                          children: [
                            _buildInfoRow(
                                context.tr('cs_invoices_count'),
                                context.tr('cs_invoice_count').replaceAll('{count}', (_summary?['SalesCount'] ?? 0).toString())),
                            _buildInfoRow(
                                context.tr('cs_total_sales_label'),
                                '${_parseD(_summary?['TotalSales']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.blue[300]),
                            _buildInfoRow(
                                context.tr('cs_paid_sales_label'),
                                '${_parseD(_summary?['TotalPaidSales']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.greenAccent),
                            _buildInfoRow(
                                context.tr('cs_credit_sales_label'),
                                '${_parseD(_summary?['TotalRemainder']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.orangeAccent),
                          ],
                        ),
                      ),

                      // بطاقة المشتريات
                      _buildCard(
                        title: context.tr('cs_purchases_summary'),
                        titleColor: Colors.orange[300],
                        child: Column(
                          children: [
                            _buildInfoRow(
                                context.tr('cs_invoices_count'),
                                context.tr('cs_invoice_count').replaceAll('{count}', (_summary?['PurchasesCount'] ?? 0).toString())),
                            _buildInfoRow(
                                context.tr('cs_total_purchases_label'),
                                '${_parseD(_summary?['TotalPurchases']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.orange[300]),
                            _buildInfoRow(
                                context.tr('cs_paid_purchases_label'),
                                '${_parseD(_summary?['TotalPaidPurchases']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.redAccent[100]),
                            _buildInfoRow(
                                context.tr('cs_credit_purchases_label'),
                                '${_parseD(_summary?['TotalPurchasesRemainder']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.orangeAccent),
                          ],
                        ),
                      ),

                      // بطاقة السندات
                      _buildCard(
                        title: context.tr('cs_vouchers_summary'),
                        titleColor: Colors.purple[300],
                        child: Column(
                          children: [
                            _buildInfoRow(
                                context.tr('cs_total_receipts'),
                                '${_totalReceiptVouchers.toStringAsFixed(3)} KWD',
                                valueColor: Colors.greenAccent[200]),
                            _buildInfoRow(
                                context.tr('cs_total_payments'),
                                '${_totalPaymentVouchers.toStringAsFixed(3)} KWD',
                                valueColor: Colors.orangeAccent),
                          ],
                        ),
                      ),

                      // بطاقة تفاصيل طرق الدفع
                      if (_summary?['PaymentTotals'] != null &&
                          (_summary!['PaymentTotals'] as List).isNotEmpty)
                        _buildCard(
                          title: 'تفاصيل طرق الدفع في الوردية',
                          titleColor: Colors.tealAccent,
                          child: Column(
                            children: (_summary!['PaymentTotals'] as List).map<Widget>((pt) {
                              final name = pt['PaymentMethodName'] ?? 'طريقة دفع';
                              final amt = _parseD(pt['TotalAmount']);
                              final isIncome = pt['InvType'] == 'Sales' || pt['InvType'] == 'Receipt';
                              final labelType = isIncome ? 'تحصيل / مبيعات' : 'سداد / مشتريات';
                              final color = isIncome ? Colors.greenAccent : Colors.orangeAccent;
                              return _buildInfoRow('$name ($labelType)', '${amt.toStringAsFixed(3)} KWD', valueColor: color);
                            }).toList(),
                          ),
                        ),



                      // بطاقة الكاش
                      _buildCard(
                        title: context.tr('cs_cash_drawer_calc'),
                        titleColor: Colors.greenAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildInfoRow(
                                context.tr('cs_starting_cash'),
                                '${_startingCash.toStringAsFixed(3)} KWD'),
                            _buildInfoRow(
                                context.tr('cs_add_paid_sales'),
                                '${_totalPaidSales.toStringAsFixed(3)} KWD',
                                valueColor: Colors.greenAccent),
                            _buildInfoRow(
                                context.tr('cs_sub_paid_purchases'),
                                '${_totalPaidPurchases.toStringAsFixed(3)} KWD',
                                valueColor: Colors.redAccent[100]),
                            if (_totalReceiptVouchers > 0)
                              _buildInfoRow(
                                  context.tr('cs_add_receipts'),
                                  '${_totalReceiptVouchers.toStringAsFixed(3)} KWD',
                                  valueColor: Colors.greenAccent[200]),
                            if (_totalPaymentVouchers > 0)
                              _buildInfoRow(
                                  context.tr('cs_sub_payments'),
                                  '${_totalPaymentVouchers.toStringAsFixed(3)} KWD',
                                  valueColor: Colors.orangeAccent),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_expectedCash.toStringAsFixed(3)} KWD',
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('= ${context.tr('cs_expected_cash')}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(color: Colors.white60, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              context.tr('cs_enter_actual_cash_hint'),
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _cashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              decoration: InputDecoration(
                                hintText: '0.000',
                                hintStyle: const TextStyle(color: Colors.white30),
                                prefixText: 'KWD  ',
                                prefixStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            // الفرق
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _difference.abs() < 0.001
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_difference >= 0 ? '+' : ''}${_difference.toStringAsFixed(3)} KWD',
                                    style: TextStyle(
                                      color: _difference.abs() < 0.001
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(context.tr('cs_difference'),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            color: Colors.white60, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // زر الإغلاق
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: isBusy ? null : _confirmAndClose,
                          icon: isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.lock_outline),
                          label: Text(
                            _isPrinting
                                ? context.tr('cs_printing')
                                : _isClosing
                                    ? context.tr('cs_closing')
                                    : context.tr('cs_close_print_btn'),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
