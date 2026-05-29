import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/voucher_provider.dart';
import '../services/api_service.dart';
import '../providers/shift_provider.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';

class GeneralReceiptVoucherScreen extends StatefulWidget {
  const GeneralReceiptVoucherScreen({Key? key}) : super(key: key);

  @override
  State<GeneralReceiptVoucherScreen> createState() =>
      _GeneralReceiptVoucherScreenState();
}

class _GeneralReceiptVoucherScreenState
    extends State<GeneralReceiptVoucherScreen> {
  bool _isLoading = false;

  Map<String, dynamic>? _selectedTargetAccount;

  List<Map<String, dynamic>> _cashAccounts = [];
  int? _selectedCashAccountId;

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCashAccounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AccountProvider>(context, listen: false)
          .fetchRevenueAccounts();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCashAccounts() async {
    final voucherProv = Provider.of<VoucherProvider>(context, listen: false);
    setState(() {
      _cashAccounts = voucherProv.cachedAccounts;
      if (_cashAccounts.isNotEmpty) {
        _selectedCashAccountId = _cashAccounts.first['AccountID'];
      }
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resp = await api.getVoucherAccounts();
      if (resp.statusCode == 200) {
        setState(() {
          _cashAccounts = List<Map<String, dynamic>>.from(resp.data);
          if (_cashAccounts.isNotEmpty && _selectedCashAccountId == null) {
            _selectedCashAccountId = _cashAccounts.first['AccountID'];
          }
        });
      }
    } catch (e) {
      // Use cached
    }
  }

  void _showAccountSelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final accProv = Provider.of<AccountProvider>(context);
            final accounts = accProv.revenueAccounts;

            final filteredAccounts = accounts.where((acc) {
              final query = _searchCtrl.text.toLowerCase();
              return acc['AccountName']
                      .toString()
                      .toLowerCase()
                      .contains(query) ||
                  acc['AccountCode'].toString().toLowerCase().contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    Text(
                      context.tr('grv_choose_revenue_account'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: context.tr('gpv_search_account_hint'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 10),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: accProv.isLoadingRevenues
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: filteredAccounts.length,
                              itemBuilder: (context, index) {
                                final acc = filteredAccounts[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(acc['AccountName'] ?? '',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800)),
                                    subtitle: Text(context
                                        .tr('gpv_account_code')
                                        .replaceAll('{code}',
                                            acc['AccountCode'].toString())),
                                    onTap: () {
                                      setState(() {
                                        _selectedTargetAccount = acc;
                                      });
                                      Navigator.pop(ctx);
                                      _searchCtrl.clear();
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _saveVoucher() async {
    final amountText = _amountCtrl.text.trim();
    if (_selectedTargetAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('grv_revenue_account_required'))));
      return;
    }
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('gpv_amount_required'))));
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('gpv_invalid_amount'))));
      return;
    }
    if (_selectedCashAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('gpv_cash_account_required'))));
      return;
    }

    setState(() => _isLoading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final shiftProv = Provider.of<ShiftProvider>(context, listen: false);
    final printerProv = Provider.of<PrinterService>(context, listen: false);

    try {
      final resp = await api.saveGeneralVoucher(
        voucherType: 'Receipt',
        totalAmount: amount,
        accountId: _selectedTargetAccount!['AccountID'],
        description: _descCtrl.text.trim(),
        paymentMethod: _selectedCashAccountId.toString(),
        shiftId: shiftProv.shiftId,
      );

      if (resp.statusCode == 200) {
        final voucher = resp.data;

        final targetAccountName = _selectedTargetAccount!['AccountName'] ??
            context.tr('gpv_undefined');
        final cashAccountName = _cashAccounts.firstWhere(
            (acc) =>
                acc['AccountID'].toString() ==
                _selectedCashAccountId.toString(),
            orElse: () =>
                {'AccountName': context.tr('gpv_cash')})['AccountName'];

        // طباعة السند مباشرة
        await printerProv.printGeneralVoucher(
            voucher, targetAccountName, cashAccountName);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('grv_save_print_success').replaceAll(
                  '{id}',
                  (voucher['VoucherID'] ?? voucher['VoucherNo']).toString())),
              backgroundColor: Colors.green),
        );
        setState(() {
          _selectedTargetAccount = null;
          _amountCtrl.clear();
          _descCtrl.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${context.tr('gpv_save_error')}${resp.data}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${context.tr('gpv_cannot_save')}$e'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('grv_screen_title')),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Target Account Selection
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: _showAccountSelectionPopup,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet,
                                  color: Colors.blue.shade700, size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('grv_target_account_label'),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                    Text(
                                      _selectedTargetAccount != null
                                          ? _selectedTargetAccount![
                                              'AccountName']
                                          : context.tr('gpv_click_to_choose'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            _selectedTargetAccount != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down,
                                  color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: context.tr('gpv_amount_label'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.money),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description and Cash Account
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _descCtrl,
                              decoration: InputDecoration(
                                labelText: context.tr('gpv_statement_label'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.notes),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              value: _selectedCashAccountId,
                              decoration: InputDecoration(
                                labelText: context.tr('grv_receive_to_account'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.account_balance),
                              ),
                              items: _cashAccounts.map((acc) {
                                return DropdownMenuItem<int>(
                                  value: acc['AccountID'],
                                  child: Text(acc['AccountName'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCashAccountId = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(context.tr('grv_save_button'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saveVoucher,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
