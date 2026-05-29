import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';

class PosScreen extends StatefulWidget {
  final String type;
  const PosScreen({super.key, required this.type});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _barcodeController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    final posProvider = Provider.of<PosProvider>(context, listen: false);

    // Quick simulator for testing barcode / item name searches
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '123456');
        return AlertDialog(
          title: Text(context.tr('pos_barcode_simulator_title'),
              textAlign: TextAlign.right),
          content: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
                labelText: context.tr('pos_barcode_simulator_input')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('pos_cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await posProvider
                    .searchAndAddProductByBarcode(controller.text.trim());
              },
              child: Text(context.tr('pos_add_to_cart')),
            ),
          ],
        );
      },
    );
  }

  void _addProductFromBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;

    final posProvider = Provider.of<PosProvider>(context, listen: false);
    await posProvider.searchAndAddProductByBarcode(barcode.trim());

    _barcodeController.clear();
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
              ? context.tr('pos_sales_title')
              : context.tr('pos_purchases_title')),
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
                    child: TextField(
                      controller: _barcodeController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: context.tr('pos_barcode_input'),
                        border: const OutlineInputBorder(),
                        suffixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: _addProductFromBarcode,
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
        // For mobile portrait, show checkout at bottom
        bottomNavigationBar:
            !isTablet ? _buildCheckoutPanel(posProvider, isMobile: true) : null,
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
      'paid_amount':  total,  // POS screen is always cash (fully paid)
      'remainder':    0.0,
      'items': List<Map<String, dynamic>>.from(posProvider.invoiceItems),
    };

    // 2. Perform save (either online or offline local persistence fallback)
    final newInvId = await posProvider.saveInvoice(widget.type);

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
          ElevatedButton.icon(
            onPressed: (!canPay || posProvider.isLoading)
                ? null
                : () => _handlePaymentAndPrint(posProvider, total),
            icon: const Icon(Icons.payment),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: posProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(context.tr('pos_pay_print'),
                      style: const TextStyle(fontSize: 18)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
            ),
          ),
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
