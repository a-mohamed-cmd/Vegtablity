import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../core/localization/app_localizations.dart';
import 'pos_screen.dart';

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
              ? 'فشل جلب قائمة العملاء من الخادم'
              : 'فشل جلب قائمة الموردين من الخادم';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال بالشبكة: $e';
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

  void _selectPartner(Map<String, dynamic> partner) {
    if (widget.isSelectionOnly) {
      // If we opened this screen as a sub-route to change the customer/supplier, we return the chosen partner!
      Navigator.pop(context, partner);
    } else {
      // Otherwise, open POS directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PosScreen(
            type: widget.type,
            partner: partner,
          ),
        ),
      ).then((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSales = widget.type == 'Sales';
    return Scaffold(
      appBar: AppBar(
        title: Text(isSales ? 'اختيار العميل' : 'اختيار المورد', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      ? 'البحث باسم العميل، الهاتف أو رقم الحساب...'
                      : 'البحث باسم المورد، الهاتف أو رقم الحساب...',
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
                              child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      )
                    : _filteredPartners.isEmpty
                        ? Center(child: Text(isSales ? 'لا يوجد عملاء مطابقين للبحث' : 'لا يوجد موردين مطابقين للبحث', style: const TextStyle(fontSize: 16)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: _filteredPartners.length,
                            itemBuilder: (context, index) {
                              final Map<String, dynamic> partner = Map<String, dynamic>.from(_filteredPartners[index]);
                              final double balance = (partner['CurrentBalance'] as num?)?.toDouble() ?? 0.0;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(
                                    partner['PartnerName'] ?? 'شريك غير معروف',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'رقم الحساب المالي: ${partner['AccountCode'] ?? partner['AccountID'] ?? 'لا يوجد'}',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                      ),
                                      if (partner['Phone'] != null && partner['Phone'].toString().trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'الهاتف: ${partner['Phone']}',
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
                                          color: isSales
                                              ? (balance > 0 ? Colors.green[700]! : Colors.red)
                                              : (balance > 0 ? Colors.red : Colors.green[700]!),
                                        ),
                                      ),
                                      Text(isSales ? 'مستحق له' : 'مستحق عليه', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
