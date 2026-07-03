import 'package:flutter/material.dart';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('مسح الباركود بالكاميرا', style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null && code.isNotEmpty) {
                    Navigator.pop(context);
                    widget.onBarcodeSubmitted(code);
                  }
                }
              },
            ),
          ),
        );
      },
    );
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
