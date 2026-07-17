import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class DailyOrdersScreen extends StatefulWidget {
  const DailyOrdersScreen({super.key});

  @override
  State<DailyOrdersScreen> createState() => _DailyOrdersScreenState();
}

class _DailyOrdersScreenState extends State<DailyOrdersScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String _errorMessage = '';
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchDailyOrders();
  }

  Future<void> _fetchDailyOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await apiService.getDailyOrders(formattedDate);

      if (response.statusCode == 200) {
        setState(() {
          _orders = response.data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Fails to load orders: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _isPastDue(String deliveryTime, String deliveryDateStr) {
    try {
      final now = DateTime.now();
      final deliveryDate = DateTime.parse(deliveryDateStr);
      
      // If date is before today
      if (deliveryDate.year < now.year ||
          (deliveryDate.year == now.year && deliveryDate.month < now.month) ||
          (deliveryDate.year == now.year && deliveryDate.month == now.month && deliveryDate.day < now.day)) {
        return true;
      }
      
      // If date is today
      if (deliveryDate.year == now.year && deliveryDate.month == now.month && deliveryDate.day == now.day) {
        final parts = deliveryTime.split(':');
        if (parts.length >= 2) {
          final hr = int.parse(parts[0]);
          final mn = int.parse(parts[1]);
          final target = DateTime(now.year, now.month, now.day, hr, mn);
          return now.isAfter(target);
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchDailyOrders();
    }
  }

  Future<void> _printOrder(Map<String, dynamic> data) async {
    final List<dynamic> dbDetails = data['Details'] ?? [];

    final printData = {
      'InvID': data['InvID'],
      'PartnerName': data['CustomerName'] ?? 'زبون مؤقت',
      'type': data['InvType'] ?? 'Sales',
      'created_at': data['DeliveryDate'] ?? DateTime.now().toIso8601String(),
      'total_amount': _parseDouble(data['NetAmount']),
      'paid_amount': _parseDouble(data['PaidAmount']),
      'voucher_paid_amount': 0.0,
      'remainder': _parseDouble(data['Remainder']),
      
      // Temporary Customer / Delivery details
      'temp_customer_name': data['CustomerName'],
      'temp_phone': data['Phone'],
      'temp_address': data['Address'],
      'temp_delivery_date': data['DeliveryDate'],
      'temp_delivery_time': data['DeliveryTime'],

      'items': dbDetails
          .map((item) => {
                'name': item['ProductName'] ?? '',
                'price': _parseDouble(item['UnitPrice']),
                'quantity': _parseDouble(item['Quantity']),
                'total': _parseDouble(item['TotalPrice']),
                'UnitName': item['UnitName'] ?? '',
              })
          .toList(),
    };

    final printerService = Provider.of<PrinterService>(context, listen: false);
    try {
      final success = await printerService.printReceipt(printData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'تمت عملية الطباعة بنجاح' : 'خطأ أثناء الطباعة الحرارية',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت الطباعة: $e', textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('home_daily_orders')),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
            // Date Filter Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_month, color: Colors.teal),
                        label: const Text(
                          'تغيير التاريخ',
                          style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _fetchDailyOrders,
                        icon: const Icon(Icons.refresh, color: Colors.teal),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            'حدث خطأ: $_errorMessage',
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        )
                      : _orders.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد طلبات توصيل مجدولة لهذا التاريخ.',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _orders.length,
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                final bool isPaid = _parseDouble(order['Remainder']) <= 0;
                                final bool isPast = _isPastDue(
                                  order['DeliveryTime'] ?? '',
                                  order['DeliveryDate'] ?? '',
                                );

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  color: isPast ? Colors.red.shade50 : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isPast ? Colors.red.shade200 : Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isPast ? Colors.red.shade100 : Colors.teal.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        order['DeliveryTime'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isPast ? Colors.red.shade800 : Colors.teal.shade800,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      order['Phone'] ?? '--',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            '💰 ${_parseDouble(order['NetAmount']).toStringAsFixed(3)} د.ك',
                                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                                          ),
                                          const SizedBox(width: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isPaid ? 'مسدد' : 'آجل',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(),
                                            const SizedBox(height: 8),
                                            Text(
                                              'اسم المستلم: ${order['CustomerName'] ?? '--'}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'العنوان: ${order['Address'] ?? '--'}',
                                              style: const TextStyle(color: Colors.black87),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'الملاحظات: ${order['Notes'] ?? '--'}',
                                              style: const TextStyle(color: Colors.black54),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'الأصناف:',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                            ),
                                            const SizedBox(height: 6),
                                            // Render details list
                                            ...List.generate(
                                              (order['Details'] as List? ?? []).length,
                                              (detIdx) {
                                                final item = order['Details'][detIdx];
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(item['ProductName'] ?? ''),
                                                      Text(
                                                        '${_parseDouble(item['Quantity'])} ${item['UnitName'] ?? ''}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () => _printOrder(Map<String, dynamic>.from(order)),
                                                icon: const Icon(Icons.print, color: Colors.white),
                                                label: const Text('طباعة إيصال التوصيل', style: TextStyle(color: Colors.white)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.teal,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
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
