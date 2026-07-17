import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/stocktake_provider.dart';
import '../../services/printer_service.dart';
import '../../widgets/product_entry_scanner.dart';
import '../../core/localization/app_localizations.dart';

class StockTakeScreen extends StatefulWidget {
  const StockTakeScreen({super.key});

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndPrint(StockTakeProvider provider) async {
    if (provider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('st_empty_cart_error'), textAlign: TextAlign.right),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notes = _notesController.text.trim();
    final double totalDiffValue = provider.totalDifferenceValue;

    // 1. Snapshot items before they are cleared on successful save
    final itemsSnapshot = provider.items
        .map((item) => {
              'ProductID': item.productID,
              'ProductName': item.productName,
              'Barcode': item.barcode,
              'UnitName': item.unitName,
              'SystemQuantity': item.systemQty,
              'ActualQuantity': item.actualQty,
              'DifferenceQuantity': item.diffQty,
              'CostPrice': item.costPrice,
              'DifferenceValue': item.diffValue,
            })
        .toList();

    // 2. Call Save API
    final id = await provider.submitStockTake(notes);

    if (id != null) {
      final invoiceData = {
        'StockTakeID': id,
        'StockTakeDate': DateTime.now().toIso8601String(),
        'WarehouseName': provider.selectedWarehouseName,
        'TotalDifferenceValue': totalDiffValue,
        'Notes': notes,
        'items': itemsSnapshot,
      };

      // 3. Print
      final printerService =
          Provider.of<PrinterService>(context, listen: false);
      final printSuccess =
          await printerService.printStockTakeReceipt(invoiceData);

      if (mounted) {
        final isVirtual = printerService.connectionType == 'None';
        final showWarning = !printSuccess && !isVirtual;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              showWarning
                  ? context.tr('st_save_success_print_failed').replaceAll('{id}', id.toString())
                  : context.tr('st_save_success_printing').replaceAll('{id}', id.toString()),
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
              provider.errorMessage ?? context.tr('st_save_failed'),
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
    final provider = Provider.of<StockTakeProvider>(context);
    final items = provider.items;
    final isLocked =
        items.isNotEmpty; // Lock warehouse selection if items exist

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('st_screen_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: context.tr('st_clear_tooltip'),
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
                  Text(
                    context.tr('st_warehouse_label'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.tr('st_warehouse_locked_warn'),
                  style: const TextStyle(
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
                  // Default product cost & quantity
                  double cost =
                      (prod['PurchasePrice'] as num?)?.toDouble() ?? 0.0;
                  provider.addProductDirectly(prod, 0.0, cost);
                  // Dynamically fetch actual system stock level & cost price for this warehouse in background
                  provider.apiService
                      .getProductStockCost(prod['ProductID'] as int,
                          provider.selectedWarehouseId)
                      .then((res) {
                    if (res.statusCode == 200) {
                      final double stockQty =
                          (res.data['StockQuantity'] as num?)?.toDouble() ??
                              0.0;
                      final double costVal =
                          (res.data['CostPrice'] as num?)?.toDouble() ?? cost;

                      // Update stock take item with real database values
                      final index = provider.items.indexWhere(
                          (item) => item.productID == prod['ProductID']);
                      if (index != -1) {
                        setState(() {
                          provider.items[index].systemQty = stockQty;
                          provider.items[index].costPrice = costVal;
                        });
                      }
                    }
                  }).catchError((_) {});
                },
              ),
            ),

            if (provider.isLoading)
              const LinearProgressIndicator(color: Colors.green),

            // Items Cart Table List
            items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                        child: Text(context.tr('st_cart_empty_hint'))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final Color diffColor = item.diffQty > 0
                          ? Colors.blue
                          : (item.diffQty < 0 ? Colors.red : Colors.grey);
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
                              // Barcode & Unit & Cost
                              Text(
                                '${context.tr('st_item_barcode')}${item.barcode}${context.tr('st_item_unit')}${item.unitName}${context.tr('st_item_cost')}${item.costPrice.toStringAsFixed(3)} ',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 8),

                              // Stats Row: System Qty & Actual Qty Input
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // System Quantity Display
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(context.tr('st_system_qty'),
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${item.systemQty.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  // Actual Quantity Input
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(context.tr('st_actual_qty'),
                                          style: const TextStyle(
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
                                                provider.updateActualQuantity(
                                                    item.productID,
                                                    item.actualQty - 1),
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
                                                  text: item.actualQty
                                                      .toString()),
                                              onSubmitted: (val) {
                                                final double? qty =
                                                    double.tryParse(val);
                                                if (qty != null) {
                                                  provider.updateActualQuantity(
                                                      item.productID, qty);
                                                }
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.add, size: 18),
                                            onPressed: () =>
                                                provider.updateActualQuantity(
                                                    item.productID,
                                                    item.actualQty + 1),
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
                              // Row 2: Difference Qty & Difference Value
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Difference Value Output
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(context.tr('st_diff_value'),
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${item.diffValue.toStringAsFixed(3)} ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: diffColor)),
                                    ],
                                  ),
                                  // Difference Quantity Output
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(context.tr('st_difference'),
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text('${item.diffQty.toStringAsFixed(2)}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: diffColor)),
                                    ],
                                  ),
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
                        '${provider.totalDifferenceValue.toStringAsFixed(3)} ',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: provider.totalDifferenceValue > 0
                                ? Colors.blue
                                : (provider.totalDifferenceValue < 0
                                    ? Colors.red
                                    : Colors.grey)),
                      ),
                      Text(
                        context.tr('st_total_diff_value'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: context.tr('st_notes_hint'),
                      border: const OutlineInputBorder(),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: items.isEmpty || provider.isLoading
                        ? null
                        : () => _handleSaveAndPrint(provider),
                    icon: const Icon(Icons.print),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(context.tr('st_save_print_btn'),
                          style: const TextStyle(
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
