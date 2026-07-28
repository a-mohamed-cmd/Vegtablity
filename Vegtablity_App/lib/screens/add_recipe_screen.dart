import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/recipe_provider.dart';
import '../providers/settings_provider.dart';
import '../services/printer_service.dart';
import '../services/receipt_designer.dart';
import '../widgets/product_entry_scanner.dart';

class AddRecipeScreen extends StatefulWidget {
  final int? initialProductID;
  final String? initialProductName;

  const AddRecipeScreen({
    Key? key,
    this.initialProductID,
    this.initialProductName,
  }) : super(key: key);

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  int? _selectedProductID;
  final TextEditingController _notesController = TextEditingController();

  int? _activeWarehouseId;
  String? _activeWarehouseName;

  final List<Map<String, dynamic>> _ingredientItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProductID = widget.initialProductID;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var item in _ingredientItems) {
      if (item['QtyController'] is TextEditingController) {
        (item['QtyController'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeWarehouseId = prefs.getInt('selected_warehouse_id');
      _activeWarehouseName = prefs.getString('selected_warehouse_name');
    });

    final provider = Provider.of<RecipeProvider>(context, listen: false);
    await provider.loadTargetProducts(warehouseId: _activeWarehouseId);
    await provider.loadRecipeIngredients(warehouseId: _activeWarehouseId);

    if (_selectedProductID != null && _selectedProductID! > 0) {
      await provider.fetchRecipeByProduct(_selectedProductID!, warehouseId: _activeWarehouseId);
      final current = provider.currentRecipe;
      if (current != null && mounted) {
        setState(() {
          _notesController.text = current.notes ?? '';
          _ingredientItems.clear();
          for (var detail in current.details) {
            final qtyCtrl = TextEditingController(text: detail.qty.toString());
            _ingredientItems.add({
              'IngredientProductID': detail.ingredientProductID,
              'IngredientName': detail.ingredientName,
              'IngredientBarcode': detail.ingredientBarcode ?? '',
              'UnitName': detail.unitName ?? '',
              'UnitCost': detail.unitCost,
              'Qty': detail.qty,
              'QtyController': qtyCtrl,
            });
          }
        });
      }
    }
  }

  double get _totalRecipeCost {
    double total = 0.0;
    for (var item in _ingredientItems) {
      final double qty = (item['Qty'] as num?)?.toDouble() ?? 0.0;
      final double unitCost = (item['UnitCost'] as num?)?.toDouble() ?? 0.0;
      total += (qty * unitCost);
    }
    return total;
  }

  void _addIngredient(Map<String, dynamic> prod) {
    final int prodId = prod['ProductID'] ?? prod['product_id'] ?? 0;
    if (prodId <= 0) return;

    final existingIdx = _ingredientItems.indexWhere((i) => i['IngredientProductID'] == prodId);
    if (existingIdx != -1) {
      setState(() {
        final currentQty = (_ingredientItems[existingIdx]['Qty'] as num).toDouble();
        final newQty = currentQty + 1.0;
        _ingredientItems[existingIdx]['Qty'] = newQty;
        (_ingredientItems[existingIdx]['QtyController'] as TextEditingController).text = newQty.toString();
      });
    } else {
      final double cost = (prod['PurchasePrice'] as num?)?.toDouble() ?? (prod['AvgCostPrice'] as num?)?.toDouble() ?? 0.0;
      final qtyCtrl = TextEditingController(text: '1.0');

      setState(() {
        _ingredientItems.add({
          'IngredientProductID': prodId,
          'IngredientName': prod['ProductName'] ?? prod['name'] ?? 'مادة خام',
          'IngredientBarcode': prod['Barcode'] ?? prod['barcode'] ?? '',
          'UnitName': prod['UnitName'] ?? prod['unit_name'] ?? prod['unit'] ?? '',
          'UnitCost': cost,
          'Qty': 1.0,
          'QtyController': qtyCtrl,
        });
      });
    }
  }

  void _openCameraScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: ProductEntryScanner(
          searchMode: CatalogSearchMode.ingredients,
          onBarcodeSubmitted: (barcode) => _matchBarcodeAndAdd(barcode),
          onProductSelected: (prod) {
            _addIngredient(prod);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تمت إضافة: ${prod['ProductName'] ?? prod['name']}'),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }

  void _matchBarcodeAndAdd(String barcode) {
    final provider = Provider.of<RecipeProvider>(context, listen: false);
    final String trimmed = barcode.trim();
    if (trimmed.isEmpty) return;

    final match = provider.ingredientProducts.firstWhere(
      (p) => (p['Barcode']?.toString() == trimmed || p['barcode']?.toString() == trimmed),
      orElse: () => null,
    );

    if (match != null) {
      _addIngredient(match);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة: ${match['ProductName'] ?? match['name']}'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم العثور على مادة خام بالباركود: $trimmed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _handleSave({bool printReceipt = false}) async {
    if (_selectedProductID == null || _selectedProductID! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المنتج المصنع أولاً'), backgroundColor: Colors.red),
      );
      return;
    }

    final cleanDetails = _ingredientItems.map((item) => {
      'IngredientProductID': item['IngredientProductID'],
      'Qty': (item['Qty'] as num).toDouble(),
      'Cost': (item['UnitCost'] as num).toDouble(),
    }).where((item) => (item['IngredientProductID'] as int) > 0 && (item['Qty'] as double) > 0).toList();

    if (cleanDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة مادة خام واحدة على الأقل بالوصفة'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final provider = Provider.of<RecipeProvider>(context, listen: false);
    final bool success = await provider.saveRecipe(
      _selectedProductID!,
      _notesController.text.trim(),
      cleanDetails,
      warehouseId: _activeWarehouseId,
    );

    setState(() {
      _isSaving = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الوصفة وتحديث التكاليف بنجاح 👌'), backgroundColor: Colors.green),
        );
      }

      if (printReceipt) {
        final targetProd = provider.targetProducts.firstWhere(
          (p) => p['ProductID'] == _selectedProductID,
          orElse: () => {'ProductName': widget.initialProductName ?? 'منتج مصنع'},
        );

        final Map<String, dynamic> recipeMap = {
          'ProductName': targetProd['ProductName'] ?? targetProd['name'] ?? widget.initialProductName ?? 'منتج مصنع',
          'WarehouseName': _activeWarehouseName ?? '',
          'Notes': _notesController.text.trim(),
          'TotalCost': _totalRecipeCost,
          'Details': _ingredientItems.map((item) => {
            'IngredientBarcode': item['IngredientBarcode'],
            'IngredientName': item['IngredientName'],
            'UnitName': item['UnitName'],
            'Qty': item['Qty'],
            'UnitCost': item['UnitCost'],
            'LineCost': (item['Qty'] as double) * (item['UnitCost'] as double),
          }).toList(),
        };

        try {
          final printerService = Provider.of<PrinterService>(context, listen: false);
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
          await printerService.printRecipe(
            recipeMap,
            companySettings: settingsProvider.companySettings ?? printerService.companySettings,
          );
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'فشل حفظ الوصفة'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecipeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              _selectedProductID != null ? 'إعداد / تعديل وصفة منتج' : 'إضافة وصفة جديدة',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_activeWarehouseName != null && _activeWarehouseName!.isNotEmpty)
              Text(
                'المستودع النشط: $_activeWarehouseName',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF2C3E50),
        centerTitle: true,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // 1. Target Product Selection Dropdown (ComboBox)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.teal[50],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Colors.teal, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                hint: const Text(
                                  'اختر المنتج المصنع أو الوسيط المطلوب *',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15),
                                ),
                                value: _selectedProductID,
                                items: () {
                                  final itemsList = provider.targetProducts.map<DropdownMenuItem<int>>((prod) {
                                    final int id = prod['ProductID'] ?? prod['product_id'];
                                    final String name = prod['ProductName'] ?? prod['name'] ?? '';
                                    final String barcode = prod['Barcode'] ?? prod['barcode'] ?? '';
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text('$name ${barcode.isNotEmpty ? "($barcode)" : ""}',
                                          style: const TextStyle(fontWeight: FontWeight.bold)),
                                    );
                                  }).toList();

                                  if (_selectedProductID != null &&
                                      !itemsList.any((item) => item.value == _selectedProductID)) {
                                    final current = provider.currentRecipe;
                                    final name = widget.initialProductName ?? current?.productName ?? 'منتج #$_selectedProductID';
                                    itemsList.insert(
                                      0,
                                      DropdownMenuItem<int>(
                                        value: _selectedProductID,
                                        child: Text('$name (الوصفة المسجلة)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                      ),
                                    );
                                  }
                                  return itemsList;
                                }(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedProductID = val;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. Notes Field
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'ملاحظات وتوجيهات الوصفة (اختياري)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.note, color: Colors.teal),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Prominent Camera Scanner & Ingredient Management Bar
                  Card(
                    elevation: 2,
                    color: const Color(0xFF2C3E50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openCameraScanner,
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.amberAccent, size: 24),
                              label: const Text(
                                'مسح باركود وتصفح المواد الخام بالكاميرا 📷',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[700],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. Ingredients List Header & Live Summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'مكونات الوصفة (${_ingredientItems.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          'الإجمالي: ${_totalRecipeCost.toStringAsFixed(2)} د.أ',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 5. Ingredients List Items
                  Expanded(
                    child: _ingredientItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text(
                                  'لم يتم إضافة مكونات بعد.\nاضغط على زر الكاميرا أعلاه للبدء في مسح الباركود وتصفح المواد الخام.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _ingredientItems.length,
                            itemBuilder: (context, index) {
                              final item = _ingredientItems[index];
                              final double qty = (item['Qty'] as num).toDouble();
                              final double unitCost = (item['UnitCost'] as num).toDouble();
                              final double lineCost = qty * unitCost;

                              return Card(
                                elevation: 1.5,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['IngredientName'],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'التكلفة: ${unitCost.toStringAsFixed(2)} / ${item['UnitName']}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Quantity input
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: item['QtyController'] as TextEditingController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              item['Qty'] = double.tryParse(val) ?? 0.0;
                                            });
                                          },
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '${lineCost.toStringAsFixed(2)} د.أ',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                      ),

                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () {
                                          setState(() {
                                            _ingredientItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // 6. Action Buttons Footer
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleSave(printReceipt: false),
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ الوصفة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleSave(printReceipt: true),
                          icon: const Icon(Icons.print),
                          label: const Text('حفظ وطباعة 🖨️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2980B9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
