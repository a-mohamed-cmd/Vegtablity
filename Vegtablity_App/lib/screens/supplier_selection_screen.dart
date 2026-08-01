import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';
import 'pos_screen.dart';
import 'temp_order_screen.dart';

class PartnerSelectionScreen extends StatefulWidget {
  final String type; // 'Sales' (Customer) or 'Purchase' (Supplier)
  final bool isSelectionOnly;
  const PartnerSelectionScreen({super.key, required this.type, this.isSelectionOnly = false});

  @override
  State<PartnerSelectionScreen> createState() => _PartnerSelectionScreenState();
}

class _PartnerSelectionScreenState extends State<PartnerSelectionScreen> {
  List<dynamic> _partners = [];
  List<dynamic> _filteredPartners = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchPartners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPartners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final String partnerType = widget.type == 'Sales' ? 'Customer' : 'Supplier';
      final response = await apiService.getPartners(type: partnerType);

      if (response.statusCode == 200) {
        setState(() {
          _partners = response.data ?? [];
          _filteredPartners = _partners;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = widget.type == 'Sales'
              ? context.tr('ps_fetch_customer_failed')
              : context.tr('ps_fetch_supplier_failed');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '${context.tr('ps_conn_error')}$e';
        _isLoading = false;
      });
    }
  }

  void _filterPartners(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredPartners = _partners;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase().trim();
    setState(() {
      _filteredPartners = _partners.where((partner) {
        final name = (partner['PartnerName'] ?? '').toString().toLowerCase();
        final phone = (partner['Phone'] ?? '').toString().toLowerCase();
        final accId = (partner['AccountID'] ?? '').toString().toLowerCase();
        final accCode = (partner['AccountCode'] ?? '').toString().toLowerCase();
        return name.contains(lowercaseQuery) || 
               phone.contains(lowercaseQuery) ||
               accId.contains(lowercaseQuery) ||
               accCode.contains(lowercaseQuery);
      }).toList();
    });
  }

  void _selectPartner(Map<String, dynamic> partner) async {
    if (widget.isSelectionOnly) {
      // If we opened this screen as a sub-route to change the customer/supplier, we return the chosen partner!
      Navigator.pop(context, partner);
    } else {
      // Check if temporary order mode is enabled for sales customers
      if (widget.type == 'Sales') {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final dbMode = settingsProvider.deliverySystemMode;
        final prefs = await SharedPreferences.getInstance();
        final mode = (dbMode != null && dbMode.isNotEmpty) ? dbMode : (prefs.getString('cash_sale_mode') ?? 'direct');
        if (mode == 'temp_order' && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TemporaryOrderScreen(
                type: widget.type,
                partner: partner,
              ),
            ),
          ).then((_) {
            if (mounted) {
              _focusNode.requestFocus();
            }
          });
          return;
        }
      }

      // Otherwise, open POS directly
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PosScreen(
              type: widget.type,
              partner: partner,
            ),
          ),
        ).then((_) {
          if (mounted) {
            _focusNode.requestFocus();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSales = widget.type == 'Sales';
    return Scaffold(
      appBar: AppBar(
        title: Text(isSales ? context.tr('ps_title_customer') : context.tr('ps_title_supplier'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSales 
                  ? [Colors.green, Colors.teal] 
                  : [Colors.orange, Colors.deepOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPartners,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Card
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: isSales 
                      ? context.tr('ps_search_customer_hint')
                      : context.tr('ps_search_supplier_hint'),
                  prefixIcon: Icon(Icons.search, color: isSales ? Colors.teal : Colors.orange),
                  border: InputBorder.none,
                ),
                onChanged: _filterPartners,
              ),
            ),
          ),
          
          // Partner List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: isSales ? Colors.teal : Colors.orange))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchPartners,
                              style: ElevatedButton.styleFrom(backgroundColor: isSales ? Colors.teal : Colors.orange),
                              child: Text(context.tr('ps_retry'), style: const TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      )
                    : (_filteredPartners.isEmpty && !isSales)
                        ? Center(child: Text(context.tr('ps_no_results_supplier'), style: const TextStyle(fontSize: 16)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: _filteredPartners.length + (isSales ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (isSales && index == 0) {
                                final Map<String, dynamic> generalCashPartner = {
                                  'PartnerID': null,
                                  'PartnerName': context.tr('ps_general_cash_label'),
                                  'AccountCode': 'حساب عام',
                                  'CurrentBalance': 0.0,
                                  'Phone': '',
                                };
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  elevation: 3,
                                  color: Colors.teal.shade50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.teal.shade200, width: 1),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    title: Text(
                                      context.tr('ps_general_cash_label'),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          context.tr('ps_general_cash_sub'),
                                          style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    leading: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '0.000 KWD',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(context.tr('ps_general_cash_desc'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.flash_on, size: 20, color: Colors.teal),
                                    onTap: () => _selectPartner(generalCashPartner),
                                  ),
                                );
                              }

                              final int actualIndex = isSales ? index - 1 : index;
                              final Map<String, dynamic> partner = Map<String, dynamic>.from(_filteredPartners[actualIndex]);
                              final double balance = (partner['CurrentBalance'] as num?)?.toDouble() ?? 0.0;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(
                                    partner['PartnerName'] ?? context.tr('ps_unknown_partner'),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '${context.tr('ps_account_code_label')}${partner['AccountCode'] ?? partner['AccountID'] ?? context.tr('ps_no_account_code')}',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                      ),
                                      if (partner['Phone'] != null && partner['Phone'].toString().trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${context.tr('ps_phone_label')}${partner['Phone']}',
                                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                        ),
                                      ],
                                    ],
                                  ),
                                   leading: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${balance.toStringAsFixed(3)} KWD',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: balance >= 0 ? Colors.green[700]! : Colors.red,
                                        ),
                                      ),
                                      Text(
                                        balance >= 0 ? context.tr('ps_balance_credit') : context.tr('ps_balance_debit'),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(Icons.arrow_back_ios, size: 16, color: isSales ? Colors.teal : Colors.orange),
                                  onTap: () => _selectPartner(partner),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
