import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../services/api_service.dart';
import 'invoice_lookup_screen.dart';
import 'partner_billing_screen.dart';
import 'pos_screen.dart';

class TemporaryOrderScreen extends StatefulWidget {
  final String type; // 'Sales' or 'Purchase'
  final Map<String, dynamic> partner;
  final int? quoteId;
  final List<Map<String, dynamic>>? allowedItems;

  const TemporaryOrderScreen({
    super.key,
    required this.type,
    required this.partner,
    this.quoteId,
    this.allowedItems,
  });

  @override
  State<TemporaryOrderScreen> createState() => _TemporaryOrderScreenState();
}

class _TemporaryOrderScreenState extends State<TemporaryOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // State for 8th-digit phone auto-lookup & previous invoices summary card
  bool _isSearchingPhone = false;
  String _lastSearchedPhone = '';
  List<Map<String, dynamic>> _customerInvoices = [];
  int _customerInvoicesCount = 0;
  double _customerInvoicesTotal = 0.0;
  bool _hasSearchedCurrentPhone = false;

  @override
  void initState() {
    super.initState();
    final partnerName = widget.partner['PartnerName']?.toString() ?? '';
    if (partnerName != 'نقدي عام') {
      _nameController.text = partnerName;
    }
    _phoneController.text = widget.partner['Phone']?.toString() ?? '';
    _addressController.text = widget.partner['Address']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _formatDateTime(String rawDateStr) {
    if (rawDateStr.isEmpty) return '-';
    try {
      final DateTime dt = DateTime.parse(rawDateStr);
      final String day = dt.day.toString().padLeft(2, '0');
      final String month = dt.month.toString().padLeft(2, '0');
      final String year = dt.year.toString();
      final String hour = dt.hour.toString().padLeft(2, '0');
      final String minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    } catch (_) {
      return rawDateStr;
    }
  }

  /// يتم تفعيل البحث تلقائياً عند الوصول للرقم الثامن (8 أرقام فأكثر) لضمان عدم التعطل أو الثقل أثناء الكتابة
  void _onPhoneChanged(String rawValue) {
    final String cleanPhone =
        rawValue.trim().replaceAll(RegExp(r'[\s\-\+]'), '');

    if (cleanPhone.length < 8) {
      if (_lastSearchedPhone.isNotEmpty ||
          _customerInvoices.isNotEmpty ||
          _hasSearchedCurrentPhone) {
        setState(() {
          _lastSearchedPhone = '';
          _customerInvoices = [];
          _customerInvoicesCount = 0;
          _customerInvoicesTotal = 0.0;
          _hasSearchedCurrentPhone = false;
        });
      }
      return;
    }

    if (cleanPhone == _lastSearchedPhone) return;
    _lookupCustomerByPhone(cleanPhone);
  }

  Future<void> _lookupCustomerByPhone(String cleanPhone) async {
    _lastSearchedPhone = cleanPhone;
    if (!mounted) return;
    setState(() {
      _isSearchingPhone = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.searchInvoicesByPhone(cleanPhone);

      // Ignore outdated responses if the user changed the phone number meanwhile
      final currentClean =
          _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\+]'), '');
      if (!mounted || currentClean != cleanPhone) return;

      if (response.statusCode == 200 && response.data is Map) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data as Map);
        final String fetchedName =
            (data['customer_name']?.toString() ?? '').trim();
        final String fetchedAddress =
            (data['customer_address']?.toString() ?? '').trim();
        final List rawList = (data['invoices'] as List?) ?? [];
        final List<Map<String, dynamic>> invoices = rawList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // تعبئة اسم الزبون والعنوان تلقائياً إذا وُجدت بيانات سابقة للعميل
        if (fetchedName.isNotEmpty) {
          _nameController.text = fetchedName;
        }
        if (fetchedAddress.isNotEmpty) {
          _addressController.text = fetchedAddress;
        }

        setState(() {
          _customerInvoices = invoices;
          _customerInvoicesCount =
              (data['total_count'] as num?)?.toInt() ?? invoices.length;
          _customerInvoicesTotal =
              _parseDouble(data['total_amount'], 0.0);
          _hasSearchedCurrentPhone = true;
          _isSearchingPhone = false;
        });
      } else {
        setState(() {
          _isSearchingPhone = false;
          _hasSearchedCurrentPhone = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearchingPhone = false;
        });
      }
    }
  }

  void _openInvoiceReadOnly(int invId) {
    if (invId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceLookupScreen(
          initialInvId: invId,
          readOnlyPrintOnly: true,
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _proceedToPOS({bool isSkipped = false}) {
    final bool isGeneralCash = widget.partner['PartnerID'] == null ||
        widget.partner['PartnerName'] == 'نقدي عام' ||
        widget.partner['PartnerName'] == 'سند مباشر';

    String? name;
    String? phone;
    String? address;
    String? notes;

    if (isSkipped) {
      name = null;
      phone = null;
      address = null;
      notes = null;
    } else {
      if (isGeneralCash) {
        name = _nameController.text.trim();
        phone = _phoneController.text.trim();
        address = _addressController.text.trim();
        notes = _notesController.text.trim();

        if (name.isEmpty && phone.isEmpty && address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('temp_order_validation_error'),
                  textAlign: TextAlign.right),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else {
        name = widget.partner['PartnerName']?.toString();
        phone = widget.partner['Phone']?.toString();
        address = widget.partner['Address']?.toString();
        notes = _notesController.text.trim();
      }
    }

    String? dateStr;
    if (_selectedDate != null) {
      dateStr =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    }

    String? timeStr;
    if (_selectedTime != null) {
      timeStr =
          "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}";
    }

    if (widget.quoteId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PartnerBillingScreen(
            partner: widget.partner,
            type: widget.type,
            quoteId: widget.quoteId!,
            allowedItems: widget.allowedItems!,
            tempCustomerName: name,
            tempPhone: phone,
            tempAddress: address,
            tempDeliveryDate: dateStr,
            tempDeliveryTime: timeStr,
            tempNotes: notes,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PosScreen(
            type: widget.type,
            partner: widget.partner,
            tempCustomerName: name,
            tempPhone: phone,
            tempAddress: address,
            tempDeliveryDate: dateStr,
            tempDeliveryTime: timeStr,
            tempNotes: notes,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isGeneralCash = widget.partner['PartnerID'] == null ||
        widget.partner['PartnerName'] == 'نقدي عام' ||
        widget.partner['PartnerName'] == 'سند مباشر';
    final skipText = isGeneralCash
        ? context.tr('temp_order_skip_general')
        : context.tr('temp_order_skip_customer');
    final titleText = isGeneralCash
        ? context.tr('temp_order_title_general')
        : context.tr('temp_order_title_customer');

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isGeneralCash)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_isSearchingPhone)
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.teal,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'جاري البحث عن بيانات العميل...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  const SizedBox.shrink(),
                                Text(
                                  context.tr('temp_order_cust_info_title'),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.phone,
                              onChanged: _onPhoneChanged,
                              onFieldSubmitted: _onPhoneChanged,
                              decoration: InputDecoration(
                                labelText: context.tr('temp_order_phone_label'),
                                helperText:
                                    'يتم البحث تلقائياً عند إدخال الرقم الثامن لجلب الاسم والعنوان والفواتير السابقة',
                                prefixIcon: const Icon(Icons.phone,
                                    color: Colors.teal),
                                suffixIcon: _phoneController.text.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'مسح الرقم',
                                        icon: const Icon(Icons.clear,
                                            size: 18, color: Colors.grey),
                                        onPressed: () {
                                          _phoneController.clear();
                                          _onPhoneChanged('');
                                        },
                                      )
                                    : null,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                labelText:
                                    context.tr('temp_order_cust_name_label'),
                                prefixIcon: const Icon(Icons.person,
                                    color: Colors.teal),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText:
                                    context.tr('temp_order_address_label'),
                                prefixIcon: const Icon(Icons.location_on,
                                    color: Colors.teal),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // الكارت الجديد لموجز الفواتير السابقة للعميل (يظهر تلقائياً عند البحث بالرقم الثامن)
                  if (isGeneralCash &&
                      (_customerInvoices.isNotEmpty ||
                          _hasSearchedCurrentPhone)) ...[
                    const SizedBox(height: 16),
                    _buildPreviousInvoicesSummaryCard(),
                  ],

                  if (isGeneralCash) const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            context.tr('temp_order_delivery_schedule_title'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectTime(context),
                                  icon: const Icon(Icons.access_time,
                                      color: Colors.teal),
                                  label: Text(
                                    _selectedTime == null
                                        ? context.tr('temp_order_select_time')
                                        : _selectedTime!.format(context),
                                    style: const TextStyle(color: Colors.teal),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.teal),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectDate(context),
                                  icon: const Icon(Icons.calendar_today,
                                      color: Colors.teal),
                                  label: Text(
                                    _selectedDate == null
                                        ? context.tr('temp_order_select_date')
                                        : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
                                    style: const TextStyle(color: Colors.teal),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.teal),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: context.tr('temp_order_notes_label'),
                              prefixIcon: const Icon(Icons.note_alt,
                                  color: Colors.teal),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _proceedToPOS(isSkipped: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      context.tr('temp_order_proceed_btn'),
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _proceedToPOS(isSkipped: true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      skipText,
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// كارت موجز الفواتير السابقة للعميل مرتبة من الأحدث إلى الأقدم مع إمكانية العرض والطباعة فقط
  Widget _buildPreviousInvoicesSummaryCard() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.teal.shade200, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس الكارت مع إجمالي الفواتير وعددها
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'موجز الفواتير السابقة للعميل',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        Text(
                          'مرتبة من الأحدث إلى الأقدم • اضغط على أي فاتورة للعرض والطباعة فقط',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // شريط إحصائيات الفواتير (عدد الفواتير + إجمالي الفواتير)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'عدد الفواتير',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_customerInvoicesCount فاتورة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'إجمالي الفواتير',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_customerInvoicesTotal.toStringAsFixed(3)} KWD',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_customerInvoices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'لا توجد فواتير سابقة مسجلة لهذا الرقم',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _customerInvoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final inv = _customerInvoices[index];
                      final int invId = _parseInt(inv['InvID']);
                      final String dateStr =
                          _formatDateTime(inv['InvDate']?.toString() ?? '');
                      final double netAmt = _parseDouble(inv['NetAmount']);
                      final double paidAmt = _parseDouble(inv['PaidAmount']);
                      final double remAmt = _parseDouble(inv['Remainder']);
                      final int itemsCount = _parseInt(inv['ItemsCount']);
                      final bool isPaid = paidAmt > 0 && remAmt <= 0.001;

                      return Card(
                        elevation: 1.5,
                        margin: EdgeInsets.zero,
                        color: index == 0
                            ? Colors.teal.shade50.withValues(alpha: 0.45)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: index == 0
                                ? Colors.teal.shade300
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openInvoiceReadOnly(invId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade700,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '#$invId',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (index == 0)
                                        const Text(
                                          'الأحدث',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'التاريخ: $dateStr',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'عدد الأصناف: $itemsCount  •  اضغط للعرض والطباعة',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${netAmt.toStringAsFixed(3)} KWD',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        isPaid ? 'مدفوع' : 'آجل',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isPaid
                                              ? Colors.green.shade900
                                              : Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.print_outlined,
                                  color: Colors.teal,
                                  size: 18,
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
          ),
        ),
      ),
    );
  }
}
