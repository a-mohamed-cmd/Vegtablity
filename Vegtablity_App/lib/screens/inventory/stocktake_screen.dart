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
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(context.tr('st_screen_title'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded,
                color: items.isEmpty ? Colors.white38 : Colors.white),
            tooltip: context.tr('st_clear_tooltip'),
            onPressed: items.isEmpty ? null : () => provider.clear(),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                // Warehouse Header (Automatically from SharedPreferences)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A)
                              .withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDFA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.warehouse_rounded,
                                  color: Color(0xFF0F766E), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr('st_warehouse_label'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            provider.selectedWarehouseName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Unified Entry Component
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Container(
                    height: 380,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A)
                              .withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ProductEntryScanner(
                        searchMode: CatalogSearchMode.purchase,
                        onBarcodeSubmitted: (barcode) =>
                            provider.searchAndAddProductByBarcode(barcode),
                        onProductSelected: (prod) {
                          // Default product cost & quantity
                          double cost =
                              (prod['PurchasePrice'] as num?)?.toDouble() ??
                                  0.0;
                          provider.addProductDirectly(prod, 0.0, cost);
                          // Dynamically fetch actual system stock level & cost price for this warehouse in background
                          provider.apiService
                              .getProductStockCost(prod['ProductID'] as int,
                                  provider.selectedWarehouseId)
                              .then((res) {
                            if (res.statusCode == 200) {
                              final double stockQty = (res
                                          .data['StockQuantity'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              final double costVal =
                                  (res.data['CostPrice'] as num?)?.toDouble() ??
                                      cost;

                              // Update stock take item with real database values
                              final index = provider.items.indexWhere(
                                  (item) =>
                                      item.productID == prod['ProductID']);
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
                  ),
                ),

                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: LinearProgressIndicator(color: Color(0xFF0D9488)),
                  ),

                // Items Cart Table List
                items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28.0),
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 8),
                            Text(context.tr('st_cart_empty_hint'),
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final Color diffColor = item.diffQty > 0
                              ? const Color(0xFF0284C7)
                              : (item.diffQty < 0
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFF64748B));
                          final Color diffBg = item.diffQty > 0
                              ? const Color(0xFFE0F2FE)
                              : (item.diffQty < 0
                                  ? const Color(0xFFFFF1F2)
                                  : const Color(0xFFF1F5F9));
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
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
                                            Icons.delete_outline_rounded,
                                            color: Color(0xFFE11D48)),
                                        onPressed: () =>
                                            provider.removeItem(item.productID),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
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
                                        color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),

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
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text(
                                              item.systemQty.toStringAsFixed(2),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                  fontSize: 15)),
                                        ],
                                      ),
                                      // Actual Quantity Input
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(context.tr('st_actual_qty'),
                                              style: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.remove_rounded,
                                                      color: Color(0xFF0F766E),
                                                      size: 18),
                                                  onPressed: () => provider
                                                      .updateActualQuantity(
                                                          item.productID,
                                                          item.actualQty - 1),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                ),
                                                SizedBox(
                                                  width: 70,
                                                  height: 34,
                                                  child: TextField(
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                            decimal: true),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        color:
                                                            Color(0xFF0F172A),
                                                        fontWeight:
                                                            FontWeight.bold),
                                                    decoration:
                                                        const InputDecoration(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 4),
                                                      border: InputBorder.none,
                                                    ),
                                                    controller:
                                                        TextEditingController(
                                                            text: item.actualQty
                                                                .toString()),
                                                    onSubmitted: (val) {
                                                      final double? qty =
                                                          double.tryParse(val);
                                                      if (qty != null) {
                                                        provider
                                                            .updateActualQuantity(
                                                                item.productID,
                                                                qty);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.add_rounded,
                                                      color: Color(0xFF0F766E),
                                                      size: 18),
                                                  onPressed: () => provider
                                                      .updateActualQuantity(
                                                          item.productID,
                                                          item.actualQty + 1),
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                      height: 20, color: Color(0xFFE2E8F0)),
                                  // Row 2: Difference Qty & Difference Value
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Difference Value Output
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: diffBg,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(context.tr('st_diff_value'),
                                                style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 10)),
                                            const SizedBox(height: 2),
                                            Text(
                                                '${item.diffValue.toStringAsFixed(3)} ',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: diffColor,
                                                    fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                      // Difference Quantity Output
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: diffBg,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(context.tr('st_difference'),
                                                style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 10)),
                                            const SizedBox(height: 2),
                                            Text(
                                                item.diffQty.toStringAsFixed(2),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: diffColor,
                                                    fontSize: 14)),
                                          ],
                                        ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A)
                              .withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                      ? const Color(0xFF0284C7)
                                      : (provider.totalDifferenceValue < 0
                                          ? const Color(0xFFE11D48)
                                          : const Color(0xFF64748B))),
                            ),
                            Text(
                              context.tr('st_total_diff_value'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: context.tr('st_notes_hint'),
                            hintStyle:
                                const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF0D9488), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: items.isEmpty || provider.isLoading
                              ? null
                              : () => _handleSaveAndPrint(provider),
                          icon: const Icon(Icons.print_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13.0),
                            child: Text(context.tr('st_save_print_btn'),
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
