import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../models/sync_models.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';
import '../services/printer_service.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../widgets/offline_operation_details_sheet.dart';
import '../widgets/sync_progress_widgets.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  SyncCategoryType? _selectedCategoryFilter;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vm = Provider.of<SyncViewModel>(context, listen: false);
        vm.setLocaleIsAr(_isAr, reload: false);
        vm.loadAllQueues();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAr = _isAr;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<SyncViewModel>(context, listen: false).setLocaleIsAr(isAr);
      }
    });
  }

  Future<void> _notifyLegacyProviders() async {
    if (!mounted) return;
    final posProv = Provider.of<PosProvider>(context, listen: false);
    final voucherProv = Provider.of<VoucherProvider>(context, listen: false);
    await posProv.reloadOfflineQueueFromPrefs();
    await voucherProv.reloadOfflineQueueFromPrefs();
  }

  Future<void> _handlePrintItem(
    BuildContext context,
    SyncViewModel syncVm,
    SyncQueueItemModel item,
  ) async {
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final bool ok = await syncVm.printQueueItem(item, printerService);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('sync_print_sent')
              : context.tr('sync_print_failed'),
        ),
        backgroundColor: ok ? Colors.teal.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _handleSyncSingleItem(
    BuildContext context,
    SyncViewModel syncVm,
    SyncQueueItemModel item,
  ) async {
    final report = await syncVm.syncSingleItem(
      item,
      onQueuesUpdated: _notifyLegacyProviders,
    );
    if (context.mounted) {
      await SyncResultSummaryDialog.show(context, report);
    }
  }

  void _openRichDetailsSheet(
    BuildContext context,
    SyncViewModel syncVm,
    SyncQueueItemModel item,
  ) {
    OfflineOperationDetailsSheet.show(
      context,
      item: item,
      onPrint: () => _handlePrintItem(context, syncVm, item),
      onSyncSingle: () => _handleSyncSingleItem(context, syncVm, item),
      onDelete: () async => _confirmDeleteItem(context, syncVm, item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          context.tr('sync_center_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        actions: [
          Consumer<SyncViewModel>(
            builder: (context, syncVm, _) => IconButton(
              tooltip: context.tr('sync_refresh_list'),
              onPressed:
                  syncVm.isSyncing ? null : () => syncVm.loadAllQueues(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: Consumer<SyncViewModel>(
          builder: (context, syncVm, _) {
            final displayedItems = _selectedCategoryFilter == null
                ? syncVm.allPendingItems
                : syncVm.itemsForCategory(_selectedCategoryFilter!);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Live Progress Indicator during Sync
                    if (syncVm.isSyncing)
                      LiveSyncProgressBarCard(syncVm: syncVm),

                    // 2. Top Summary Header & Sync All Button
                    _buildTopSummaryCard(context, syncVm),
                    const SizedBox(height: 16),

                    // 3. Category Filter Cards
                    _buildCategoryCardsRow(syncVm),
                    const SizedBox(height: 16),

                    // 4. Category-Specific Bulk Sync Bar (when a filter is selected)
                    if (_selectedCategoryFilter != null &&
                        displayedItems.isNotEmpty)
                      _buildSelectedCategoryActionHeader(
                        context,
                        syncVm,
                        _selectedCategoryFilter!,
                        displayedItems.length,
                      ),

                    // 5. Pending Operations List
                    if (displayedItems.isEmpty)
                      _buildEmptyState()
                    else
                      ...displayedItems.map(
                        (item) => _buildQueueItemCard(context, syncVm, item),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
  }

  Widget _buildTopSummaryCard(BuildContext context, SyncViewModel syncVm) {
    final int total = syncVm.totalPendingCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: total > 0
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  total > 0
                      ? Icons.cloud_upload_rounded
                      : Icons.cloud_done_rounded,
                  size: 32,
                  color: total > 0
                      ? Colors.orange.shade800
                      : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total > 0
                        ? context
                            .tr('sync_pending_total')
                            .replaceAll('{count}', '$total')
                        : context.tr('sync_all_synced'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('sync_summary_hint'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncVm.lastSyncReport != null &&
                  syncVm.lastSyncReport!.results.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => SyncResultSummaryDialog.show(
                      context,
                      syncVm.lastSyncReport!,
                    ),
                    icon: const Icon(Icons.assignment_turned_in_outlined,
                        size: 18),
                    label: Text(context.tr('sync_last_report_btn')),
                  ),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (total == 0 || syncVm.isSyncing)
                    ? null
                    : () async {
                        final report = await syncVm.syncAll(
                          onQueuesUpdated: _notifyLegacyProviders,
                        );
                        if (context.mounted) {
                          await SyncResultSummaryDialog.show(context, report);
                        }
                      },
                icon: const Icon(Icons.sync_rounded),
                label: Text(
                  context.tr('sync_all_now_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCardsRow(SyncViewModel syncVm) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildFilterChipCard(
          title: context.tr('sync_cat_all'),
          count: syncVm.totalPendingCount,
          icon: Icons.all_inbox_rounded,
          color: Colors.teal,
          isSelected: _selectedCategoryFilter == null,
          onTap: () => setState(() => _selectedCategoryFilter = null),
        ),
        _buildFilterChipCard(
          title: context.tr('sync_cat_invoices'),
          count: syncVm.invoicesCount,
          icon: Icons.receipt_long_rounded,
          color: Colors.blue.shade700,
          isSelected: _selectedCategoryFilter == SyncCategoryType.invoice,
          onTap: () => setState(
              () => _selectedCategoryFilter = SyncCategoryType.invoice),
        ),
        _buildFilterChipCard(
          title: context.tr('sync_cat_vouchers'),
          count: syncVm.vouchersCount,
          icon: Icons.payments_rounded,
          color: Colors.purple.shade700,
          isSelected: _selectedCategoryFilter == SyncCategoryType.voucher,
          onTap: () => setState(
              () => _selectedCategoryFilter = SyncCategoryType.voucher),
        ),
        _buildFilterChipCard(
          title: context.tr('sync_cat_wastages'),
          count: syncVm.wastagesCount,
          icon: Icons.delete_sweep_rounded,
          color: Colors.deepOrange.shade700,
          isSelected: _selectedCategoryFilter == SyncCategoryType.wastage,
          onTap: () => setState(
              () => _selectedCategoryFilter = SyncCategoryType.wastage),
        ),
        _buildFilterChipCard(
          title: context.tr('sync_cat_stocktakes'),
          count: syncVm.stockTakesCount,
          icon: Icons.inventory_2_rounded,
          color: Colors.indigo.shade700,
          isSelected: _selectedCategoryFilter == SyncCategoryType.stocktake,
          onTap: () => setState(
              () => _selectedCategoryFilter = SyncCategoryType.stocktake),
        ),
      ],
    );
  }

  Widget _buildFilterChipCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCategoryActionHeader(
    BuildContext context,
    SyncViewModel syncVm,
    SyncCategoryType category,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${category.localizedTitle(_isAr)} ($count)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: syncVm.isSyncing
                ? null
                : () async {
                    final report = await syncVm.syncCategory(
                      category,
                      onQueuesUpdated: _notifyLegacyProviders,
                    );
                    if (context.mounted) {
                      await SyncResultSummaryDialog.show(context, report);
                    }
                  },
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: Text(
              '${context.tr('sync_sync_all_cat_prefix')} ${category.localizedShortTitle(_isAr)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemCard(
    BuildContext context,
    SyncViewModel syncVm,
    SyncQueueItemModel item,
  ) {
    final bool isThisItemSyncing =
        syncVm.isSyncing && syncVm.activeSingleItemKey == item.uniqueKey;

    Color badgeColor;
    IconData badgeIcon;
    switch (item.category) {
      case SyncCategoryType.invoice:
        badgeColor = Colors.blue.shade700;
        badgeIcon = Icons.receipt_long_rounded;
        break;
      case SyncCategoryType.voucher:
        badgeColor = Colors.purple.shade700;
        badgeIcon = Icons.payments_rounded;
        break;
      case SyncCategoryType.wastage:
        badgeColor = Colors.deepOrange.shade700;
        badgeIcon = Icons.delete_sweep_rounded;
        break;
      case SyncCategoryType.stocktake:
        badgeColor = Colors.indigo.shade700;
        badgeIcon = Icons.inventory_2_rounded;
        break;
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.lastError != null
              ? Colors.red.shade300
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRichDetailsSheet(context, syncVm, item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(badgeIcon, color: badgeColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.category.shortTitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                context.tr('sync_badge_unapproved'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.tr('sync_date_prefix')} ${item.date}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.amount.toStringAsFixed(3),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal.shade800,
                        ),
                      ),
                      Text(
                        context.tr('sync_total_word'),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),

              // Last sync error box (if any)
              if (item.lastError != null && item.lastError!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${context.tr('sync_prev_error_prefix')} ${item.lastError}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 20),

              // Individual Item Actions Bar (Details, Print Unapproved, Delete, Single Sync)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. View Full Details Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade800,
                          side: BorderSide(color: Colors.blueGrey.shade200),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            _openRichDetailsSheet(context, syncVm, item),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text(
                          context.tr('sync_btn_details'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 2. Print Unapproved Receipt Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade800,
                          side: BorderSide(color: Colors.blue.shade300),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: syncVm.isSyncing
                            ? null
                            : () => _handlePrintItem(context, syncVm, item),
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: Text(
                          context.tr('sync_btn_print_unapproved'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3. Dedicated Delete Operation Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          backgroundColor: Colors.red.shade50,
                          side: BorderSide(color: Colors.red.shade300),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: syncVm.isSyncing
                            ? null
                            : () => _confirmDeleteItem(context, syncVm, item),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 16),
                        label: Text(
                          context.tr('sync_btn_delete_op'),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 4. Sync This Single Item Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: syncVm.isSyncing
                            ? null
                            : () =>
                                _handleSyncSingleItem(context, syncVm, item),
                        icon: isThisItemSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: Text(
                          isThisItemSyncing
                              ? context.tr('sync_btn_syncing')
                              : context.tr('sync_btn_sync_op'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_done_rounded,
            size: 64,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('sync_empty_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('sync_empty_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(
    BuildContext context,
    SyncViewModel syncVm,
    SyncQueueItemModel item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('sync_del_title'))),
          ],
        ),
        content: Text(
          context.tr('sync_del_msg').replaceAll('{title}', item.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('sync_cancel_btn')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await syncVm.deleteQueueItem(
                item,
                onQueuesUpdated: _notifyLegacyProviders,
              );
            },
            child: Text(context.tr('sync_del_confirm_btn')),
          ),
        ],
      ),
    );
  }
}
