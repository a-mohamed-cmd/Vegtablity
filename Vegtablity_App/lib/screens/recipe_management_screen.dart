import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../models/recipe_model.dart';
import '../services/printer_service.dart';
import '../services/receipt_designer.dart';
import '../services/api_service.dart';
import '../widgets/product_entry_scanner.dart';
import 'add_recipe_screen.dart';

class RecipeManagementScreen extends StatefulWidget {
  const RecipeManagementScreen({Key? key}) : super(key: key);

  @override
  State<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  int? _activeWarehouseId;
  String? _activeWarehouseName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveWarehouseAndData();
    });
  }

  Future<void> _loadActiveWarehouseAndData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeWarehouseId = prefs.getInt('selected_warehouse_id');
      _activeWarehouseName = prefs.getString('selected_warehouse_name');
    });

    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    await recipeProvider.fetchAllRecipes();
    await recipeProvider.loadTargetProducts(warehouseId: _activeWarehouseId);
    await recipeProvider.loadRecipeIngredients(warehouseId: _activeWarehouseId);
  }

  void _openCameraScanner(BuildContext context, Function(String) onBarcodeScanned) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: ProductEntryScanner(
          searchMode: CatalogSearchMode.targetProducts,
          onBarcodeSubmitted: onBarcodeScanned,
          onProductSelected: (prod) {
            final int prodID = prod['ProductID'] ?? prod['product_id'] ?? 0;
            final String prodName = prod['ProductName'] ?? prod['name'] ?? '';

            if (prodID > 0) {
              Navigator.pop(context); // Close bottom sheet modal

              final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
              final recipeMatch = recipeProvider.recipes.firstWhere(
                (r) => r.productID == prodID,
                orElse: () => RecipeHeader(
                  recipeID: 0,
                  productID: 0,
                  productName: '',
                  ingredientsCount: 0,
                  totalCost: 0,
                ),
              );

              if (recipeMatch.productID > 0) {
                _navigateToCreateRecipe(prodID, prodName);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('المنتج ($prodName) ليس له وصفة مسجلة بعد، يمكنك إعداد الوصفة الآن 👌'),
                    backgroundColor: Colors.teal,
                    duration: const Duration(seconds: 3),
                  ),
                );
                _navigateToCreateRecipe(prodID, prodName);
              }
            } else {
              final String code = prod['Barcode'] ?? prod['barcode'] ?? '';
              if (code.isNotEmpty) {
                onBarcodeScanned(code);
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _navigateToCreateRecipe([int? initialProductID, String? initialProductName]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecipeScreen(
          initialProductID: initialProductID,
          initialProductName: initialProductName,
        ),
      ),
    );
    if (result == true) {
      _loadActiveWarehouseAndData();
    }
  }

  void _openBarcodeSearchScanner(BuildContext context) {
    _openCameraScanner(context, (scannedCode) async {
      final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final String trimmed = scannedCode.trim();
      if (trimmed.isEmpty) return;

      // 1. Search in existing loaded recipes list (Manufactured/Semi-Finished only)
      final recipeMatch = recipeProvider.recipes.firstWhere(
        (r) => r.barcode == trimmed || (r.barcode != null && r.barcode!.trim() == trimmed),
        orElse: () => RecipeHeader(
          recipeID: 0,
          productID: 0,
          productName: '',
          ingredientsCount: 0,
          totalCost: 0,
        ),
      );

      if (recipeMatch.productID > 0) {
        Navigator.pop(context); // Close camera sheet
        _navigateToCreateRecipe(recipeMatch.productID, recipeMatch.productName);
        return;
      }

      // 2. Fetch product by barcode via API
      try {
        final response = await apiService.getProductByBarcode(trimmed);
        if (response.statusCode == 200 && response.data != null) {
          final int prodID = response.data['ProductID'] ?? response.data['product_id'] ?? 0;
          final String prodName = response.data['ProductName'] ?? response.data['name'] ?? '';
          final int prodType = (response.data['ProductType'] as num?)?.toInt() ?? 1;

          // Check if product is Manufactured (2) or Semi-Finished (3)
          if (prodID > 0 && (prodType == 2 || prodType == 3)) {
            Navigator.pop(context); // Close camera sheet

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('المنتج ($prodName) ليس له وصفة مسجلة بعد، يمكنك إعداد الوصفة الآن 👌'),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 3),
              ),
            );

            _navigateToCreateRecipe(prodID, prodName);
            return;
          }
        }
      } catch (_) {}

      // 3. Product not found in DB at all: Prompt for quick add with ProductType selector (Manufactured / Semi-finished)
      Navigator.pop(context);
      _showQuickAddForRecipeTargetDialog(trimmed, apiService);
    });
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

  void _showQuickAddForRecipeTargetDialog(String scannedBarcode, ApiService apiService) {
    final bool isManualEntry = scannedBarcode.trim().isEmpty;
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);

    final String initialBarcode = isManualEntry
        ? _generateUniqueBarcode(recipeProvider.targetProducts)
        : scannedBarcode.trim();

    final barcodeController = TextEditingController(text: initialBarcode);
    final nameController = TextEditingController(text: !isManualEntry ? 'منتج مصنع - $scannedBarcode' : '');
    final purchasePriceController = TextEditingController(text: '0.00');
    final salePriceController = TextEditingController(text: '0.00');
    int selectedProductType = 2; // Default to Manufactured Product

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
                  Icon(Icons.add_business, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text(
                    'إضافة منتج جديد (حفظ سريع)',
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

                    const Text('تصنيف المنتج المستهدف:', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                          items: const [
                            DropdownMenuItem(value: 2, child: Text('🏭 منتج مصنع (نهائي)')),
                            DropdownMenuItem(value: 3, child: Text('⚙️ منتج وسيط (نصف تصنيع)')),
                          ],
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

                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'اسم المنتج *',
                        labelStyle: TextStyle(color: Colors.teal),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'سعر التكلفة المبدئي',
                        labelStyle: TextStyle(color: Colors.teal),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: salePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'سعر البيع',
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
                  icon: const Icon(Icons.bolt, color: Colors.white),
                  label: const Text('حفظ وفتح الوصفة ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        const SnackBar(content: Text('يرجى إدخال اسم المنتج'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

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
                        await _loadActiveWarehouseAndData();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ تم حفظ المنتج ($name) نجاح 👌'), backgroundColor: Colors.green),
                          );
                        }

                        if (newProdId > 0 && mounted) {
                          _navigateToCreateRecipe(newProdId, name);
                        }
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('إدارة وصفات المنتجات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (_activeWarehouseName != null && _activeWarehouseName!.isNotEmpty)
              Text(
                'المستودع النشط: $_activeWarehouseName',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF2C3E50),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.amberAccent),
            tooltip: 'مسح باركود لبحث الوصفات المسجلة',
            onPressed: () => _openBarcodeSearchScanner(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: _loadActiveWarehouseAndData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateRecipe(),
        backgroundColor: const Color(0xFF2ECC71),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة وصفة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: recipeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : recipeProvider.recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد وصفات منتجات مسجلة',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToCreateRecipe(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة وصفة جديدة الآن'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                        ),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: recipeProvider.recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipeProvider.recipes[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF2ECC71),
                          child: Icon(Icons.restaurant_menu, color: Colors.white),
                        ),
                        title: Text(
                          recipe.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          'عدد المكونات: ${recipe.ingredientsCount} | ${recipe.notes ?? ""}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${recipe.totalCost.toStringAsFixed(2)} د.أ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.print, color: Color(0xFF2980B9)),
                              tooltip: 'طباعة الإيصال الحراري للوصفة',
                              onPressed: () {
                                _printRecipeReceipt(context, recipe);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          _navigateToCreateRecipe(recipe.productID, recipe.productName);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _printRecipeReceipt(BuildContext context, RecipeHeader recipe) async {
    final recipeProvider = Provider.of<RecipeProvider>(context, listen: false);
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    RecipeHeader current = recipe;
    if (recipe.details.isEmpty) {
      await recipeProvider.fetchRecipeByProduct(recipe.productID, warehouseId: _activeWarehouseId);
      if (recipeProvider.currentRecipe != null) {
        current = recipeProvider.currentRecipe!;
      }
    }

    try {
      final Map<String, dynamic> recipeMap = {
        'ProductName': current.productName,
        'WarehouseName': _activeWarehouseName ?? '',
        'Notes': current.notes ?? '',
        'TotalCost': current.totalCost,
        'Details': current.details.map((d) => {
          'IngredientBarcode': d.ingredientBarcode,
          'IngredientName': d.ingredientName,
          'UnitName': d.unitName,
          'Qty': d.qty,
          'UnitCost': d.unitCost,
          'LineCost': d.lineCost,
        }).toList(),
      };

      final bool success = await printerService.printRecipe(
        recipeMap,
        companySettings: settingsProvider.companySettings ?? printerService.companySettings,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال بطاقة الوصفة للطابعة الحرارية بنجاح 👌'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشلت طباعة الوصفة، يرجى التحقق من إعدادات الطابعة'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
