import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../viewmodels/language_viewmodel.dart';
import '../core/localization/app_localizations.dart';
import '../models/language_model.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  String _selectedSalesMode = 'direct';
  bool _isLoading = true;

  bool _showNewInvoice = true;
  bool _showNewPurchase = true;
  bool _showCustomerSales = true;
  bool _showSupplierPurchases = true;
  bool _showCustomerReceipts = true;
  bool _showSupplierPayments = true;
  bool _showStockTake = true;
  bool _showWastage = true;
  bool _showDailyOrders = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedSalesMode = prefs.getString('cash_sale_mode') ?? 'direct';
        _showNewInvoice = prefs.getBool('show_new_invoice') ?? true;
        _showNewPurchase = prefs.getBool('show_new_purchase') ?? true;
        _showCustomerSales = prefs.getBool('show_customer_sales') ?? true;
        _showSupplierPurchases = prefs.getBool('show_supplier_purchases') ?? true;
        _showCustomerReceipts = prefs.getBool('show_customer_receipts') ?? true;
        _showSupplierPayments = prefs.getBool('show_supplier_payments') ?? true;
        _showStockTake = prefs.getBool('show_stocktake') ?? true;
        _showWastage = prefs.getBool('show_wastage') ?? true;
        _showDailyOrders = prefs.getBool('show_daily_orders') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSalesMode(String mode) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cash_sale_mode', mode);
      setState(() {
        _selectedSalesMode = mode;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('settings_save_success'), textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('settings_save_error'), textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      setState(() {
        switch (key) {
          case 'show_new_invoice':
            _showNewInvoice = value;
            break;
          case 'show_new_purchase':
            _showNewPurchase = value;
            break;
          case 'show_customer_sales':
            _showCustomerSales = value;
            break;
          case 'show_supplier_purchases':
            _showSupplierPurchases = value;
            break;
          case 'show_customer_receipts':
            _showCustomerReceipts = value;
            break;
          case 'show_supplier_payments':
            _showSupplierPayments = value;
            break;
          case 'show_stocktake':
            _showStockTake = value;
            break;
          case 'show_wastage':
            _showWastage = value;
            break;
          case 'show_daily_orders':
            _showDailyOrders = value;
            break;
        }
      });
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings')),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  const Text(
                    'نظام التوصيل ومواعيد التسليم',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر ما إذا كنت ترغب بتطبيق نظام توصيل وتسجيل مواعيد شحن الطلبات للعملاء أو تفضل البيع المباشر الفوري.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedSalesMode,
                    alignment: AlignmentDirectional.centerEnd,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'direct', child: Text('بيع مباشر بدون توصيل', textAlign: TextAlign.right)),
                      DropdownMenuItem(value: 'temp_order', child: Text('تطبيق نظام التوصيل', textAlign: TextAlign.right)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _saveSalesMode(val);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('language'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer<LanguageViewModel>(
                    builder: (context, langVm, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: LanguageModel.supportedLanguages.map((lang) {
                          final isSelected = langVm.appLocale.languageCode == lang.languageCode;
                          return ChoiceChip(
                            label: Text(
                              lang.languageCode == 'ar' ? context.tr('arabic') : context.tr('english'),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal,
                            onSelected: (selected) {
                              if (selected) {
                                langVm.changeLanguage(lang.languageCode);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('settings_home_modules_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('settings_home_modules_desc'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(context.tr('home_classic_new_invoice')),
                    value: _showNewInvoice,
                    onChanged: (val) => _saveBoolSetting('show_new_invoice', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_premium_customer_sales')),
                    value: _showCustomerSales,
                    onChanged: (val) => _saveBoolSetting('show_customer_sales', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_classic_new_purchase')),
                    value: _showNewPurchase,
                    onChanged: (val) => _saveBoolSetting('show_new_purchase', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_premium_supplier_purchases')),
                    value: _showSupplierPurchases,
                    onChanged: (val) => _saveBoolSetting('show_supplier_purchases', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_premium_customer_receipts')),
                    value: _showCustomerReceipts,
                    onChanged: (val) => _saveBoolSetting('show_customer_receipts', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_premium_supplier_payments')),
                    value: _showSupplierPayments,
                    onChanged: (val) => _saveBoolSetting('show_supplier_payments', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_classic_stocktake')),
                    value: _showStockTake,
                    onChanged: (val) => _saveBoolSetting('show_stocktake', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_classic_wastage')),
                    value: _showWastage,
                    onChanged: (val) => _saveBoolSetting('show_wastage', val),
                    activeColor: Colors.teal,
                  ),
                  SwitchListTile(
                    title: Text(context.tr('home_daily_orders')),
                    value: _showDailyOrders,
                    onChanged: (val) => _saveBoolSetting('show_daily_orders', val),
                    activeColor: Colors.teal,
                  ),
                ],
              ),
            ),
    );
  }
}
