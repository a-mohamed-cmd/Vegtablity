import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../core/localization/app_localizations.dart';
import 'partner_billing_screen.dart';

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
        _errorMessage = '${context.tr('po_error_network')}$e';
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

      // Navigate to Billing Screen with the quote details
      if (mounted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('po_error_loading_quote')}$e',
                textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'Sales'
        ? context.tr('po_sales_partners_title')
        : context.tr('po_purchases_partners_title');
    final primaryColor =
        widget.type == 'Sales' ? Colors.blue[700]! : Colors.orange[800]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.type == 'Sales'
                  ? [Colors.blue, Colors.teal]
                  : [Colors.orange, Colors.red],
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
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
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
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPartners('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0.0, horizontal: 16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),

            // Loading / Error / Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.teal))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 60, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(_errorMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.grey)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchActivePartners,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(context.tr('po_retry')),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredPartners.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline_rounded,
                                      size: 70, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.tr('po_no_partners_found'),
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.grey),
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

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16.0)),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () => _selectPartner(
                                        Map<String, dynamic>.from(partner)),
                                    borderRadius: BorderRadius.circular(16.0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor:
                                                primaryColor.withOpacity(0.1),
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.phone,
                                                        size: 14,
                                                        color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      phone,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.grey[600]),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    const Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        address,
                                                        style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .grey[600]),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Navigation arrow
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 16,
                                                  color: Colors.grey[400]),
                                            ],
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
    );
  }
}
