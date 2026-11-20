import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/app_snackbar.dart';
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
        _errorMessage = DbErrorHelper.format(e);
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
    final Color accentColor =
        isSales ? const Color(0xFF0F766E) : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          isSales
              ? context.tr('ps_title_customer')
              : context.tr('ps_title_supplier'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSales
                  ? const [Color(0xFF0F766E), Color(0xFF0D9488)]
                  : const [Color(0xFFB45309), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchPartners,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: isSales
                    ? context.tr('ps_search_customer_hint')
                    : context.tr('ps_search_supplier_hint'),
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search_rounded, color: accentColor),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accentColor, width: 1.4),
                ),
              ),
              onChanged: _filterPartners,
            ),
          ),

          // Partner List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFE11D48), size: 44),
                                const SizedBox(height: 10),
                                Text(
                                  _errorMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF991B1B), fontSize: 15),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _fetchPartners,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(context.tr('ps_retry')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : (_filteredPartners.isEmpty && !isSales)
                        ? Center(
                            child: Text(
                              context.tr('ps_no_results_supplier'),
                              style: const TextStyle(
                                  fontSize: 16, color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            itemCount:
                                _filteredPartners.length + (isSales ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (isSales && index == 0) {
                                final Map<String, dynamic> generalCashPartner =
                                    {
                                  'PartnerID': null,
                                  'PartnerName':
                                      context.tr('ps_general_cash_label'),
                                  'AccountCode': 'حساب عام',
                                  'CurrentBalance': 0.0,
                                  'Phone': '',
                                };
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFECFDF5),
                                        Color(0xFFF0FDFA)
                                      ],
                                      begin: Alignment.topRight,
                                      end: Alignment.bottomLeft,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFF99F6E4),
                                        width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F766E)
                                            .withValues(alpha: 0.07),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () =>
                                          _selectPartner(generalCashPartner),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 46,
                                              height: 46,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F766E),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                              ),
                                              child: const Icon(
                                                  Icons.flash_on_rounded,
                                                  color: Colors.white,
                                                  size: 24),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.tr(
                                                        'ps_general_cash_label'),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15.5,
                                                      color: Color(0xFF0F766E),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    context.tr(
                                                        'ps_general_cash_sub'),
                                                    style: const TextStyle(
                                                      color: Color(0xFF0D9488),
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                const Text(
                                                  '0.000 KWD',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                Text(
                                                  context.tr(
                                                      'ps_general_cash_desc'),
                                                  style: const TextStyle(
                                                      fontSize: 10.5,
                                                      color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final int actualIndex =
                                  isSales ? index - 1 : index;
                              final Map<String, dynamic> partner =
                                  Map<String, dynamic>.from(
                                      _filteredPartners[actualIndex]);
                              final double balance =
                                  (partner['CurrentBalance'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                              final String partnerName =
                                  partner['PartnerName'] ??
                                      context.tr('ps_unknown_partner');
                              final String initial = partnerName.isNotEmpty
                                  ? partnerName.substring(0, 1)
                                  : '?';
                              final bool isCredit = balance >= 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _selectPartner(partner),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(
                                                  alpha: 0.11),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              initial,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  partnerName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${context.tr('ps_account_code_label')}${partner['AccountCode'] ?? partner['AccountID'] ?? context.tr('ps_no_account_code')}',
                                                  style: const TextStyle(
                                                      color: Color(0xFF64748B),
                                                      fontSize: 12),
                                                ),
                                                if (partner['Phone'] != null &&
                                                    partner['Phone']
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.phone_outlined,
                                                          size: 13,
                                                          color: Color(
                                                              0xFF64748B)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${partner['Phone']}',
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFF475569),
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isCredit
                                                  ? const Color(0xFFECFDF5)
                                                  : const Color(0xFFFFF1F2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isCredit
                                                    ? const Color(0xFFA7F3D0)
                                                    : const Color(0xFFFECDD3),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${balance.toStringAsFixed(3)} KWD',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    color: isCredit
                                                        ? const Color(
                                                            0xFF047857)
                                                        : const Color(
                                                            0xFFBE123C),
                                                  ),
                                                ),
                                                Text(
                                                  isCredit
                                                      ? context.tr(
                                                          'ps_balance_credit')
                                                      : context.tr(
                                                          'ps_balance_debit'),
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
