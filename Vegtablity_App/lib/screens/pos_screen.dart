import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../providers/pos_provider.dart';
import '../providers/shift_provider.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';
import 'supplier_selection_screen.dart';

class PosScreen extends StatefulWidget {
  final String type; // 'Sales' or 'Purchase'
  final Map<String, dynamic>? partner; // Optional selected partner (for purchases)
  final String? tempCustomerName;
  final String? tempPhone;
  final String? tempAddress;
  final String? tempDeliveryDate;
  final String? tempDeliveryTime;
  final String? tempNotes;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _fetchAndProcessProducts(); // Initial pre-fetch of catalog in background
    });
    _loadPaymentAccounts();
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
      final response = await Provider.of<ApiService>(context, listen: false).getProducts();
      if (response.statusCode == 200) {
        final List<dynamic> rawList = response.data ?? [];
        
        // Map and group items once
        final List<Map<String, dynamic>> mappedList = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        
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
        _productsError = 'فشل تحميل قائمة المنتجات: $e';
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
        setState(() {
          _accounts = List<Map<String, dynamic>>.from(decoded);
          final cashAcc = _accounts.firstWhere(
            (acc) => (acc['AccountName']?.toString() ?? '').contains('صندوق') || (acc['AccountName']?.toString() ?? '').contains('كاش'),
            orElse: () => <String, dynamic>{},
          );
          if (cashAcc.isNotEmpty) {
            _selectedAccountId = cashAcc['AccountID'];
          } else if (_accounts.isNotEmpty) {
            _selectedAccountId = _accounts.first['AccountID'];
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scanBarcode() {
    final Map<String, DateTime> lastScanned = {};
    String? statusMessage;
    Color statusColor = Colors.teal;
    List<String> sessionItems = [];

    // Create the controller outside showModalBottomSheet so it persists across rebuilds of the sheet
    final MobileScannerController scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('مسح متتابع للباركود بالكاميرا',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.grey[900],
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.check, color: Colors.greenAccent),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    actions: [
                      TextButton.icon(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        label: const Text('إنهاء', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      )
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: scannerController,
                          onDetect: (BarcodeCapture capture) async {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final String code = barcode.rawValue ?? '';
                              final String trimmed = code.trim();
                              if (trimmed.isEmpty) continue;

                              // Debounce: prevent duplicate scan within 2 seconds
                              final now = DateTime.now();
                              if (lastScanned.containsKey(trimmed) &&
                                  now.difference(lastScanned[trimmed]!).inSeconds < 2) {
                                continue;
                              }
                              lastScanned[trimmed] = now;

                              // Trigger feedback & visual status update
                              setSheetState(() {
                                statusMessage = 'جاري البحث عن الصنف...';
                                statusColor = Colors.orange;
                              });

                              final posProvider = Provider.of<PosProvider>(context, listen: false);
                              final bool success = await posProvider.searchAndAddProductByBarcode(trimmed);

                              if (success) {
                                // Find product name
                                final productItem = posProvider.invoiceItems.firstWhere(
                                  (item) => item['barcode'] == trimmed,
                                  orElse: () => <String, dynamic>{},
                                );
                                final String prodName = productItem['name'] ?? trimmed;
                                
                                SystemSound.play(SystemSoundType.click);
                                HapticFeedback.mediumImpact();

                                setSheetState(() {
                                  statusMessage = 'تمت إضافة: $prodName';
                                  statusColor = Colors.green;
                                  if (!sessionItems.contains(prodName)) {
                                    sessionItems.insert(0, prodName);
                                  }
                                });
                              } else {
                                // Unrecognized barcode - show prompt dialog above bottom sheet
                                SystemSound.play(SystemSoundType.click);
                                HapticFeedback.heavyImpact();
                                
                                setSheetState(() {
                                  statusMessage = 'صنف غير معرف! يرجى إدخال السعر';
                                  statusColor = Colors.red;
                                });

                                // Open price dialog
                                if (mounted) {
                                  _showUnrecognizedPriceDialogForSheet(trimmed, posProvider, () {
                                    // Callback when saved
                                    final addedItem = posProvider.invoiceItems.firstWhere(
                                      (item) => item['barcode'] == trimmed,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    final addedName = addedItem['name'] ?? trimmed;
                                    setSheetState(() {
                                      statusMessage = 'تمت إضافة: $addedName';
                                      statusColor = Colors.green;
                                      if (!sessionItems.contains(addedName)) {
                                        sessionItems.insert(0, addedName);
                                      }
                                    });
                                  });
                                }
                              }

                              // Auto clear status message after 1.5 seconds
                              Future.delayed(const Duration(milliseconds: 1500), () {
                                if (context.mounted) {
                                  setSheetState(() {
                                    if (statusMessage != 'جاري البحث عن الصنف...') {
                                      statusMessage = null;
                                    }
                                  });
                                }
                              });
                              break;
                            }
                          },
                        ),
                        // Scanner box
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: statusColor, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        
                        // Status Overlay Message (SnapMessage)
                        if (statusMessage != null)
                          Positioned(
                            top: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                statusMessage!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        // Scan Instructions
                        const Positioned(
                          bottom: 140,
                          child: Text('ضع الباركود في منتصف المربع للمسح التلقائي',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ),

                        // List of scanned items in this session
                        if (sessionItems.isNotEmpty)
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            height: 110,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'المنتجات المضافة في هذه الجلسة:',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: sessionItems.length,
                                      itemBuilder: (ctx, index) {
                                        return Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.teal[900]?.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.teal, width: 0.5),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            sessionItems[index],
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // Dispose scanner controller when bottom sheet is closed to release camera hardware resources
      scannerController.dispose();
      // Refresh screen when sheet is closed
      setState(() {});
    });
  }

  void _showUnrecognizedPriceDialogForSheet(String barcode, PosProvider posProvider, VoidCallback onSuccess) {
    final priceController = TextEditingController();
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'سعر البيع',
                  labelStyle: TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                ),
                textAlign: TextAlign.center,
                onFieldSubmitted: (_) {
                  _submitUnrecognizedProductForSheet(barcode, priceController.text, posProvider, ctx, onSuccess);
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
              onPressed: () => _submitUnrecognizedProductForSheet(barcode, priceController.text, posProvider, ctx, onSuccess),
              child: const Text('حفظ وإضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUnrecognizedProductForSheet(String barcode, String priceText, PosProvider posProvider, BuildContext dialogContext, VoidCallback onSuccess) async {
    final double? price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر', textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.pop(dialogContext);
    
    final product = await posProvider.quickAddUnrecognizedProduct(barcode, price);
    if (product != null) {
      onSuccess();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(posProvider.errorMessage ?? 'حدث خطأ في التسجيل', textAlign: TextAlign.right),
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
              content = const Center(
                child: Text(
                  'لا توجد منتجات نشطة حالياً',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              const String allLabel = 'الكل';
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
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        final double price = (prod['SalePrice'] as num?)?.toDouble() ?? 0.0;

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
                                  content: Text('تمت إضافة $name لسلة المشتريات', textAlign: TextAlign.right),
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
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${price.toStringAsFixed(2)} د.ك',
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
                      const Text(
                        'كتالوج المنتجات',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                            tooltip: 'تحديث المنتجات',
                            onPressed: () async {
                              setModalState(() {
                                _isLoadingProducts = true;
                              });
                              await _fetchAndProcessProducts(force: true);
                              setModalState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
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
    final bool success = await posProvider.searchAndAddProductByBarcode(trimmedBarcode);

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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'سعر البيع',
                  labelStyle: TextStyle(color: Colors.teal),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                ),
                textAlign: TextAlign.center,
                onFieldSubmitted: (_) {
                  // Submit on Enter key press
                  _submitUnrecognizedProduct(barcode, priceController.text, posProvider, ctx);
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
              onPressed: () => _submitUnrecognizedProduct(barcode, priceController.text, posProvider, ctx),
              child: const Text('حفظ وإضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUnrecognizedProduct(String barcode, String priceText, PosProvider posProvider, BuildContext dialogContext) async {
    final double? price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال سعر صحيح أكبر من الصفر', textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.pop(dialogContext);
    
    final product = await posProvider.quickAddUnrecognizedProduct(barcode, price);
    if (product != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الصنف وإضافته بنجاح', textAlign: TextAlign.right),
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
            content: Text(posProvider.errorMessage ?? 'حدث خطأ في التسجيل', textAlign: TextAlign.right),
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
        appBar: AppBar(
          title: Text(widget.type == 'Sales'
              ? (_selectedPartner != null
                  ? 'فاتورة مبيعات - ${_selectedPartner!['PartnerName']}'
                  : context.tr('pos_sales_title'))
              : (_selectedPartner != null
                  ? 'فاتورة مشتريات - ${_selectedPartner!['PartnerName']}'
                  : 'فاتورة مشتريات جديدة')),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.type == 'Sales'
                    ? [Colors.green, Colors.teal]
                    : [Colors.orange, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
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
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.grid_view, color: widget.type == 'Sales' ? Colors.teal : Colors.deepOrange, size: 30),
                          tooltip: 'عرض كتالوج المنتجات',
                          onPressed: () => _openProductCatalog(posProvider),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _barcodeController,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: context.tr('pos_barcode_input'),
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.search),
                            ),
                            onSubmitted: _addProductFromBarcode,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _selectedPartner != null
                              ? '${widget.type == 'Sales' ? 'العميل' : 'المورد'}: ${_selectedPartner!['PartnerName']}'
                              : '${widget.type == 'Sales' ? 'العميل' : 'المورد'}: نقدي (عام)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.person_search, color: widget.type == 'Sales' ? Colors.teal : Colors.deepOrange),
                          tooltip: widget.type == 'Sales' ? 'تغيير العميل' : 'تغيير المورد',
                          onPressed: () async {
                            final selected = await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PartnerSelectionScreen(type: widget.type, isSelectionOnly: true),
                              ),
                            );
                            if (selected != null) {
                              setState(() {
                                _selectedPartner = selected;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (posProvider.isLoading)
                    const LinearProgressIndicator(color: Colors.green),
                  Expanded(
                    child: invoiceItems.isEmpty
                        ? Center(
                            child: Text(context.tr('pos_empty_cart'),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                          )
                        : ListView.builder(
                            itemCount: invoiceItems.length,
                            itemBuilder: (context, index) {
                              final item = invoiceItems[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  title: Text(item['name'],
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                          '${context.tr('pos_item_price')}${item['price']} KWD${context.tr('pos_item_quantity')}',
                                          textAlign: TextAlign.right),
                                      _QuantityEditor(
                                        initialQuantity: item['quantity'],
                                        onChanged: (newQty) {
                                          posProvider.updateQuantity(
                                              index, newQty);
                                        },
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${item['total']} KWD',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green)),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        onPressed: () =>
                                            posProvider.removeItem(index),
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

  Future<void> _handlePaymentAndPrint(
      PosProvider posProvider, double total) async {
    // 1. Capture invoice elements BEFORE clearing provider state upon save
    final invoiceToPrint = {
      'type': widget.type,
      'created_at': DateTime.now().toIso8601String(),
      'total_amount': total,
      'paid_amount':  _isCash ? total : 0.0,
      'remainder':    _isCash ? 0.0 : total,
      'items': List<Map<String, dynamic>>.from(posProvider.invoiceItems),
      'temp_customer_name': widget.tempCustomerName,
      'temp_phone': widget.tempPhone,
      'temp_address': widget.tempAddress,
      'temp_delivery_date': widget.tempDeliveryDate,
      'temp_delivery_time': widget.tempDeliveryTime,
      'temp_notes': widget.tempNotes,
    };

    // 2. Perform save (either online or offline local persistence fallback)
    final newInvId = await posProvider.saveInvoice(
      widget.type, 
      paymentAccountId: _isCash ? _selectedAccountId : null, 
      partnerId: _selectedPartner?['PartnerID'],
      isCash: _isCash,
      tempCustomerName: widget.tempCustomerName,
      tempPhone: widget.tempPhone,
      tempAddress: widget.tempAddress,
      tempDeliveryDate: widget.tempDeliveryDate,
      tempDeliveryTime: widget.tempDeliveryTime,
      tempNotes: widget.tempNotes,
    );

    if (mounted) {
      if (newInvId != null) {
        // Add database-generated or local InvID to print invoice
        invoiceToPrint['InvID'] = newInvId;

        // 3. Trigger automatic receipt printing on thermal printer service
        final printerService =
            Provider.of<PrinterService>(context, listen: false);
        final printSuccess = await printerService.printReceipt(invoiceToPrint);

        if (mounted) {
          final isVirtual = printerService.connectionType == 'None';
          final showWarning = !printSuccess && !isVirtual;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                showWarning
                    ? context
                        .tr('pos_save_success_warn')
                        .replaceAll('{id}', newInvId.toString())
                    : context
                        .tr('pos_save_success_ok')
                        .replaceAll('{id}', newInvId.toString()),
                textAlign: TextAlign.right,
              ),
              backgroundColor: showWarning ? Colors.orange : Colors.green,
              action: SnackBarAction(
                label: printSuccess
                    ? context.tr('pos_print_status_printed')
                    : (isVirtual
                        ? context.tr('pos_print_status_virtual')
                        : context.tr('pos_print_status_failed')),
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              posProvider.errorMessage ?? context.tr('pos_save_failed'),
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCheckoutPanel(PosProvider posProvider, {bool isMobile = false}) {
    final double total = posProvider.totalAmount;
    final bool canPay = posProvider.invoiceItems.isNotEmpty;

    return Container(
      width: isMobile ? double.infinity : 300,
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('pos_total'),
              style: const TextStyle(fontSize: 20, color: Colors.grey),
              textAlign: TextAlign.right),
          Text('$total KWD',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
              textAlign: TextAlign.right),
          const SizedBox(height: 16),
          const Text(
            'نوع المعاملة',
            style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('آجل / ذمم', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: !_isCash,
                  selectedColor: Colors.orange[200],
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
                  label: const Text('نقدي / كاش', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _isCash,
                  selectedColor: Colors.green[200],
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
            const Text(
              'طريقة الدفع / الحساب',
              style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              dropdownColor: Colors.white,
              value: _selectedAccountId,
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
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedAccountId = val;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton.icon(
            onPressed: (!canPay || posProvider.isLoading)
                ? null
                : () => _handlePaymentAndPrint(posProvider, total),
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
                  : Text(widget.type == 'Sales' ? context.tr('pos_pay_print') : 'حفظ الفاتورة والطباعة',
                      style: const TextStyle(fontSize: 18)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.type == 'Sales' ? Colors.green : Colors.deepOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBottomBar(PosProvider posProvider) {
    final double total = posProvider.totalAmount;
    final bool hasItems = posProvider.invoiceItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, -2)),
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
                  Text(
                    'الإجمالي المستحق',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    '${total.toStringAsFixed(3)} KWD',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                'إنهاء الطلب',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.type == 'Sales' ? Colors.teal : Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
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

  Widget _buildCheckoutSheetContent(PosProvider posProvider, StateSetter setSheetState) {
    final double total = posProvider.totalAmount;
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
          Text(
            context.tr('pos_total'),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
          Text(
            '${total.toStringAsFixed(3)} KWD',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: widget.type == 'Sales' ? Colors.teal : Colors.deepOrange,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'نوع المعاملة',
            style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('آجل / ذمم', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Center(
                    child: Text('نقدي / كاش', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Text(
              'طريقة الدفع / الحساب',
              style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              dropdownColor: Colors.white,
              value: _selectedAccountId,
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
            const SizedBox(height: 20),
          ],
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
                      widget.type == 'Sales' ? context.tr('pos_pay_print') : 'حفظ الفاتورة والطباعة',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.type == 'Sales' ? Colors.green : Colors.deepOrange,
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
