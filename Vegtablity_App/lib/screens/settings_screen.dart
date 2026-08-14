import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../viewmodels/language_viewmodel.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
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
  bool _showRecipes = true;
  bool _showBarcodePrinting = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsProvider>(context, listen: false).fetchSettings();
    });
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
        _showRecipes = prefs.getBool('show_recipes') ?? true;
        _showBarcodePrinting = prefs.getBool('show_barcode_printing') ?? true;
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
          case 'show_recipes':
            _showRecipes = value;
            break;
          case 'show_barcode_printing':
            _showBarcodePrinting = value;
            break;
        }
      });
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('settings'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 72, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('غير مسموح بالوصول: هذه الشاشة مخصصة للمدير (Admin) فقط',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('الرجوع'),
              ),
            ],
          ),
        ),
      );
    }

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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    padding: const EdgeInsets.all(20.0),
                    children: [
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
                  if (Provider.of<SettingsProvider>(context).enableDailyOrders)
                    SwitchListTile(
                      title: Text(context.tr('home_daily_orders')),
                      value: _showDailyOrders,
                      onChanged: (val) => _saveBoolSetting('show_daily_orders', val),
                      activeColor: Colors.teal,
                    ),
                  if (Provider.of<SettingsProvider>(context).isProductionMode)
                    SwitchListTile(
                      title: Text(context.tr('home_recipes')),
                      value: _showRecipes,
                      onChanged: (val) => _saveBoolSetting('show_recipes', val),
                      activeColor: Colors.teal,
                    ),
                  SwitchListTile(
                    title: Text(context.tr('settings_show_barcode_print')),
                    value: _showBarcodePrinting,
                    onChanged: (val) => _saveBoolSetting('show_barcode_printing', val),
                    activeColor: Colors.teal,
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
