import 'dart:convert';
import '../providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../widgets/product_entry_scanner.dart';
import '../core/localization/app_localizations.dart';

class PartnerBillingScreen extends StatefulWidget {
  final Map<String, dynamic> partner;
  final String type; // 'Sales' or 'Purchases'
  final int quoteId;
  final List<Map<String, dynamic>> allowedItems;
  final String? tempCustomerName;
  final String? tempPhone;
  final String? tempAddress;
  final String? tempDeliveryDate;
  final String? tempDeliveryTime;
  final String? tempNotes;

  const PartnerBillingScreen({
    super.key,
    required this.partner,
    required this.type,
    required this.quoteId,
    required this.allowedItems,
    this.tempCustomerName,
    this.tempPhone,
    this.tempAddress,
    this.tempDeliveryDate,
    this.tempDeliveryTime,
    this.tempNotes,
  });

  @override
  State<PartnerBillingScreen> createState() => _PartnerBillingScreenState();
}

class _PartnerBillingScreenState extends State<PartnerBillingScreen> {
  final List<Map<String, dynamic>> _cartItems = [];
  final _searchController = TextEditingController();
  final _barcodeInputController = TextEditingController();
  final _focusNode = FocusNode();
  final _discountController = TextEditingController(text: '0.0');

  List<Map<String, dynamic>> _filteredAllowedItems = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _accounts = [];
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _filteredAllowedItems = widget.allowedItems;
    _focusNode.requestFocus();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedAccJson = prefs.getString('cached_accounts');
      if (cachedAccJson != null) {
        final List<dynamic> decoded = json.decode(cachedAccJson);
        if (mounted) {
          setState(() {
            _accounts = List<Map<String, dynamic>>.from(decoded);
            _updateSelectedAccountId();
          });
        }
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.getPaymentAccounts();
      if (res.statusCode == 200 && res.data is List) {
        final List<Map<String, dynamic>> fetched = List<Map<String, dynamic>>.from(res.data);
        if (fetched.isNotEmpty && mounted) {
          setState(() {
            _accounts = fetched;
            _updateSelectedAccountId();
          });
          prefs.setString('cached_accounts', json.encode(fetched));
        }
      }
    } catch (_) {}
  }

  void _updateSelectedAccountId() {
    if (_accounts.isNotEmpty && _selectedAccountId == null) {
      final cashAcc = _accounts.firstWhere(
        (acc) => (acc['AccountName']?.toString() ?? '').contains('صندوق') || (acc['AccountName']?.toString() ?? '').contains('كاش'),
        orElse: () => _accounts.first,
      );
      _selectedAccountId = cashAcc['AccountID'];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeInputController.dispose();
    _focusNode.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0.0));
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _netAmount {
    final net = _subtotal - _discount;
    return net < 0 ? 0.0 : net;
  }

  void _filterAllowedItems(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredAllowedItems = widget.allowedItems;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredAllowedItems = widget.allowedItems.where((item) {
        final name = (item['ProductName'] ?? '').toString().toLowerCase();
        final barcode = (item['Barcode'] ?? '').toString().toLowerCase();
        return name.contains(lowercaseQuery) ||
            barcode.contains(lowercaseQuery);
      }).toList();
    });
  }

  void _addOrIncrementProduct(Map<String, dynamic> allowedItem) {
    final productId = allowedItem['ProductID'];
    final price =
        (allowedItem['UnitPrice'] ?? allowedItem['QuotedPrice'] ?? 0.0)
            .toDouble();
    final name = allowedItem['ProductName'] ?? context.tr('pb_unknown_item');
    final barcode = allowedItem['Barcode'] ?? '';
    final unitName = allowedItem['UnitName'] ?? context.tr('pb_item_piece');

    final existingIndex =
        _cartItems.indexWhere((item) => item['ProductID'] == productId);

    setState(() {
      if (existingIndex != -1) {
        _cartItems[existingIndex]['quantity'] += 1.0;
        _cartItems[existingIndex]['total'] = _cartItems[existingIndex]
                ['quantity'] *
            _cartItems[existingIndex]['price'];
      } else {
        _cartItems.add({
          'ProductID': productId,
          'name': name,
          'barcode': barcode,
          'price': price,
          'quantity': 1.0,
          'total': price,
          'unitName': unitName,
        });
      }
    });

    HapticFeedback.lightImpact();
  }

  void _decrementOrRemoveProduct(int productId) {
    final existingIndex =
        _cartItems.indexWhere((item) => item['ProductID'] == productId);
    if (existingIndex == -1) return;

    setState(() {
      if (_cartItems[existingIndex]['quantity'] > 1.0) {
        _cartItems[existingIndex]['quantity'] -= 1.0;
        _cartItems[existingIndex]['total'] = _cartItems[existingIndex]
                ['quantity'] *
            _cartItems[existingIndex]['price'];
      } else {
        _cartItems.removeAt(existingIndex);
      }
    });

    HapticFeedback.lightImpact();
  }

  void _updateCartQuantity(int productId, num newQty) {
    final existingIndex =
        _cartItems.indexWhere((item) => item['ProductID'] == productId);
    if (existingIndex == -1) return;

    setState(() {
      if (newQty > 0) {
        _cartItems[existingIndex]['quantity'] = newQty.toDouble();
        _cartItems[existingIndex]['total'] = _cartItems[existingIndex]
                ['quantity'] *
            _cartItems[existingIndex]['price'];
      } else {
        _cartItems.removeAt(existingIndex);
      }
    });
  }

  void _handleBarcodeScanned(String barcode) {
    final trimmedBarcode = barcode.trim();
    if (trimmedBarcode.isEmpty) return;

    // Find barcode in allowedItems
    final allowedItem = widget.allowedItems.firstWhere(
      (item) => (item['Barcode'] ?? '').toString().trim() == trimmedBarcode,
      orElse: () => {},
    );

    if (allowedItem.isNotEmpty) {
      _addOrIncrementProduct(allowedItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${context.tr('pb_item_added')}${allowedItem['ProductName']}',
              textAlign: TextAlign.right),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      _showBarcodeWarning(trimmedBarcode);
    }
  }

  void _showBarcodeWarning(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(context.tr('pb_alert_unapproved'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          context
              .tr('pb_alert_unapproved_desc')
              .replaceAll('{barcode}', barcode),
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(context.tr('pb_ok')),
          )
        ],
      ),
    );
  }

  void _openCameraScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: ProductEntryScanner(
            searchMode: widget.type.toLowerCase().contains('purchase')
                ? CatalogSearchMode.purchase
                : CatalogSearchMode.sales,
            onBarcodeSubmitted: (barcode) {
              _handleBarcodeScanned(barcode);
            },
            onProductSelected: (prod) {
              _addOrIncrementProduct(prod);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إضافة: ${prod['ProductName'] ?? prod['name']}'),
                  backgroundColor: Colors.teal,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        _focusNode.requestFocus();
        setState(() {});
      }
    });
  }

  void _showCashPaymentDialog() {
    int? dialogSelectedAccountId = _selectedAccountId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'تأكيد السداد النقدي',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'المبلغ المطلوب: ${_netAmount.toStringAsFixed(2)} د.ك',
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 15),
                  if (_accounts.isNotEmpty) ...[
                    const Text(
                      'طريقة الدفع / حساب السداد:',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      dropdownColor: Colors.grey[850],
                      value: dialogSelectedAccountId,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: _accounts.map((acc) {
                        return DropdownMenuItem<int>(
                          value: acc['AccountID'],
                          child: Text(
                            acc['AccountName']?.toString() ?? '',
                            style: const TextStyle(color: Colors.black, fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          dialogSelectedAccountId = val;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _submitInvoice(true, paymentAccountId: dialogSelectedAccountId);
                  },
                  child: const Text('تأكيد وحفظ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSplitPaymentDialog() {
    if (_accounts.isEmpty) return;

    List<Map<String, dynamic>> splits = [
      {'PaymentAccountID': _accounts.first['AccountID'], 'Amount': _netAmount}
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final double totalAmount = _netAmount;
            final double totalPaid = splits.fold(0.0, (sum, s) => sum + ((s['Amount'] as num?)?.toDouble() ?? 0.0));
            final double remainder = totalAmount > totalPaid ? totalAmount - totalPaid : 0.0;

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'تقسيم وسائل الدفع (Split Payment)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${totalAmount.toStringAsFixed(2)} د.ك',
                                    style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('إجمالي الصافي:', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${totalPaid.toStringAsFixed(2)} د.ك',
                                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(context.tr('split_paid_now'), style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                            if (remainder > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${remainder.toStringAsFixed(2)} د.ك',
                                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(context.tr('split_remainder_credit'), style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...splits.asMap().entries.map((entry) {
                        final index = entry.key;
                        final split = entry.value;
                        if (split['controller'] == null) {
                          final initialAmt = (split['Amount'] as num?)?.toDouble() ?? 0.0;
                          split['controller'] = TextEditingController(text: initialAmt > 0 ? initialAmt.toStringAsFixed(2) : '');
                        }
                        final controller = split['controller'] as TextEditingController;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  if (splits.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                      onPressed: () {
                                        setDialogState(() {
                                          final removed = splits.removeAt(index);
                                          (removed['controller'] as TextEditingController?)?.dispose();
                                        });
                                      },
                                    ),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      value: split['PaymentAccountID'],
                                      dropdownColor: Colors.grey[800],
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        labelText: context.tr('split_payment_account'),
                                        labelStyle: const TextStyle(color: Colors.white54),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                                      ),
                                      items: _accounts.map((acc) {
                                        return DropdownMenuItem<int>(
                                          value: acc['AccountID'],
                                          child: Text(acc['AccountName'] ?? '', textDirection: TextDirection.rtl),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            split['PaymentAccountID'] = val;
                                            final matchedAcc = _accounts.firstWhere((a) => a['AccountID'] == val, orElse: () => {});
                                            split['PaymentMethodName'] = matchedAcc['AccountName'] ?? '';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: context.tr('split_amount_paid'),
                                  labelStyle: const TextStyle(color: Colors.white54),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                                ),
                                onChanged: (val) {
                                  final double parsed = double.tryParse(val) ?? 0.0;
                                  split['Amount'] = parsed;
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            final nextAcc = _accounts.length > splits.length ? _accounts[splits.length]['AccountID'] : _accounts.first['AccountID'];
                            final nextName = _accounts.length > splits.length ? _accounts[splits.length]['AccountName'] : _accounts.first['AccountName'];
                            splits.add({
                              'PaymentAccountID': nextAcc,
                              'PaymentMethodName': nextName,
                              'Amount': remainder > 0 ? remainder : 0.0
                            });
                          });
                        },
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: Text(context.tr('split_add_another_method')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final controllers = splits
                        .map((s) => s['controller'] as TextEditingController?)
                        .whereType<TextEditingController>()
                        .toList();
                    Navigator.pop(ctx);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      for (var c in controllers) {
                        try {
                          c.dispose();
                        } catch (_) {}
                      }
                    });
                  },
                  child: Text(context.tr('split_cancel'), style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final validSplits = splits
                        .where((s) => ((s['Amount'] as num?)?.toDouble() ?? 0.0) > 0)
                        .map((s) => {
                              'PaymentAccountID': s['PaymentAccountID'],
                              'PaymentMethodName': s['PaymentMethodName'],
                              'Amount': (s['Amount'] as num).toDouble(),
                            })
                        .toList();

                    if (validSplits.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('split_valid_amounts_warn'), textAlign: TextAlign.right), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    final controllers = splits
                        .map((s) => s['controller'] as TextEditingController?)
                        .whereType<TextEditingController>()
                        .toList();

                    Navigator.pop(ctx);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      for (var c in controllers) {
                        try {
                          c.dispose();
                        } catch (_) {}
                      }
                    });

                    _submitInvoice(true, paymentSplits: validSplits);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                  child: Text(context.tr('split_confirm_and_save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitInvoice(bool isCash, {int? paymentAccountId, List<Map<String, dynamic>>? paymentSplits}) async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('pb_cart_empty_error'),
              textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final warehouseId = prefs.getInt('selected_warehouse_id') ?? 1;

    final double total = _subtotal;
    final double discount = _discount;
    final double net = _netAmount;
    double paid = isCash ? net : 0.0;
    double remainder = isCash ? 0.0 : net;

    if (paymentSplits != null && paymentSplits.isNotEmpty) {
      paid = paymentSplits.fold<double>(0.0, (sum, s) => sum + ((s['Amount'] as num?)?.toDouble() ?? 0.0));
      remainder = net > paid ? net - paid : 0.0;
    }

    // Build details list matching InvoiceDetail schema
    final details = _cartItems.map((item) {
      return {
        'ProductID': item['ProductID'],
        'UnitPrice': item['price'],
        'Quantity': item['quantity'],
        'TotalPrice': item['total'],
        'CostPrice':
            item['price'], // Default cost price to sale price if unknown
      };
    }).toList();

    // Build payload matching InvoiceCreate schema
    final payload = {
      'InvType': widget.type == 'Sales' ? 'Sales' : 'Purchase',
      'InvDate': DateTime.now().toIso8601String(),
      'PartnerID': widget.partner['PartnerID'],
      'WarehouseID': warehouseId,
      'TotalAmount': total,
      'Discount': discount,
      'NetAmount': net,
      'PaidAmount': paid,
      'Remainder': remainder,
      'Notes': '${context.tr('pb_offer_notes')}${widget.quoteId}${widget.tempNotes != null && widget.tempNotes!.isNotEmpty ? " | " + widget.tempNotes! : ""}',
      'IsPosted': false,
      'Details': details,
      if (isCash && (paymentAccountId ?? _selectedAccountId) != null)
        'PaymentAccountID': paymentAccountId ?? _selectedAccountId,
      if (paymentSplits != null && paymentSplits.isNotEmpty)
        'PaymentSplits': paymentSplits,
      'TempCustomerName': widget.tempCustomerName,
      'TempPhone': widget.tempPhone,
      'TempAddress': widget.tempAddress,
      'TempDeliveryDate': widget.tempDeliveryDate,
      'TempDeliveryTime': widget.tempDeliveryTime,
    };

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final pbSaveSuccessTpl = context.tr('pb_save_success');
    final pbSaveErrorTpl = context.tr('pb_save_error');

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final printerService = Provider.of<PrinterService>(context, listen: false);
      final response = await apiService.savePartnerInvoice(payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final int newInvId = response.data['InvID'] ?? 0;

        String? paymentAccountName;
        if (isCash) {
          if (_accounts.isNotEmpty) {
            final selectedId = paymentAccountId ?? _selectedAccountId;
            final selected = _accounts.firstWhere(
              (a) => a['AccountID'] == selectedId,
              orElse: () => _accounts.first,
            );
            paymentAccountName = selected['AccountName']?.toString();
          }
          if (paymentAccountName == null || paymentAccountName.trim().isEmpty) {
            paymentAccountName = 'نقداً';
          }
        }

        final printInvoiceData = {
          'InvID': newInvId,
          'PartnerName': widget.partner['PartnerName'],
          'type': widget.type == 'Sales' ? 'Sales' : 'Purchase',
          'created_at': DateTime.now().toIso8601String(),
          'total_amount': net,
          'paid_amount':  paid,
          'remainder':    remainder,
          if (paymentSplits != null && paymentSplits.isNotEmpty) 'PaymentSplits': paymentSplits,
          if (paymentAccountName != null && paymentAccountName.isNotEmpty) 'PaymentAccountName': paymentAccountName,
          'temp_customer_name': widget.tempCustomerName,
          'temp_phone':        widget.tempPhone,
          'temp_address':      widget.tempAddress,
          'temp_delivery_date': widget.tempDeliveryDate,
          'temp_delivery_time': widget.tempDeliveryTime,
          'items': _cartItems
              .map((c) => {
                    'name': c['name'],
                    'price': c['price'],
                    'quantity': (c['quantity'] as num).toDouble(),
                    'total': c['total'],
                    'UnitName': c['UnitName'] ?? c['unitName'] ?? c['unit_name'] ?? c['unit'] ?? '',
                  })
              .toList(),
        };

        final successMsg = pbSaveSuccessTpl.replaceAll('{id}', newInvId.toString());

        await printerService.printReceipt(printInvoiceData);

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                successMsg,
                textAlign: TextAlign.right,
              ),
              backgroundColor: Colors.green,
            ),
          );
          nav.pop(); // Return to offers screen
        }
      } else {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                pbSaveErrorTpl,
                textAlign: TextAlign.right,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${pbSaveErrorTpl}: $e',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 700;
    final primaryColor =
        widget.type == 'Sales' ? Colors.blue[700]! : Colors.orange[800]!;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f12 && !_isLoading) {
            _showCashPaymentDialog();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                widget.type == 'Sales'
                    ? context.tr('pb_sales_offer_invoice')
                    : context.tr('pb_purchase_offer_invoice'),
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '${context.tr('pb_partner_name')}${widget.partner['PartnerName']}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              )
            ],
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.type == 'Sales'
                    ? [Colors.blue, Colors.teal]
                    : [Colors.orange, Colors.red],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Consumer<PrinterService>(
              builder: (context, printerService, child) {
                return IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'طباعة أحدث إضافة بالنظام',
                  onPressed: () async {
                    if (printerService.lastAddedDocument == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يوجد مستند سابق مضاف حالياً لطباعته', textAlign: TextAlign.right),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final success = await printerService.printLastAddedDocument();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? 'تمت طباعة أحدث إضافة بنجاح' : 'فشلت عملية طباعة أحدث إضافة',
                            textAlign: TextAlign.right,
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              tooltip: context.tr('pb_scan_tooltip'),
              onPressed: _openCameraScanner,
            )
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.teal))
              : isTablet
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Cart items list and invoice summery checkout
                        Expanded(
                          flex: 5,
                          child: _buildCartPanel(primaryColor),
                        ),
                        // Right: Allowed items catalog
                        Expanded(
                          flex: 6,
                          child: _buildCatalogPanel(primaryColor),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Search bar in mobile
                        _buildSearchBar(primaryColor),
                        // Small stats
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: Colors.grey[100],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  '${context.tr('pb_items_in_cart')}${_cartItems.length}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  context.tr('pb_total_kd').replaceAll(
                                      '{total}', _subtotal.toStringAsFixed(2)),
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        // Allowed Items List (Tap to add)
                        Expanded(
                          child: _buildMobileCatalogList(),
                        ),
                        // Checkout bottom bar
                        _buildMobileCheckoutBar(primaryColor),
                      ],
                    ),
        ),
      ),
    );
  }

  // === UI Panels for Tablet Layout ===

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filterAllowedItems,
              decoration: InputDecoration(
                hintText: context.tr('pb_search_hint'),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Quick Barcode Manual Field
          Container(
            width: 160,
            child: TextField(
              controller: _barcodeInputController,
              decoration: InputDecoration(
                hintText: context.tr('pb_barcode_hint'),
                border: const OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onSubmitted: (val) {
                _handleBarcodeScanned(val);
                _barcodeInputController.clear();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel(Color primaryColor) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(primaryColor),
          const SizedBox(height: 8),
          Text(
            context.tr('pb_approved_items_title'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: _filteredAllowedItems.length,
              itemBuilder: (context, index) {
                final item = _filteredAllowedItems[index];
                final price = (item['UnitPrice'] ?? item['QuotedPrice'] ?? 0.0)
                    .toDouble();
                final name = item['ProductName'] ?? 'صنف غير معروف';
                final barcode = item['Barcode'] ?? context.tr('pb_no_barcode');
                final unitName =
                    item['UnitName'] ?? context.tr('pb_item_piece');

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _addOrIncrementProduct(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              color: primaryColor, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${price.toStringAsFixed(3)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol} / $unitName',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            barcode,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCartPanel(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.teal),
                const SizedBox(width: 8),
                Text(context.tr('pb_cart_title'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Text(context.tr('pb_cart_empty'),
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return ListTile(
                        title: Text(item['name'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                                '${context.tr('pb_item_price')}${item['price'].toStringAsFixed(3)}${context.tr('pb_item_quantity')}'),
                            _QuantityEditor(
                              initialQuantity: item['quantity'],
                              onChanged: (newQty) => _updateCartQuantity(
                                  item['ProductID'], newQty),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item['total'].toStringAsFixed(2)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 15),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _updateCartQuantity(item['ProductID'], 0),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildCheckoutSummaryPanel(primaryColor),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummaryPanel(Color primaryColor) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('pb_subtotal'),
                  style: const TextStyle(fontSize: 15)),
              Text('${_subtotal.toStringAsFixed(2)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('pb_discount_value'),
                  style: const TextStyle(fontSize: 15)),
              Container(
                width: 100,
                height: 35,
                child: TextField(
                  controller: _discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('pb_net_amount'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${_netAmount.toStringAsFixed(2)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          // Pay Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _cartItems.isEmpty ? null : () => _showCashPaymentDialog(),
                  icon: const Icon(Icons.payment),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(context.tr('pb_pay_cash'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cartItems.isEmpty
                      ? null
                      : () async {
                          if (_accounts.isEmpty) {
                            await _loadPaymentAccounts();
                          }
                          if (mounted) {
                            _showSplitPaymentDialog();
                          }
                        },
                  icon: const Icon(Icons.call_split, color: Colors.teal),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(context.tr('pos_split_payment'),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _cartItems.isEmpty ? null : () => _submitInvoice(false),
                  icon: const Icon(Icons.timer_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(context.tr('pb_pay_credit'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === UI Panels for Mobile Layout ===

  Widget _buildMobileCatalogList() {
    return _filteredAllowedItems.isEmpty
        ? Center(child: Text(context.tr('pb_no_results')))
        : ListView.builder(
            itemCount: _filteredAllowedItems.length,
            itemBuilder: (context, index) {
              final item = _filteredAllowedItems[index];
              final price =
                  (item['UnitPrice'] ?? item['QuotedPrice'] ?? 0.0).toDouble();
              final name = item['ProductName'] ?? '';
              final barcode = item['Barcode'] ?? '';
              final unitName = item['UnitName'] ?? '';

              final cartIndex = _cartItems
                  .indexWhere((c) => c['ProductID'] == item['ProductID']);
              final cartQty =
                  cartIndex != -1 ? _cartItems[cartIndex]['quantity'] : 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '$barcode | السعر: ${price.toStringAsFixed(3)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol} / $unitName'),
                  trailing: cartQty > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () =>
                                  _decrementOrRemoveProduct(item['ProductID']),
                            ),
                            _QuantityEditor(
                              initialQuantity: cartQty,
                              onChanged: (newQty) => _updateCartQuantity(
                                  item['ProductID'], newQty),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              onPressed: () => _addOrIncrementProduct(item),
                            ),
                          ],
                        )
                      : ElevatedButton(
                          onPressed: () => _addOrIncrementProduct(item),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal),
                          child: Text(context.tr('pb_add_btn'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                ),
              );
            },
          );
  }

  Widget _buildMobileCheckoutBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي: ${_netAmount.toStringAsFixed(2)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.shopping_cart),
                label: Text(context
                    .tr('pb_view_cart')
                    .replaceAll('{count}', _cartItems.length.toString())),
                onPressed: _showCartDetailsBottomSheet,
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cartItems.isEmpty
                      ? null
                      : () async {
                          if (_accounts.isEmpty) {
                            await _loadPaymentAccounts();
                          }
                          if (mounted) {
                            _showSplitPaymentDialog();
                          }
                        },
                  icon: const Icon(Icons.call_split, color: Colors.teal, size: 16),
                  label: Text(context.tr('pos_split_payment'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _cartItems.isEmpty ? null : () => _showCashPaymentDialog(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: Text(context.tr('pb_pay_cash'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _cartItems.isEmpty ? null : () => _submitInvoice(false),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                  child: Text(context.tr('pb_pay_credit'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showCartDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('pb_current_cart'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _cartItems.isEmpty
                          ? Center(
                              child: Text(context.tr('pb_empty_cart_short')))
                          : ListView.builder(
                              itemCount: _cartItems.length,
                              itemBuilder: (context, index) {
                                final item = _cartItems[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(item['name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                            '${context.tr('pb_item_price')}${item['price'].toStringAsFixed(3)}${context.tr('pb_item_quantity')}'),
                                        _QuantityEditor(
                                          initialQuantity: item['quantity'],
                                          onChanged: (newQty) {
                                            _updateCartQuantity(
                                                item['ProductID'], newQty);
                                            setSheetState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            '${item['total'].toStringAsFixed(2)} ${Provider.of<SettingsProvider>(context, listen: false).currencySymbol}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            _updateCartQuantity(
                                                item['ProductID'], 0);
                                            setSheetState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('pb_discount_value'),
                            style: const TextStyle(fontSize: 16)),
                        Container(
                          width: 100,
                          height: 35,
                          child: TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              setSheetState(() {});
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context
                          .tr('pb_final_net')
                          .replaceAll('{total}', _netAmount.toStringAsFixed(2)),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuantityEditor extends StatefulWidget {
  final num initialQuantity;
  final Function(num) onChanged;

  const _QuantityEditor(
      {required this.initialQuantity, required this.onChanged});

  @override
  _QuantityEditorState createState() => _QuantityEditorState();
}

class _QuantityEditorState extends State<_QuantityEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialQuantity.toString());
  }

  @override
  void didUpdateWidget(covariant _QuantityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity) {
      if (num.tryParse(_controller.text) != widget.initialQuantity) {
        _controller.text = widget.initialQuantity.toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 35,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (val) {
          final numVal = num.tryParse(val);
          if (numVal != null) {
            widget.onChanged(numVal);
          } else {
            _controller.text = widget.initialQuantity.toString();
          }
        },
      ),
    );
  }
}
