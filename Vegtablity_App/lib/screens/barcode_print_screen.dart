import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printer_service.dart';
import '../providers/settings_provider.dart';
import '../viewmodels/language_viewmodel.dart';
import '../viewmodels/barcode_print_viewmodel.dart';
import '../core/localization/app_localizations.dart';

class BarcodePrintScreen extends StatefulWidget {
  const BarcodePrintScreen({super.key});

  @override
  State<BarcodePrintScreen> createState() => _BarcodePrintScreenState();
}

class _BarcodePrintScreenState extends State<BarcodePrintScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<BarcodePrintViewModel>(context, listen: false);
      viewModel.loadProducts();
    });
  }

  void _showPrintDialog(Map<String, dynamic> product) {
    int copies = 1;
    final isArabic = Provider.of<LanguageViewModel>(context, listen: false).appLocale.languageCode == 'ar';
    final companySettings = Provider.of<SettingsProvider>(context, listen: false).companySettings;
    final companyName = companySettings?['CompanyName']?.toString().trim() ?? 'Vegtablity POS';
    final currencySymbol = Provider.of<SettingsProvider>(context, listen: false).currencySymbol;

    final productName = product['ProductName'] ?? product['product_name'] ?? product['name'] ?? '';
    final barcode = product['Barcode'] ?? product['barcode'] ?? '000000';
    final salePrice = double.tryParse(product['SalePrice']?.toString() ?? product['saleprice']?.toString() ?? '0') ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('barcode_preview_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 16),
                  // Live Barcode Label Preview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          companyName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          productName.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        // Barcode Visual Representation
                        Container(
                          height: 45,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              28,
                              (index) => Container(
                                margin: EdgeInsets.only(right: index % 3 == 0 ? 3 : 1),
                                width: (index % 4 == 0) ? 3 : (index % 2 == 0 ? 1.5 : 2),
                                height: 35,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          barcode.toString(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${salePrice.toStringAsFixed(3)} $currencySymbol',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Copies Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr('barcode_copies_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: copies > 1
                            ? () {
                                setModalState(() => copies--);
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 32),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          '$copies',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setModalState(() => copies++);
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Print Action Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(this.context);
                      final successMsg = context.tr('barcode_print_success');
                      final failMsg = context.tr('barcode_print_failed');
                      final printerService = Provider.of<PrinterService>(this.context, listen: false);
                      Navigator.pop(context);
                      final success = await printerService.printBarcodeLabel(
                        product,
                        copies: copies,
                        isArabic: isArabic,
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? successMsg : failMsg,
                              textAlign: TextAlign.right,
                            ),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.print, size: 24),
                    label: Text(
                      '${context.tr('barcode_print_button')} ($copies)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  String _getProductTypeName(int type, BuildContext context) {
    switch (type) {
      case 2:
        return context.tr('barcode_type_manufactured');
      case 3:
        return context.tr('barcode_type_intermediate');
      default:
        return context.tr('barcode_type_regular');
    }
  }

  Color _getProductTypeColor(int type) {
    switch (type) {
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = Provider.of<SettingsProvider>(context).currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('barcode_print_title')),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<BarcodePrintViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            children: [
              // Search & Filter Header Section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: viewModel.searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('barcode_search_hint'),
                        prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                        suffixIcon: viewModel.searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  viewModel.searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.indigo.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Category Filter Chips
                    if (viewModel.categories.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 6, right: 6),
                              child: ChoiceChip(
                                label: Text(context.tr('barcode_category_all')),
                                selected: viewModel.selectedCategory == 'ALL',
                                selectedColor: Colors.indigo,
                                labelStyle: TextStyle(
                                  color: viewModel.selectedCategory == 'ALL' ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    viewModel.setSelectedCategory('ALL');
                                  }
                                },
                              ),
                            ),
                            ...viewModel.categories.map((cat) {
                              final isSelected = viewModel.selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6, right: 6),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: Colors.indigo,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      viewModel.setSelectedCategory(cat);
                                    }
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Product List / Grid Content
              Expanded(
                child: viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                    : viewModel.errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text(
                                    viewModel.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () => viewModel.loadProducts(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة المحاولة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : viewModel.filteredProducts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.tr('pos_empty_cart'),
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.95,
                                  ),
                                  itemCount: viewModel.filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = viewModel.filteredProducts[index];
                                    final productName = product['ProductName'] ?? product['product_name'] ?? product['name'] ?? '';
                                    final barcode = product['Barcode'] ?? product['barcode'] ?? 'N/A';
                                    final salePrice = double.tryParse(product['SalePrice']?.toString() ?? product['saleprice']?.toString() ?? '0') ?? 0.0;
                                    final productType = int.tryParse(product['ProductType']?.toString() ?? '1') ?? 1;

                                    return InkWell(
                                      onTap: () => _showPrintDialog(product),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Card(
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Product Type Badge Header
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Flexible(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: _getProductTypeColor(productType).withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          _getProductTypeName(productType, context),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: _getProductTypeColor(productType),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.print_outlined, color: Colors.indigo, size: 18),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Product Name & Barcode
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      productName.toString(),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.2),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.qr_code, size: 13, color: Colors.grey),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            barcode.toString(),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Sale Price
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '${salePrice.toStringAsFixed(3)} $currencySymbol',
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
                                                ),
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
        },
      ),
    );
  }
}
