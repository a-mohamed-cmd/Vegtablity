import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import 'shift_screen.dart';

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
  // معادلة الكاش: عهدة الافتتاح - مشتريات مسددة + مبيعات مسددة
  double get _expectedCash => _startingCash - _totalPaidPurchases + _totalPaidSales;
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
          _errorMessage = 'تعذر جلب ملخص الوردية. تأكد من وجود وردية مفتوحة.';
          _isLoadingSummary = false;
        });
        return;
      }

      // جلب قوائم الفواتير للطباعة
      final shiftStart = shiftProvider.shiftStartTime;
      String? shiftDateOnly;
      if (shiftStart != null) {
        try {
          final parsed = DateTime.parse(shiftStart);
          shiftDateOnly =
              '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
        } catch (_) {}
      }

      final results = await Future.wait([
        apiService.getInvoices(type: 'Sales', shiftDate: shiftDateOnly),
        apiService.getInvoices(type: 'Purchase', shiftDate: shiftDateOnly),
      ]);

      setState(() {
        _summary = summaryData;
        _salesInvoices = (results[0].statusCode == 200) ? (results[0].data ?? []) : [];
        _purchaseInvoices = (results[1].statusCode == 200) ? (results[1].data ?? []) : [];
        _isLoadingSummary = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تحميل البيانات: $e';
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
        const SnackBar(content: Text('لا توجد وردية مفتوحة'), backgroundColor: Colors.red),
      );
      return;
    }

    final posProvider = Provider.of<PosProvider>(context, listen: false);
    if (posProvider.offlineInvoicesCount > 0) {
      final syncConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2A38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'فواتير غير متزامنة',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: Text(
            'يوجد عدد ${posProvider.offlineInvoicesCount} فاتورة/فواتير غير متزامنة.\nيجب مزامنتها مع الخادم قبل إغلاق الوردية.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('مزامنة الآن'),
            ),
          ],
        ),
      );

      if (syncConfirmed == true) {
        setState(() => _isClosing = true);
        final success = await posProvider.syncOfflineInvoices();
        setState(() => _isClosing = false);
        
        if (!success || posProvider.offlineInvoicesCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشلت مزامنة بعض الفواتير. يرجى التحقق من اتصالك بالإنترنت.', textAlign: TextAlign.right),
              backgroundColor: Colors.redAccent,
            ),
          );
          return; // Abort closure
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تمت المزامنة بنجاح.', textAlign: TextAlign.right),
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
        title: const Text(
          'تأكيد إغلاق الوردية',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'الكاش الختامي المُدخل: ${endingCash.toStringAsFixed(3)} KWD',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'الكاش المتوقع: ${_expectedCash.toStringAsFixed(3)} KWD',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'الفرق: ${_difference.toStringAsFixed(3)} KWD',
                style: TextStyle(
                  color: _difference.abs() < 0.001 ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'هل أنت متأكد من إغلاق الوردية؟\nسيتم طباعة تقرير اليومية قبل الإغلاق.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، أغلق الوردية'),
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
          const SnackBar(
            content: Text('تم إغلاق الوردية بنجاح ✓', textAlign: TextAlign.right),
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
            content: Text('فشل إغلاق الوردية: $e', textAlign: TextAlign.right),
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
          Text(value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.white,
              )),
          Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.white60)),
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
        title: const Text('إغلاق الوردية'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E2A38),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingSummary
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('جاري تحميل ملخص الوردية...',
                      style: TextStyle(color: Colors.white60)),
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
                          label: const Text('إعادة المحاولة'),
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
                        title: '📋 معلومات الوردية',
                        child: Column(
                          children: [
                            _buildInfoRow('الكاشير', _summary?['UserName'] ?? '-'),
                            _buildInfoRow('وقت الفتح', _formatDateTime(_summary?['StartTime'])),
                            _buildInfoRow('الحالة', _summary?['Status'] ?? '-',
                                valueColor: Colors.greenAccent),
                          ],
                        ),
                      ),

                      // بطاقة المبيعات
                      _buildCard(
                        title: '📈 مبيعات الوردية',
                        titleColor: Colors.blue[300],
                        child: Column(
                          children: [
                            _buildInfoRow(
                                'عدد الفواتير',
                                '${_summary?['SalesCount'] ?? 0} فاتورة'),
                            _buildInfoRow(
                                'إجمالي المبيعات',
                                '${_parseD(_summary?['TotalSales']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.blue[300]),
                            _buildInfoRow(
                                'مُسدَّد نقداً',
                                '${_parseD(_summary?['TotalPaidSales']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.greenAccent),
                            _buildInfoRow(
                                'آجل متبقي',
                                '${_parseD(_summary?['TotalRemainder']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.orangeAccent),
                          ],
                        ),
                      ),

                      // بطاقة المشتريات
                      _buildCard(
                        title: '📦 مشتريات الوردية',
                        titleColor: Colors.orange[300],
                        child: Column(
                          children: [
                            _buildInfoRow(
                                'عدد الفواتير',
                                '${_summary?['PurchasesCount'] ?? 0} فاتورة'),
                            _buildInfoRow(
                                'إجمالي المشتريات',
                                '${_parseD(_summary?['TotalPurchases']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.orange[300]),
                            _buildInfoRow(
                                'مُسدَّد نقداً',
                                '${_parseD(_summary?['TotalPaidPurchases']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.redAccent[100]),
                            _buildInfoRow(
                                'آجل متبقي',
                                '${_parseD(_summary?['TotalPurchasesRemainder']).toStringAsFixed(3)} KWD',
                                valueColor: Colors.orangeAccent),
                          ],
                        ),
                      ),

                      // بطاقة الكاش
                      _buildCard(
                        title: '💰 تسوية الكاش',
                        titleColor: Colors.greenAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildInfoRow(
                                'عهدة الافتتاح',
                                '${_startingCash.toStringAsFixed(3)} KWD'),
                            _buildInfoRow(
                                '+ مبيعات مسددة',
                                '${_totalPaidSales.toStringAsFixed(3)} KWD',
                                valueColor: Colors.greenAccent),
                            _buildInfoRow(
                                '- مشتريات مسددة',
                                '${_totalPaidPurchases.toStringAsFixed(3)} KWD',
                                valueColor: Colors.redAccent[100]),
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
                                  const Text('= الكاش المتوقع',
                                      style: TextStyle(color: Colors.white60, fontSize: 14)),
                                ],
                              ),
                            ),
                            const Text(
                              'أدخل الكاش الختامي الفعلي:',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.white60, fontSize: 13),
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
                                  const Text('الفرق:',
                                      style: TextStyle(
                                          color: Colors.white60, fontSize: 14)),
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
                                ? 'جاري الطباعة...'
                                : _isClosing
                                    ? 'جاري الإغلاق...'
                                    : 'طباعة التقرير وإغلاق الوردية',
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
