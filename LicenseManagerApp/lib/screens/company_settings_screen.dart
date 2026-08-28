import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/license_provider.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _currencyController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _deliverySystemModeController;

  bool _productionMode = false;
  bool _useCustomInvoiceDesign = false;
  bool _useDetailedInvoiceDesign = false;
  bool _unifiedPartnerSearch = false;
  bool _enableDailyOrders = false;
  bool _enableSalesDiscounts = false;
  bool _enableHR = false;
  String? _lastSyncedDb;


  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _currencyController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _deliverySystemModeController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LicenseProvider>(context, listen: false);
      if (provider.databases.isEmpty) {
        provider.fetchDatabases();
      } else if (provider.selectedDatabase != null) {
        provider.fetchCompanySettings(provider.selectedDatabase!);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _deliverySystemModeController.dispose();
    super.dispose();
  }

  void _syncSettings(Map<String, dynamic>? settings, String? currentDb) {
    if (settings != null) {
      _nameController.text = settings['CompanyName']?.toString() ?? '';
      _currencyController.text = settings['CurrencySymbol']?.toString() ?? '';
      _addressController.text = settings['Address']?.toString() ?? '';
      _phoneController.text = settings['Phone']?.toString() ?? '';

      _productionMode = settings['ProductionMode'] == true || settings['ProductionMode'] == 1 || settings['ProductionMode'] == '1';
      _useCustomInvoiceDesign = settings['UseCustomInvoiceDesign'] == true || settings['UseCustomInvoiceDesign'] == 1 || settings['UseCustomInvoiceDesign'] == '1';
      _useDetailedInvoiceDesign = settings['UseDetailedInvoiceDesign'] == true || settings['UseDetailedInvoiceDesign'] == 1 || settings['UseDetailedInvoiceDesign'] == '1';
      _unifiedPartnerSearch = settings['UnifiedPartnerSearch'] == true || settings['UnifiedPartnerSearch'] == 1 || settings['UnifiedPartnerSearch'] == '1';
      _enableDailyOrders = settings['EnableDailyOrders'] == true || settings['EnableDailyOrders'] == 1 || settings['EnableDailyOrders'] == '1';
      _enableSalesDiscounts = settings['EnableSalesDiscounts'] == true || settings['EnableSalesDiscounts'] == 1 || settings['EnableSalesDiscounts'] == '1';
      _enableHR = settings['EnableHR'] == true || settings['EnableHR'] == 1 || settings['EnableHR'] == '1';
      _deliverySystemModeController.text = settings['DeliverySystemMode']?.toString() ?? '';

      _lastSyncedDb = currentDb;
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenseProvider = Provider.of<LicenseProvider>(context);
    final selectedDb = licenseProvider.selectedDatabase;
    final settings = licenseProvider.companySettings;

    if (_lastSyncedDb != selectedDb && settings != null) {
      _syncSettings(settings, selectedDb);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text("الخصائص وتفضيلات النظام"),
        backgroundColor: const Color(0xFF252538),
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Database Selector Card
                    Card(
                      color: const Color(0xFF252538),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.storage_rounded, color: Colors.amber, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: licenseProvider.isLoading
                                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                                  : DropdownButtonFormField<String>(
                                      value: licenseProvider.selectedDatabase,
                                      dropdownColor: const Color(0xFF252538),
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      items: licenseProvider.databases.map((db) {
                                        return DropdownMenuItem<String>(
                                          value: db,
                                          child: Text(db),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          licenseProvider.selectDatabase(val);
                                        }
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (licenseProvider.isSettingsLoading)
                      const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator(color: Colors.amber)),
                      )
                    else if (selectedDb == null)
                      const Card(
                        color: Color(0xFF252538),
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              "يرجى اختيار قاعدة بيانات من القائمة أعلى للتحكم بإعداداتها.",
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // System Features Toggles Card
                      Card(
                        color: const Color(0xFF252538),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.vpn_key, color: Colors.amber, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    "تفضيلات وخيارات تفعيل النظام:",
                                    style: TextStyle(color: Colors.amber, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                activeColor: Colors.tealAccent,
                                title: const Text(
                                  "تفعيل وضع الوصفات والتصنيع (ProductionMode)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "إظهار أو إخفاء قوائم وكروت وصفات المنتجات وتصنيع المواد الخام بالمنظومة بالكامل",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _productionMode,
                                onChanged: (val) => setState(() => _productionMode = val),
                              ),
                              const Divider(color: Colors.white10),
                              SwitchListTile(
                                activeColor: Colors.amber,
                                title: const Text(
                                  "تفعيل التصميم المخصص للفاتورة (UseCustomInvoiceDesign)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "اعتماد نموذج الفواتير المخصص الجديد عند الطباعة",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _useCustomInvoiceDesign,
                                onChanged: (val) => setState(() => _useCustomInvoiceDesign = val),
                              ),
                              const Divider(color: Colors.white10),
                              SwitchListTile(
                                activeColor: Colors.blueAccent,
                                title: const Text(
                                  "تفعيل التصميم التفصيلي للفاتورة (UseDetailedInvoiceDesign)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "طباعة جداول الفواتير بالتفاصيل والبيانات الموسعة ورأس الفاتورة الموحد",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _useDetailedInvoiceDesign,
                                onChanged: (val) => setState(() => _useDetailedInvoiceDesign = val),
                              ),
                              const Divider(color: Colors.white10),
                              SwitchListTile(
                                activeColor: Colors.purpleAccent,
                                title: const Text(
                                  "تفعيل البحث الموحد (UnifiedPartnerSearch)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "دمج العملاء والموردين معاً في قوائم البحث بشاشات الفواتير",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _unifiedPartnerSearch,
                                onChanged: (val) => setState(() => _unifiedPartnerSearch = val),
                              ),
                              const Divider(color: Colors.white10),
                              SwitchListTile(
                                activeColor: Colors.lightGreenAccent,
                                title: const Text(
                                  "تفعيل ميزة الطلبات اليومية والتوصيل (EnableDailyOrders)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "إظهار والتحكم بصلاحيات وشاشات الطلبات اليومية والتوصيل للعملاء",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _enableDailyOrders,
                                onChanged: (val) => setState(() => _enableDailyOrders = val),
                              ),
                              const Divider(color: Colors.white10),
                              SwitchListTile(
                                activeColor: Colors.orangeAccent,
                                title: const Text(
                                  "تفعيل ميزة خصومات وباقات المبيعات (EnableSalesDiscounts)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "إظهار والتحكم بصلاحيات وشاشات وباقات خصومات المنتجات بالفواتير وتطبيق POS",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _enableSalesDiscounts,
                                onChanged: (val) => setState(() => _enableSalesDiscounts = val),
                              ),
                              const Divider(color: Colors.white10),
                              SwitchListTile(
                                activeColor: Colors.cyanAccent,
                                title: const Text(
                                  "تفعيل نظام الموارد البشرية والرواتب (EnableHR)",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: const Text(
                                  "إظهار والتحكم بقوائم وصلاحيات وشاشات الموارد البشرية، الموظفين، الإجازات، والرواتب",
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                value: _enableHR,
                                onChanged: (val) => setState(() => _enableHR = val),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: ['direct', 'temp_order'].contains(_deliverySystemModeController.text.trim())
                                    ? _deliverySystemModeController.text.trim()
                                    : 'direct',
                                dropdownColor: const Color(0xFF252538),
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: const InputDecoration(
                                  labelText: "نظام ومواعيد التوصيل (DeliverySystemMode)",
                                  labelStyle: TextStyle(color: Colors.grey),
                                  prefixIcon: Icon(Icons.local_shipping, color: Colors.amber),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'direct',
                                    child: Text('direct', style: TextStyle(color: Colors.white)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'temp_order',
                                    child: Text('temp_order', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _deliverySystemModeController.text = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // General Company Settings Card
                      Card(
                        color: const Color(0xFF252538),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.business, color: Colors.amber, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    "بيانات المؤسسة والعملة العامة:",
                                    style: TextStyle(color: Colors.amber, fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "اسم الشركة / المؤسسة",
                                  labelStyle: TextStyle(color: Colors.grey),
                                  prefixIcon: Icon(Icons.store, color: Colors.grey),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _currencyController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "رمز العملة (مثال: د.ك)",
                                  labelStyle: TextStyle(color: Colors.grey),
                                  prefixIcon: Icon(Icons.monetization_on, color: Colors.grey),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Save Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final payload = {
                            'ProductionMode': _productionMode,
                            'UseCustomInvoiceDesign': _useCustomInvoiceDesign,
                            'UseDetailedInvoiceDesign': _useDetailedInvoiceDesign,
                            'UnifiedPartnerSearch': _unifiedPartnerSearch,
                            'CompanyName': _nameController.text.trim(),
                            'CurrencySymbol': _currencyController.text.trim(),
                            'Address': _addressController.text.trim(),
                            'Phone': _phoneController.text.trim(),
                            'EnableDailyOrders': _enableDailyOrders,
                            'EnableSalesDiscounts': _enableSalesDiscounts,
                            'EnableHR': _enableHR,
                            'DeliverySystemMode': _deliverySystemModeController.text.trim(),
                          };

                          final res = await licenseProvider.saveCompanySettings(payload);
                          if (res && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green,
                                content: Text("تم حفظ خيارات وإعدادات النظام لقاعدة البيانات [ $selectedDb ] بنجاح! 💾"),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save, color: Color(0xFF1E1E2E), size: 24),
                        label: const Text(
                          "حفظ إعدادات النظام 💾",
                          style: TextStyle(color: Color(0xFF1E1E2E), fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
