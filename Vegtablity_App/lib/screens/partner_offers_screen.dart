// Imports
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/utils/app_snackbar.dart';
import 'partner_billing_screen.dart';
import 'temp_order_screen.dart';

class PartnerOffersScreen extends StatefulWidget {
  final String type; // 'Sales' or 'Purchases'
  const PartnerOffersScreen({super.key, required this.type});

  @override
  State<PartnerOffersScreen> createState() => _PartnerOffersScreenState();
}

class _PartnerOffersScreenState extends State<PartnerOffersScreen> {
  List<dynamic> _partners = [];
  List<dynamic> _filteredPartners = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchActivePartners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchActivePartners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = widget.type == 'Sales'
          ? await apiService.getActiveSalesPartners()
          : await apiService.getActivePurchasePartners();

      if (response.statusCode == 200) {
        setState(() {
          _partners = response.data ?? [];
          _filteredPartners = _partners;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = context.tr('po_error_fetch_partners');
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

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredPartners = _partners.where((partner) {
        final name = (partner['PartnerName'] ?? '').toString().toLowerCase();
        final phone = (partner['Phone'] ?? '').toString().toLowerCase();
        return name.contains(lowercaseQuery) || phone.contains(lowercaseQuery);
      }).toList();
    });
  }

  Future<void> _selectPartner(Map<String, dynamic> partner) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.teal),
                const SizedBox(height: 16),
                Text(context.tr('po_loading_quote'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      int? activeQuoteId;
      List<dynamic> quoteDetails = [];

      if (widget.type == 'Sales') {
        // Fetch sales quotes & filter by PartnerID
        final quotesRes = await apiService.getSalesQuotes();
        if (quotesRes.statusCode == 200) {
          final List<dynamic> quotes = quotesRes.data ?? [];
          final partnerQuotes = quotes
              .where((q) => q['PartnerID'] == partner['PartnerID'])
              .toList();

          if (partnerQuotes.isNotEmpty) {
            // Sort by QuoteDate or QuoteID descending to get the latest
            partnerQuotes.sort(
                (a, b) => (b['QuoteID'] ?? 0).compareTo(a['QuoteID'] ?? 0));
            activeQuoteId = partnerQuotes.first['QuoteID'];

            // Get details
            final detailsRes =
                await apiService.getSalesQuoteDetails(activeQuoteId!);
            if (detailsRes.statusCode == 200) {
              quoteDetails = detailsRes.data ?? [];
            }
          }
        }
      } else {
        // Fetch purchase quotes & filter by PartnerID
        final quotesRes = await apiService.getPurchaseQuotes();
        if (quotesRes.statusCode == 200) {
          final List<dynamic> quotes = quotesRes.data ?? [];
          final partnerQuotes = quotes
              .where((q) => q['PartnerID'] == partner['PartnerID'])
              .toList();

          if (partnerQuotes.isNotEmpty) {
            partnerQuotes.sort((a, b) => (b['PurchaseQuoteID'] ?? 0)
                .compareTo(a['PurchaseQuoteID'] ?? 0));
            activeQuoteId = partnerQuotes.first['PurchaseQuoteID'];

            // Get details
            final detailsRes =
                await apiService.getPurchaseQuoteDetails(activeQuoteId!);
            if (detailsRes.statusCode == 200) {
              quoteDetails = detailsRes.data ?? [];
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (activeQuoteId == null || quoteDetails.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('po_no_active_quote'),
                  textAlign: TextAlign.right),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Navigate to Billing Screen or Temporary Order Screen with the quote details
      if (mounted) {
        if (widget.type == 'Sales') {
          final settingsProvider =
              Provider.of<SettingsProvider>(context, listen: false);
          final dbMode = settingsProvider.deliverySystemMode;
          final prefs = await SharedPreferences.getInstance();
          final mode = (dbMode != null && dbMode.isNotEmpty)
              ? dbMode
              : (prefs.getString('cash_sale_mode') ?? 'direct');
          if (mode == 'temp_order') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TemporaryOrderScreen(
                  type: widget.type,
                  partner: partner,
                  quoteId: activeQuoteId!,
                  allowedItems: List<Map<String, dynamic>>.from(quoteDetails),
                ),
              ),
            );
            return;
          }
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerBillingScreen(
              partner: partner,
              type: widget.type,
              quoteId: activeQuoteId!,
              allowedItems: List<Map<String, dynamic>>.from(quoteDetails),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        AppSnackBar.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'Sales'
        ? context.tr('po_sales_partners_title')
        : context.tr('po_purchases_partners_title');
    final primaryColor = widget.type == 'Sales'
        ? const Color(0xFF2563EB)
        : const Color(0xFFD97706);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.type == 'Sales'
                  ? const [Color(0xFF1D4ED8), Color(0xFF0D9488)]
                  : const [Color(0xFFB45309), Color(0xFFEA580C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Modern Elegant Search Area
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterPartners,
                decoration: InputDecoration(
                  hintText: context.tr('po_search_hint'),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _filterPartners('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),

            // Loading / Error / Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      size: 52, color: Color(0xFFE11D48)),
                                  const SizedBox(height: 12),
                                  Text(_errorMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF475569))),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: _fetchActivePartners,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: Text(context.tr('po_retry')),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _filteredPartners.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.people_outline_rounded,
                                      size: 64, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 14),
                                  Text(
                                    context.tr('po_no_partners_found'),
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        color: Color(0xFF64748B)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _filteredPartners.length,
                              itemBuilder: (context, index) {
                                final partner = _filteredPartners[index];
                                final String name =
                                    partner['PartnerName'] ?? '';
                                final String phone = partner['Phone'] ??
                                    context.tr('po_no_phone');
                                final String address = partner['Address'] ??
                                    context.tr('po_no_address');
                                final String initials = name.isNotEmpty
                                    ? name.substring(0, 1)
                                    : '?';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16.0),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(
                                            alpha: 0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16.0),
                                    child: InkWell(
                                      onTap: () => _selectPartner(
                                          Map<String, dynamic>.from(partner)),
                                      borderRadius: BorderRadius.circular(16.0),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    primaryColor.withValues(
                                                        alpha: 0.16),
                                                    primaryColor.withValues(
                                                        alpha: 0.06),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: primaryColor
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.phone_outlined,
                                                          size: 13.5,
                                                          color: Color(
                                                              0xFF64748B)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        phone,
                                                        style: const TextStyle(
                                                            fontSize: 12.5,
                                                            color: Color(
                                                                0xFF475569)),
                                                      ),
                                                      const SizedBox(width: 14),
                                                      const Icon(
                                                          Icons
                                                              .location_on_outlined,
                                                          size: 13.5,
                                                          color: Color(
                                                              0xFF64748B)),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          address,
                                                          style: const TextStyle(
                                                              fontSize: 12.5,
                                                              color: Color(
                                                                  0xFF64748B)),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFE2E8F0)),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 12,
                                                color: Color(0xFF64748B),
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
      ),
    );
  }
}
