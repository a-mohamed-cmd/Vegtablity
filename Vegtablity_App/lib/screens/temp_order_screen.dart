import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import 'pos_screen.dart';
import 'partner_billing_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Pre-populate if this is a regular customer
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
            const SnackBar(
              content: Text('الرجاء إدخال بعض البيانات أو اختيار تخطي للمتابعة بنقدي عام مباشر', textAlign: TextAlign.right),
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
      dateStr = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    }

    String? timeStr;
    if (_selectedTime != null) {
      timeStr = "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}";
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
    final skipText = isGeneralCash ? 'تخطي والمتابعة كنقدي عام مباشر' : 'تخطي والمتابعة بدون بيانات توصيل';
    final titleText = isGeneralCash ? 'بيانات التوصيل والطلب المؤقت' : 'تحديد موعد التوصيل للعميل';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'معلومات الزبون المؤقت',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'اسم الزبون / العميل',
                            prefixIcon: Icon(Icons.person, color: Colors.teal),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            prefixIcon: Icon(Icons.phone, color: Colors.teal),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'عنوان التوصيل بالتفصيل',
                            prefixIcon: Icon(Icons.location_on, color: Colors.teal),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isGeneralCash) const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'موعد التسليم والملاحظات',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(context),
                              icon: const Icon(Icons.access_time, color: Colors.teal),
                              label: Text(
                                _selectedTime == null
                                    ? 'تحديد الوقت'
                                    : _selectedTime!.format(context),
                                style: const TextStyle(color: Colors.teal),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(context),
                              icon: const Icon(Icons.calendar_today, color: Colors.teal),
                              label: Text(
                                _selectedDate == null
                                    ? 'تحديد التاريخ'
                                    : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
                                style: const TextStyle(color: Colors.teal),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات إضافية حول الطلب والتوصيل',
                          prefixIcon: Icon(Icons.note_alt, color: Colors.teal),
                          border: OutlineInputBorder(),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'متابعة إلى سلة المنتجات ⬅',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _proceedToPOS(isSkipped: true),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  skipText,
                  style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
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
}
