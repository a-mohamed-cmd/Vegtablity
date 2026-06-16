import '../providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/voucher_provider.dart';
import '../services/api_service.dart';
import '../providers/shift_provider.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';

/// شاشة سند الصرف - سداد مستحقات للموردين
class PaymentVoucherScreen extends StatefulWidget {
  const PaymentVoucherScreen({Key? key}) : super(key: key);

  @override
  State<PaymentVoucherScreen> createState() => _PaymentVoucherScreenState();
}

class _PaymentVoucherScreenState extends State<PaymentVoucherScreen> {
  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;

  List<Map<String, dynamic>> _allPartners = [];
  List<Map<String, dynamic>> _filteredPartners = [];
  Map<String, dynamic>? _selectedPartner;

  List<Map<String, dynamic>> _unpaidInvoices = [];
  final Map<int, bool> _selectedMap = {};
  final Map<int, double> _payAmountMap = {};

  List<Map<String, dynamic>> _accounts = [];
  int? _selectedAccountId;

  final _searchCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

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
      _allPartners = voucherProv.cachedVendors;
      _filteredPartners = List.from(_allPartners);
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getPartners(type: 'Supplier');
      if (resp.statusCode == 200) {
        setState(() {
          _allPartners = List<Map<String, dynamic>>.from(resp.data);
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
      final resp = await api.getUnpaidInvoices(partnerId, 'Purchase');
      if (resp.statusCode == 200) {
        final invoices = List<Map<String, dynamic>>.from(resp.data);
        setState(() {
          _unpaidInvoices = invoices;
          _selectedMap.clear();
          _payAmountMap.clear();
          for (final inv in invoices) {
            final id = inv['InvID'] as int;
            _selectedMap[id] = false;
            _payAmountMap[id] = (inv['Remainder'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      _showError(context.tr('pv_offline_error'));
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
      _filteredPartners = query.isEmpty
          ? List.from(_allPartners)
          : _allPartners.where((p) {
              final name = (p['PartnerName'] ?? '').toString().toLowerCase();
              final phone = (p['Phone'] ?? '').toString();
              return name.contains(query.toLowerCase()) ||
                  phone.contains(query);
            }).toList();
    });
  }

  void _selectPartner(Map<String, dynamic> partner) {
    setState(() {
      _selectedPartner = partner;
      _unpaidInvoices = [];
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

  List<Map<String, dynamic>> get _selectedAllocations => _selectedMap.entries
      .where((e) => e.value && (_payAmountMap[e.key] ?? 0) > 0)
      .map((e) => {'InvID': e.key, 'Amount': _payAmountMap[e.key]!})
      .toList();

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
    }).toList();
  }

  Future<void> _submitPayment() async {
    if (_selectedPartner == null)
      return _showError(context.tr('pv_supplier_required'));

    final double freePaymentAmount =
        double.tryParse(_freePaymentCtrl.text) ?? 0.0;
    if (_selectedAllocations.isEmpty && freePaymentAmount <= 0) {
      return _showError(context.tr('pv_invoice_or_free_required'));
    }

    if (_selectedAccountId == null)
      return _showError(context.tr('pv_account_required'));

    final shift = Provider.of<ShiftProvider>(context, listen: false);
    if (shift.shiftId == null)
      return _showError(context.tr('pv_no_shift_open'));

    final double amountToPay =
        _selectedAllocations.isNotEmpty ? _totalSelected : freePaymentAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('pv_confirm_title'),
            style: const TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl),
        content: Text(
          context
              .tr('pv_confirm_desc')
              .replaceAll('{amount}', amountToPay.toStringAsFixed(3))
              .replaceAll('{partner}', _selectedPartner!['PartnerName'] ?? ''),
          style: const TextStyle(color: Colors.white70, fontSize: 15),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('pv_cancel'),
                  style: const TextStyle(color: Colors.red))),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('pv_confirm'),
                style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final voucherProv = Provider.of<VoucherProvider>(context, listen: false);
    final accountName = _accounts.firstWhere(
        (a) => a['AccountID'] == _selectedAccountId,
        orElse: () => {'AccountName': ''})['AccountName'];

    try {
      final savedVoucher = await voucherProv.saveVoucher(
        partnerId: _selectedPartner!['PartnerID'],
        voucherType: 'Payment',
        totalAmount: amountToPay,
        accountId: _selectedAccountId!,
        shiftId: shift.shiftId!,
        allocations: _selectedAllocations,
        description: _descCtrl.text.isEmpty
            ? '${context.tr('pv_default_desc')}${_selectedPartner!['PartnerName']}'
            : _descCtrl.text,
        partnerName: _selectedPartner!['PartnerName'],
        accountName: accountName,
      );

      if (savedVoucher != null) {
        final printData = _selectedAllocationsForPrint;
        if (mounted) {
          final printer = Provider.of<PrinterService>(context, listen: false);
          await printer.printVoucher(savedVoucher, printData);

          _showSuccess(context
              .tr('pv_save_print_success')
              .replaceAll('{id}', savedVoucher['VoucherID'].toString()));

          if (voucherProv.errorMessage == null) {
            await _loadUnpaidInvoices(_selectedPartner!['PartnerID']);
            _freePaymentCtrl.clear();
          }
        }
      } else if (voucherProv.errorMessage != null) {
        _showError(voucherProv.errorMessage!);
      }
    } catch (e) {
      _showError('${context.tr('pv_save_error')}$e');
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: Colors.red));

  void _showSuccess(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: Colors.green));

  // ─── Build ────────────────────────────────────────────────────────────────
  final _freePaymentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final voucherProv = Provider.of<VoucherProvider>(context);

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
          title: Row(
            children: [
              const Icon(Icons.arrow_circle_up, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Text(context.tr('pv_screen_title'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          bottom: _selectedPartner != null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront,
                              color: Colors.orangeAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                              '${context.tr('pv_supplier_label')}${_selectedPartner!['PartnerName']}',
                              style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedPartner = null;
                              _unpaidInvoices = [];
                            }),
                            child: const Icon(Icons.close,
                                color: Colors.white54, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: voucherProv.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.orangeAccent))
            : _selectedPartner == null
                ? _buildPartnerSelector()
                : _buildInvoiceList(),
        bottomNavigationBar: _selectedPartner != null &&
                (_selectedAllocations.isNotEmpty ||
                    _freePaymentCtrl.text.isNotEmpty)
            ? _buildBottomBar()
            : null,
      ),
    );
  }

  Widget _buildPartnerSelector() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.tr('pv_search_hint'),
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.orangeAccent),
                filled: true,
                fillColor: const Color(0xFF1E1E2C),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: _filterPartners,
            ),
          ),
          Expanded(
            child: _filteredPartners.isEmpty
                ? Center(
                    child: Text(context.tr('pv_no_suppliers'),
                        style: const TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: _filteredPartners.length,
                    itemBuilder: (ctx, i) {
                      final p = _filteredPartners[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF2A2A3C),
                          child: Icon(Icons.storefront_outlined,
                              color: Colors.orangeAccent),
                        ),
                        title: Text(p['PartnerName'] ?? '-',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(p['Phone'] ?? '',
                            style: const TextStyle(color: Colors.white38)),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white38, size: 14),
                        onTap: () => _selectPartner(p),
                      );
                    },
                  ),
          ),
        ],
      );

  Widget _buildInvoiceList() {
    if (_unpaidInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.orangeAccent, size: 64),
            const SizedBox(height: 12),
            Text(context.tr('pv_no_dues'),
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DropdownButtonFormField<int>(
            value: _selectedAccountId,
            dropdownColor: const Color(0xFF1E1E2C),
            decoration: InputDecoration(
              labelText: context.tr('pv_account_label'),
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1E1E2C),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: Colors.white),
            items: _accounts
                .map((a) => DropdownMenuItem<int>(
                      value: a['AccountID'],
                      child: Text(a['AccountName'] ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedAccountId = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.tr('pv_note_hint'),
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E2C),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              prefixIcon:
                  const Icon(Icons.note_alt_outlined, color: Colors.white38),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_unpaidInvoices.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off,
                      color: Colors.orangeAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(context.tr('pv_no_invoices'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orangeAccent)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _freePaymentCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr('pv_free_payment_label'),
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E2C),
                suffixText: ' ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                suffixStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
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
    final id = inv['InvID'] as int;
    final remainder = (inv['Remainder'] as num).toDouble();
    final net = (inv['NetAmount'] as num).toDouble();
    final selected = _selectedMap[id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2E1A0A) : const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              selected ? Colors.orangeAccent.withOpacity(0.6) : Colors.white12,
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
                    activeColor: Colors.orangeAccent,
                    checkColor: Colors.black,
                    onChanged: (v) =>
                        setState(() => _selectedMap[id] = v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${context.tr('pv_purchase_invoice_label')}$id',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(_formatDate(inv['InvDate']),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${context.tr('pv_total_label')}${net.toStringAsFixed(3)}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text(
                          context.tr('pv_remainder_label').replaceAll(
                              '{amount}', remainder.toStringAsFixed(3)),
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12, left: 12),
                  child: Row(
                    children: [
                      Text(context.tr('pv_payment_amount_label'),
                          style: const TextStyle(color: Colors.white70)),
                      Expanded(
                        child: TextFormField(
                          initialValue: (_payAmountMap[id] ?? remainder)
                              .toStringAsFixed(3),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                          style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: ' ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                            suffixStyle: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF12121E),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(v) ?? 0;
                            setState(() =>
                                _payAmountMap[id] = parsed.clamp(0, remainder));
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
    final double total = _selectedAllocations.isNotEmpty
        ? _totalSelected
        : (double.tryParse(_freePaymentCtrl.text) ?? 0.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    context.tr('pv_selected_invoices').replaceAll(
                        '{count}', _selectedAllocations.length.toString()),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(
                    '${context.tr('pv_total_label')}${total.toStringAsFixed(3)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: Text(context.tr('pv_submit_button'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
