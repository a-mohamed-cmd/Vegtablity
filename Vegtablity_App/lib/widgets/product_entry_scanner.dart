import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../providers/recipe_provider.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

enum CatalogSearchMode {
  ingredients,    // مواد الوصفات (0, 1, 3) - sp_Product_GetForRecipeIngredients - "اختيار المواد من القائمة"
  targetProducts, // أصناف هدف الوصفة (2, 3) - sp_Product_GetForRecipeTarget(includeAll: true) - "اختيار منتج من القائمة"
  purchase,       // مشتريات (0, 1) - sp_Product_GetForPurchase - "كتالوج مواد المشتريات"
  sales,          // مبيعات (2) - sp_Product_GetForSales - "كتالوج منتجات المبيعات"
}

class ProductEntryScanner extends StatefulWidget {
  final Function(String) onBarcodeSubmitted;
  final Function(Map<String, dynamic>) onProductSelected;
  final CatalogSearchMode searchMode;

  const ProductEntryScanner({
    super.key,
    required this.onBarcodeSubmitted,
    required this.onProductSelected,
    this.searchMode = CatalogSearchMode.ingredients,
  });

  @override
  State<ProductEntryScanner> createState() => _ProductEntryScannerState();
}

class _ProductEntryScannerState extends State<ProductEntryScanner> {
  late MobileScannerController _scannerController;
  final Map<String, DateTime> _lastScanned = {};
  String? _statusMessage;
  Color _statusColor = Colors.teal;
  final List<String> _sessionItems = [];
  bool _isTorchOn = false;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isDialogShowing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String code = barcode.rawValue ?? '';
      final String trimmed = code.trim();
      if (trimmed.isEmpty) continue;

      // Debounce: prevent duplicate scan within 2 seconds
      final now = DateTime.now();
      if (_lastScanned.containsKey(trimmed) &&
          now.difference(_lastScanned[trimmed]!).inSeconds < 2) {
        continue;
      }
      _lastScanned[trimmed] = now;

      setState(() {
        _statusMessage = 'جاري البحث عن الصنف...';
        _statusColor = Colors.orange;
      });

      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.getProductByBarcode(trimmed);

        if (response.statusCode == 200 && response.data != null) {
          final product = response.data;
          final String prodName = product['ProductName'] ?? product['name'] ?? trimmed;

          SystemSound.play(SystemSoundType.click);
          HapticFeedback.mediumImpact();

          widget.onBarcodeSubmitted(trimmed);

          setState(() {
            _statusMessage = 'تمت إضافة: $prodName';
            _statusColor = Colors.green;
            if (!_sessionItems.contains(prodName)) {
              _sessionItems.insert(0, prodName);
            }
          });
        } else {
          throw Exception('Product not found');
        }
      } catch (_) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.heavyImpact();

        final apiService = Provider.of<ApiService>(context, listen: false);
        final int defaultType = (widget.searchMode == CatalogSearchMode.ingredients || widget.searchMode == CatalogSearchMode.purchase)
            ? 0
            : 2;
        _showQuickAddDialog(trimmed, apiService, defaultProductType: defaultType);
      }

      // Auto clear status message after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            if (_statusMessage != 'جاري البحث عن الصنف...') {
              _statusMessage = null;
            }
          });
        }
      });
      break;
    }
  }

  String _generateUniqueBarcode(List<dynamic> existingProducts) {
    final Set<String> existingBarcodes = existingProducts
        .map((p) => (p['Barcode'] ?? p['barcode'] ?? '').toString().trim())
        .where((b) => b.isNotEmpty)
        .toSet();

    final random = Random();
    String code;
    do {
      final numStr = (10000000 + random.nextInt(89999999)).toString();
      code = '29$numStr';
    } while (existingBarcodes.contains(code));

    return code;
  }

  void _showQuickAddDialog(String scannedBarcode, ApiService apiService, {int defaultProductType = 0}) {
    _isDialogShowing = true;
    final bool isManualEntry = scannedBarcode.trim().isEmpty;

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final String initialBarcode = isManualEntry
        ? _generateUniqueBarcode(recipeProvider.targetProducts)
        : scannedBarcode.trim();

    final barcodeController = TextEditingController(text: initialBarcode);
    final nameController = TextEditingController(text: !isManualEntry ? 'صنف - $scannedBarcode' : '');
    final purchasePriceController = TextEditingController(text: '0.00');
    final salePriceController = TextEditingController(text: '0.00');
    int selectedProductType = defaultProductType;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text(
                    'إضافة صنف جديد (حفظ سريع)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isManualEntry)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'رمز الباركود الممسوح: $scannedBarcode',
                          style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      )
                    else ...[
                      TextFormField(
                        controller: barcodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'رمز الباركود (يدوي / تلقائي فريد) *',
                          labelStyle: const TextStyle(color: Colors.teal),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.autorenew, color: Colors.amberAccent),
                            tooltip: 'توليد باركود فريد جديد',
                            onPressed: () {
                              barcodeController.text = _generateUniqueBarcode(recipeProvider.targetProducts);
                            },
                          ),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Product Type Selector
                    const Text('تصنيف المنتج:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedProductType,
                          dropdownColor: Colors.grey[850],
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          items: () {
                            if (widget.searchMode == CatalogSearchMode.purchase) {
                              return const [
                                DropdownMenuItem(value: 0, child: Text('🌾 مادة أولية (خام)')),
                                DropdownMenuItem(value: 1, child: Text('📦 مادة عادية (صنف قياسي)')),
                              ];
                            } else if (widget.searchMode == CatalogSearchMode.sales) {
                              return const [
                                DropdownMenuItem(value: 1, child: Text('📦 مادة عادية (صنف قياسي)')),
                                DropdownMenuItem(value: 2, child: Text('🏭 منتج مصنع (نهائي)')),
                              ];
                            } else if (widget.searchMode == CatalogSearchMode.ingredients) {
                              return const [
                                DropdownMenuItem(value: 0, child: Text('🌾 مادة أولية (خام)')),
                                DropdownMenuItem(value: 1, child: Text('📦 مادة عادية (صنف قياسي)')),
                                DropdownMenuItem(value: 3, child: Text('⚙️ مادة مؤقتة (وسيطة)')),
                              ];
                            } else {
                              return const [
                                DropdownMenuItem(value: 2, child: Text('🏭 منتج مصنع (نهائي)')),
                                DropdownMenuItem(value: 3, child: Text('⚙️ منتج وسيط (نصف تصنيع)')),
                              ];
                            }
                          }(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedProductType = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name field
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'اسم الصنف / المادة *',
                        labelStyle: TextStyle(color: Colors.teal),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Purchase Cost field
                    TextFormField(
                      controller: purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'سعر التكلفة (الشراء)',
                        labelStyle: TextStyle(color: Colors.teal),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Sale Price field
                    TextFormField(
                      controller: salePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'سعر البيع (إن وجد)',
                        labelStyle: TextStyle(color: Colors.teal),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isDialogShowing = false;
                  },
                  child: const Text('إلغاء', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
                  icon: const Icon(Icons.bolt, color: Colors.white),
                  label: const Text('حفظ سريـع ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final String name = nameController.text.trim();
                    final String targetBarcode = isManualEntry
                        ? (barcodeController.text.trim().isNotEmpty
                            ? barcodeController.text.trim()
                            : _generateUniqueBarcode(recipeProvider.targetProducts))
                        : scannedBarcode.trim();

                    final double purchasePrice = double.tryParse(purchasePriceController.text.trim()) ?? 0.0;
                    final double salePrice = double.tryParse(salePriceController.text.trim()) ?? 0.0;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال اسم الصنف'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    _isDialogShowing = false;

                    try {
                      final payload = {
                        'Barcode': targetBarcode,
                        'ProductName': name,
                        'PurchasePrice': purchasePrice,
                        'SalePrice': salePrice,
                        'ProductType': selectedProductType,
                      };

                      final resp = await apiService.quickAddProduct(payload);
                      if (resp.statusCode == 200 || resp.statusCode == 201) {
                        final int newProdId = (resp.data != null && resp.data['ProductID'] != null)
                            ? (resp.data['ProductID'] as num).toInt()
                            : 0;

                        try {
                          await recipeProvider.loadRecipeIngredients();
                          await recipeProvider.loadTargetProducts();
                        } catch (_) {}

                        if (widget.searchMode == CatalogSearchMode.targetProducts && newProdId > 0) {
                          if (mounted) {
                            Navigator.pop(context); // Close bottom sheet camera modal
                          }
                          widget.onProductSelected({
                            'ProductID': newProdId,
                            'ProductName': name,
                            'Barcode': targetBarcode,
                          });
                          return;
                        }

                        if (targetBarcode.isNotEmpty) {
                          widget.onBarcodeSubmitted(targetBarcode);
                        }

                        setState(() {
                          _statusMessage = '✅ تم الحفظ السريع: $name';
                          _statusColor = Colors.green;
                          if (!_sessionItems.contains(name)) {
                            _sessionItems.insert(0, name);
                          }
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ أثناء الحفظ السريع: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _openCatalogBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: _CatalogSelector(
            apiService: apiService,
            searchMode: widget.searchMode,
            onSelected: (product) {
              Navigator.pop(context);
              widget.onProductSelected(product);
            },
            onQuickAddRequested: (barcode) {
              final int defaultType = (widget.searchMode == CatalogSearchMode.ingredients || widget.searchMode == CatalogSearchMode.purchase)
                  ? 0
                  : 2;
              _showQuickAddDialog(barcode, apiService, defaultProductType: defaultType);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle = () {
      switch (widget.searchMode) {
        case CatalogSearchMode.ingredients:
          return 'مسح باركود المواد الخام 📷';
        case CatalogSearchMode.targetProducts:
          return 'مسح باركود المنتجات 📷';
        case CatalogSearchMode.purchase:
          return 'مسح باركود المشتريات 📷';
        case CatalogSearchMode.sales:
          return 'مسح باركود المبيعات 📷';
      }
    }();

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header Bar
          AppBar(
            title: Text(appBarTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            backgroundColor: Colors.grey[900],
            elevation: 0,
            leading: IconButton(
              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.amberAccent),
              tooltip: 'الفلاش',
              onPressed: () {
                _scannerController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.list_alt, color: Colors.greenAccent),
                tooltip: 'قائمة الكتالوج',
                onPressed: _openCatalogBottomSheet,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // Main Camera Scanner View
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),

                // Viewfinder Box Overlay
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: _statusColor, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                // Status Message Overlay
                if (_statusMessage != null)
                  Positioned(
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Scanned Session Items List
                if (_sessionItems.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 65,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المواد المضافة في الجلسة الحالية:',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _sessionItems.length,
                              itemBuilder: (ctx, index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[900]?.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.teal, width: 0.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _sessionItems[index],
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
  }
}

class _CatalogSelector extends StatefulWidget {
  final ApiService apiService;
  final Function(Map<String, dynamic>) onSelected;
  final Function(String)? onQuickAddRequested;
  final CatalogSearchMode searchMode;

  const _CatalogSelector({
    required this.apiService,
    required this.onSelected,
    this.onQuickAddRequested,
    this.searchMode = CatalogSearchMode.ingredients,
  });

  @override
  State<_CatalogSelector> createState() => _CatalogSelectorState();
}

class _CatalogSelectorState extends State<_CatalogSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final Response response;
      switch (widget.searchMode) {
        case CatalogSearchMode.ingredients:
          response = await widget.apiService.getProductsForRecipeIngredients();
          break;
        case CatalogSearchMode.targetProducts:
          response = await widget.apiService.getProductsForRecipeTarget(includeAll: true);
          break;
        case CatalogSearchMode.purchase:
          response = await widget.apiService.getProductsForPurchase();
          break;
        case CatalogSearchMode.sales:
          response = await widget.apiService.getProductsForSales();
          break;
      }

      if (response.statusCode == 200) {
        setState(() {
          _allProducts = List<Map<String, dynamic>>.from(response.data);
          _filteredProducts = _allProducts;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((p) {
          final name = (p['ProductName'] ?? p['name'] ?? '').toString().toLowerCase();
          final barcode = (p['Barcode'] ?? p['barcode'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || barcode.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String listTitle = () {
      switch (widget.searchMode) {
        case CatalogSearchMode.ingredients:
          return 'اختيار المواد من القائمة';
        case CatalogSearchMode.targetProducts:
          return 'اختيار منتج من القائمة';
        case CatalogSearchMode.purchase:
          return 'كتالوج مواد المشتريات (أولية وعادية)';
        case CatalogSearchMode.sales:
          return 'كتالوج منتجات المبيعات (منتجات مصنعة)';
      }
    }();

    final String hintText = () {
      switch (widget.searchMode) {
        case CatalogSearchMode.ingredients:
          return 'ابحث باسم المادة الخام أو الباركود...';
        case CatalogSearchMode.targetProducts:
          return 'ابحث باسم المنتج أو الباركود...';
        case CatalogSearchMode.purchase:
          return 'ابحث باسم المادة أو الباركود...';
        case CatalogSearchMode.sales:
          return 'ابحث باسم المنتج أو الباركود...';
      }
    }();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  listTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'إضافة صنف جديد بالسريع ⚡',
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onQuickAddRequested != null) {
                    widget.onQuickAddRequested!('');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: _filterProducts,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _filteredProducts.isEmpty
                    ? const Center(child: Text('لا توجد عناصر تطابق البحث'))
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final prod = _filteredProducts[index];
                          final String name = prod['ProductName'] ?? prod['name'] ?? 'عنصر غير معروف';
                          final String barcode = prod['Barcode'] ?? prod['barcode'] ?? 'لا يوجد';
                          final double price = (prod['PurchasePrice'] as num?)?.toDouble() ?? (prod['SalePrice'] as num?)?.toDouble() ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(name,
                                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'الباركود: $barcode | التكلفة/السعر: $price',
                                textAlign: TextAlign.right,
                              ),
                              trailing: const Icon(Icons.add_shopping_cart, color: Colors.green),
                              onTap: () => widget.onSelected(prod),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
