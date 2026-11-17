import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../models/sync_models.dart';

class OfflineOperationDetailsSheet extends StatefulWidget {
  final SyncQueueItemModel item;
  final Future<void> Function() onPrint;
  final Future<void> Function() onSyncSingle;
  final Future<void> Function() onDelete;

  const OfflineOperationDetailsSheet({
    super.key,
    required this.item,
    required this.onPrint,
    required this.onSyncSingle,
    required this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required SyncQueueItemModel item,
    required Future<void> Function() onPrint,
    required Future<void> Function() onSyncSingle,
    required Future<void> Function() onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => OfflineOperationDetailsSheet(
        item: item,
        onPrint: onPrint,
        onSyncSingle: onSyncSingle,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<OfflineOperationDetailsSheet> createState() =>
      _OfflineOperationDetailsSheetState();
}

class _OfflineOperationDetailsSheetState
    extends State<OfflineOperationDetailsSheet> {
  bool _isPrinting = false;
  bool _isBusy = false;

  SyncQueueItemModel get item => widget.item;
  Map<String, dynamic> get raw => item.rawPayload;

  Color get _themeColor {
    switch (item.category) {
      case SyncCategoryType.invoice:
        final bool isPurchase = raw['InvType'] == 'Purchase';
        return isPurchase ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
      case SyncCategoryType.voucher:
        final bool isPayment = raw['VoucherType'] == 'Payment';
        return isPayment ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
      case SyncCategoryType.wastage:
        return const Color(0xFFF97316);
      case SyncCategoryType.stocktake:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _headerIcon {
    switch (item.category) {
      case SyncCategoryType.invoice:
        final bool isPurchase = raw['InvType'] == 'Purchase';
        return isPurchase
            ? Icons.shopping_cart_checkout_rounded
            : Icons.receipt_long_rounded;
      case SyncCategoryType.voucher:
        final bool isPayment = raw['VoucherType'] == 'Payment';
        return isPayment
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
      case SyncCategoryType.wastage:
        return Icons.delete_sweep_rounded;
      case SyncCategoryType.stocktake:
        return Icons.fact_check_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Prominent Unapproved / Unsynced Watermark Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade900.withValues(alpha: 0.45),
                  Colors.red.shade900.withValues(alpha: 0.45),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.6),
                width: 1.3,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amberAccent,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('sync_sheet_warn_title'),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        context.tr('sync_sheet_warn_sub'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Header Bar (Matching DailyInvoicesScreen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _themeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_headerIcon, color: _themeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${context.tr('sync_sheet_dt_prefix')} ${item.date}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orangeAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    context.tr('sync_sheet_unsynced_badge'),
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Error Banner if previous sync attempt failed
          if (item.hasError)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${context.tr('sync_sheet_last_err_prefix')} ${item.lastError}',
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildCategoryBody(),
            ),
          ),

          // Bottom Action Bar (Print Unapproved, Sync Now, Delete Operation)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // 1. Print with Unapproved Watermark
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: (_isPrinting || _isBusy)
                            ? null
                            : () async {
                                setState(() => _isPrinting = true);
                                try {
                                  await widget.onPrint();
                                } finally {
                                  if (mounted) {
                                    setState(() => _isPrinting = false);
                                  }
                                }
                              },
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_rounded, size: 19),
                        label: Text(
                          _isPrinting
                              ? context.tr('sync_sheet_printing')
                              : context.tr('sync_sheet_print_btn'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 2. Sync Single Item Now
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: (_isPrinting || _isBusy)
                            ? null
                            : () async {
                                setState(() => _isBusy = true);
                                Navigator.pop(context);
                                await widget.onSyncSingle();
                              },
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(
                          context.tr('sync_sheet_sync_now_btn'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 3. Delete Operation Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isPrinting || _isBusy)
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await widget.onDelete();
                              },
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.redAccent,
                          size: 19,
                        ),
                        label: Text(
                          context.tr('sync_sheet_del_btn'),
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBody() {
    switch (item.category) {
      case SyncCategoryType.invoice:
        return _buildInvoiceDetailsBody();
      case SyncCategoryType.voucher:
        return _buildVoucherDetailsBody();
      case SyncCategoryType.wastage:
        return _buildWastageDetailsBody();
      case SyncCategoryType.stocktake:
        return _buildStockTakeDetailsBody();
    }
  }

  // ===========================================================================
  // 1. INVOICE DETAILS (Sales / Purchase / Quotations - Matching DailyInvoices)
  // ===========================================================================
  Widget _buildInvoiceDetailsBody() {
    final bool isPurchase = raw['InvType'] == 'Purchase';
    final String partnerLabel = isPurchase
        ? context.tr('sync_sheet_supplier')
        : context.tr('sync_sheet_customer');
    final String partnerName = raw['_resolvedPartnerName']?.toString() ??
        raw['_partnerName']?.toString() ??
        raw['TempCustomerName']?.toString() ??
        (raw['PartnerID'] != null
            ? '${context.tr('sync_sheet_partner_prefix')} #${raw['PartnerID']}'
            : (isPurchase
                ? context.tr('sync_sheet_cash_supplier')
                : context.tr('sync_sheet_cash_customer')));

    final String paymentMethod = raw['PaymentMethod']?.toString() ?? 'Cash';
    final String paymentAccName =
        raw['_resolvedPaymentAccountName']?.toString() ??
            (paymentMethod == 'Credit'
                ? context.tr('sync_sheet_credit')
                : context.tr('sync_sheet_cash_card'));

    final List<dynamic> details =
        (raw['Details'] is List) ? raw['Details'] : [];
    final List<dynamic> splits =
        (raw['PaymentSplits'] is List) ? raw['PaymentSplits'] : [];

    final double totalAmount =
        ((raw['TotalAmount'] ?? raw['NetAmount'] ?? 0) as num).toDouble();
    final double discount =
        ((raw['Discount'] ?? raw['TotalDiscount'] ?? 0) as num).toDouble();
    final double netAmount =
        ((raw['NetAmount'] ?? totalAmount) as num).toDouble();
    final double paidAmount = ((raw['PaidAmount'] ?? 0) as num).toDouble();
    final double remainder = ((raw['Remainder'] ??
                ((netAmount - paidAmount) > 0 ? (netAmount - paidAmount) : 0.0))
            as num)
        .toDouble();

    final String? tempCustomerName = raw['TempCustomerName']?.toString();
    final String? tempPhone = raw['TempPhone']?.toString();
    final String? tempAddress = raw['TempAddress']?.toString();
    final String? tempDeliveryDate = raw['TempDeliveryDate']?.toString();
    final String? tempDeliveryTime = raw['TempDeliveryTime']?.toString();
    final String? tempNotes =
        raw['TempNotes']?.toString() ?? raw['Notes']?.toString();

    final bool hasDelivery =
        (tempCustomerName != null && tempCustomerName.isNotEmpty) ||
            (tempPhone != null && tempPhone.isNotEmpty) ||
            (tempAddress != null && tempAddress.isNotEmpty) ||
            (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metadata Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.badge_outlined,
                context.tr('sync_sheet_inv_status_lbl'),
                context.tr('sync_sheet_inv_status_val'),
                valueColor: Colors.amberAccent,
              ),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(
                Icons.person_outline_rounded,
                '$partnerLabel:',
                partnerName,
              ),
              const Divider(color: Colors.white10, height: 16),
              _buildInfoRow(
                Icons.account_balance_wallet_outlined,
                context.tr('sync_sheet_pay_method_lbl'),
                paymentAccName,
              ),
              if (raw['WarehouseID'] != null) ...[
                const Divider(color: Colors.white10, height: 16),
                _buildInfoRow(
                  Icons.warehouse_outlined,
                  context.tr('sync_sheet_warehouse_lbl'),
                  '${context.tr('sync_sheet_warehouse_prefix')} #${raw['WarehouseID']}',
                ),
              ],
              if (raw['ShiftID'] != null) ...[
                const Divider(color: Colors.white10, height: 16),
                _buildInfoRow(
                  Icons.point_of_sale_rounded,
                  context.tr('sync_sheet_shift_lbl'),
                  '#${raw['ShiftID']}',
                ),
              ],
              if (tempNotes != null && tempNotes.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 16),
                _buildInfoRow(
                  Icons.notes_rounded,
                  context.tr('sync_sheet_notes_lbl'),
                  tempNotes,
                ),
              ],
            ],
          ),
        ),

        // Delivery Info Section (if present)
        if (hasDelivery) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('sync_sheet_delivery_title'),
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (tempCustomerName != null && tempCustomerName.isNotEmpty)
                  _buildInfoRow(Icons.person,
                      context.tr('sync_sheet_recipient'), tempCustomerName),
                if (tempPhone != null && tempPhone.isNotEmpty)
                  _buildInfoRow(
                      Icons.phone, context.tr('sync_sheet_phone'), tempPhone),
                if (tempAddress != null && tempAddress.isNotEmpty)
                  _buildInfoRow(Icons.location_on,
                      context.tr('sync_sheet_address'), tempAddress),
                if (tempDeliveryDate != null && tempDeliveryDate.isNotEmpty)
                  _buildInfoRow(
                    Icons.calendar_today,
                    context.tr('sync_sheet_delivery_time'),
                    '$tempDeliveryDate ${tempDeliveryTime ?? ''}',
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Items Table Header (Exact match with DailyInvoicesScreen)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${context.tr('sync_sheet_col_item')} (${details.length})',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_price'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_qty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_total'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Items Rows
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.55),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: Colors.white10),
          ),
          child: details.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      context.tr('sync_sheet_no_items'),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: details.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final d = Map<String, dynamic>.from(details[idx] as Map);
                    final pid = d['ProductID'] ?? '';
                    final String pName = d['ProductName']?.toString() ??
                        d['product_name']?.toString() ??
                        d['name']?.toString() ??
                        '${context.tr('sync_sheet_item_prefix')} #$pid';
                    final String unitName = d['UnitName']?.toString() ??
                        d['unit_name']?.toString() ??
                        '';
                    final double price =
                        ((d['UnitPrice'] ?? d['price'] ?? 0) as num).toDouble();
                    final double qty =
                        ((d['Quantity'] ?? d['quantity'] ?? 0) as num)
                            .toDouble();
                    final double total = ((d['TotalPrice'] ??
                            d['total'] ??
                            (price * qty)) as num)
                        .toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (unitName.isNotEmpty ||
                                    pid.toString().isNotEmpty)
                                  Text(
                                    [
                                      if (pid.toString().isNotEmpty) '#$pid',
                                      if (unitName.isNotEmpty) unitName,
                                    ].join(' • '),
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              price.toStringAsFixed(3),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              qty % 1 == 0
                                  ? qty.toInt().toString()
                                  : qty.toStringAsFixed(3),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              total.toStringAsFixed(3),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: const Color(0xFF10B981),
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 16),

        // Payment Splits (if multi-payment)
        if (splits.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('sync_sheet_splits_title'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...splits.map((s) {
                  final sm = Map<String, dynamic>.from(s as Map);
                  final double sAmt = ((sm['Amount'] ?? 0) as num).toDouble();
                  final String sAcc = sm['AccountName']?.toString() ??
                      '${context.tr('sync_sheet_acc_prefix')} #${sm['AccountID'] ?? ''}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '• $sAcc',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          sAmt.toStringAsFixed(3),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Financial Totals Summary Box (Matching DailyInvoicesScreen)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _themeColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              if (discount > 0) ...[
                _buildSummaryRow(
                  context.tr('sync_sheet_before_disc'),
                  (netAmount + discount).toStringAsFixed(3),
                  Colors.white70,
                ),
                const SizedBox(height: 6),
                _buildSummaryRow(
                  context.tr('sync_sheet_disc_val'),
                  '-${discount.toStringAsFixed(3)}',
                  Colors.orangeAccent,
                ),
                const Divider(color: Colors.white10, height: 18),
              ],
              _buildSummaryRow(
                context.tr('sync_sheet_net_total'),
                netAmount.toStringAsFixed(3),
                _themeColor,
                isLarge: true,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                context.tr('sync_sheet_paid_lbl'),
                paidAmount.toStringAsFixed(3),
                const Color(0xFF3B82F6),
              ),
              if (remainder > 0.001) ...[
                const SizedBox(height: 6),
                _buildSummaryRow(
                  context.tr('sync_sheet_rem_lbl'),
                  remainder.toStringAsFixed(3),
                  Colors.redAccent,
                  isBold: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. VOUCHER DETAILS (Customer Receipt / Supplier Payment / General Voucher)
  // ===========================================================================
  Widget _buildVoucherDetailsBody() {
    final bool isReceipt = raw['VoucherType'] == 'Receipt';
    final bool isGeneral = raw['IsGeneral'] == true;
    final String targetLabel = isGeneral
        ? context.tr('sync_sheet_vch_target_acc')
        : (isReceipt
            ? '${context.tr('sync_sheet_customer')}:'
            : '${context.tr('sync_sheet_supplier')}:');
    final String targetName = raw['_resolvedTargetName']?.toString() ??
        raw['PartnerName']?.toString() ??
        (isGeneral
            ? '${context.tr('sync_sheet_acc_prefix')} #${raw['AccountID'] ?? ''}'
            : '${context.tr('sync_sheet_partner_prefix')} #${raw['PartnerID'] ?? ''}');
    final String cashAccName = raw['_resolvedCashAccountName']?.toString() ??
        '${context.tr('sync_sheet_vch_cash_prefix')} #${raw['AccountID'] ?? 1}';
    final String description =
        raw['Description']?.toString() ?? context.tr('sync_sheet_no_desc');
    final List<dynamic> allocations =
        (raw['Allocations'] is List) ? raw['Allocations'] : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.badge_outlined,
                context.tr('sync_sheet_vch_status_lbl'),
                context.tr('sync_sheet_vch_status_val'),
                valueColor: Colors.amberAccent,
              ),
              const Divider(color: Colors.white10, height: 18),
              _buildInfoRow(
                Icons.category_outlined,
                context.tr('sync_sheet_vch_type_lbl'),
                item.title,
              ),
              const Divider(color: Colors.white10, height: 18),
              _buildInfoRow(
                Icons.person_outline_rounded,
                targetLabel,
                targetName,
              ),
              const Divider(color: Colors.white10, height: 18),
              _buildInfoRow(
                Icons.account_balance_wallet_outlined,
                context.tr('sync_sheet_vch_treasury_lbl'),
                cashAccName,
              ),
              if (raw['ShiftID'] != null) ...[
                const Divider(color: Colors.white10, height: 18),
                _buildInfoRow(
                  Icons.point_of_sale_rounded,
                  context.tr('sync_sheet_shift_lbl'),
                  '#${raw['ShiftID']}',
                ),
              ],
              const Divider(color: Colors.white10, height: 18),
              _buildInfoRow(
                Icons.notes_rounded,
                context.tr('sync_sheet_vch_notes_lbl'),
                description,
              ),
            ],
          ),
        ),
        if (allocations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${context.tr('sync_sheet_vch_allocs_title')} (${allocations.length}):',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allocations.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, i) {
                final a = Map<String, dynamic>.from(allocations[i] as Map);
                final invId = a['InvID'] ?? a['InvoiceID'] ?? '--';
                final double allocAmt =
                    ((a['AllocatedAmount'] ?? a['PaidAmount'] ?? 0) as num)
                        .toDouble();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${context.tr('sync_sheet_inv_no_prefix')} #$invId',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        allocAmt.toStringAsFixed(3),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _themeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _themeColor.withValues(alpha: 0.4)),
          ),
          child: _buildSummaryRow(
            isReceipt
                ? context.tr('sync_sheet_vch_total_rcpt')
                : context.tr('sync_sheet_vch_total_pay'),
            item.amount.toStringAsFixed(3),
            _themeColor,
            isLarge: true,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. WASTAGE DETAILS
  // ===========================================================================
  Widget _buildWastageDetailsBody() {
    final List<dynamic> details =
        (raw['Details'] is List) ? raw['Details'] : [];
    final String notes = raw['Notes']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.warehouse_outlined,
                context.tr('sync_sheet_warehouse_lbl'),
                '${context.tr('sync_sheet_warehouse_prefix')} #${raw['WarehouseID'] ?? 1}',
              ),
              if (notes.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 16),
                _buildInfoRow(
                  Icons.notes_rounded,
                  context.tr('sync_sheet_wst_reason_lbl'),
                  notes,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${context.tr('sync_sheet_col_item')} (${details.length})',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_qty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_cost'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_total'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.55),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: Colors.white10),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, i) {
              final d = Map<String, dynamic>.from(details[i] as Map);
              final pid = d['ProductID'] ?? '';
              final String pName = d['ProductName']?.toString() ??
                  '${context.tr('sync_sheet_item_prefix')} #$pid';
              final double qty = ((d['Quantity'] ?? 0) as num).toDouble();
              final double cost = ((d['CostPrice'] ?? 0) as num).toDouble();
              final double tot = qty * cost;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        pName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        qty.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        cost.toStringAsFixed(3),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tot.toStringAsFixed(3),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _themeColor.withValues(alpha: 0.4)),
          ),
          child: _buildSummaryRow(
            context.tr('sync_sheet_wst_total_lbl'),
            item.amount.toStringAsFixed(3),
            _themeColor,
            isLarge: true,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. STOCKTAKE DETAILS
  // ===========================================================================
  Widget _buildStockTakeDetailsBody() {
    final List<dynamic> details =
        (raw['Details'] is List) ? raw['Details'] : [];
    final String notes = raw['Notes']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.warehouse_outlined,
                context.tr('sync_sheet_warehouse_lbl'),
                '${context.tr('sync_sheet_warehouse_prefix')} #${raw['WarehouseID'] ?? 1}',
              ),
              if (notes.isNotEmpty) ...[
                const Divider(color: Colors.white10, height: 16),
                _buildInfoRow(
                  Icons.notes_rounded,
                  context.tr('sync_sheet_stk_notes_lbl'),
                  notes,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${context.tr('sync_sheet_col_item')} (${details.length})',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_book'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_actual'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.tr('sync_sheet_col_diff'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.55),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: Colors.white10),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, i) {
              final d = Map<String, dynamic>.from(details[i] as Map);
              final pid = d['ProductID'] ?? '';
              final String pName = d['ProductName']?.toString() ??
                  '${context.tr('sync_sheet_item_prefix')} #$pid';
              final double sysQty =
                  ((d['SystemQuantity'] ?? 0) as num).toDouble();
              final double actQty =
                  ((d['ActualQuantity'] ?? 0) as num).toDouble();
              final double diff = actQty - sysQty;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        pName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        sysQty.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        actQty.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        (diff >= 0 ? '+' : '') + diff.toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: diff < 0
                              ? Colors.redAccent
                              : const Color(0xFF10B981),
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _themeColor.withValues(alpha: 0.4)),
          ),
          child: _buildSummaryRow(
            context.tr('sync_sheet_stk_total_lbl'),
            item.amount.toStringAsFixed(3),
            _themeColor,
            isLarge: true,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color valueColor = Colors.white,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color valueColor, {
    bool isLarge = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isLarge ? Colors.white : Colors.white70,
            fontSize: isLarge ? 15 : 13,
            fontWeight:
                (isLarge || isBold) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isLarge ? 18 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
