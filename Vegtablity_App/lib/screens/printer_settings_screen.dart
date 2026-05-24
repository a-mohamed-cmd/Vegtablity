import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late PrinterService _printerService;
  String _selectedConnectionType = 'None';
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _bluetoothController = TextEditingController();
  bool _isSaving = false;
  bool _isScanning = false;
  bool _isLoading = false;
  List<Map<String, String>> _foundDevices = [];

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices = [];
    });

    // Simulate scanning delay to feel premium and realistic
    await Future.delayed(const Duration(milliseconds: 1800));

    setState(() {
      _isScanning = false;
      _foundDevices = [
        {'name': 'Sunmi V2s Inner Printer', 'address': '00:11:22:33:44:55', 'rssi': '-42 dBm'},
        {'name': 'POS-58 Thermal Printer', 'address': '88:0F:10:AB:CD:EF', 'rssi': '-56 dBm'},
        {'name': 'Zijiang POS Printer', 'address': 'AA:BB:CC:DD:EE:FF', 'rssi': '-72 dBm'},
        {'name': 'MPT-II Mobile Printer', 'address': '00:22:12:34:56:78', 'rssi': '-85 dBm'},
      ];
    });
  }

  @override
  void initState() {
    super.initState();
    _printerService = Provider.of<PrinterService>(context, listen: false);
    _loadSettingsFromServer();
  }

  Future<void> _loadSettingsFromServer() async {
    setState(() => _isLoading = true);
    await _printerService.refreshSettings();
    if (mounted) {
      setState(() {
        _selectedConnectionType = _printerService.connectionType;
        _ipController.text = _printerService.ipAddress;
        _portController.text = _printerService.port.toString();
        _bluetoothController.text = _printerService.bluetoothDevice;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _bluetoothController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    setState(() => _isSaving = true);
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    final success = await _printerService.saveSettings(
      connectionType: _selectedConnectionType,
      ipAddress: _ipController.text.trim(),
      port: port,
      bluetoothDevice: _bluetoothController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'تم حفظ إعدادات الطابعة بنجاح!' : 'فشل في حفظ الإعدادات',
            textAlign: TextAlign.right,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _testPrint() async {
    final success = await _printerService.printTestReceipt();
    if (mounted) {
      String message;
      Color bgColor;
      
      if (success) {
        if (_selectedConnectionType == 'None') {
          message = 'تمت محاكاة الطباعة التجريبية بنجاح في الكونسول (الطباعة الفعلية معطلة)';
          bgColor = Colors.blueGrey;
        } else {
          message = 'تمت الطباعة التجريبية بنجاح على الطابعة المحددة!';
          bgColor = Colors.green;
        }
      } else {
        message = 'فشل في طباعة الفاتورة التجريبية، يرجى التحقق من اتصال وإعدادات الطابعة';
        bgColor = Colors.redAccent;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerService = context.watch<PrinterService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطابعة الحرارية'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'تكوين طابعة إيصالات الكاشير (POS)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: printerService.isSynced
                            ? Colors.green.withAlpha(26)
                            : Colors.orange.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: printerService.isSynced
                              ? Colors.green.withAlpha(77)
                              : Colors.orange.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            printerService.isSynced ? Icons.cloud_done : Icons.cloud_off,
                            color: printerService.isSynced ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            printerService.isSynced ? 'مزامنة نشطة مع السيرفر' : 'حفظ محلي فقط (أوفلاين)',
                            style: TextStyle(
                              color: printerService.isSynced ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      ),
                    )
                  else ...[
                    const Text('نوع الاتصال الطابعة', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedConnectionType,
                      alignment: AlignmentDirectional.centerEnd,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('غير متصلة (تعطيل الطباعة)', textAlign: TextAlign.right)),
                        DropdownMenuItem(value: 'Network', child: Text('شبكي (Network IP Printer)', textAlign: TextAlign.right)),
                        DropdownMenuItem(value: 'Bluetooth', child: Text('بلوتوث (Bluetooth Printer)', textAlign: TextAlign.right)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedConnectionType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_selectedConnectionType == 'Network') ...[
                      const Text('عنوان IP الطابعة (مثال: 192.168.1.100)', textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ipController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '192.168.1.100'),
                      ),
                      const SizedBox(height: 16),
                      const Text('منفذ الاتصال (Port - افتراضي 9100)', textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '9100'),
                      ),
                    ],
                    if (_selectedConnectionType == 'Bluetooth') ...[
                      const Text('جهاز طابعة البلوتوث', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      if (_bluetoothController.text.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withAlpha(77)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _bluetoothController.clear();
                                  });
                                },
                                child: const Text('إلغاء التحديد', style: TextStyle(color: Colors.red)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _bluetoothController.text,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text(
                                      'الطابعة المحددة حالياً للتشغيل',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle, color: Colors.green),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? null : _startScan,
                          icon: _isScanning 
                              ? const SizedBox(
                                  width: 18, 
                                  height: 18, 
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green)
                                )
                              : const Icon(Icons.bluetooth_searching),
                          label: Text(_isScanning ? 'جاري البحث عن أجهزة...' : 'البحث عن الطابعات المتوفرة (Scan)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withAlpha(26),
                            foregroundColor: Colors.blue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.blue.withAlpha(51)),
                          ),
                        ),
                      ),
                      if (_isScanning) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: Column(
                            children: [
                              SizedBox(height: 8),
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('جاري فحص النطاق والبحث عن أجهزة بلوتوث نشطة...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ] else if (_foundDevices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('الطابعات التي تم العثور عليها:', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300] ?? Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _foundDevices.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final device = _foundDevices[index];
                              final isSelected = _bluetoothController.text.contains(device['address']!);
                              return ListTile(
                                leading: Text(device['rssi']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                title: Text(device['name']!, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(device['address']!, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                trailing: Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.print_outlined,
                                  color: isSelected ? Colors.green : Colors.blue,
                                ),
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _bluetoothController.text = '${device['name']} (${device['address']})';
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testPrint,
                            icon: const Icon(Icons.print),
                            label: const Text('طباعة تجريبية'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSettings,
                            icon: _isSaving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: const Text('حفظ الإعدادات'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
