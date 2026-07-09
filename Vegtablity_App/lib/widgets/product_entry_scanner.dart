import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';

class ProductEntryScanner extends StatefulWidget {
  final Function(String) onBarcodeSubmitted;
  final Function(Map<String, dynamic>) onProductSelected;

  const ProductEntryScanner({
    super.key,
    required this.onBarcodeSubmitted,
    required this.onProductSelected,
  });

  @override
  State<ProductEntryScanner> createState() => _ProductEntryScannerState();
}

class _ProductEntryScannerState extends State<ProductEntryScanner> {
  final TextEditingController _inputController = TextEditingController();

  void _openCameraScanner() {
    final Map<String, DateTime> lastScanned = {};
    String? statusMessage;
    Color statusColor = Colors.teal;
    List<String> sessionItems = [];

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
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          controller: MobileScannerController(
                            detectionSpeed: DetectionSpeed.normal,
                          ),
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

                              try {
                                final apiService = Provider.of<ApiService>(context, listen: false);
                                final response = await apiService.getProductByBarcode(trimmed);

                                if (response.statusCode == 200 && response.data != null) {
                                  final product = response.data;
                                  final String prodName = product['ProductName'] ?? product['name'] ?? trimmed;
                                  
                                  SystemSound.play(SystemSoundType.click);
                                  HapticFeedback.mediumImpact();

                                  widget.onBarcodeSubmitted(trimmed);

                                  setSheetState(() {
                                    statusMessage = 'تمت إضافة: $prodName';
                                    statusColor = Colors.green;
                                    if (!sessionItems.contains(prodName)) {
                                      sessionItems.insert(0, prodName);
                                    }
                                  });
                                } else {
                                  throw Exception();
                                }
                              } catch (_) {
                                // Product not found / unrecognized
                                SystemSound.play(SystemSoundType.click);
                                HapticFeedback.heavyImpact();

                                setSheetState(() {
                                  statusMessage = 'صنف غير معرف! يرجى إدخال السعر';
                                  statusColor = Colors.red;
                                });

                                if (mounted) {
                                  final apiService = Provider.of<ApiService>(context, listen: false);
                                  _showUnrecognizedPriceDialogForSheet(trimmed, apiService, () {
                                    // Callback when saved
                                    setSheetState(() {
                                      final addedName = 'صنف عام - $trimmed';
                                      statusMessage = 'تمت إضافة: $addedName';
                                      statusColor = Colors.green;
                                      if (!sessionItems.contains(addedName)) {
                                        sessionItems.insert(0, addedName);
                                      }
                                    });
                                    // Notify the parent component of barcode submission
                                    widget.onBarcodeSubmitted(trimmed);
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
    );
  }

  void _showUnrecognizedPriceDialogForSheet(String barcode, ApiService apiService, VoidCallback onSuccess) {
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
                  _submitUnrecognizedProductForSheet(barcode, priceController.text, apiService, ctx, onSuccess);
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
              onPressed: () => _submitUnrecognizedProductForSheet(barcode, priceController.text, apiService, ctx, onSuccess),
              child: const Text('حفظ وإضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUnrecognizedProductForSheet(String barcode, String priceText, ApiService apiService, BuildContext dialogContext, VoidCallback onSuccess) async {
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
    
    try {
      final payload = {
        'Barcode': barcode,
        'ProductName': 'صنف عام - $barcode',
        'SalePrice': price,
        'PurchasePrice': 0.0,
      };
      final response = await apiService.quickAddProduct(payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        onSuccess();
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الصنف', textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            onSelected: (product) {
              Navigator.pop(context);
              widget.onProductSelected(product);
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Barcode Text Field
          Expanded(
            child: TextField(
              controller: _inputController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: 'أدخل الباركود يدوياً أو الصنف',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  widget.onBarcodeSubmitted(value.trim());
                  _inputController.clear();
                }
              },
            ),
          ),
          
          // Camera Scanner Button
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.green),
            tooltip: 'مسح باركود',
            onPressed: _openCameraScanner,
          ),
          
          // Catalog Selection Button
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.green),
            tooltip: 'قائمة الأصناف',
            onPressed: _openCatalogBottomSheet,
          ),
        ],
      ),
    );
  }
}

class _CatalogSelector extends StatefulWidget {
  final ApiService apiService;
  final Function(Map<String, dynamic>) onSelected;

  const _CatalogSelector({
    required this.apiService,
    required this.onSelected,
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
      final response = await widget.apiService.getProducts();
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
          final name = (p['ProductName'] ?? '').toString().toLowerCase();
          final barcode = (p['Barcode'] ?? '').toString().toLowerCase();
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header
          const Text(
            'اختيار صنف من القائمة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          // Search Input
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث باسم الصنف أو الباركود...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: _filterProducts,
          ),
          const SizedBox(height: 12),
          
          // Products list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _filteredProducts.isEmpty
                    ? const Center(child: Text('لا توجد أصناف تطابق البحث'))
                    : ListView.builder(
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final prod = _filteredProducts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(prod['ProductName'] ?? 'صنف غير معروف', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'الباركود: ${prod['Barcode'] ?? 'لا يوجد'} | السعر: ${prod['SalePrice'] ?? 0.0} KWD',
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
