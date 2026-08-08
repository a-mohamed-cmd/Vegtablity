import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../viewmodels/invoice_lookup_viewmodel.dart';

class InvoiceLookupScreen extends StatelessWidget {
  final int? initialInvId;
  const InvoiceLookupScreen({super.key, this.initialInvId});

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? fallback;
    }
    return fallback;
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static String _formatDateTime(String rawDateStr) {
    if (rawDateStr.isEmpty) return '-';
    try {
      final DateTime dt = DateTime.parse(rawDateStr);
      final String day = dt.day.toString().padLeft(2, '0');
      final String month = dt.month.toString().padLeft(2, '0');
      final String year = dt.year.toString();
      final String hour = dt.hour.toString().padLeft(2, '0');
      final String minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    } catch (_) {
      return rawDateStr;
    }
  }

  static String _resolvePaymentAccountName(Map<String, dynamic> inv, BuildContext context) {
    final List splits = (inv['PaymentSplits'] ?? inv['payment_splits'] ?? []) as List;
    final double paidAmount = _parseDouble(inv['PaidAmount'] ?? inv['paid_amount']);

    // Case 1: Multiple payment splits recorded -> Return "مدفوع" / "Paid" (splits breakdown is in card below)
    if (splits.isNotEmpty) {
      return context.tr('inv_lookup_paid_status');
    }

    // Case 2: Unpaid / Credit -> Return "آجل" / "Credit"
    if (paidAmount <= 0.0001) {
      return context.tr('inv_lookup_credit');
    }

    // Case 3: Paid amount > 0 -> Return "مدفوع" / "Paid"
    return context.tr('inv_lookup_paid_status');
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    return ChangeNotifierProvider<InvoiceLookupViewModel>(
      create: (_) {
        final vm = InvoiceLookupViewModel(apiService);
        if (initialInvId != null && initialInvId! > 0) {
          vm.searchController.text = initialInvId.toString();
          vm.searchInvoice(invId: initialInvId);
        }
        return vm;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.tr('inv_lookup_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: Consumer<InvoiceLookupViewModel>(
          builder: (context, vm, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchCard(context, vm),
                  const SizedBox(height: 16),
                  if (vm.isLoading) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: Colors.teal),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('inv_lookup_loading'),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ] else if (vm.errorMessage != null) ...[
                    _buildErrorMessageCard(vm.errorMessage!),
                  ] else if (vm.invoiceData != null) ...[
                    _buildInvoiceViewCard(context, vm),
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('inv_lookup_empty_hint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context, InvoiceLookupViewModel vm) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('inv_lookup_by_id'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: vm.searchController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => vm.searchInvoice(),
                    decoration: InputDecoration(
                      hintText: context.tr('inv_lookup_hint'),
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      suffixIcon: vm.searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => vm.clearSearch(),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => vm.searchInvoice(),
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: Text(context.tr('inv_lookup_search_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessageCard(String errorMsg) {
    bool isNetworkErr = errorMsg.contains('الاتصال') || errorMsg.contains('الشبكة') || errorMsg.contains('connection');
    bool isNotFound = errorMsg.contains('غير موجودة') || errorMsg.contains('not found');

    Color bgColor = isNetworkErr
        ? Colors.red.shade50
        : (isNotFound ? Colors.amber.shade50 : Colors.purple.shade50);
    Color borderColor = isNetworkErr
        ? Colors.red.shade300
        : (isNotFound ? Colors.amber.shade400 : Colors.purple.shade300);
    IconData iconData = isNetworkErr
        ? Icons.wifi_off_rounded
        : (isNotFound ? Icons.search_off_rounded : Icons.bug_report_rounded);
    Color iconColor = isNetworkErr
        ? Colors.red.shade700
        : (isNotFound ? Colors.amber.shade900 : Colors.purple.shade700);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(iconData, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMsg,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceViewCard(BuildContext context, InvoiceLookupViewModel vm) {
    final inv = vm.invoiceData!;
    final String invType = inv['InvType']?.toString() ?? 'Sales';
    final bool isSales = (invType == 'Sales');
    final String partnerLabel = isSales ? context.tr('inv_lookup_partner_cust') : context.tr('inv_lookup_partner_supp');

    final int invId = _parseInt(inv['InvID']);
    final String rawInvDate = inv['InvDate']?.toString() ?? '';
    final String invDate = _formatDateTime(rawInvDate);

    final String partnerName = inv['PartnerName']?.toString() ?? context.tr('inv_lookup_general_cash');
    final String warehouseName = inv['WarehouseName']?.toString() ?? '-';
    final String userName = inv['UserName']?.toString() ?? '-';
    final String paymentAccName = _resolvePaymentAccountName(inv, context);

    final double grossTotal = _parseDouble(inv['TotalAmount'] ?? inv['original_total']);
    final double discount = _parseDouble(inv['Discount'] ?? inv['discount_amount']);
    final double netTotal = _parseDouble(inv['NetAmount'] ?? inv['total_amount'] ?? (grossTotal - discount));
    final double paidAmount = _parseDouble(inv['PaidAmount']);
    final double remainder = _parseDouble(inv['Remainder']);

    final List splits = (inv['PaymentSplits'] ?? inv['payment_splits'] ?? []) as List;

    // TempOrderInfo Delivery fields check
    final String? tempName = inv['TempCustomerName']?.toString();
    final String? tempPhone = inv['TempPhone']?.toString();
    final String? tempAddress = inv['TempAddress']?.toString();
    final String? tempDate = inv['TempDeliveryDate']?.toString();
    final String? tempTime = inv['TempDeliveryTime']?.toString();
    final String? tempNotes = inv['TempNotes']?.toString();
    final String? generalNotes = inv['Notes']?.toString();

    final bool hasDelivery = (tempName != null && tempName.trim().isNotEmpty) ||
        (tempPhone != null && tempPhone.trim().isNotEmpty) ||
        (tempAddress != null && tempAddress.trim().isNotEmpty) ||
        (tempDate != null && tempDate.trim().isNotEmpty);

    final List details = (inv['Details'] as List?) ?? [];

    final String badgeText = isSales
        ? '${context.tr('inv_lookup_sales_badge')} #$invId'
        : '${context.tr('inv_lookup_purchase_badge')} #$invId';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Bar Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSales ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSales ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSales ? Icons.shopping_bag_outlined : Icons.inventory_2_outlined,
                        size: 18,
                        color: isSales ? Colors.green.shade800 : Colors.orange.shade900,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSales ? Colors.green.shade900 : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Metadata Grid
            _buildMetaRow(partnerLabel, partnerName, Icons.person_outline),
            _buildMetaRow(context.tr('inv_lookup_inv_date'), invDate, Icons.calendar_today_outlined),
            _buildMetaRow(context.tr('inv_lookup_warehouse'), warehouseName, Icons.storefront_outlined),
            _buildMetaRow(context.tr('inv_lookup_cashier'), userName, Icons.account_circle_outlined),
            _buildMetaRow(context.tr('inv_lookup_payment_acc'), paymentAccName, Icons.account_balance_wallet_outlined),
            if (generalNotes != null && generalNotes.trim().isNotEmpty)
              _buildMetaRow(context.tr('inv_lookup_notes'), generalNotes, Icons.note_outlined),

            // Payment Splits Section (If Multiple Payment Methods Used)
            if (splits.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_outlined, color: Colors.teal, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('inv_lookup_split_payments_card'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    ...splits.map((s) {
                      if (s is! Map) return const SizedBox.shrink();
                      final Map<String, dynamic> sMap = Map<String, dynamic>.from(s);
                      final String accName = sMap['PaymentMethodName']?.toString() ?? sMap['AccountName']?.toString() ?? sMap['PaymentAccountName']?.toString() ?? context.tr('inv_lookup_cash');
                      final double amt = _parseDouble(sMap['Amount']);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• $accName',
                              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${amt.toStringAsFixed(3)} KWD',
                              style: TextStyle(fontSize: 13, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],

            // Delivery Details Card Section (From TempOrderInfo Table)
            if (hasDelivery) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('inv_lookup_delivery_title'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    if (tempName != null && tempName.trim().isNotEmpty)
                      _buildDeliveryField(context.tr('temp_order_cust_name_label'), tempName),
                    if (tempPhone != null && tempPhone.trim().isNotEmpty)
                      _buildDeliveryField(context.tr('temp_order_phone_label'), tempPhone),
                    if (tempAddress != null && tempAddress.trim().isNotEmpty)
                      _buildDeliveryField(context.tr('temp_order_address_label'), tempAddress),
                    if ((tempDate != null && tempDate.trim().isNotEmpty) || (tempTime != null && tempTime.trim().isNotEmpty))
                      _buildDeliveryField(context.tr('inv_lookup_delivery_schedule'), '${tempDate ?? ""}  ${tempTime ?? ""}'),
                    if (tempNotes != null && tempNotes.trim().isNotEmpty)
                      _buildDeliveryField(context.tr('inv_lookup_notes'), tempNotes),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              context.tr('inv_lookup_items_title'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),

            // Items List Table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: Colors.grey.shade200,
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(context.tr('inv_lookup_col_item'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text(context.tr('inv_lookup_col_qty'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text(context.tr('inv_lookup_col_price'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(flex: 2, child: Text(context.tr('inv_lookup_col_total'), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: details.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(details[index] as Map);
                      final String pName = item['ProductName']?.toString() ?? context.tr('inv_lookup_unknown_item');
                      final String unit = item['UnitName']?.toString() ?? '';
                      final double q = _parseDouble(item['quantity'] ?? item['Quantity'], 1.0);
                      final double p = _parseDouble(item['price'] ?? item['UnitPrice'], 0.0);
                      final double t = _parseDouble(item['total'] ?? item['TotalPrice'], q * p);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                pName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${q.toStringAsFixed(2)} $unit',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                p.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                t.toStringAsFixed(3),
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Financial Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildFinancialRow(context.tr('inv_lookup_gross_total'), '${grossTotal.toStringAsFixed(3)} KWD', Colors.black87),
                  if (discount > 0)
                    _buildFinancialRow(context.tr('inv_lookup_discount'), '- ${discount.toStringAsFixed(3)} KWD', Colors.redAccent),
                  const Divider(height: 16),
                  _buildFinancialRow(context.tr('inv_lookup_net_total'), '${netTotal.toStringAsFixed(3)} KWD', Colors.green.shade800, isBold: true, fontSize: 16),
                  const SizedBox(height: 4),
                  _buildFinancialRow(context.tr('inv_lookup_paid_amount'), '${paidAmount.toStringAsFixed(3)} KWD', Colors.black54),
                  if (remainder > 0)
                    _buildFinancialRow(context.tr('inv_lookup_remainder'), '${remainder.toStringAsFixed(3)} KWD', Colors.orange.shade800, isBold: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bottom Re-print Button Only
            ElevatedButton.icon(
              onPressed: () async {
                final printerService = Provider.of<PrinterService>(context, listen: false);
                final success = await vm.printInvoice(printerService);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? context.tr('inv_lookup_reprint_success') : context.tr('inv_lookup_reprint_failed'),
                        textAlign: TextAlign.right,
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.print, color: Colors.white),
              label: Text(
                context.tr('inv_lookup_reprint_full'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryField(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String val, Color color, {bool isBold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            val,
            style: TextStyle(fontSize: fontSize, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
