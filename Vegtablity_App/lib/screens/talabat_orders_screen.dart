import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../models/integration_models.dart';
import '../services/integrations/integration_service.dart';

class TalabatOrdersScreen extends StatefulWidget {
  const TalabatOrdersScreen({super.key});

  @override
  State<TalabatOrdersScreen> createState() => _TalabatOrdersScreenState();
}

class _TalabatOrdersScreenState extends State<TalabatOrdersScreen> {
  final IntegrationPosService _service = IntegrationPosService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  List<TalabatOrderModel> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final list = await _service.fetchTalabatOrders(
      status: _selectedStatus,
      searchText: _searchCtrl.text.trim(),
    );
    if (mounted) {
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(TalabatOrderModel order, String action) async {
    final ok = await _service.performTalabatAction(
      orderToken: order.orderToken,
      orderCode: order.orderCode,
      action: action,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? Colors.green : Colors.red,
          content: Text(
            ok
                ? context
                    .tr('talabat_action_ok')
                    .replaceAll('{code}', order.orderCode)
                : context.tr('talabat_action_fail'),
          ),
        ),
      );
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('talabat_title')),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: context.tr('talabat_refresh_tooltip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('talabat_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadOrders(),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: [
                    DropdownMenuItem(
                        value: 'ALL',
                        child: Text(context.tr('talabat_status_all'))),
                    DropdownMenuItem(
                        value: 'Received',
                        child: Text(context.tr('talabat_status_received'))),
                    DropdownMenuItem(
                        value: 'Accepted',
                        child: Text(context.tr('talabat_status_accepted'))),
                    DropdownMenuItem(
                        value: 'Prepared',
                        child: Text(context.tr('talabat_status_prepared'))),
                    DropdownMenuItem(
                        value: 'Rejected',
                        child: Text(context.tr('talabat_status_rejected'))),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedStatus = v);
                      _loadOrders();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Colors.deepOrange))
                : _orders.isEmpty
                    ? Center(child: Text(context.tr('talabat_empty')))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final order = _orders[i];
                          final isReceived = order.orderStatus == 'Received';
                          final isAccepted = order.orderStatus == 'Accepted';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${context.tr('talabat_order_prefix')}${order.orderCode} (${order.shortCode})',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepOrange),
                                      ),
                                      Chip(
                                        label: Text(order.orderStatus,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                      '${context.tr('talabat_customer_label')} ${order.customerName} | ${context.tr('talabat_phone_label')} ${order.customerPhone}'),
                                  Text(
                                      '${context.tr('talabat_delivery_label')} ${order.expeditionType} | ${context.tr('talabat_payment_label')} ${order.paymentType}'),
                                  Text(
                                    '${context.tr('talabat_total_label')} ${order.grandTotal.toStringAsFixed(3)} ${order.currencyCode}'
                                    '${order.invId != null ? "${context.tr('talabat_sales_inv_prefix')}${order.invId}" : ""}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  if (order.comments.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                          '${context.tr('talabat_notes_label')} ${order.comments}',
                                          style: const TextStyle(
                                              color: Colors.brown)),
                                    ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (isReceived) ...[
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white),
                                          onPressed: () =>
                                              _handleAction(order, 'Accept'),
                                          icon: const Icon(Icons.check_circle,
                                              size: 18),
                                          label: Text(
                                              context.tr('talabat_btn_accept')),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white),
                                          onPressed: () =>
                                              _handleAction(order, 'Reject'),
                                          icon: const Icon(Icons.cancel,
                                              size: 18),
                                          label: Text(
                                              context.tr('talabat_btn_reject')),
                                        ),
                                      ],
                                      if (isAccepted)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepOrange,
                                              foregroundColor: Colors.white),
                                          onPressed: () =>
                                              _handleAction(order, 'Prepared'),
                                          icon: const Icon(Icons.restaurant,
                                              size: 18),
                                          label: Text(context
                                              .tr('talabat_btn_prepared')),
                                        ),
                                    ],
                                  ),
                                ],
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

