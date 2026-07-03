import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wastage_provider.dart';
import '../../services/printer_service.dart';
import '../../widgets/product_entry_scanner.dart';

class WastageScreen extends StatefulWidget {
  const WastageScreen({super.key});

  @override
  State<WastageScreen> createState() => _WastageScreenState();
}

class _WastageScreenState extends State<WastageScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndPrint(WastageProvider provider) async {
    if (provider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة أصناف أولاً', textAlign: TextAlign.right),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notes = _notesController.text.trim();

    // 1. Snapshot items before they are cleared on successful save
    final itemsSnapshot = provider.items
        .map((item) => {
              'ProductID': item.productID,
              'ProductName': item.productName,
              'Barcode': item.barcode,
              'UnitName': item.unitName,
              'Quantity': item.quantity,
              'CostPrice': item.costPrice,
              'TotalCost': item.totalCost,
            })
        .toList();

    // 2. Call Save API
    final id = await provider.submitWastage(notes);

    if (id != null) {
      final invoiceData = {
        'WastageID': id,
        'WastageDate': DateTime.now().toIso8601String(),
        'WarehouseName': provider.selectedWarehouseName,
        'TotalValue': itemsSnapshot.fold(
            0.0, (sum, i) => sum + (i['TotalCost'] as double)),
        'Notes': notes,
        'items': itemsSnapshot,
      };

      // 3. Print
      final printerService =
          Provider.of<PrinterService>(context, listen: false);
      final printSuccess =
          await printerService.printWastageReceipt(invoiceData);

      if (mounted) {
        final isVirtual = printerService.connectionType == 'None';
        final showWarning = !printSuccess && !isVirtual;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              showWarning
                  ? 'تم حفظ الهالك بنجاح برقم ($id) ولكن فشلت الطباعة'
                  : 'تم حفظ الهالك بنجاح برقم ($id) وجاري الطباعة',
              textAlign: TextAlign.right,
            ),
            backgroundColor: showWarning ? Colors.orange : Colors.green,
          ),
        );
        _notesController.clear();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'فشل حفظ الهالك كمسودة',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WastageProvider>(context);
    final items = provider.items;
    final isLocked =
        items.isNotEmpty; // Lock warehouse selection if items exist

    return Scaffold(
      appBar: AppBar(
        title: const Text('إهلاك بضاعة (الهالك)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: 'مسح القائمة',
            onPressed: items.isEmpty ? null : () => provider.clear(),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Warehouse Selector Top Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'المستودع المالي:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<int>(
                    value: provider.selectedWarehouseId,
                    disabledHint: Text(provider.selectedWarehouseName,
                        style: const TextStyle(color: Colors.black54)),
                    onChanged: isLocked
                        ? null
                        : (id) {
                            if (id != null) {
                              final wh = provider.warehouses
                                  .firstWhere((w) => w['WarehouseID'] == id);
                              provider.selectWarehouse(
                                  id, wh['WarehouseName'] ?? 'غير معروف');
                            }
                          },
                    items: provider.warehouses.map<DropdownMenuItem<int>>((wh) {
                      return DropdownMenuItem<int>(
                        value: wh['WarehouseID'],
                        child: Text(wh['WarehouseName'] ?? ''),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            if (isLocked)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'تم قفل تعديل المستودع بسبب وجود عناصر في السلة',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),

            // Unified Entry Component
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ProductEntryScanner(
                onBarcodeSubmitted: (barcode) =>
                    provider.searchAndAddProductByBarcode(barcode),
                onProductSelected: (prod) {
                  // Find stock cost for this product in current warehouse
                  double cost =
                      (prod['PurchasePrice'] as num?)?.toDouble() ?? 0.0;
                  provider.addProductDirectly(prod, cost);
                  // Dynamically load average cost and stock level in background
                  provider.apiService
                      .getProductStockCost(prod['ProductID'] as int,
                          provider.selectedWarehouseId)
                      .then((res) {
                    if (res.statusCode == 200) {
                      final dynamic costVal = res.data['CostPrice'];
                      final dynamic stockQty = res.data['StockQuantity'];
                      if (costVal != null) {
                        provider.updateCostPrice(prod['ProductID'] as int,
                            (costVal as num).toDouble());
                      }
                      if (stockQty != null) {
                        provider.updateStockBefore(prod['ProductID'] as int,
                            (stockQty as num).toDouble());
                      }
                    }
                  }).catchError((_) {});
                },
              ),
            ),

            if (provider.isLoading)
              const LinearProgressIndicator(color: Colors.green),

            // Items Cart Table List
            // Items Cart Table List
            items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                        child: Text('السلة فارغة. ابدأ بمسح أو إضافة أصناف')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Product Name & Delete
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red),
                                    onPressed: () =>
                                        provider.removeItem(item.productID),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              // Barcode & Unit
                              Text(
                                'الباركود: ${item.barcode} | الوحدة: ${item.unitName}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              // Inputs Row: Quantity & Cost Price
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Cost Price Input
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('سعر التكلفة',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 90,
                                        height: 35,
                                        child: TextField(
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 4),
                                            border: OutlineInputBorder(),
                                          ),
                                          controller: TextEditingController(
                                              text: item.costPrice
                                                  .toStringAsFixed(3)),
                                          onSubmitted: (val) {
                                            final double? price =
                                                double.tryParse(val);
                                            if (price != null) {
                                              provider.updateCostPrice(
                                                  item.productID, price);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Quantity Input
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('الكمية',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove,
                                                size: 18),
                                            onPressed: () =>
                                                provider.updateQuantity(
                                                    item.productID,
                                                    item.quantity - 1),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                          SizedBox(
                                            width: 70,
                                            height: 35,
                                            child: TextField(
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                              decoration: const InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 4),
                                                border: OutlineInputBorder(),
                                              ),
                                              controller: TextEditingController(
                                                  text:
                                                      item.quantity.toString()),
                                              onSubmitted: (val) {
                                                final double? qty =
                                                    double.tryParse(val);
                                                if (qty != null) {
                                                  provider.updateQuantity(
                                                      item.productID, qty);
                                                }
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.add, size: 18),
                                            onPressed: () =>
                                                provider.updateQuantity(
                                                    item.productID,
                                                    item.quantity + 1),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              // Row 2: Total Cost Output
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('إجمالي التكلفة:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  Text('${item.totalCost.toStringAsFixed(3)} ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // Total Value, Notes & Submit Bar at Bottom
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${provider.totalCost.toStringAsFixed(3)} ',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const Text(
                        'إجمالي قيمة الهالك:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      hintText: 'ملاحظات إضافية...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: items.isEmpty || provider.isLoading
                        ? null
                        : () => _handleSaveAndPrint(provider),
                    icon: const Icon(Icons.print),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('حفظ وطباعة المسودة',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
