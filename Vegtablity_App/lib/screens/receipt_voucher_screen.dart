import '../providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/voucher_provider.dart';
import '../services/api_service.dart';
import '../providers/shift_provider.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/app_snackbar.dart';
import '../models/integration_models.dart';
import '../providers/auth_provider.dart';
import '../services/integrations/integration_service.dart';
import '../widgets/payment_link_issue_dialog.dart';

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

  List<Map<String, dynamic>> _allPartners = [];
  List<Map<String, dynamic>> _filteredPartners = [];
  Map<String, dynamic>? _selectedPartner;

  List<Map<String, dynamic>> _unpaidInvoices = [];
  final Map<int, bool> _selectedMap = {};
  final Map<int, double> _payAmountMap = {};

  List<Map<String, dynamic>> _accounts = [];
  List<IntegrationProviderModel> _configuredGateways = [];
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
      _allPartners = voucherProv.cachedCustomers;
      _filteredPartners = List.from(_allPartners);
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getPartners(type: 'Customer');
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
    final baseCached = await IntegrationPosService.filterOutGatewayAccounts(
      List<Map<String, dynamic>>.from(voucherProv.cachedAccounts),
    );
    if (mounted) {
      setState(() {
        _accounts = baseCached;
        if (_accounts.isNotEmpty &&
            !_accounts.any((a) => a['AccountID'] == _selectedAccountId)) {
          _selectedAccountId = _accounts.first['AccountID'];
        }
      });
    }

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getVoucherAccounts();
      if (resp.statusCode == 200) {
        final filtered = await IntegrationPosService.filterOutGatewayAccounts(
          List<Map<String, dynamic>>.from(resp.data),
        );
        if (mounted) {
          setState(() {
            _accounts = filtered;
            _mergeConfiguredGatewayAccountsIntoDropdown();
            if (_accounts.isNotEmpty &&
                (_selectedAccountId == null ||
                    !_accounts
                        .any((a) => a['AccountID'] == _selectedAccountId))) {
              _selectedAccountId = _accounts.first['AccountID'];
            }
          });
        }
      }
    } catch (e) {
      // Use cached data
    }

    try {
      final summary = await IntegrationPosService().fetchProvidersSummary();
      final providers =
          (summary['providers'] as List<IntegrationProviderModel>?) ?? [];
      if (mounted) {
        setState(() {
          _configuredGateways = providers
              .where((p) =>
                  p.isPaymentGateway &&
                  p.isEnabledInCompany &&
                  (p.isConfigured || p.isConnectionVerified))
              .toList();
          _mergeConfiguredGatewayAccountsIntoDropdown();
        });
      }
    } catch (_) {}
  }

  void _mergeConfiguredGatewayAccountsIntoDropdown() {
    if (_configuredGateways.isEmpty) return;
    for (final gw in _configuredGateways) {
      if (gw.linkedAccountId != null && gw.linkedAccountId! > 0) {
        final exists = _accounts.any((a) {
          final id = a['AccountID'] is int
              ? a['AccountID'] as int
              : int.tryParse(a['AccountID']?.toString() ?? '');
          return id == gw.linkedAccountId;
        });
        if (!exists) {
          _accounts.add({
            'AccountID': gw.linkedAccountId,
            'AccountName': gw.linkedAccountName.isNotEmpty
                ? gw.linkedAccountName
                : gw.providerNameAr,
            'AccountCode': gw.linkedAccountCode,
          });
        }
      }
    }
  }

  IntegrationProviderModel? _matchGatewayForAccount(
      int? accId, String? accName) {
    if (_configuredGateways.isEmpty) return null;
    if (accId != null) {
      for (final g in _configuredGateways) {
        if (g.linkedAccountId != null && g.linkedAccountId == accId) {
          return g;
        }
      }
    }
    final lower = (accName ?? '').toLowerCase().trim();
    if (lower.isEmpty) return null;
    for (final g in _configuredGateways) {
      final code = g.providerCode.toLowerCase();
      final nameAr = g.providerNameAr.toLowerCase();
      final nameEn = g.providerNameEn.toLowerCase();
      final linkedName = g.linkedAccountName.toLowerCase().trim();
      if ((code.isNotEmpty && lower.contains(code)) ||
          (code == 'myfatoorah' && lower.contains('my fatoorah')) ||
          (nameAr.isNotEmpty && lower.contains(nameAr)) ||
          (nameEn.isNotEmpty && lower.contains(nameEn)) ||
          (linkedName.isNotEmpty && lower == linkedName)) {
        return g;
      }
    }
    return null;
  }

  String? _getAccountNameById(int? accId) {
    if (accId == null) return null;
    for (final acc in _accounts) {
      if (acc['AccountID'] == accId) {
        return acc['AccountName']?.toString();
      }
    }
    return null;
  }

  IntegrationProviderModel? get _selectedGateway => _matchGatewayForAccount(
      _selectedAccountId, _getAccountNameById(_selectedAccountId));

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
            _selectedMap[id] = false;
            _payAmountMap[id] = (inv['Remainder'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      // Offline mode: Allow free payment
      _showError(context.tr('rv_offline_error'));
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
    }).toList();
  }

  Future<void> _submitPayment() async {
    if (_selectedPartner == null)
      return _showError(context.tr('rv_customer_required'));

    // Allow free payment if offline
    final double freePaymentAmount =
        double.tryParse(_freePaymentCtrl.text) ?? 0.0;
    if (_selectedAllocations.isEmpty && freePaymentAmount <= 0) {
      return _showError(context.tr('rv_invoice_or_free_required'));
    }

    if (_selectedAccountId == null)
      return _showError(context.tr('rv_account_required'));

    final selectedGateway = _selectedGateway;
    final shift = Provider.of<ShiftProvider>(context, listen: false);

    // عند اختيار بوابة دفع إلكتروني في شاشة تحصيلات العملاء:
    // يتم إصدار رابط دفع مجمع للفواتير المحددة وحفظه في صفحة اللينكات فقط دون إنشاء سند قبض
    if (selectedGateway != null) {
      final bool isAr = Localizations.localeOf(context).languageCode == 'ar';
      if (_selectedAllocations.isEmpty || _totalSelected <= 0) {
        return _showError(isAr
            ? '⚠️ لإصدار رابط دفع عبر البوابة، يرجى تحديد فاتورة واحدة على الأقل.'
            : '⚠️ Please select at least one invoice to issue a gateway payment link.');
      }
      final int createdByUserId =
          Provider.of<AuthProvider>(context, listen: false).userId ?? 1;
      final String partnerName =
          (_selectedPartner!['PartnerName'] ?? '').toString();
      final String partnerPhone =
          (_selectedPartner!['Phone'] ?? _selectedPartner!['Mobile'] ?? '')
              .toString();

      final createdLink = await showConsolidatedPaymentLinkDialog(
        context: context,
        configuredGateways: _configuredGateways,
        initialGateway: selectedGateway,
        partnerId: (_selectedPartner!['PartnerID'] as num).toInt(),
        customerName: partnerName,
        customerPhone: partnerPhone,
        allocations: _selectedAllocationsForPrint,
        initialNotes: _descCtrl.text.trim(),
        shiftId: shift.shiftId,
        createdByUserId: createdByUserId,
      );

      if (createdLink != null && mounted) {
        setState(() {
          _selectedMap.updateAll((_, __) => false);
          _descCtrl.clear();
        });
        _showSuccess(isAr
            ? '✅ تم إصدار وحفظ رابط الدفع (#${createdLink.linkId}) في صفحة اللينكات بنجاح (دون تسجيل سند قبض).'
            : '✅ Payment link (#${createdLink.linkId}) issued and saved in Payment Links without creating a receipt voucher.');
      }
      return;
    }

    if (shift.shiftId == null)
      return _showError(context.tr('rv_no_shift_open'));

    final double amountToPay =
        _selectedAllocations.isNotEmpty ? _totalSelected : freePaymentAmount;

    // تأكيد السداد
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('rv_confirm_title'),
            style: const TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl),
        content: Text(
          context
              .tr('rv_confirm_desc')
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
              child: Text(context.tr('rv_cancel'),
                  style: const TextStyle(color: Colors.red))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('rv_confirm')),
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
        voucherType: 'Receipt',
        totalAmount: amountToPay,
        accountId: _selectedAccountId!,
        shiftId: shift.shiftId!,
        allocations: _selectedAllocations,
        description: _descCtrl.text.isEmpty
            ? '${context.tr('rv_default_desc')}${_selectedPartner!['PartnerName']}'
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
              .tr('rv_save_print_success')
              .replaceAll('{id}', savedVoucher['VoucherID'].toString()));

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
      _showError(DbErrorHelper.format(e));
    }
  }

  void _showError(String msg) {
    AppSnackBar.show(context, DbErrorHelper.format(msg), isError: true);
  }

  void _showSuccess(String msg) {
    AppSnackBar.showSuccess(context, msg);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  final _freePaymentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final voucherProv = Provider.of<VoucherProvider>(context);
    final bool isOfflineAction = voucherProv.errorMessage != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: _selectedPartner == null,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_selectedPartner != null) {
            setState(() {
              _selectedPartner = null;
              _unpaidInvoices = [];
              _selectedMap.clear();
              _payAmountMap.clear();
            });
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F7FA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () {
                if (_selectedPartner != null) {
                  setState(() {
                    _selectedPartner = null;
                    _unpaidInvoices = [];
                    _selectedMap.clear();
                    _payAmountMap.clear();
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_circle_down_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(context.tr('rv_screen_title'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
            bottom: _selectedPartner != null
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(54),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${context.tr('rv_customer_label')}${_selectedPartner!['PartnerName']}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedPartner = null;
                                _unpaidInvoices = [];
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: voucherProv.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0D9488)))
                  : _selectedPartner == null
                      ? _buildPartnerSelector()
                      : _buildInvoiceList(),
            ),
          ),
          bottomNavigationBar: _selectedPartner != null &&
                  (_selectedAllocations.isNotEmpty ||
                      _freePaymentCtrl.text.isNotEmpty)
              ? _buildBottomBar()
              : null,
        ),
      ),
    );
  }

  Widget _buildPartnerSelector() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: context.tr('rv_search_hint'),
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF059669)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF0D9488), width: 1.5)),
              ),
              onChanged: _filterPartners,
            ),
          ),
        ),
        Expanded(
          child: _filteredPartners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_search_rounded,
                          size: 56, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 10),
                      Text(context.tr('rv_no_customers'),
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _filteredPartners.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final p = _filteredPartners[i];
                    final name = (p['PartnerName'] ?? '-').toString();
                    final initial =
                        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _selectPartner(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFECFDF5),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    if ((p['Phone'] ?? '').toString().isNotEmpty)
                                      Text(p['Phone'] ?? '',
                                          style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF94A3B8), size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceList() {
    if (_unpaidInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF059669), size: 56),
            ),
            const SizedBox(height: 14),
            Text(context.tr('rv_no_dues'),
                style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // حقل الحساب والملاحظة
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _selectedAccountId,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: context.tr('rv_account_label'),
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFF0D9488), width: 1.5)),
                  ),
                  style: const TextStyle(
                      color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                  items: _accounts
                      .map((a) {
                        final accId = a['AccountID'] is int
                            ? a['AccountID'] as int
                            : int.tryParse(a['AccountID']?.toString() ?? '');
                        final accName = a['AccountName']?.toString() ?? '';
                        final isGw =
                            _matchGatewayForAccount(accId, accName) != null;
                        return DropdownMenuItem<int>(
                          value: a['AccountID'],
                          child: Row(
                            children: [
                              if (isGw) ...[
                                const Icon(Icons.add_link,
                                    color: Color(0xFF0D9488), size: 16),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  isGw ? '$accName (بوابة دفع)' : accName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: isGw
                                          ? const Color(0xFF0F766E)
                                          : const Color(0xFF0F172A),
                                      fontWeight: isGw
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
              ),
            ],
          ),
        ),
        if (_selectedGateway != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_link,
                      color: Color(0xFF0F766E), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'عند اختيار بوابة الدفع (${_selectedGateway!.providerNameAr}) سيتم إصدار رابط دفع مجمع للفواتير المحددة وحفظه في صفحة اللينكات دون إنشاء سند قبض لتجنب ازدواجية القيود.'
                          : 'Selecting payment gateway (${_selectedGateway!.providerNameEn.isNotEmpty ? _selectedGateway!.providerNameEn : _selectedGateway!.providerCode}) will issue a consolidated payment link saved in Payment Links without creating a receipt voucher.',
                      style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: context.tr('rv_note_hint'),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
              prefixIcon: const Icon(Icons.note_alt_outlined,
                  color: Color(0xFF64748B)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_unpaidInvoices.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFD97706).withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Color(0xFFD97706), size: 42),
                    const SizedBox(height: 10),
                    Text(context.tr('rv_no_invoices'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
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
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr('rv_free_payment_label'),
                labelStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                suffixText:
                    ' ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                suffixStyle: const TextStyle(
                    color: Color(0xFF475569), fontWeight: FontWeight.w600),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
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
    final payAmount = _payAmountMap[id] ?? remainder;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FDFA) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? const Color(0xFF0D9488)
              : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (selected
                    ? const Color(0xFF0D9488)
                    : const Color(0xFF0F172A))
                .withValues(alpha: selected ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedMap[id] = !selected),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: selected,
                    activeColor: const Color(0xFF0D9488),
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onChanged: (v) =>
                        setState(() => _selectedMap[id] = v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${context.tr('rv_sales_invoice_label')}$id',
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(inv['InvDate']),
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${context.tr('rv_total_label')}${net.toStringAsFixed(3)}',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            context.tr('rv_remainder_label').replaceAll(
                                '{amount}', remainder.toStringAsFixed(3)),
                            style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 8, left: 8),
                  child: Row(
                    children: [
                      Text(context.tr('rv_receipt_amount_label'),
                          style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: payAmount.toStringAsFixed(3),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                          style: const TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText:
                                ' ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                            suffixStyle: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0D9488), width: 1.5)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3))
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
                    context.tr('rv_selected_invoices').replaceAll(
                        '{count}', _selectedAllocations.length.toString()),
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12)),
                Text(
                    '${context.tr('rv_total_label')}${total.toStringAsFixed(3)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                    style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: Icon(
                  _selectedGateway != null
                      ? Icons.add_link
                      : Icons.check_circle_outline_rounded,
                  size: 19),
              label: Text(
                  _selectedGateway != null
                      ? (Localizations.localeOf(context).languageCode == 'ar'
                          ? 'إصدار رابط دفع مجمع'
                          : 'Issue Payment Link')
                      : context.tr('rv_submit_button'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedGateway != null
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
