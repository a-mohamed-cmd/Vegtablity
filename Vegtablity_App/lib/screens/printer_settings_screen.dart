import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/printer_service.dart';
import '../core/localization/app_localizations.dart';

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
  int _selectedPaperSize = 80;
  String _selectedNetworkPrintMode = 'direct';
  int _selectedPrintCopies = 1;
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
        _selectedPaperSize = _printerService.paperSize;
        _selectedNetworkPrintMode = _printerService.networkPrintMode;
        _selectedPrintCopies = _printerService.printCopies;
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
      paperSize: _selectedPaperSize,
      networkPrintMode: _selectedNetworkPrintMode,
      printCopies: _selectedPrintCopies,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? context.tr('ps_save_success') : context.tr('ps_save_failed'),
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
          message = context.tr('ps_test_simulated');
          bgColor = Colors.blueGrey;
        } else {
          message = context.tr('ps_test_success');
          bgColor = Colors.green;
        }
      } else {
        message = context.tr('ps_test_failed');
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
        title: Text(context.tr('ps_screen_title')),
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
                  Text(
                    context.tr('ps_config_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                            printerService.isSynced ? context.tr('ps_synced') : context.tr('ps_offline'),
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
                    Text(context.tr('ps_conn_type'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedConnectionType,
                      alignment: AlignmentDirectional.centerEnd,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: 'None', child: Text(context.tr('ps_conn_none'), textAlign: TextAlign.right)),
                        DropdownMenuItem(value: 'Network', child: Text(context.tr('ps_conn_network'), textAlign: TextAlign.right)),
                        DropdownMenuItem(value: 'Bluetooth', child: Text(context.tr('ps_conn_bluetooth'), textAlign: TextAlign.right)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedConnectionType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('حجم ورق الطباعة الحراري', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: _selectedPaperSize,
                      alignment: AlignmentDirectional.centerEnd,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 58, child: Text('58 ملم (Mobile/Sunmi)', textAlign: TextAlign.right)),
                        DropdownMenuItem(value: 80, child: Text('80 ملم (Desktop/Standard)', textAlign: TextAlign.right)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPaperSize = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_selectedConnectionType == 'Network') ...[
                      Text(context.tr('ps_ip_label'), textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ipController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '192.168.1.100'),
                      ),
                      const SizedBox(height: 16),
                      Text(context.tr('ps_port_label'), textAlign: TextAlign.right),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '9100'),
                      ),
                      const SizedBox(height: 16),
                      Text(context.tr('ps_network_mode_label'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedNetworkPrintMode,
                        alignment: AlignmentDirectional.centerEnd,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: [
                          DropdownMenuItem(
                            value: 'direct',
                            child: Text(context.tr('ps_network_mode_direct'), textAlign: TextAlign.right),
                          ),
                          DropdownMenuItem(
                            value: 'raster',
                            child: Text(context.tr('ps_network_mode_raster'), textAlign: TextAlign.right),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedNetworkPrintMode = val);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('ps_network_mode_desc'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text('عدد نسخ الطباعة (Print Copies)', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _selectedPrintCopies,
                        alignment: AlignmentDirectional.centerEnd,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 نسخة', textAlign: TextAlign.right)),
                          DropdownMenuItem(value: 2, child: Text('2 نسختان (مزدوج)', textAlign: TextAlign.right)),
                          DropdownMenuItem(value: 3, child: Text('3 ثلاث نسخ', textAlign: TextAlign.right)),
                          DropdownMenuItem(value: 4, child: Text('4 أربع نسخ', textAlign: TextAlign.right)),
                          DropdownMenuItem(value: 5, child: Text('5 خمس نسخ', textAlign: TextAlign.right)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPrintCopies = val);
                          }
                        },
                      ),
                    ],
                    if (_selectedConnectionType == 'Bluetooth') ...[
                      Text(context.tr('ps_bt_device'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
                                child: Text(context.tr('ps_bt_clear'), style: const TextStyle(color: Colors.red)),
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
                                    Text(
                                      context.tr('ps_bt_selected'),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                          label: Text(_isScanning ? context.tr('ps_bt_scan_searching') : context.tr('ps_bt_scan_button')),
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
                            ],
                          ),
                        ),
                        Center(child: Text(context.tr('ps_bt_scan_desc'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
                      ] else if (_foundDevices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(context.tr('ps_bt_found'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            label: Text(context.tr('ps_test_print_btn')),
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
                            label: Text(context.tr('ps_save_btn')),
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
