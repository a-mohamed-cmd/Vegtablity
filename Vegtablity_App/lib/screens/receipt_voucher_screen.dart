import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/voucher_provider.dart';
import '../services/api_service.dart';
import '../providers/shift_provider.dart';
import '../services/printer_service.dart';

/// شاشة سند القبض - تحصيل مديونيات من العملاء
class ReceiptVoucherScreen extends StatefulWidget {
  const ReceiptVoucherScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptVoucherScreen> createState() => _ReceiptVoucherScreenState();
}

class _ReceiptVoucherScreenState extends State<ReceiptVoucherScreen> {
  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String _searchText = '';

  List<Map<String, dynamic>> _allPartners  = [];
  List<Map<String, dynamic>> _filteredPartners = [];
  Map<String, dynamic>?      _selectedPartner;

  List<Map<String, dynamic>> _unpaidInvoices = [];
  final Map<int, bool>   _selectedMap     = {};
  final Map<int, double> _payAmountMap    = {};

  List<Map<String, dynamic>> _accounts    = [];
  int?                       _selectedAccountId;

  final _searchCtrl   = TextEditingController();
  final _descCtrl     = TextEditingController();

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPartners();
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────
  Future<void> _loadPartners() async {
    final voucherProv = Provider.of<VoucherProvider>(context, listen: false);
    setState(() {
      _allPartners = voucherProv.cachedCustomers;
      _filteredPartners = List.from(_allPartners);
    });
    
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getPartners(type: 'Customer');
      if (resp.statusCode == 200) {
        setState(() {
          _allPartners      = List<Map<String, dynamic>>.from(resp.data);
          _filteredPartners = List.from(_allPartners);
        });
      }
    } catch (e) {
      // Use cached data
    }
  }

  Future<void> _loadAccounts() async {
    final voucherProv = Provider.of<VoucherProvider>(context, listen: false);
    setState(() {
      _accounts = voucherProv.cachedAccounts;
      if (_accounts.isNotEmpty) {
        _selectedAccountId = _accounts.first['AccountID'];
      }
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getVoucherAccounts();
      if (resp.statusCode == 200) {
        setState(() {
          _accounts = List<Map<String, dynamic>>.from(resp.data);
          if (_accounts.isNotEmpty && _selectedAccountId == null) {
            _selectedAccountId = _accounts.first['AccountID'];
          }
        });
      }
    } catch (e) {
      // Use cached data
    }
  }

  Future<void> _loadUnpaidInvoices(int partnerId) async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getUnpaidInvoices(partnerId, 'Sales');
      if (resp.statusCode == 200) {
        final invoices = List<Map<String, dynamic>>.from(resp.data);
        setState(() {
          _unpaidInvoices = invoices;
          _selectedMap.clear();
          _payAmountMap.clear();
          for (final inv in invoices) {
            final id = inv['InvID'] as int;
            _selectedMap[id]  = false;
            _payAmountMap[id] = (inv['Remainder'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      // Offline mode: Allow free payment
      _showError('أنت في وضع عدم الاتصال. لا يمكن جلب الفواتير. يرجى إدخال مبلغ السداد الحر.');
      setState(() {
        _unpaidInvoices = [];
        _selectedMap.clear();
        _payAmountMap.clear();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  void _filterPartners(String query) {
    setState(() {
      _searchText = query;
      _filteredPartners = query.isEmpty
          ? List.from(_allPartners)
          : _allPartners.where((p) {
              final name  = (p['PartnerName'] ?? '').toString().toLowerCase();
              final phone = (p['Phone'] ?? '').toString();
              return name.contains(query.toLowerCase()) || phone.contains(query);
            }).toList();
    });
  }

  void _selectPartner(Map<String, dynamic> partner) {
    setState(() {
      _selectedPartner = partner;
      _unpaidInvoices  = [];
      _selectedMap.clear();
      _payAmountMap.clear();
    });
    _loadUnpaidInvoices(partner['PartnerID']);
  }

  double get _totalSelected {
    double total = 0;
    _selectedMap.forEach((id, selected) {
      if (selected) total += (_payAmountMap[id] ?? 0);
    });
    return total;
  }

  List<Map<String, dynamic>> get _selectedAllocations {
    return _selectedMap.entries
        .where((e) => e.value && (_payAmountMap[e.key] ?? 0) > 0)
        .map((e) => {'InvID': e.key, 'Amount': _payAmountMap[e.key]!})
        .toList();
  }

  List<Map<String, dynamic>> get _selectedAllocationsForPrint {
    return _selectedMap.entries
        .where((e) => e.value && (_payAmountMap[e.key] ?? 0) > 0)
        .map((e) {
          final inv = _unpaidInvoices.firstWhere((x) => x['InvID'] == e.key);
          return {
            'InvID': e.key,
            'Amount': _payAmountMap[e.key]!,
            'InvDate': inv['InvDate']
          };
        })
        .toList();
  }

  Future<void> _submitPayment() async {
    if (_selectedPartner == null) return _showError('يرجى اختيار عميل أولاً');
    
    // Allow free payment if offline
    final double freePaymentAmount = double.tryParse(_freePaymentCtrl.text) ?? 0.0;
    if (_selectedAllocations.isEmpty && freePaymentAmount <= 0) {
       return _showError('يرجى اختيار فاتورة واحدة على الأقل أو إدخال مبلغ سداد حر');
    }
    
    if (_selectedAccountId == null) return _showError('يرجى اختيار حساب القبض');

    final shift = Provider.of<ShiftProvider>(context, listen: false);
    if (shift.shiftId == null) return _showError('لا توجد وردية مفتوحة');

    final double amountToPay = _selectedAllocations.isNotEmpty ? _totalSelected : freePaymentAmount;

    // تأكيد السداد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد سند القبض', style: TextStyle(color: Colors.white), textDirection: TextDirection.rtl),
        content: Text(
          'سيتم تسجيل سند قبض بقيمة\n${amountToPay.toStringAsFixed(3)} د.ك\nمن العميل: ${_selectedPartner!['PartnerName']}',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.red))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final voucherProv = Provider.of<VoucherProvider>(context, listen: false);
    final accountName = _accounts.firstWhere((a) => a['AccountID'] == _selectedAccountId, orElse: () => {'AccountName': ''})['AccountName'];

    try {
      final savedVoucher = await voucherProv.saveVoucher(
        partnerId:   _selectedPartner!['PartnerID'],
        voucherType: 'Receipt',
        totalAmount: amountToPay,
        accountId:   _selectedAccountId!,
        shiftId:     shift.shiftId!,
        allocations: _selectedAllocations,
        description: _descCtrl.text.isEmpty
            ? 'سند قبض - ${_selectedPartner!['PartnerName']}'
            : _descCtrl.text,
        partnerName: _selectedPartner!['PartnerName'],
        accountName: accountName,
      );

      if (savedVoucher != null) {
        final printData = _selectedAllocationsForPrint;
        if (mounted) {
          _showSuccess(voucherProv.successMessage ?? 'تم الحفظ');
          await _showVoucherDialog(savedVoucher, printData);
          // إعادة تحميل الفواتير
          if (voucherProv.errorMessage == null) {
            await _loadUnpaidInvoices(_selectedPartner!['PartnerID']);
            _freePaymentCtrl.clear();
          }
        }
      } else if (voucherProv.errorMessage != null) {
        _showError(voucherProv.errorMessage!);
      }
    } catch (e) {
      _showError('خطأ غير متوقع: $e');
    }
  }

  Future<void> _showVoucherDialog(Map<String, dynamic> voucher, List<Map<String, dynamic>> printData) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, color: Colors.greenAccent, size: 28),
            const SizedBox(width: 8),
            const Text('سند القبض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _voucherRow('رقم السند', '#${voucher['VoucherID']}'),
            _voucherRow('العميل',    voucher['PartnerName'] ?? '-'),
            _voucherRow('المبلغ',    '${(voucher['Amount'] ?? 0).toStringAsFixed(3)} د.ك'),
            _voucherRow('الحساب',    voucher['AccountName'] ?? '-'),
            _voucherRow('الكاشير',   voucher['UserName'] ?? '-'),
            _voucherRow('ملاحظة',    voucher['Description'] ?? '-'),
            const SizedBox(height: 8),
            const Text('⏳ سيتم ترحيل السند عند إغلاق الوردية', style: TextStyle(color: Colors.orangeAccent, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(color: Colors.white70))),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async { 
              Navigator.pop(ctx); 
              final printer = Provider.of<PrinterService>(context, listen: false);
              await printer.printVoucher(voucher, printData);
            },
            label: const Text('طباعة حرارية'),
          ),
        ],
      ),
    );
  }

  Widget _voucherRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, textDirection: TextDirection.rtl), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, textDirection: TextDirection.rtl), backgroundColor: Colors.green));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  final _freePaymentCtrl = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final voucherProv = Provider.of<VoucherProvider>(context);
    final bool isOfflineAction = voucherProv.errorMessage != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF12121E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E2C),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(
            children: [
              Icon(Icons.arrow_circle_down, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text('سند قبض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          bottom: _selectedPartner != null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.greenAccent, size: 18),
                          const SizedBox(width: 8),
                          Text('العميل: ${_selectedPartner!['PartnerName']}',
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() { _selectedPartner = null; _unpaidInvoices = []; }),
                            child: const Icon(Icons.close, color: Colors.white54, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: voucherProv.isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
            : _selectedPartner == null
                ? _buildPartnerSelector()
                : _buildInvoiceList(),
        bottomNavigationBar: _selectedPartner != null && (_selectedAllocations.isNotEmpty || _freePaymentCtrl.text.isNotEmpty)
            ? _buildBottomBar()
            : null,
      ),
    );
  }

  Widget _buildPartnerSelector() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'بحث عن عميل بالاسم أو الهاتف...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.greenAccent),
              filled: true,
              fillColor: const Color(0xFF1E1E2C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: _filterPartners,
          ),
        ),
        Expanded(
          child: _filteredPartners.isEmpty
              ? const Center(child: Text('لا يوجد عملاء', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  itemCount: _filteredPartners.length,
                  itemBuilder: (ctx, i) {
                    final p = _filteredPartners[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF2A2A3C),
                        child: Icon(Icons.person_outline, color: Colors.greenAccent),
                      ),
                      title: Text(p['PartnerName'] ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(p['Phone'] ?? '', style: const TextStyle(color: Colors.white38)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                      onTap: () => _selectPartner(p),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceList() {
    if (_unpaidInvoices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
            SizedBox(height: 12),
            Text('لا توجد فواتير مستحقة لهذا العميل', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // حقل الحساب والملاحظة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedAccountId,
                  dropdownColor: const Color(0xFF1E1E2C),
                  decoration: InputDecoration(
                    labelText: 'حساب القبض',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true, fillColor: const Color(0xFF1E1E2C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: _accounts.map((a) => DropdownMenuItem<int>(
                    value: a['AccountID'],
                    child: Text(a['AccountName'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ملاحظة (اختياري)...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: const Color(0xFF1E1E2C),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.white38),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_unpaidInvoices.isEmpty) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 48),
                  SizedBox(height: 12),
                  Text('لا يمكن جلب الفواتير (أو لا توجد فواتير).\nيمكنك إدخال سداد حر (دفعة من الحساب).', textAlign: TextAlign.center, style: TextStyle(color: Colors.orangeAccent)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _freePaymentCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
              onChanged: (v) => setState((){}),
              decoration: InputDecoration(
                labelText: 'مبلغ الدفعة الحرة (سداد من الحساب)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true, fillColor: const Color(0xFF1E1E2C),
                suffixText: 'د.ك', suffixStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          )
        ] else ...[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _unpaidInvoices.length,
              itemBuilder: (ctx, i) => _buildInvoiceCard(_unpaidInvoices[i]),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    final id        = inv['InvID'] as int;
    final remainder = (inv['Remainder'] as num).toDouble();
    final net       = (inv['NetAmount'] as num).toDouble();
    final selected  = _selectedMap[id] ?? false;
    final payAmount = _payAmountMap[id] ?? remainder;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1A2E20) : const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? Colors.greenAccent.withOpacity(0.6) : Colors.white12,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedMap[id] = !selected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: selected,
                    activeColor: Colors.greenAccent,
                    checkColor: Colors.black,
                    onChanged: (v) => setState(() => _selectedMap[id] = v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('فاتورة رقم #$id', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(
                          _formatDate(inv['InvDate']),
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('الإجمالي: ${net.toStringAsFixed(3)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      Text('المتبقي: ${remainder.toStringAsFixed(3)} د.ك',
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12, left: 12),
                  child: Row(
                    children: [
                      const Text('مبلغ السداد: ', style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: TextFormField(
                          initialValue: payAmount.toStringAsFixed(3),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: 'د.ك',
                            suffixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true, fillColor: const Color(0xFF12121E),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(v) ?? 0;
                            setState(() => _payAmountMap[id] = parsed.clamp(0, remainder));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final double total = _selectedAllocations.isNotEmpty ? _totalSelected : (double.tryParse(_freePaymentCtrl.text) ?? 0.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selectedAllocations.length} فاتورة محددة', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text('الإجمالي: ${total.toStringAsFixed(3)} د.ك',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تسجيل القبض', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _submitPayment,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString().substring(0, 10);
    }
  }
}
