import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../providers/pos_provider.dart';
import '../providers/shift_provider.dart';
import '../providers/settings_provider.dart';
import '../models/product_discount.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/app_snackbar.dart';
import '../widgets/product_entry_scanner.dart';
import '../models/integration_models.dart';
import '../services/integrations/integration_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'supplier_selection_screen.dart';

class PosScreen extends StatefulWidget {
  final String type; // 'Sales' or 'Purchase'
  final Map<String, dynamic>?
      partner; // Optional selected partner (for purchases)
  final String? tempCustomerName;
  final String? tempPhone;
  final String? tempAddress;
  final String? tempDeliveryDate;
  final String? tempDeliveryTime;
  final String? tempNotes;
  final Map<String, dynamic>? editingInvoice;

  const PosScreen({
    super.key,
    required this.type,
    this.partner,
    this.tempCustomerName,
    this.tempPhone,
    this.tempAddress,
    this.tempDeliveryDate,
    this.tempDeliveryTime,
    this.tempNotes,
    this.editingInvoice,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _barcodeController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedCat;
  List<Map<String, dynamic>> _accounts = [];
  int? _selectedAccountId;
  bool _isCash = true;
  Map<String, dynamic>? _selectedPartner;
  List<IntegrationProviderModel> _configuredGateways = [];
  bool _gatewaysChecked = false;

  // Catalog Products Caching Fields for Performance Optimization
  bool _isLoadingProducts = false;
  String? _productsError;
  List<Map<String, dynamic>> _allProducts = [];
  Map<String, List<Map<String, dynamic>>> _groupedProducts = {};
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _selectedPartner = widget.partner;
    if (widget.editingInvoice != null) {
      final inv = widget.editingInvoice!;
      final rawPartnerId = inv['PartnerID'] ?? inv['partner_id'];
      final rawPartnerName = inv['PartnerName'] ?? inv['partner_name'];
      if (_selectedPartner == null && rawPartnerId != null) {
        _selectedPartner = {
          'PartnerID': rawPartnerId is num
              ? rawPartnerId.toInt()
              : int.tryParse(rawPartnerId.toString()) ?? 1,
          'PartnerName': rawPartnerName?.toString() ?? '',
        };
      }
      final double paid = (inv['PaidAmount'] is num)
          ? (inv['PaidAmount'] as num).toDouble()
          : double.tryParse(inv['PaidAmount']?.toString() ?? '0') ?? 0.0;
      _isCash = paid > 0;
      final rawAccId = inv['PaymentAccountID'] ?? inv['payment_account_id'];
      _selectedAccountId = rawAccId is num
          ? rawAccId.toInt()
          : int.tryParse(rawAccId?.toString() ?? '');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final posProv = Provider.of<PosProvider>(context, listen: false);
        posProv.loadInvoiceIntoCart(inv);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _fetchAndProcessProducts(); // Initial pre-fetch of catalog in background
    });
    _loadPaymentAccounts();
    if (widget.type == 'Sales') {
      _loadConfiguredGateways();
    } else {
      _gatewaysChecked = true;
    }
  }

  Future<void> _loadConfiguredGateways() async {
    if (widget.type != 'Sales') {
      _gatewaysChecked = true;
      return;
    }
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.companySettings != null &&
          !settings.hasAnyPaymentGatewayEnabled) {
        if (mounted) {
          setState(() {
            _configuredGateways = [];
            _gatewaysChecked = true;
          });
        } else {
          _gatewaysChecked = true;
        }
        return;
      }

      final summary = await IntegrationPosService().fetchProvidersSummary();
      final List<IntegrationProviderModel> providers =
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
          _gatewaysChecked = true;
        });
      }
    } catch (_) {
      _gatewaysChecked = true;
    }
  }

  /// يضمن ظهور حسابات بوابات الدفع المضافة والمفعلة ضمن قائمة طرق السداد
  void _mergeConfiguredGatewayAccountsIntoDropdown() {
    if (widget.type != 'Sales' || _configuredGateways.isEmpty) return;
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

  /// يطابق الحساب المختار مع البوابات المضافة والمفعلة فعلياً لدى المستخدم فقط
  IntegrationProviderModel? _matchGatewayForAccount(
      int? accId, String? accName) {
    if (widget.type != 'Sales' || _configuredGateways.isEmpty) return null;
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
    if (accId == null || _accounts.isEmpty) return null;
    for (final acc in _accounts) {
      if (acc['AccountID'] == accId) {
        return acc['AccountName']?.toString();
      }
    }
    return null;
  }

  List<Widget> _buildGatewaySelectionWidgets(double total) {
    final gw = _matchGatewayForAccount(
        _selectedAccountId, _getAccountNameById(_selectedAccountId));
    if (gw == null) return const [];

    final dynamic rawEditId = widget.editingInvoice?['InvID'] ??
        widget.editingInvoice?['inv_id'] ??
        widget.editingInvoice?['InvoiceID'];
    final int? existingInvId = rawEditId is int
        ? rawEditId
        : int.tryParse(rawEditId?.toString() ?? '');

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: Colors.indigo.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${context.tr('pos_gw_auto_link_prefix')}${Localizations.localeOf(context).languageCode == 'ar' ? gw.providerNameAr : (gw.providerNameEn.isNotEmpty ? gw.providerNameEn : gw.providerCode)}${context.tr('pos_gw_auto_link_suffix')}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade800),
                ),
              ),
            ],
          ),
        ),
      ),
      if (existingInvId != null && existingInvId > 0 && total > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: OutlinedButton.icon(
            onPressed: () {
              final initName = (widget.tempCustomerName ??
                      _selectedPartner?['PartnerName']?.toString() ??
                      '')
                  .trim();
              final initPhone = (widget.tempPhone ??
                      _selectedPartner?['Phone']?.toString() ??
                      _selectedPartner?['Mobile']?.toString() ??
                      '')
                  .trim();
              _showSendPaymentLinkDialog(
                invId: existingInvId,
                amount: total,
                isPaidViaGateway: true,
                preferredAccountId: _selectedAccountId,
                preferredProvider: gw,
                initialCustomerName: initName,
                initialCustomerPhone: initPhone,
              );
            },
            icon: const Icon(Icons.add_link, size: 18, color: Colors.indigo),
            label: Text(
              '${context.tr('pos_gw_send_link_prefix')}${Localizations.localeOf(context).languageCode == 'ar' ? gw.providerNameAr : (gw.providerNameEn.isNotEmpty ? gw.providerNameEn : gw.providerCode)})',
              style: const TextStyle(
                  color: Colors.indigo, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.indigo.shade300),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
    ];
  }

  Future<void> _fetchAndProcessProducts({bool force = false}) async {
    if (_allProducts.isNotEmpty && !force) {
      return;
    }
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = widget.type == 'Purchase'
          ? await apiService.getProductsForPurchase()
          : await apiService.getProductsForSales();
      if (response.statusCode == 200) {
        final List<dynamic> rawList = response.data ?? [];

        // Map and group items once
        final List<Map<String, dynamic>> mappedList =
            rawList.map((e) => Map<String, dynamic>.from(e)).toList();

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var prod in mappedList) {
          final String cat = prod['CatName']?.toString() ?? 'أخرى';
          if (!grouped.containsKey(cat)) {
            grouped[cat] = [];
          }
          grouped[cat]!.add(prod);
        }

        setState(() {
          _allProducts = mappedList;
          _groupedProducts = grouped;
          _categories = grouped.keys.toList();
          _isLoadingProducts = false;
        });
      } else {
        setState(() {
          _productsError = 'فشل تحميل قائمة المنتجات من السيرفر';
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      setState(() {
        _productsError =
            'تعذر تحميل قائمة المنتجات: ${DbErrorHelper.format(e)}';
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadPaymentAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedAccJson = prefs.getString('cached_accounts');
      if (cachedAccJson != null) {
        final List<dynamic> decoded = json.decode(cachedAccJson);
        var accountsList = List<Map<String, dynamic>>.from(decoded);
        if (widget.type != 'Sales') {
          accountsList = await IntegrationPosService.filterOutGatewayAccounts(
              accountsList);
        }
        if (mounted) {
          setState(() {
            _accounts = accountsList;
            _mergeConfiguredGatewayAccountsIntoDropdown();
            _updateSelectedAccountId();
          });
        }
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.getPaymentAccounts();
      if (res.statusCode == 200 && res.data is List) {
        var fetched = List<Map<String, dynamic>>.from(res.data);
        if (widget.type != 'Sales') {
          fetched =
              await IntegrationPosService.filterOutGatewayAccounts(fetched);
        }
        if (fetched.isNotEmpty && mounted) {
          setState(() {
            _accounts = fetched;
            _mergeConfiguredGatewayAccountsIntoDropdown();
            _updateSelectedAccountId();
          });
          prefs.setString('cached_accounts', json.encode(fetched));
        }
      }
    } catch (_) {}
  }

  void _updateSelectedAccountId() {
    if (_accounts.isNotEmpty) {
      if (_selectedAccountId == null) {
        final cashAcc = _accounts.firstWhere((acc) {
          final name = (acc['AccountName']?.toString() ?? '').toLowerCase();
          final code = (acc['AccountCode']?.toString() ?? '');
          return name.contains('صندوق') ||
              name.contains('كاش') ||
              name.contains('cash') ||
              name.contains('نقدا') ||
              name.contains('نقداً') ||
              code == '110101' ||
              code.startsWith('1101');
        }, orElse: () => _accounts.first);
        _selectedAccountId = cashAcc['AccountID'];
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final posProvider = Provider.of<PosProvider>(context, listen: false);
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: ProductEntryScanner(
            searchMode: widget.type == 'Purchase'
                ? CatalogSearchMode.purchase
                : CatalogSearchMode.sales,
            onBarcodeSubmitted: (barcode) async {
              await posProvider.searchAndAddProductByBarcode(barcode,
                  invoiceType: widget.type);
            },
            onProductSelected: (prod) {
              posProvider.addProductToCart(prod, invoiceType: widget.type);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('تمت إضافة: ${prod['ProductName'] ?? prod['name']}'),
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
        setState(() {});
      }
    });
  }

  void _showUnrecognizedPriceDialogForSheet(
      String barcode, PosProvider posProvider, VoidCallback onSuccess) {
    final priceController = TextEditingController();
    final bool isPurchase = (widget.type == 'Purchase');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            context.tr('pos_unrecognized_title'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context
                    .tr('pos_barcode_label')
                    .replaceAll('{barcode}', barcode),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isPurchase
                      ? 'سعر الشراء الافتراضي'
                      : context.tr('pos_sale_price'),
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                ),
                textAlign: TextAlign.center,
                onFieldSubmitted: (_) {
                  _submitUnrecognizedProductForSheet(barcode,
                      priceController.text, posProvider, ctx, onSuccess);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('pos_cancel'),
                  style: const TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => _submitUnrecognizedProductForSheet(
                  barcode, priceController.text, posProvider, ctx, onSuccess),
              child: Text(context.tr('pos_save_and_add'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUnrecognizedProductForSheet(
      String barcode,
      String priceText,
      PosProvider posProvider,
      BuildContext dialogContext,
      VoidCallback onSuccess) async {
    final double? price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('pos_invalid_price_error'),
              textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.pop(dialogContext);

    final bool isPurchase = (widget.type == 'Purchase');
    final product = await posProvider
        .quickAddUnrecognizedProduct(barcode, price, isPurchase: isPurchase);
    if (product != null) {
      onSuccess();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                posProvider.errorMessage ?? context.tr('pos_quick_add_error'),
                textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openProductCatalog(PosProvider posProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget content;
            if (_isLoadingProducts) {
              content = const Center(
                  child: CircularProgressIndicator(color: Colors.teal));
            } else if (_productsError != null) {
              content = Center(
                child: Text(
                  _productsError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            } else if (_allProducts.isEmpty) {
              content = Center(
                child: Text(
                  context.tr('pos_catalog_no_products'),
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              final String allLabel = context.tr('pos_catalog_all');
              final List<String> tabList = [allLabel, ..._categories];

              _selectedCat ??= allLabel;
              if (!tabList.contains(_selectedCat)) {
                _selectedCat = allLabel;
              }

              List<Map<String, dynamic>> displayedProducts = [];
              if (_selectedCat == allLabel) {
                displayedProducts = _allProducts;
              } else {
                displayedProducts = _groupedProducts[_selectedCat] ?? [];
              }

              content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tabList.length,
                      itemBuilder: (ctx, index) {
                        final catName = tabList[index];
                        final isSelected = catName == _selectedCat;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(
                              catName,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal[700],
                            backgroundColor: Colors.grey[800],
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  _selectedCat = catName;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: displayedProducts.length,
                      itemBuilder: (ctx, index) {
                        final prod = displayedProducts[index];
                        final String name = prod['ProductName'] ?? '';
                        final String unit = prod['UnitName'] ?? '';
                        final double price =
                            (prod['SalePrice'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          color: Colors.grey[850],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          child: InkWell(
                            onTap: () {
                              posProvider.addProductToCart(prod);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      context
                                          .tr('pos_added_to_cart')
                                          .replaceAll('{name}', name),
                                      textAlign: TextAlign.right),
                                  duration: const Duration(milliseconds: 700),
                                  backgroundColor: Colors.teal[800],
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (unit.isNotEmpty)
                                    Text(
                                      unit,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 11),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${price.toStringAsFixed(3)} KWD',
                                    style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
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

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('pos_catalog_title'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.tealAccent),
                            tooltip: context.tr('pos_catalog_refresh'),
                            onPressed: () async {
                              setModalState(() {
                                _isLoadingProducts = true;
                              });
                              await _fetchAndProcessProducts(force: true);
                              setModalState(() {});
                            },
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(child: content),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addProductFromBarcode(String barcode) async {
    final String trimmedBarcode = barcode.trim();
    if (trimmedBarcode.isEmpty) return;

    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final bool success = await posProvider
        .searchAndAddProductByBarcode(trimmedBarcode, invoiceType: widget.type);

    if (!success) {
      _barcodeController.clear();
      if (mounted) {
        _showUnrecognizedPriceDialog(trimmedBarcode, posProvider);
      }
    } else {
      _barcodeController.clear();
    }
  }

  void _showUnrecognizedPriceDialog(String barcode, PosProvider posProvider) {
    final priceController = TextEditingController();
    final bool isPurchase = (widget.type == 'Purchase');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'صنف جديد غير معرف',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'رمز الباركود: $barcode',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isPurchase ? 'سعر الشراء الافتراضي' : 'سعر البيع',
                  labelStyle: const TextStyle(color: Colors.teal),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                ),
                textAlign: TextAlign.center,
                onFieldSubmitted: (_) {
                  // Submit on Enter key press
                  _submitUnrecognizedProduct(
                      barcode, priceController.text, posProvider, ctx);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => _submitUnrecognizedProduct(
                  barcode, priceController.text, posProvider, ctx),
              child: const Text('حفظ وإضافة',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUnrecognizedProduct(String barcode, String priceText,
      PosProvider posProvider, BuildContext dialogContext) async {
    final double? price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر',
              textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.pop(dialogContext);

    final bool isPurchase = (widget.type == 'Purchase');
    final product = await posProvider
        .quickAddUnrecognizedProduct(barcode, price, isPurchase: isPurchase);
    if (product != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الصنف وإضافته بنجاح',
                textAlign: TextAlign.right),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 1500),
          ),
        );
        _focusNode.requestFocus();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(posProvider.errorMessage ?? 'حدث خطأ في التسجيل',
                textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final invoiceItems = posProvider.invoiceItems;
    final bool isTablet = MediaQuery.of(context).size.width > 600;
    final double total = posProvider.totalAmount;
    final bool canPay = invoiceItems.isNotEmpty;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.f12) {
          if (canPay && !posProvider.isLoading) {
            _handlePaymentAndPrint(posProvider, total);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(
              widget.editingInvoice != null
                  ? (widget.type == 'Sales'
                      ? context.tr('pos_editing_invoice_sales').replaceAll(
                          '{id}',
                          widget.editingInvoice!['InvID']?.toString() ?? '')
                      : context.tr('pos_editing_invoice_purchase').replaceAll(
                          '{id}',
                          widget.editingInvoice!['InvID']?.toString() ?? ''))
                  : (widget.type == 'Sales'
                      ? (_selectedPartner != null
                          ? context
                              .tr('pos_sales_title_with_partner')
                              .replaceAll(
                                  '{name}',
                                  _selectedPartner!['PartnerName']
                                          ?.toString() ??
                                      '')
                          : context.tr('pos_sales_title'))
                      : (_selectedPartner != null
                          ? context
                              .tr('pos_purchase_title_with_partner')
                              .replaceAll(
                                  '{name}',
                                  _selectedPartner!['PartnerName']
                                          ?.toString() ??
                                      '')
                          : context.tr('pos_purchase_title'))),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.type == 'Sales'
                    ? [const Color(0xFF0F766E), const Color(0xFF0D9488)]
                    : [const Color(0xFFB45309), const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            Consumer<PrinterService>(
              builder: (context, printerService, child) {
                return IconButton(
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'طباعة أحدث إضافة بالنظام',
                  onPressed: () async {
                    if (printerService.lastAddedDocument == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'لا يوجد مستند سابق مضاف حالياً لطباعته',
                              textAlign: TextAlign.right),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    final success =
                        await printerService.printLastAddedDocument();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'تمت طباعة أحدث إضافة بنجاح'
                                : 'فشلت عملية طباعة أحدث إضافة',
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
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: _scanBarcode,
            )
          ],
        ),
        body: Row(
          children: [
            // Items Area
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: widget.type == 'Sales'
                                ? const Color(0xFFF0FDFA)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.type == 'Sales'
                                  ? const Color(0xFF99F6E4)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.grid_view_rounded,
                                color: widget.type == 'Sales'
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFFB45309),
                                size: 26),
                            tooltip: context.tr('pos_catalog_tooltip'),
                            onPressed: () => _openProductCatalog(posProvider),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _barcodeController,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                labelText: context.tr('pos_barcode_input'),
                                labelStyle:
                                    const TextStyle(color: Color(0xFF64748B)),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: widget.type == 'Sales'
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFFD97706),
                                        width: 1.5)),
                                suffixIcon: Icon(Icons.search_rounded,
                                    color: widget.type == 'Sales'
                                        ? const Color(0xFF0D9488)
                                        : const Color(0xFFD97706)),
                              ),
                              onSubmitted: _addProductFromBarcode,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final selected =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PartnerSelectionScreen(
                                type: widget.type, isSelectionOnly: true),
                          ),
                        );
                        if (selected != null) {
                          setState(() {
                            _selectedPartner = selected;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPartner != null
                                    ? '${widget.type == 'Sales' ? context.tr('pos_customer') : context.tr('pos_supplier')}: ${_selectedPartner!['PartnerName']}'
                                    : '${widget.type == 'Sales' ? context.tr('pos_customer') : context.tr('pos_supplier')}: ${context.tr('pos_cash_general')}',
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: widget.type == 'Sales'
                                    ? const Color(0xFFF0FDFA)
                                    : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_search_rounded,
                                  color: widget.type == 'Sales'
                                      ? const Color(0xFF0F766E)
                                      : const Color(0xFFB45309),
                                  size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (posProvider.isLoading)
                    LinearProgressIndicator(
                        color: widget.type == 'Sales'
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFD97706)),
                  Expanded(
                    child: invoiceItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_cart_outlined,
                                    size: 56, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 10),
                                Text(context.tr('pos_empty_cart'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                            itemCount: invoiceItems.length,
                            itemBuilder: (context, index) {
                              final item = invoiceItems[index];
                              final int productId = item['ProductID'] ?? 0;
                              final availableDiscounts = widget.type == 'Sales'
                                  ? (posProvider.activeDiscountsByProduct[
                                          productId] ??
                                      [])
                                  : <ProductDiscount>[];
                              final ProductDiscount? activeDiscount =
                                  item['appliedDiscount'] as ProductDiscount?;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        title: Row(
                                          children: [
                                            if (activeDiscount != null)
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFFFFBEB),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFF59E0B)),
                                                    ),
                                                    child: Text(
                                                      '${context.tr('pos_item_discount')}: ${activeDiscount.formattedLabel}',
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                              0xFFB45309)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                item['name'],
                                                textAlign: TextAlign.right,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6.0),
                                          child: Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              if (widget.type == 'Purchase')
                                                _PriceEditor(
                                                  initialPrice:
                                                      (item['price'] as num)
                                                          .toDouble(),
                                                  isPurchase: true,
                                                  onChanged: (newPrice) {
                                                    posProvider.updatePrice(
                                                        index, newPrice);
                                                  },
                                                )
                                              else
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF0FDFA),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    '${context.tr('pos_item_price')}${(item['price'] as num).toStringAsFixed(3)}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12.5,
                                                        color:
                                                            Color(0xFF0F766E)),
                                                  ),
                                                ),
                                              Text(
                                                  '${context.tr('pos_item_quantity')}',
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                      color:
                                                          Color(0xFF64748B))),
                                              _QuantityEditor(
                                                initialQuantity:
                                                    item['quantity'],
                                                onChanged: (newQty) {
                                                  posProvider.updateQuantity(
                                                      index, newQty);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                if (activeDiscount != null &&
                                                    item['originalPrice'] !=
                                                        null)
                                                  Text(
                                                    '${((item['originalPrice'] as num) * (item['quantity'] as num)).toStringAsFixed(3)}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF94A3B8),
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                    ),
                                                  ),
                                                Text(
                                                  '${(item['total'] as num).toStringAsFixed(3)} KWD',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color:
                                                          widget.type == 'Sales'
                                                              ? const Color(
                                                                  0xFF059669)
                                                              : const Color(
                                                                  0xFFB45309)),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Color(0xFFE11D48),
                                                  size: 20),
                                              onPressed: () =>
                                                  posProvider.removeItem(index),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (availableDiscounts.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 16.0,
                                              left: 16.0,
                                              bottom: 8.0),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children:
                                                availableDiscounts.map((disc) {
                                              final bool isSelected =
                                                  activeDiscount?.discountId ==
                                                      disc.discountId;
                                              return ChoiceChip(
                                                label: Text(
                                                  disc.formattedLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF0F766E),
                                                  ),
                                                ),
                                                selected: isSelected,
                                                selectedColor:
                                                    const Color(0xFF0F766E),
                                                backgroundColor:
                                                    const Color(0xFFF0FDFA),
                                                onSelected: (_) {
                                                  posProvider
                                                      .toggleDiscountForItem(
                                                          index, disc);
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Checkout Area (Only side-by-side if Tablet, else stacked or modal)
            if (isTablet) _buildCheckoutPanel(posProvider),
          ],
        ),
        // For mobile portrait, show compact checkout bar at bottom
        bottomNavigationBar:
            !isTablet ? _buildCompactBottomBar(posProvider) : null,
      ),
    );
  }

  Future<void> _handlePaymentAndPrint(PosProvider posProvider, double total,
      {List<Map<String, dynamic>>? paymentSplits}) async {
    // Capture ALL UI context objects and translation strings BEFORE any async gaps
    final messenger = ScaffoldMessenger.of(context);
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final warnMsgTpl = context.tr('pos_save_success_warn');
    final okMsgTpl = context.tr('pos_save_success_ok');
    final printedLabel = context.tr('pos_print_status_printed');
    final errorLabel = context.tr('pos_print_status_failed');
    final virtualLabel = context.tr('pos_print_status_virtual');
    final failedMsg = posProvider.errorMessage ?? context.tr('pos_save_failed');

    double paid = _isCash ? total : 0.0;
    double remainder = _isCash ? 0.0 : total;

    if (paymentSplits != null && paymentSplits.isNotEmpty) {
      paid = paymentSplits.fold<double>(
          0.0, (sum, s) => sum + ((s['Amount'] as num?)?.toDouble() ?? 0.0));
      remainder = total > paid ? total - paid : 0.0;
    }

    String? paymentAccountName;
    if (_isCash) {
      _updateSelectedAccountId();
      if (_accounts.isNotEmpty) {
        final selected = _accounts.firstWhere(
          (a) => a['AccountID'] == _selectedAccountId,
          orElse: () => _accounts.first,
        );
        paymentAccountName = selected['AccountName']?.toString();
      }
      if (paymentAccountName == null || paymentAccountName.trim().isEmpty) {
        paymentAccountName = 'Cash';
      }
    }

    int? editId;
    String? origInvDate;
    int? origShiftId;

    if (widget.editingInvoice != null) {
      final rawId = widget.editingInvoice!['InvID'] ??
          widget.editingInvoice!['inv_id'] ??
          widget.editingInvoice!['InvoiceID'];
      if (rawId is int) {
        editId = rawId;
      } else if (rawId is num) {
        editId = rawId.toInt();
      } else if (rawId is String) {
        editId = int.tryParse(rawId);
      }

      origInvDate = widget.editingInvoice!['InvDate']?.toString() ??
          widget.editingInvoice!['created_at']?.toString();

      final rawShift = widget.editingInvoice!['ShiftID'] ??
          widget.editingInvoice!['shift_id'];
      if (rawShift is int) {
        origShiftId = rawShift;
      } else if (rawShift is num) {
        origShiftId = rawShift.toInt();
      } else if (rawShift is String) {
        origShiftId = int.tryParse(rawShift);
      }
    }

    if (widget.type == 'Sales' &&
        !_gatewaysChecked &&
        _configuredGateways.isEmpty) {
      await _loadConfiguredGateways();
    }

    bool isPaidViaGateway = false;
    IntegrationProviderModel? matchedGateway;
    int? matchedGatewayAccId;
    double gatewayAmount = 0.0;
    double savePaid = paid;
    double saveRemainder = remainder;
    List<Map<String, dynamic>>? savePaymentSplits = paymentSplits;
    int? savePaymentAccountId = _selectedAccountId;

    if (widget.type == 'Sales' && _configuredGateways.isNotEmpty) {
      if (paymentSplits != null && paymentSplits.isNotEmpty) {
        final List<Map<String, dynamic>> nonGatewaySplits = [];
        double nonGatewayPaidSum = 0.0;

        for (final split in paymentSplits) {
          final rawId = split['AccountID'] ?? split['PaymentAccountID'];
          final int? sAccId =
              rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          final String? sName = (split['AccountName'] ??
                  split['PaymentAccountName'] ??
                  split['PaymentMethodName'])
              ?.toString();
          final double sAmt = (split['Amount'] is num)
              ? (split['Amount'] as num).toDouble()
              : double.tryParse(split['Amount']?.toString() ?? '0') ?? 0.0;
          final gw = sAmt > 0 ? _matchGatewayForAccount(sAccId, sName) : null;
          if (gw != null) {
            isPaidViaGateway = true;
            matchedGateway ??= gw;
            matchedGatewayAccId ??= sAccId;
            gatewayAmount += sAmt;
          } else {
            nonGatewaySplits.add(split);
            nonGatewayPaidSum += sAmt;
          }
        }

        // منع ازدواجية قيد التحصيل: جزء البوابة يبقى آجل حتى يتأكد السداد عبر الرابط
        if (isPaidViaGateway) {
          savePaymentSplits =
              nonGatewaySplits.isNotEmpty ? nonGatewaySplits : null;
          savePaid = nonGatewayPaidSum;
          saveRemainder =
              total > nonGatewayPaidSum ? (total - nonGatewayPaidSum) : 0.0;
          if (matchedGatewayAccId != null && nonGatewaySplits.isEmpty) {
            savePaymentAccountId = matchedGatewayAccId;
          }
        }
      } else if (_isCash && paid > 0) {
        final gw =
            _matchGatewayForAccount(_selectedAccountId, paymentAccountName);
        if (gw != null) {
          isPaidViaGateway = true;
          matchedGateway = gw;
          matchedGatewayAccId = _selectedAccountId;
          gatewayAmount = paid;
          savePaid = 0.0;
          saveRemainder = total;
        }
      }
    }

    // 1. Capture invoice elements BEFORE clearing provider state upon save
    final invoiceToPrint = {
      'type': widget.type,
      'created_at': origInvDate ?? DateTime.now().toIso8601String(),
      'InvDate': origInvDate ?? DateTime.now().toIso8601String(),
      'PartnerName': _selectedPartner != null
          ? (_selectedPartner!['PartnerName']?.toString() ?? '')
          : '',
      'partner_name': _selectedPartner != null
          ? (_selectedPartner!['PartnerName']?.toString() ?? '')
          : '',
      'total_amount': total,
      'original_total': posProvider.totalOriginalAmount,
      'discount_amount': posProvider.totalDiscountAmount,
      'paid_amount': savePaid,
      'remainder': saveRemainder,
      'items': List<Map<String, dynamic>>.from(posProvider.invoiceItems),
      if (savePaymentSplits != null && savePaymentSplits.isNotEmpty)
        'PaymentSplits': savePaymentSplits,
      if (paymentAccountName != null && paymentAccountName.isNotEmpty)
        'PaymentAccountName': paymentAccountName,
      'temp_customer_name':
          widget.tempCustomerName ?? widget.editingInvoice?['TempCustomerName'],
      'temp_phone': widget.tempPhone ?? widget.editingInvoice?['TempPhone'],
      'temp_address':
          widget.tempAddress ?? widget.editingInvoice?['TempAddress'],
      'temp_delivery_date':
          widget.tempDeliveryDate ?? widget.editingInvoice?['TempDeliveryDate'],
      'temp_delivery_time':
          widget.tempDeliveryTime ?? widget.editingInvoice?['TempDeliveryTime'],
      'temp_notes': widget.tempNotes ?? widget.editingInvoice?['Notes'],
    };

    // 2. Perform save (either online or offline local persistence fallback)
    final newInvId = await posProvider.saveInvoice(
      widget.type,
      paymentAccountId: savePaymentAccountId,
      partnerId: _selectedPartner?['PartnerID'],
      isCash: _isCash,
      paymentSplits: savePaymentSplits,
      overridePaidAmount: isPaidViaGateway ? savePaid : null,
      overrideRemainder: isPaidViaGateway ? saveRemainder : null,
      tempCustomerName:
          widget.tempCustomerName ?? widget.editingInvoice?['TempCustomerName'],
      tempPhone: widget.tempPhone ?? widget.editingInvoice?['TempPhone'],
      tempAddress: widget.tempAddress ?? widget.editingInvoice?['TempAddress'],
      tempDeliveryDate:
          widget.tempDeliveryDate ?? widget.editingInvoice?['TempDeliveryDate'],
      tempDeliveryTime:
          widget.tempDeliveryTime ?? widget.editingInvoice?['TempDeliveryTime'],
      tempNotes: widget.tempNotes ?? widget.editingInvoice?['Notes'],
      existingInvId: editId,
      invDate: origInvDate,
      shiftId: origShiftId,
    );

    if (newInvId != null) {
      // اعتماد رقم الفاتورة الفعلي (InvID) الراجع من الخادم بعد إتمام الحفظ قبل الطباعة
      invoiceToPrint['InvID'] = newInvId;
      invoiceToPrint['id'] = newInvId;
      invoiceToPrint['InvoiceID'] = newInvId;
      invoiceToPrint['invoice_id'] = newInvId;
      if (newInvId == 0) {
        invoiceToPrint['is_offline_unapproved'] = true;
      }

      // 2.5 فتح نافذة رابط الدفع حصراً عند اختيار إحدى بوابات الدفع المضافة والمفعلة
      if (widget.type == 'Sales' &&
          newInvId > 0 &&
          mounted &&
          isPaidViaGateway) {
        final double linkAmount = gatewayAmount > 0 ? gatewayAmount : total;
        final String initCustName = (widget.tempCustomerName ??
                _selectedPartner?['PartnerName']?.toString() ??
                '')
            .trim();
        final String initCustPhone = (widget.tempPhone ??
                _selectedPartner?['Phone']?.toString() ??
                _selectedPartner?['Mobile']?.toString() ??
                '')
            .trim();

        final createdLink = await _showSendPaymentLinkDialog(
          invId: newInvId,
          amount: linkAmount,
          isPaidViaGateway: true,
          preferredAccountId: matchedGatewayAccId ?? _selectedAccountId,
          preferredProvider: matchedGateway,
          initialCustomerName: initCustName,
          initialCustomerPhone: initCustPhone,
        );
        if (createdLink != null && createdLink.paymentUrl.isNotEmpty) {
          IntegrationProviderModel? linkProvider = matchedGateway;
          for (final g in _configuredGateways) {
            if (g.providerId == createdLink.providerId) {
              linkProvider = g;
              break;
            }
          }
          final bool allowQr = linkProvider == null
              ? true
              : (printerService.paperSize == 58
                  ? linkProvider.printQrOnPos58mm
                  : linkProvider.printQrOnPos80mm);
          invoiceToPrint['PaymentUrl'] = createdLink.paymentUrl;
          invoiceToPrint['payment_url'] = createdLink.paymentUrl;
          invoiceToPrint['AllowPrintQr'] = allowQr;
        }
      }

      final warnMsg = warnMsgTpl.replaceAll('{id}', newInvId.toString());
      final okMsg = okMsgTpl.replaceAll('{id}', newInvId.toString());

      final printSuccess = await printerService.printReceipt(invoiceToPrint);

      final isVirtual = printerService.connectionType == 'None';
      final showWarning = !printSuccess && !isVirtual;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            showWarning ? warnMsg : okMsg,
            textAlign: TextAlign.right,
          ),
          backgroundColor: showWarning ? Colors.orange : Colors.green,
          action: SnackBarAction(
            label: printSuccess
                ? printedLabel
                : (isVirtual ? virtualLabel : errorLabel),
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      if (widget.editingInvoice != null && mounted) {
        Navigator.pop(context, true);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failedMsg,
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCheckoutPanel(PosProvider posProvider, {bool isMobile = false}) {
    final double total = posProvider.totalAmount;
    final double originalTotal = posProvider.totalOriginalAmount;
    final double totalDiscount = posProvider.totalDiscountAmount;
    final bool canPay = posProvider.invoiceItems.isNotEmpty;

    return Container(
      width: isMobile ? double.infinity : 310,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${originalTotal.toStringAsFixed(3)} KWD',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                    Text('${context.tr('pos_gross_total')}:',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('- ${totalDiscount.toStringAsFixed(3)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: totalDiscount > 0
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B))),
                    Text('${context.tr('pos_total_discount')}:',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF64748B))),
                  ],
                ),
                _ExtraDiscountInputField(posProvider: posProvider),
                const Divider(height: 18, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${total.toStringAsFixed(3)} KWD',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: widget.type == 'Sales'
                                ? const Color(0xFF059669)
                                : const Color(0xFFB45309))),
                    Text('${context.tr('pos_net_total')}:',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('pos_trans_type'),
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(context.tr('pos_credit_mode'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isCash
                                ? const Color(0xFFB45309)
                                : const Color(0xFF475569))),
                  ),
                  selected: !_isCash,
                  selectedColor: const Color(0xFFFEF3C7),
                  backgroundColor: const Color(0xFFF8FAFC),
                  onSelected: (val) {
                    setState(() {
                      _isCash = !val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(context.tr('pos_cash_mode'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isCash
                                ? const Color(0xFF059669)
                                : const Color(0xFF475569))),
                  ),
                  selected: _isCash,
                  selectedColor: const Color(0xFFD1FAE5),
                  backgroundColor: const Color(0xFFF8FAFC),
                  onSelected: (val) {
                    setState(() {
                      _isCash = val;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isCash && _accounts.isNotEmpty) ...[
            Text(
              context.tr('pos_payment_account'),
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              isExpanded: true,
              dropdownColor: Colors.white,
              value: _selectedAccountId,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                fillColor: const Color(0xFFF8FAFC),
                filled: true,
              ),
              items: _accounts.map((acc) {
                return DropdownMenuItem<int>(
                  value: acc['AccountID'],
                  child: Text(
                    acc['AccountName']?.toString() ?? '',
                    style:
                        const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedAccountId = val;
                });
              },
            ),
            ..._buildGatewaySelectionWidgets(total),
            const SizedBox(height: 16),
          ],
          if (_isCash) ...[
            OutlinedButton.icon(
              onPressed: (!canPay || posProvider.isLoading)
                  ? null
                  : () async {
                      if (_accounts.isEmpty) {
                        await _loadPaymentAccounts();
                      }
                      if (mounted) {
                        _showSplitPaymentDialog(posProvider, total);
                      }
                    },
              icon: const Icon(Icons.call_split_rounded,
                  color: Color(0xFF0D9488)),
              label: Text(context.tr('pos_split_payment'),
                  style: const TextStyle(
                      color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: (!canPay || posProvider.isLoading)
                ? null
                : () => _handlePaymentAndPrint(posProvider, total),
            icon: Icon(widget.type == 'Sales'
                ? Icons.payment_rounded
                : Icons.save_alt_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13.0),
              child: posProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.type == 'Sales'
                          ? context.tr('pos_pay_print')
                          : context.tr('pos_save_and_print'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.type == 'Sales'
                  ? const Color(0xFF0F766E)
                  : const Color(0xFFB45309),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSplitPaymentDialog(
      PosProvider posProvider, double totalAmount) async {
    if (_accounts.isEmpty) {
      await _loadPaymentAccounts();
      if (_accounts.isEmpty) {
        _accounts = [
          {'AccountID': 0, 'AccountName': 'نقداً'}
        ];
      }
    }

    List<Map<String, dynamic>> splits = [];
    final existingSplits = widget.editingInvoice?['PaymentSplits'] ??
        widget.editingInvoice?['payment_splits'];
    if (existingSplits is List && existingSplits.isNotEmpty) {
      for (var s in existingSplits) {
        splits.add({
          'PaymentAccountID': s['PaymentAccountID'] ??
              s['payment_account_id'] ??
              _accounts.first['AccountID'],
          'PaymentMethodName': s['PaymentMethodName'] ?? s['AccountName'] ?? '',
          'Amount': (s['Amount'] is num)
              ? (s['Amount'] as num).toDouble()
              : double.tryParse(s['Amount']?.toString() ?? '0') ?? 0.0,
        });
      }
    } else {
      splits = [
        {
          'PaymentAccountID': _accounts.first['AccountID'],
          'Amount': totalAmount
        }
      ];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            double totalPaid = splits.fold(0.0,
                (sum, s) => sum + ((s['Amount'] as num?)?.toDouble() ?? 0.0));
            double remainder =
                totalAmount > totalPaid ? totalAmount - totalPaid : 0.0;

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('pos_split_payment'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
                          border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${totalAmount.toStringAsFixed(3)} د.ك',
                                    style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const Text('إجمالي الفاتورة:',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${totalPaid.toStringAsFixed(3)} د.ك',
                                    style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(context.tr('split_paid_now'),
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ],
                            ),
                            if (remainder > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${remainder.toStringAsFixed(3)} د.ك',
                                      style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  Text(context.tr('split_remainder_credit'),
                                      style: const TextStyle(
                                          color: Colors.white70)),
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
                          final initialAmt =
                              (split['Amount'] as num?)?.toDouble() ?? 0.0;
                          split['controller'] = TextEditingController(
                              text: initialAmt > 0
                                  ? initialAmt.toStringAsFixed(3)
                                  : '');
                        }
                        final controller =
                            split['controller'] as TextEditingController;

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
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.redAccent),
                                      onPressed: () {
                                        setDialogState(() {
                                          final removed =
                                              splits.removeAt(index);
                                          (removed['controller']
                                                  as TextEditingController?)
                                              ?.dispose();
                                        });
                                      },
                                    ),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      value: split['PaymentAccountID'],
                                      dropdownColor: Colors.grey[800],
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        labelText:
                                            context.tr('split_payment_account'),
                                        labelStyle: const TextStyle(
                                            color: Colors.white54),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                        enabledBorder: const OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white24)),
                                        focusedBorder: const OutlineInputBorder(
                                            borderSide:
                                                BorderSide(color: Colors.teal)),
                                      ),
                                      items: _accounts.map((acc) {
                                        return DropdownMenuItem<int>(
                                          value: acc['AccountID'],
                                          child: Text(acc['AccountName'] ?? '',
                                              textDirection: TextDirection.rtl),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            split['PaymentAccountID'] = val;
                                            final matchedAcc =
                                                _accounts.firstWhere(
                                                    (a) =>
                                                        a['AccountID'] == val,
                                                    orElse: () => {});
                                            split['PaymentMethodName'] =
                                                matchedAcc['AccountName'] ?? '';
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                    color: Colors.tealAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: context.tr('split_amount_paid'),
                                  labelStyle:
                                      const TextStyle(color: Colors.white54),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  enabledBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.white24)),
                                  focusedBorder: const OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.teal)),
                                ),
                                onChanged: (val) {
                                  final double parsed =
                                      double.tryParse(val) ?? 0.0;
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
                            final nextAcc = _accounts.length > splits.length
                                ? _accounts[splits.length]['AccountID']
                                : _accounts.first['AccountID'];
                            final nextName = _accounts.length > splits.length
                                ? _accounts[splits.length]['AccountName']
                                : _accounts.first['AccountName'];
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                  child: Text(context.tr('split_cancel'),
                      style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final validSplits = splits
                        .where((s) =>
                            ((s['Amount'] as num?)?.toDouble() ?? 0.0) > 0)
                        .map((s) => {
                              'PaymentAccountID': s['PaymentAccountID'],
                              'PaymentMethodName': s['PaymentMethodName'],
                              'Amount': (s['Amount'] as num).toDouble(),
                            })
                        .toList();

                    if (validSplits.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                context.tr('split_valid_amounts_warn'),
                                textAlign: TextAlign.right),
                            backgroundColor: Colors.orange),
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

                    _handlePaymentAndPrint(posProvider, totalAmount,
                        paymentSplits: validSplits);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white),
                  child: Text(context.tr('split_confirm_and_save'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCompactBottomBar(PosProvider posProvider) {
    final double total = posProvider.totalAmount;
    final double originalTotal = posProvider.totalOriginalAmount;
    final double totalDiscount = posProvider.totalDiscountAmount;
    final bool hasItems = posProvider.invoiceItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      children: [
                        Text(
                          'الإجمالي: ${originalTotal.toStringAsFixed(3)}',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11.5),
                        ),
                        if (totalDiscount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            'الخصم: -${totalDiscount.toStringAsFixed(3)}',
                            style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      children: [
                        const Text(
                          'الصافي: ',
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${total.toStringAsFixed(3)} KWD',
                          style: TextStyle(
                            color: widget.type == 'Sales'
                                ? const Color(0xFF059669)
                                : const Color(0xFFB45309),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: !hasItems
                  ? null
                  : () {
                      _showCheckoutBottomSheet(posProvider);
                    },
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white),
              label: Text(
                context.tr('pos_finish_order'),
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.type == 'Sales'
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB45309),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutBottomSheet(PosProvider posProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: _buildCheckoutSheetContent(posProvider, setSheetState),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCheckoutSheetContent(
      PosProvider posProvider, StateSetter setSheetState) {
    final double total = posProvider.totalAmount;
    final double originalTotal = posProvider.totalOriginalAmount;
    final double totalDiscount = posProvider.totalDiscountAmount;
    final bool canPay = posProvider.invoiceItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${originalTotal.toStringAsFixed(3)} KWD',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const Text('الإجمالي:',
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('- ${totalDiscount.toStringAsFixed(3)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: totalDiscount > 0
                                ? Colors.redAccent
                                : Colors.black54)),
                    Text('${context.tr('pos_total_discount')}:',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54)),
                  ],
                ),
                _ExtraDiscountInputField(posProvider: posProvider),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${total.toStringAsFixed(3)} KWD',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal)),
                    const Text('الصافي:',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            context.tr('pos_trans_type'),
            style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(context.tr('pos_credit_mode'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  selected: !_isCash,
                  selectedColor: Colors.orange[200],
                  onSelected: (val) {
                    setState(() {
                      _isCash = !val;
                    });
                    setSheetState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(context.tr('pos_cash_mode'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  selected: _isCash,
                  selectedColor: Colors.green[200],
                  onSelected: (val) {
                    setState(() {
                      _isCash = val;
                    });
                    setSheetState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isCash && _accounts.isNotEmpty) ...[
            Text(
              context.tr('pos_payment_account'),
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              isExpanded: true,
              dropdownColor: Colors.white,
              value: _selectedAccountId,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              items: _accounts.map((acc) {
                return DropdownMenuItem<int>(
                  value: acc['AccountID'],
                  child: Text(
                    acc['AccountName']?.toString() ?? '',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedAccountId = val;
                });
                setSheetState(() {});
              },
            ),
            ..._buildGatewaySelectionWidgets(total),
            const SizedBox(height: 20),
          ],
          if (_isCash) ...[
            OutlinedButton.icon(
              onPressed: (!canPay || posProvider.isLoading)
                  ? null
                  : () async {
                      Navigator.pop(context); // Close bottom sheet
                      if (_accounts.isEmpty) {
                        await _loadPaymentAccounts();
                      }
                      if (mounted) {
                        _showSplitPaymentDialog(posProvider, total);
                      }
                    },
              icon: const Icon(Icons.call_split, color: Colors.teal),
              label: Text(context.tr('pos_split_payment'),
                  style: const TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.teal, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: (!canPay || posProvider.isLoading)
                ? null
                : () async {
                    Navigator.pop(context); // Close bottom sheet
                    await _handlePaymentAndPrint(posProvider, total);
                  },
            icon: Icon(widget.type == 'Sales' ? Icons.payment : Icons.save_alt),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: posProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.type == 'Sales'
                          ? context.tr('pos_pay_print')
                          : context.tr('pos_save_and_print'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  widget.type == 'Sales' ? Colors.green : Colors.deepOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<PaymentLinkRecordModel?> _showSendPaymentLinkDialog({
    required int invId,
    required double amount,
    required bool isPaidViaGateway,
    int? preferredAccountId,
    IntegrationProviderModel? preferredProvider,
    String initialCustomerName = '',
    String initialCustomerPhone = '',
  }) async {
    if (_configuredGateways.isEmpty) return null;

    IntegrationProviderModel selectedGateway = preferredProvider ??
        _configuredGateways.firstWhere(
          (g) =>
              preferredAccountId != null &&
              g.linkedAccountId == preferredAccountId,
          orElse: () => _configuredGateways.first,
        );

    final bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    String providerLabel(IntegrationProviderModel p) {
      if (isAr) {
        return p.providerNameAr.isNotEmpty ? p.providerNameAr : p.providerCode;
      }
      if (p.providerNameEn.isNotEmpty) return p.providerNameEn;
      return p.providerCode;
    }

    final defaultCust = context.tr('pos_gw_default_customer');
    final nameCtrl = TextEditingController(
      text: initialCustomerName.isNotEmpty ? initialCustomerName : defaultCust,
    );
    final phoneCtrl = TextEditingController(text: initialCustomerPhone);
    bool sendWhatsApp = selectedGateway.autoSendWhatsApp;
    bool isCreating = false;
    String statusMsg = '';
    bool isError = false;
    PaymentLinkRecordModel? createdLink;
    bool autoTriggered = false;

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
              'يرجى سداد فاتورة المبيعات رقم #$invId بقيمة ${amount.toStringAsFixed(3)} $curr عبر رابط الدفع الآمن:\n'
              '$url\n'
              'شكراً لتعاملكم معنا.'
          : 'Hello $custName,\n'
              'Please pay sales invoice #$invId for ${amount.toStringAsFixed(3)} $curr via the secure payment link:\n'
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
                  Provider.of<PrinterService>(context, listen: false)
                              .paperSize ==
                          58
                      ? '58mm'
                      : '80mm';
              final res =
                  await IntegrationPosService().createPaymentLinkWithFeedback(
                invId: invId,
                partnerId: _selectedPartner?['PartnerID'] is int
                    ? _selectedPartner!['PartnerID'] as int
                    : int.tryParse(
                        _selectedPartner?['PartnerID']?.toString() ?? ''),
                providerId: selectedGateway.providerId,
                providerCode: selectedGateway.providerCode,
                providerConfig: selectedGateway,
                amount: amount,
                currencyCode: selectedGateway.defaultCurrency,
                customerName: nameCtrl.text.trim().isEmpty
                    ? defaultCust
                    : nameCtrl.text.trim(),
                customerPhone: phoneCtrl.text.trim(),
                sendViaWhatsApp: sendWhatsApp,
                sendViaSms: selectedGateway.autoSendSms,
                printQrMode: paperMode,
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

            if (isPaidViaGateway && !autoTriggered) {
              autoTriggered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                generateLink();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.add_link, color: Colors.teal, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPaidViaGateway
                          ? '${context.tr('pos_gw_dlg_title_paid')}$invId'
                          : '${context.tr('pos_gw_dlg_title_credit')}$invId',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('pos_gw_amount_due'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${amount.toStringAsFixed(3)} ${isAr ? 'د.ك' : selectedGateway.defaultCurrency}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_configuredGateways.length > 1) ...[
                      DropdownButtonFormField<IntegrationProviderModel>(
                        value: selectedGateway,
                        decoration: InputDecoration(
                          labelText: context.tr('pos_gw_gateway_label'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _configuredGateways
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
                                  setDialogState(() => selectedGateway = val);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: nameCtrl,
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
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('pos_gw_customer_phone'),
                        hintText: context.tr('pos_gw_customer_phone_hint'),
                        prefixIcon: const Icon(Icons.phone_android),
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
                      onChanged: (v) =>
                          setDialogState(() => sendWhatsApp = v ?? false),
                    ),
                    if (statusMsg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red.withOpacity(0.1)
                              : (createdLink != null
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (isCreating) ...[
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                                  size: 170,
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
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
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
                        ? context.tr('pos_gw_continue_print')
                        : context.tr('pos_gw_skip_print'),
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

class _PriceEditor extends StatefulWidget {
  final double initialPrice;
  final bool isPurchase;
  final Function(double) onChanged;

  const _PriceEditor({
    required this.initialPrice,
    this.isPurchase = false,
    required this.onChanged,
  });

  @override
  State<_PriceEditor> createState() => _PriceEditorState();
}

class _PriceEditorState extends State<_PriceEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialPrice.toStringAsFixed(3));
  }

  @override
  void didUpdateWidget(covariant _PriceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrice != widget.initialPrice) {
      final double? currentVal = double.tryParse(_controller.text);
      if (currentVal != widget.initialPrice) {
        _controller.text = widget.initialPrice.toStringAsFixed(3);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showEditDialog() {
    final dialogController =
        TextEditingController(text: widget.initialPrice.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          widget.isPurchase
              ? 'تعديل سعر الشراء للوحدة'
              : 'تعديل سعر البيع للوحدة',
          textAlign: TextAlign.right,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: dialogController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: widget.isPurchase
                    ? 'سعر الشراء الجديد'
                    : 'سعر البيع الجديد',
                labelStyle: const TextStyle(color: Colors.teal),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal)),
              ),
              textAlign: TextAlign.center,
              onFieldSubmitted: (val) {
                final double? p = double.tryParse(val);
                if (p != null && p >= 0) {
                  widget.onChanged(p);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final double? p = double.tryParse(dialogController.text);
              if (p != null && p >= 0) {
                widget.onChanged(p);
                Navigator.pop(ctx);
              }
            },
            child: const Text('تحديث', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _showEditDialog,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.isPurchase
              ? Colors.orange.withOpacity(0.15)
              : Colors.teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: widget.isPurchase
                  ? Colors.orange.withOpacity(0.4)
                  : Colors.teal.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.isPurchase ? "الشراء: " : "السعر: "}${widget.initialPrice.toStringAsFixed(3)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color:
                    widget.isPurchase ? Colors.orange[300] : Colors.teal[300],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 14,
              color: widget.isPurchase ? Colors.orange[300] : Colors.teal[300],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraDiscountInputField extends StatefulWidget {
  final PosProvider posProvider;
  const _ExtraDiscountInputField({Key? key, required this.posProvider})
      : super(key: key);

  @override
  State<_ExtraDiscountInputField> createState() =>
      _ExtraDiscountInputFieldState();
}

class _ExtraDiscountInputFieldState extends State<_ExtraDiscountInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final double extra = widget.posProvider.extraDiscountAmount;
    _controller =
        TextEditingController(text: extra > 0 ? extra.toStringAsFixed(3) : '');
  }

  @override
  void didUpdateWidget(covariant _ExtraDiscountInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.posProvider.extraDiscountAmount == 0.0 &&
        _controller.text.isNotEmpty &&
        widget.posProvider.invoiceItems.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent),
                decoration: InputDecoration(
                  hintText: '0.000',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  prefixIcon: const Icon(Icons.local_offer,
                      size: 16, color: Colors.amber),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.amber, width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  final double parsed = double.tryParse(val) ?? 0.0;
                  widget.posProvider.setExtraDiscount(parsed);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'خصم إضافي:',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
