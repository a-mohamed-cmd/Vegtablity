import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../services/printer_service.dart';
import '../providers/shift_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class DailyInvoicesScreen extends StatefulWidget {
  const DailyInvoicesScreen({super.key});

  @override
  State<DailyInvoicesScreen> createState() => _DailyInvoicesScreenState();
}

class _DailyInvoicesScreenState extends State<DailyInvoicesScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _salesInvoices = [];
  List<dynamic> _purchaseInvoices = [];
  List<dynamic> _receiptVouchers = [];
  List<dynamic> _paymentVouchers = [];

  double _totalSalesAmount = 0.0;
  double _totalPurchasesAmount = 0.0;
  double _totalReceiptAmount = 0.0;
  double _totalPaymentAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDailyData();
  }

  Future<void> _fetchDailyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      
      final shiftId = shiftProvider.shiftId;
      
      // Fetch Sales and Purchase invoices filtered by the shift ID
      final results = await Future.wait([
        apiService.getInvoices(type: 'Sales', shiftId: shiftId),
        apiService.getInvoices(type: 'Purchase', shiftId: shiftId),
      ]);
      
      final shiftSummary = await shiftProvider.fetchShiftSummary();
      final List<dynamic> allVouchers = shiftSummary != null && shiftSummary['Vouchers'] != null 
          ? List<dynamic>.from(shiftSummary['Vouchers']) 
          : [];

      final salesRes = results[0];
      final purchaseRes = results[1];

      if (salesRes.statusCode == 200 && purchaseRes.statusCode == 200) {
        final List<dynamic> allSales = salesRes.data ?? [];
        final List<dynamic> allPurchases = purchaseRes.data ?? [];

        List<dynamic> todaySales;
        List<dynamic> todayPurchases;

        if (shiftId != null) {
          // Stored procedure sp_Invoice_GetAll_Pos already filtered by shift ID!
          todaySales = allSales;
          todayPurchases = allPurchases;
        } else {
          // Fallback: Filter for today's invoices only if no active shift exists
          final now = DateTime.now();
          final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          todaySales = allSales.where((inv) {
            final dateStr = inv['InvDate']?.toString() ?? '';
            return dateStr.startsWith(todayStr);
          }).toList();

          todayPurchases = allPurchases.where((inv) {
            final dateStr = inv['InvDate']?.toString() ?? '';
            return dateStr.startsWith(todayStr);
          }).toList();
        }

        // Calculate Sums
        double salesSum = 0.0;
        for (var inv in todaySales) {
          salesSum += _parseDouble(inv['NetAmount']);
        }

        double purchasesSum = 0.0;
        for (var inv in todayPurchases) {
          purchasesSum += _parseDouble(inv['NetAmount']);
        }

        // Process Vouchers
        List<dynamic> receiptVouchers = allVouchers.where((v) => v['VoucherType'] == 'Receipt').toList();
        List<dynamic> paymentVouchers = allVouchers.where((v) => v['VoucherType'] == 'Payment').toList();
        
        double receiptSum = 0.0;
        for (var v in receiptVouchers) {
          receiptSum += _parseDouble(v['Amount']);
        }
        
        double paymentSum = 0.0;
        for (var v in paymentVouchers) {
          paymentSum += _parseDouble(v['Amount']);
        }

        setState(() {
          _salesInvoices = todaySales;
          _purchaseInvoices = todayPurchases;
          _receiptVouchers = receiptVouchers;
          _paymentVouchers = paymentVouchers;
          
          _totalSalesAmount = salesSum;
          _totalPurchasesAmount = purchasesSum;
          _totalReceiptAmount = receiptSum;
          _totalPaymentAmount = paymentSum;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'فشل استرجاع فواتير اليوم من الخادم';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل الفواتير: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--:--';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final hour = parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:$minute $ampm';
    } catch (_) {
      return dateStr.split('T').last.substring(0, 5);
    }
  }

  void _showInvoiceDetails(int invId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _InvoiceDetailsBottomSheet(invId: invId);
      },
    );
    _fetchDailyData(); // Refresh daily report totals and lists on sheet dismissal
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final posProvider = Provider.of<PosProvider>(context);
    final voucherProvider = Provider.of<VoucherProvider>(context);
    
    final offlineInvoices = posProvider.offlineInvoices;
    final offlineVouchers = voucherProvider.offlineVouchers;
    final bool hasOfflineData = offlineInvoices.isNotEmpty || offlineVouchers.isNotEmpty;

    final now = DateTime.now();
    final todayFormatted = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('تقرير الفواتير اليومية والمستخدم'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDailyData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchDailyData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Cashier Info Header Banner
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person, color: Colors.tealAccent, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'المستخدم الحالي',
                                            style: TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                          Text(
                                            authProvider.username ?? 'غير معروف',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'تاريخ التقرير',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      Text(
                                        todayFormatted,
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),

                            if (hasOfflineData)
                              _buildOfflineDataSection(offlineInvoices, offlineVouchers),

                            // 1. Purchases Section (TOP)
                            _buildCategorySection(
                              title: 'مشتريات الموردين اليومية',
                              icon: Icons.shopping_basket_rounded,
                              accentColor: Colors.orange[700]!,
                              invoices: _purchaseInvoices,
                              totalAmount: _totalPurchasesAmount,
                            ),

                            // Decorative Split Divider with Label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: Colors.black26,
                              child: Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[800], thickness: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: const Text(
                                        'الفصل المالي اليومي',
                                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[800], thickness: 1)),
                                ],
                              ),
                            ),

                            // 2. Sales Section
                            _buildCategorySection(
                              title: 'مبيعات العملاء اليومية',
                              icon: Icons.point_of_sale_rounded,
                              accentColor: Colors.blue[600]!,
                              invoices: _salesInvoices,
                              totalAmount: _totalSalesAmount,
                            ),

                            // Decorative Split Divider with Label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: Colors.black26,
                              child: Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[800], thickness: 1)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: const Text(
                                        'السندات المالية للوردية',
                                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[800], thickness: 1)),
                                ],
                              ),
                            ),
                            
                            // 3. Receipt Vouchers
                            _buildVoucherSection(
                              title: 'سندات القبض (محصلات)',
                              icon: Icons.download_rounded,
                              accentColor: Colors.greenAccent[700]!,
                              vouchers: _receiptVouchers,
                              totalAmount: _totalReceiptAmount,
                            ),
                            
                            // 4. Payment Vouchers
                            _buildVoucherSection(
                              title: 'سندات الصرف (مدفوعات)',
                              icon: Icons.upload_rounded,
                              accentColor: Colors.deepOrangeAccent[200]!,
                              vouchers: _paymentVouchers,
                              totalAmount: _totalPaymentAmount,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Net cash flow footer Summary (Pinned to the bottom)
                    _buildSummaryFooter(),
                  ],
                ),
    );
  }

  Widget _buildOfflineDataSection(List<Map<String, dynamic>> invoices, List<Map<String, dynamic>> vouchers) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[900]?.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: const Border(bottom: BorderSide(color: Colors.redAccent)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_problem, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'بيانات معلقة (غير متزامنة)',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${invoices.length} فاتورة | ${vouchers.length} سند',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (invoices.isNotEmpty)
            ...invoices.map((inv) => ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.orangeAccent),
              title: Text('فاتورة (${inv['type'] == 'Sales' ? 'مبيعات' : 'مشتريات'})', style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text('الصافي: ${_parseDouble(inv['total_amount']).toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.cloud_off, color: Colors.redAccent, size: 16),
            )),
          if (vouchers.isNotEmpty)
            ...vouchers.map((v) => ListTile(
              leading: const Icon(Icons.receipt, color: Colors.purpleAccent),
              title: Text('سند (${v['VoucherType'] == 'Receipt' ? 'قبض' : 'صرف'})', style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text('المبلغ: ${_parseDouble(v['TotalAmount']).toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: const Icon(Icons.cloud_off, color: Colors.redAccent, size: 16),
            )),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<dynamic> invoices,
    required double totalAmount,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${invoices.length} فواتير',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Invoices List - Expands dynamically down based on contents
          invoices.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[700]),
                      const SizedBox(height: 8),
                      Text(
                        'لا يوجد فواتير مسجلة اليوم',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      )
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: invoices.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey[800], height: 1),
                  itemBuilder: (context, index) {
                    final inv = invoices[index];
                    final int invId = inv['InvID'] ?? 0;
                    final String partnerName = inv['PartnerName'] ?? 'عميل افتراضي';
                    final double netAmount = _parseDouble(inv['NetAmount']);
                    final double paidAmount = _parseDouble(inv['PaidAmount']);
                    final String timeFormatted = _formatTime(inv['InvDate']);
                    final bool isCredit = paidAmount < netAmount;

                    return InkWell(
                      onTap: () => _showInvoiceDetails(invId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Row(
                          children: [
                            // Time indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                timeFormatted,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Inv ID and partner
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'فاتورة #$invId',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (isCredit) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 0.5),
                                          ),
                                          child: const Text(
                                            'آجل',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      ] else ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 0.5),
                                          ),
                                          child: const Text(
                                            'نقدي / مدفوع',
                                            style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      ]
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    partnerName,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Amount column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${netAmount.toStringAsFixed(2)} د.ك',
                                  style: TextStyle(
                                    color: isCredit ? Colors.orangeAccent : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  paidAmount == netAmount
                                      ? 'مدفوع بالكامل'
                                      : 'متبقي آجل: ${(netAmount - paidAmount).toStringAsFixed(2)} د.ك',
                                  style: TextStyle(
                                    color: paidAmount == netAmount ? Colors.green[300] : Colors.red[300],
                                    fontSize: 10,
                                    fontWeight: paidAmount == netAmount ? FontWeight.normal : FontWeight.bold,
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // Total glow box footer inside category
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المجموع المالي للمعاملات',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '${totalAmount.toStringAsFixed(2)} د.ك',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVoucherSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<dynamic> vouchers,
    required double totalAmount,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: accentColor, fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: Text('${vouchers.length} سندات', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),
          vouchers.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 30, color: Colors.grey[700]),
                      const SizedBox(height: 8),
                      Text('لا توجد سندات في هذا القسم اليوم', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vouchers.length,
                  separatorBuilder: (ctx, idx) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (ctx, idx) {
                    final v = vouchers[idx];
                    final amount = _parseDouble(v['Amount']);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () => _showVoucherDetails(v),
                      title: Text(
                        'سند #${v['VoucherID']} - ${v['PartnerName'] ?? 'بدون شريك'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${_formatTime(v['VoucherDate'])} | ${v['AccountName'] ?? '-'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Text(
                        '${amount.toStringAsFixed(3)} KWD',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    );
                  },
                ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي السندات:', style: TextStyle(color: Colors.white60, fontSize: 14)),
                Text(
                  '${totalAmount.toStringAsFixed(3)} KWD',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVoucherDetails(Map<String, dynamic> voucher) {
    final amount = _parseDouble(voucher['Amount']);
    final vType = voucher['VoucherType'] == 'Receipt' ? 'سند قبض' : 'سند صرف';
    final accountName = voucher['AccountName'] ?? '-';
    final partnerName = voucher['PartnerName'] ?? 'بدون شريك';
    final date = _formatTime(voucher['VoucherDate']);
    final desc = voucher['Description']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.0,
          left: 24.0,
          right: 24.0,
          top: 24.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل $vType #${voucher['VoucherID']}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            _buildDetailRow('تاريخ السند', date),
            _buildDetailRow('الاسم (الشريك)', partnerName),
            _buildDetailRow('طريقة السداد', accountName),
            _buildDetailRow('ملاحظات', desc.isEmpty ? 'لا يوجد' : desc),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المبلغ الإجمالي', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text('${amount.toStringAsFixed(3)} د.ك', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('إعادة طباعة السند', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  try {
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    final printer = Provider.of<PrinterService>(context, listen: false);
                    
                    final res = await apiService.getVoucherAllocations(voucher['VoucherID']);
                    List<Map<String, dynamic>> allocs = [];
                    if (res.statusCode == 200 && res.data != null) {
                      allocs = List<Map<String, dynamic>>.from(res.data);
                    }
                    
                    await printer.printVoucher(voucher, allocs);
                  } catch (e) {
                    print("Error fetching allocations: $e");
                    final printer = Provider.of<PrinterService>(context, listen: false);
                    await printer.printVoucher(voucher, []);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryFooter() {
    final double netFlow = (_totalSalesAmount + _totalReceiptAmount) - (_totalPurchasesAmount + _totalPaymentAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: const Border(top: BorderSide(color: Colors.white10)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 15,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'صافي التدفق اليومي',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${netFlow >= 0 ? '+' : ''}${netFlow.toStringAsFixed(2)} د.ك',
                  style: TextStyle(
                    color: netFlow >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _fetchDailyData,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث البيانات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceDetailsBottomSheet extends StatefulWidget {
  final int invId;
  const _InvoiceDetailsBottomSheet({required this.invId});

  @override
  State<_InvoiceDetailsBottomSheet> createState() => _InvoiceDetailsBottomSheetState();
}

class _InvoiceDetailsBottomSheetState extends State<_InvoiceDetailsBottomSheet> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _invoiceData;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.getInvoiceDetails(widget.invId);

      if (response.statusCode == 200) {
        setState(() {
          _invoiceData = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'فشل جلب تفاصيل الفاتورة من الخادم';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ أثناء الاتصال بالشبكة: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _reprintInvoice(Map<String, dynamic> data) async {
    final List<dynamic> dbDetails = data['Details'] ?? [];
    
    final printData = {
      'InvID': data['InvID'],
      'PartnerName': data['PartnerName'],
      'type': data['InvType'],
      'created_at': data['InvDate'] ?? data['CreatedAt'] ?? DateTime.now().toIso8601String(),
      'total_amount': _parseDouble(data['NetAmount']),
      'items': dbDetails.map((item) => {
        'name': item['ProductName'] ?? 'صنف غير معروف',
        'price': _parseDouble(item['UnitPrice']),
        'quantity': _parseDouble(item['Quantity']).toInt(),
        'total': _parseDouble(item['TotalPrice']),
      }).toList(),
    };

    final printerService = Provider.of<PrinterService>(context, listen: false);
    final success = await printerService.printReceipt(printData);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم إعادة طباعة الفاتورة بنجاح' : 'فشل الاتصال بالطابعة',
            textAlign: TextAlign.right,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showPaymentDialog(Map<String, dynamic> invoiceData) {
    final double remainder = _parseDouble(invoiceData['Remainder']);
    final int invId = invoiceData['InvID'] ?? 0;
    
    final controller = TextEditingController(text: remainder.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'تسجيل سداد للفاتورة الآجلة',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المتبقي غير المدفوع: ${remainder.toStringAsFixed(2)} د.ك',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'مبلغ السداد المستلم',
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white30), borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.teal), borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? payAmount = double.tryParse(controller.text);
                if (payAmount == null || payAmount <= 0 || payAmount > remainder) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الرجاء إدخال مبلغ صحيح لا يتجاوز المتبقي', textAlign: TextAlign.right),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(context); // Close dialog
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  final response = await apiService.payInvoice(invId, payAmount);
                  
                  if (response.statusCode == 200) {
                    await _fetchDetails();
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تسجيل السداد بنجاح وتحديث القيود المحاسبية!', textAlign: TextAlign.right),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    setState(() {
                      _isLoading = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('فشل تسجيل السداد: ${response.data}', textAlign: TextAlign.right),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ أثناء عملية السداد: $e', textAlign: TextAlign.right),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              child: const Text('تأكيد السداد'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final year = parsed.year;
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      final hour = parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$year/$month/$day ${displayHour.toString().padLeft(2, '0')}:$minute $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: Colors.white10),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_isLoading) ...[
            const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.teal))),
          ] else if (_error.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(_error, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                ],
              ),
            ),
          ] else if (_invoiceData != null) ...[
            // Invoice header details
            _buildHeaderWidget(),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),

            // Products table header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('الصنف', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('السعر', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('الكمية', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                ],
              ),
            ),
            const Divider(color: Colors.white10),

            // Products list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: (_invoiceData!['Details'] as List?)?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = _invoiceData!['Details'][index];
                  final String prodName = item['ProductName'] ?? 'صنف غير معروف';
                  final double price = _parseDouble(item['UnitPrice']);
                  final double qty = _parseDouble(item['Quantity']);
                  final double total = _parseDouble(item['TotalPrice']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(prodName, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        Expanded(flex: 1, child: Text(price.toStringAsFixed(2), style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center)),
                        Expanded(flex: 1, child: Text(qty.toStringAsFixed(2), style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('${total.toStringAsFixed(2)} د.ك', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10),

            // Financial Summary
            _buildFinancialSummaryWidget(),
          ],
          const SizedBox(height: 24),
          if (_invoiceData != null) ...[
            Builder(
              builder: (context) {
                final double remainder = _parseDouble(_invoiceData!['Remainder']);
                if (remainder > 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPaymentDialog(_invoiceData!),
                        icon: const Icon(Icons.payment),
                        label: const Text('تسجيل سداد دفعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
            ),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _reprintInvoice(_invoiceData!),
                  icon: const Icon(Icons.print),
                  label: const Text('إعادة طباعة', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWidget() {
    final invoiceData = _invoiceData!;
    final String partnerName = invoiceData['PartnerName'] ?? 'عميل افتراضي';
    final String invTypeStr = invoiceData['InvType'] == 'Purchase' ? 'مشتريات' : 'مبيعات';
    final int invId = invoiceData['InvID'] ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فاتورة $invTypeStr #$invId',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              partnerName,
              style: const TextStyle(color: Colors.tealAccent, fontSize: 14),
            ),
          ],
        ),
        Text(
          _formatDateTime(invoiceData['InvDate']),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryWidget() {
    final invoiceData = _invoiceData!;
    final double totalAmount = _parseDouble(invoiceData['TotalAmount']);
    final double discount = _parseDouble(invoiceData['Discount']);
    final double netAmount = _parseDouble(invoiceData['NetAmount']);
    final double paidAmount = _parseDouble(invoiceData['PaidAmount']);
    final double remainder = _parseDouble(invoiceData['Remainder']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _buildSummaryRow('الإجمالي الكلي', '${totalAmount.toStringAsFixed(2)} د.ك', false),
        ),
        if (discount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: _buildSummaryRow('الخصم', '-${discount.toStringAsFixed(2)} د.ك', false, textColor: Colors.redAccent),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _buildSummaryRow('الصافي الكلي', '${netAmount.toStringAsFixed(2)} د.ك', true),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text('المدفوع', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${paidAmount.toStringAsFixed(2)} د.ك',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text('المتبقي (الآجل)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      '${remainder.toStringAsFixed(2)} د.ك',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isBold, {Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor ?? (isBold ? Colors.tealAccent : Colors.white70),
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
