import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';

class PartnerBillingScreen extends StatefulWidget {
  final Map<String, dynamic> partner;
  final String type; // 'Sales' or 'Purchases'
  final int quoteId;
  final List<Map<String, dynamic>> allowedItems;

  const PartnerBillingScreen({
    super.key,
    required this.partner,
    required this.type,
    required this.quoteId,
    required this.allowedItems,
  });

  @override
  State<PartnerBillingScreen> createState() => _PartnerBillingScreenState();
}

class _PartnerBillingScreenState extends State<PartnerBillingScreen> {
  final List<Map<String, dynamic>> _cartItems = [];
  final _searchController = TextEditingController();
  final _barcodeInputController = TextEditingController();
  final _focusNode = FocusNode();
  final _discountController = TextEditingController(text: '0.0');

  List<Map<String, dynamic>> _filteredAllowedItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredAllowedItems = widget.allowedItems;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeInputController.dispose();
    _focusNode.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0.0));
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _netAmount {
    final net = _subtotal - _discount;
    return net < 0 ? 0.0 : net;
  }

  void _filterAllowedItems(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredAllowedItems = widget.allowedItems;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredAllowedItems = widget.allowedItems.where((item) {
        final name = (item['ProductName'] ?? '').toString().toLowerCase();
        final barcode = (item['Barcode'] ?? '').toString().toLowerCase();
        return name.contains(lowercaseQuery) || barcode.contains(lowercaseQuery);
      }).toList();
    });
  }

  void _addOrIncrementProduct(Map<String, dynamic> allowedItem) {
    final productId = allowedItem['ProductID'];
    final price = (allowedItem['UnitPrice'] ?? allowedItem['QuotedPrice'] ?? 0.0).toDouble();
    final name = allowedItem['ProductName'] ?? 'صنف غير معروف';
    final barcode = allowedItem['Barcode'] ?? '';
    final unitName = allowedItem['UnitName'] ?? 'حبة';

    final existingIndex = _cartItems.indexWhere((item) => item['ProductID'] == productId);

    setState(() {
      if (existingIndex != -1) {
        _cartItems[existingIndex]['quantity'] += 1.0;
        _cartItems[existingIndex]['total'] = _cartItems[existingIndex]['quantity'] * _cartItems[existingIndex]['price'];
      } else {
        _cartItems.add({
          'ProductID': productId,
          'name': name,
          'barcode': barcode,
          'price': price,
          'quantity': 1.0,
          'total': price,
          'unitName': unitName,
        });
      }
    });

    HapticFeedback.lightImpact();
  }

  void _decrementOrRemoveProduct(int productId) {
    final existingIndex = _cartItems.indexWhere((item) => item['ProductID'] == productId);
    if (existingIndex == -1) return;

    setState(() {
      if (_cartItems[existingIndex]['quantity'] > 1.0) {
        _cartItems[existingIndex]['quantity'] -= 1.0;
        _cartItems[existingIndex]['total'] = _cartItems[existingIndex]['quantity'] * _cartItems[existingIndex]['price'];
      } else {
        _cartItems.removeAt(existingIndex);
      }
    });

    HapticFeedback.lightImpact();
  }

  void _handleBarcodeScanned(String barcode) {
    final trimmedBarcode = barcode.trim();
    if (trimmedBarcode.isEmpty) return;

    // Find barcode in allowedItems
    final allowedItem = widget.allowedItems.firstWhere(
      (item) => (item['Barcode'] ?? '').toString().trim() == trimmedBarcode,
      orElse: () => {},
    );

    if (allowedItem.isNotEmpty) {
      _addOrIncrementProduct(allowedItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة: ${allowedItem['ProductName']}', textAlign: TextAlign.right),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      _showBarcodeWarning(trimmedBarcode);
    }
  }

  void _showBarcodeWarning(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('تنبيه - صنف غير معتمد', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'الباركود ($barcode) غير مدرج في عرض الأسعار النشط والعتمد لهذا الشريك!\n\nيُمنع إضافة منتجات من خارج العرض.',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('موافق'),
          )
        ],
      ),
    );
  }

  void _openCameraScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('مسح الباركود بالكاميرا', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: MobileScannerController(
                            detectionSpeed: DetectionSpeed.noDuplicates,
                          ),
                          onDetect: (BarcodeCapture capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              final String code = barcode.rawValue ?? '';
                              if (code.isNotEmpty) {
                                Navigator.pop(context); // Close sheet
                                _handleBarcodeScanned(code);
                                break;
                              }
                            }
                          },
                        ),
                        // Scanner overlay grid
                        Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        // Animated scanner line
                        const Positioned(
                          top: 150,
                          child: Text('وجه الكاميرا نحو باركود الصنف', style: TextStyle(color: Colors.white, fontSize: 16)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _submitInvoice(bool isCash) async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('السلة فارغة! يرجى إضافة منتجات أولاً', textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final double total = _subtotal;
    final double discount = _discount;
    final double net = _netAmount;
    final double paid = isCash ? net : 0.0;
    final double remainder = isCash ? 0.0 : net;

    // Build details list matching InvoiceDetail schema
    final details = _cartItems.map((item) {
      return {
        'ProductID': item['ProductID'],
        'UnitPrice': item['price'],
        'Quantity': item['quantity'],
        'TotalPrice': item['total'],
        'CostPrice': item['price'], // Default cost price to sale price if unknown
      };
    }).toList();

    // Build payload matching InvoiceCreate schema
    final payload = {
      'InvType': widget.type == 'Sales' ? 'Sales' : 'Purchase',
      'InvDate': DateTime.now().toIso8601String(),
      'PartnerID': widget.partner['PartnerID'],
      'WarehouseID': 1, // Default warehouse
      'TotalAmount': total,
      'Discount': discount,
      'NetAmount': net,
      'PaidAmount': paid,
      'Remainder': remainder,
      'Notes': 'فاتورة عروض شركاء - عرض رقم ${widget.quoteId}',
      'IsPosted': false,
      'Details': details,
    };

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.savePartnerInvoice(payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final int newInvId = response.data['InvID'] ?? 0;

        // Auto print receipt using PrinterService
        final printerService = Provider.of<PrinterService>(context, listen: false);
        
        final printInvoiceData = {
          'InvID': newInvId,
          'PartnerName': widget.partner['PartnerName'],
          'type': widget.type == 'Sales' ? 'Sales' : 'Purchase',
          'created_at': DateTime.now().toIso8601String(),
          'total_amount': net,
          'items': _cartItems.map((c) => {
            'name': c['name'],
            'price': c['price'],
            'quantity': c['quantity'].toInt(),
            'total': c['total'],
          }).toList(),
        };
        
        await printerService.printReceipt(printInvoiceData);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('تم الحفظ والطباعة', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'تم تسجيل الفاتورة رقم ($newInvId) بنجاح وإرسال أمر الطباعة للمكينة.\n\nطريقة الدفع: ${isCash ? "نقدي (كاش)" : "آجل (ذمم)"}',
                textAlign: TextAlign.right,
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to offers screen
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text('موافق'),
                )
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حفظ الفاتورة على السيرفر: ${response.data}', textAlign: TextAlign.right),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال بالشبكة: $e', textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 700;
    final primaryColor = widget.type == 'Sales' ? Colors.blue[700]! : Colors.orange[800]!;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f12 && !_isLoading) {
            _submitInvoice(true); // Cash on F12
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                widget.type == 'Sales' ? 'فاتورة مبيعات عروض' : 'فاتورة مشتريات عروض',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'الشريك: ${widget.partner['PartnerName']}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              )
            ],
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.type == 'Sales'
                    ? [Colors.blue, Colors.teal]
                    : [Colors.orange, Colors.red],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              tooltip: 'مسح باركود بالكاميرا',
              onPressed: _openCameraScanner,
            )
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : isTablet
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Cart items list and invoice summery checkout
                        Expanded(
                          flex: 5,
                          child: _buildCartPanel(primaryColor),
                        ),
                        // Right: Allowed items catalog
                        Expanded(
                          flex: 6,
                          child: _buildCatalogPanel(primaryColor),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Search bar in mobile
                        _buildSearchBar(primaryColor),
                        // Small stats
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.grey[100],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('الأصناف في السلة: ${_cartItems.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('الإجمالي: ${_subtotal.toStringAsFixed(2)} د.ك', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        // Allowed Items List (Tap to add)
                        Expanded(
                          child: _buildMobileCatalogList(),
                        ),
                        // Checkout bottom bar
                        _buildMobileCheckoutBar(primaryColor),
                      ],
                    ),
        ),
      ),
    );
  }

  // === UI Panels for Tablet Layout ===

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filterAllowedItems,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المنتج أو الباركود...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Quick Barcode Manual Field
          Container(
            width: 160,
            child: TextField(
              controller: _barcodeInputController,
              decoration: const InputDecoration(
                hintText: 'أدخل الباركود...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onSubmitted: (val) {
                _handleBarcodeScanned(val);
                _barcodeInputController.clear();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel(Color primaryColor) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(primaryColor),
          const SizedBox(height: 8),
          const Text(
            'الأصناف والأسعار المعتمدة داخل عرض الشريك:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: _filteredAllowedItems.length,
              itemBuilder: (context, index) {
                final item = _filteredAllowedItems[index];
                final price = (item['UnitPrice'] ?? item['QuotedPrice'] ?? 0.0).toDouble();
                final name = item['ProductName'] ?? 'صنف غير معروف';
                final barcode = item['Barcode'] ?? 'بلا باركود';
                final unitName = item['UnitName'] ?? 'حبة';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _addOrIncrementProduct(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, color: primaryColor, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${price.toStringAsFixed(3)} د.ك / $unitName',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            barcode,
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCartPanel(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: primaryColor.withOpacity(0.05),
            child: const Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.teal),
                SizedBox(width: 8),
                Text('سلة المشتريات / الفاتورة الحالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: _cartItems.isEmpty
                ? const Center(
                    child: Text('السلة فارغة\nانقر على الأصناف لإضافتها', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return ListTile(
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${item['price'].toStringAsFixed(3)} د.ك  x  ${item['quantity']} ${item['unitName']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item['total'].toStringAsFixed(2)} د.ك',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _decrementOrRemoveProduct(item['ProductID']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => _addOrIncrementProduct(item),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _buildCheckoutSummaryPanel(primaryColor),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummaryPanel(Color primaryColor) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي الفرعي:', style: TextStyle(fontSize: 15)),
              Text('${_subtotal.toStringAsFixed(2)} د.ك', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('قيمة الخصم:', style: TextStyle(fontSize: 15)),
              Container(
                width: 100,
                height: 35,
                child: TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الصافي النهائي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${_netAmount.toStringAsFixed(2)} د.ك', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const SizedBox(height: 16),
          // Pay Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cartItems.isEmpty ? null : () => _submitInvoice(true),
                  icon: const Icon(Icons.payment),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('حفظ كاش (F12)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cartItems.isEmpty ? null : () => _submitInvoice(false),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('حفظ آجل (Credit)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // === UI Panels for Mobile Layout ===

  Widget _buildMobileCatalogList() {
    return _filteredAllowedItems.isEmpty
        ? const Center(child: Text('لا توجد نتائج مطابقة للبحث'))
        : ListView.builder(
            itemCount: _filteredAllowedItems.length,
            itemBuilder: (context, index) {
              final item = _filteredAllowedItems[index];
              final price = (item['UnitPrice'] ?? item['QuotedPrice'] ?? 0.0).toDouble();
              final name = item['ProductName'] ?? '';
              final barcode = item['Barcode'] ?? '';
              final unitName = item['UnitName'] ?? '';

              final cartIndex = _cartItems.indexWhere((c) => c['ProductID'] == item['ProductID']);
              final cartQty = cartIndex != -1 ? _cartItems[cartIndex]['quantity'] : 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$barcode | السعر: ${price.toStringAsFixed(3)} د.ك / $unitName'),
                  trailing: cartQty > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _decrementOrRemoveProduct(item['ProductID']),
                            ),
                            Text(cartQty.toInt().toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => _addOrIncrementProduct(item),
                            ),
                          ],
                        )
                      : ElevatedButton(
                          onPressed: () => _addOrIncrementProduct(item),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          child: const Text('إضافة', style: TextStyle(color: Colors.white)),
                        ),
                ),
              );
            },
          );
  }

  Widget _buildMobileCheckoutBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي: ${_netAmount.toStringAsFixed(2)} د.ك', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.shopping_cart),
                label: Text('عرض السلة (${_cartItems.length})'),
                onPressed: _showCartDetailsBottomSheet,
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _cartItems.isEmpty ? null : () => _submitInvoice(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text('دفع نقدي (كاش)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _cartItems.isEmpty ? null : () => _submitInvoice(false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                  child: const Text('دفع آجل (Credit)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showCartDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('محتويات السلة الحالية:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _cartItems.isEmpty
                          ? const Center(child: Text('السلة فارغة'))
                          : ListView.builder(
                              itemCount: _cartItems.length,
                              itemBuilder: (context, index) {
                                final item = _cartItems[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${item['price'].toStringAsFixed(3)} د.ك  x  ${item['quantity']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${item['total'].toStringAsFixed(2)} د.ك', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                          onPressed: () {
                                            _decrementOrRemoveProduct(item['ProductID']);
                                            setSheetState(() {});
                                            setState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                          onPressed: () {
                                            _addOrIncrementProduct(item);
                                            setSheetState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('قيمة الخصم:', style: TextStyle(fontSize: 16)),
                        Container(
                          width: 100,
                          height: 35,
                          child: TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              setSheetState(() {});
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'الإجمالي النهائي الصافي: ${_netAmount.toStringAsFixed(2)} د.ك',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
