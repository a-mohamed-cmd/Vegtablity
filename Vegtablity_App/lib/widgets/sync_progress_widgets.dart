import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_models.dart';
import '../providers/pos_provider.dart';
import '../providers/voucher_provider.dart';
import '../providers/wastage_provider.dart';
import '../providers/stocktake_provider.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../screens/sync_center_screen.dart';

/// شريط مؤشر التحميل المباشر أثناء المزامنة (يعرض ما تمت مزامنته والمتبقي لحظياً)
class LiveSyncProgressBarCard extends StatelessWidget {
  final SyncViewModel syncVm;

  const LiveSyncProgressBarCard({super.key, required this.syncVm});

  @override
  Widget build(BuildContext context) {
    final int percent = (syncVm.progressFraction * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.green.shade50],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    syncVm.currentStatusText.isNotEmpty
                        ? syncVm.currentStatusText
                        : 'جاري مزامنة العمليات مع قاعدة البيانات...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: syncVm.progressFraction,
                minHeight: 10,
                backgroundColor: Colors.teal.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCounterBadge(
                  label: 'تمت مزامنته',
                  count: syncVm.syncedCount,
                  color: Colors.green.shade700,
                  icon: Icons.check_circle_outline,
                ),
                _buildCounterBadge(
                  label: 'المتبقي',
                  count: syncVm.remainingCount,
                  color: Colors.orange.shade800,
                  icon: Icons.hourglass_bottom_rounded,
                ),
                _buildCounterBadge(
                  label: 'الإجمالي',
                  count: syncVm.totalToSyncCount,
                  color: Colors.blueGrey.shade700,
                  icon: Icons.layers_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterBadge({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة عرض تقرير ما تم مزامنته بعد انتهاء المزامنة
class SyncResultSummaryDialog extends StatelessWidget {
  final SyncBatchReportModel report;

  const SyncResultSummaryDialog({super.key, required this.report});

  static Future<void> show(
      BuildContext context, SyncBatchReportModel report) async {
    if (report.results.isEmpty) return;
    await showDialog(
      context: context,
      builder: (_) => SyncResultSummaryDialog(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final synced = report.syncedItems;
    final failed = report.failedItems;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: report.isAllSuccess
                  ? Colors.green.shade100
                  : (synced.isNotEmpty
                      ? Colors.orange.shade100
                      : Colors.red.shade100),
              child: Icon(
                report.isAllSuccess
                    ? Icons.cloud_done_rounded
                    : (synced.isNotEmpty
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline_rounded),
                color: report.isAllSuccess
                    ? Colors.green.shade800
                    : (synced.isNotEmpty
                        ? Colors.orange.shade800
                        : Colors.red.shade800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقرير نتائج المزامنة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'تمت مزامنة ${synced.length} من أصل ${report.totalAttempted} عملية',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 440),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (synced.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'العمليات التي تم حفظها في قاعدة البيانات (${synced.length}):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...synced.map((item) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.green.shade200),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.verified_rounded,
                            color: Colors.green.shade600,
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${item.subtitle}  •  التاريخ: ${item.date}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.amount.toStringAsFixed(3),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.serverReferenceId != null &&
                                  item.serverReferenceId! > 0)
                                Text(
                                  'رقم الحفظ: #${item.serverReferenceId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                if (failed.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'العمليات المتبقية التي تعذرت مزامنتها (${failed.length}):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...failed.map((item) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        color: Colors.red.shade50.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade700,
                          ),
                          title: Text(
                            '${item.title} (${item.amount.toStringAsFixed(3)})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            'السبب: ${item.errorMessage ?? 'خطأ غير معروف'}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.red.shade800),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

/// شريط التنبيه الذكي للمزامنة في الشاشة الرئيسية (مبني على SyncViewModel)
class HomeSyncBannerWidget extends StatelessWidget {
  const HomeSyncBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // مراقبة تغير طوابير الأوفلاين في الـ Providers لتحديث SyncViewModel تلقائياً
    final posCount = context.watch<PosProvider>().offlineInvoicesCount;
    final voucherCount = context.watch<VoucherProvider>().offlineVouchersCount;
    context.watch<WastageProvider>();
    context.watch<StockTakeProvider>();

    return Consumer<SyncViewModel>(
      builder: (context, syncVm, _) {
        if (!syncVm.isSyncing &&
            (syncVm.invoicesCount != posCount ||
                syncVm.vouchersCount != voucherCount)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            syncVm.loadAllQueues();
          });
        }

        if (syncVm.totalPendingCount == 0 && !syncVm.isSyncing) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (syncVm.isSyncing)
              LiveSyncProgressBarCard(syncVm: syncVm)
            else
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_upload_rounded,
                              color: Colors.orange.shade800),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'يوجد (${syncVm.totalPendingCount}) عمليات محفوظة محلياً بانتظار المزامنة',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                [
                                  if (syncVm.invoicesCount > 0)
                                    '${syncVm.invoicesCount} فاتورة',
                                  if (syncVm.vouchersCount > 0)
                                    '${syncVm.vouchersCount} سند',
                                  if (syncVm.wastagesCount > 0)
                                    '${syncVm.wastagesCount} هالك',
                                  if (syncVm.stockTakesCount > 0)
                                    '${syncVm.stockTakesCount} جرد',
                                ].join('  •  '),
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade900,
                              side: BorderSide(color: Colors.orange.shade400),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SyncCenterScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                            label: const Text('عرض التفاصيل'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final posProv = Provider.of<PosProvider>(context,
                                  listen: false);
                              final voucherProv = Provider.of<VoucherProvider>(
                                  context,
                                  listen: false);
                              final report = await syncVm.syncAll(
                                onQueuesUpdated: () async {
                                  await posProv.reloadOfflineQueueFromPrefs();
                                  await voucherProv
                                      .reloadOfflineQueueFromPrefs();
                                },
                              );
                              if (context.mounted) {
                                await SyncResultSummaryDialog.show(
                                    context, report);
                              }
                            },
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('مزامنة الكل'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
