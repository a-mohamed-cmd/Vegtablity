import 'package:flutter/material.dart';
import '../models/sync_models.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../services/printer_service.dart';

class SyncViewModel extends ChangeNotifier {
  final OfflineSyncService _syncService;

  List<SyncQueueItemModel> _pendingInvoices = [];
  List<SyncQueueItemModel> _pendingVouchers = [];
  List<SyncQueueItemModel> _pendingWastages = [];
  List<SyncQueueItemModel> _pendingStockTakes = [];

  bool _isSyncing = false;
  String? _activeSingleItemKey;
  int _syncedCount = 0;
  int _processedCount = 0;
  int _totalToSyncCount = 0;
  String _currentStatusText = '';
  SyncBatchReportModel? _lastSyncReport;

  SyncViewModel(ApiService apiService)
      : _syncService = OfflineSyncService(apiService) {
    loadAllQueues();
  }

  // ===========================================================================
  // Getters (Bound to the View)
  // ===========================================================================

  List<SyncQueueItemModel> get pendingInvoices => _pendingInvoices;
  List<SyncQueueItemModel> get pendingVouchers => _pendingVouchers;
  List<SyncQueueItemModel> get pendingWastages => _pendingWastages;
  List<SyncQueueItemModel> get pendingStockTakes => _pendingStockTakes;

  List<SyncQueueItemModel> get allPendingItems => [
        ..._pendingInvoices,
        ..._pendingVouchers,
        ..._pendingWastages,
        ..._pendingStockTakes,
      ];

  int get invoicesCount => _pendingInvoices.length;
  int get vouchersCount => _pendingVouchers.length;
  int get wastagesCount => _pendingWastages.length;
  int get stockTakesCount => _pendingStockTakes.length;

  int get totalPendingCount =>
      _pendingInvoices.length +
      _pendingVouchers.length +
      _pendingWastages.length +
      _pendingStockTakes.length;

  bool get isSyncing => _isSyncing;
  String? get activeSingleItemKey => _activeSingleItemKey;
  int get syncedCount => _syncedCount;
  int get processedCount => _processedCount;
  int get totalToSyncCount => _totalToSyncCount;

  int get remainingCount =>
      (_totalToSyncCount - _processedCount).clamp(0, _totalToSyncCount);

  double get progressFraction => _totalToSyncCount > 0
      ? (_processedCount / _totalToSyncCount).clamp(0.0, 1.0)
      : 0.0;

  String get currentStatusText => _currentStatusText;
  SyncBatchReportModel? get lastSyncReport => _lastSyncReport;

  List<SyncQueueItemModel> itemsForCategory(SyncCategoryType category) {
    switch (category) {
      case SyncCategoryType.invoice:
        return _pendingInvoices;
      case SyncCategoryType.voucher:
        return _pendingVouchers;
      case SyncCategoryType.wastage:
        return _pendingWastages;
      case SyncCategoryType.stocktake:
        return _pendingStockTakes;
    }
  }

  // ===========================================================================
  // Commands / Actions
  // ===========================================================================

  Future<void> loadAllQueues() async {
    _pendingInvoices =
        await _syncService.loadQueueItemsByCategory(SyncCategoryType.invoice);
    _pendingVouchers =
        await _syncService.loadQueueItemsByCategory(SyncCategoryType.voucher);
    _pendingWastages =
        await _syncService.loadQueueItemsByCategory(SyncCategoryType.wastage);
    _pendingStockTakes =
        await _syncService.loadQueueItemsByCategory(SyncCategoryType.stocktake);
    notifyListeners();
  }

  /// طباعة أي عملية معلقة بكامل تفاصيلها مع ترويسة وعلامة "وثيقة غير معتمدة / لم تتم مزامنتها"
  Future<bool> printQueueItem(
    SyncQueueItemModel item,
    PrinterService printerService,
  ) async {
    return await _syncService.printOfflineQueueItem(item, printerService);
  }

  /// مزامنة عملية واحدة منفردة
  Future<SyncBatchReportModel> syncSingleItem(
    SyncQueueItemModel item, {
    Future<void> Function()? onQueuesUpdated,
  }) async {
    if (_isSyncing) {
      return SyncBatchReportModel(results: const [], completedAt: DateTime.now());
    }

    _isSyncing = true;
    _activeSingleItemKey = item.uniqueKey;
    _syncedCount = 0;
    _processedCount = 0;
    _totalToSyncCount = 1;
    _currentStatusText = 'جاري مزامنة: ${item.title}...';
    notifyListeners();

    final result = await _syncService.executeApiForItem(item);

    if (result.success) {
      _syncedCount = 1;
      await _syncService.removeOrUpdateItemInStorage(
        category: item.category,
        index: item.indexInCategory,
        remove: true,
      );
      _currentStatusText = 'تمت مزامنة ${item.title} بنجاح!';
    } else {
      await _syncService.removeOrUpdateItemInStorage(
        category: item.category,
        index: item.indexInCategory,
        remove: false,
        errorToSave: result.errorMessage,
      );
      _currentStatusText = 'تعذرت مزامنة ${item.title}';
    }

    _processedCount = 1;
    await loadAllQueues();
    if (onQueuesUpdated != null) {
      await onQueuesUpdated();
    }

    final report = SyncBatchReportModel(
      results: [result],
      completedAt: DateTime.now(),
    );
    _lastSyncReport = report;
    _isSyncing = false;
    _activeSingleItemKey = null;
    notifyListeners();

    return report;
  }

  /// مزامنة قسم محدد بالكامل (مثلاً الفواتير فقط أو السندات فقط)
  Future<SyncBatchReportModel> syncCategory(
    SyncCategoryType category, {
    Future<void> Function()? onQueuesUpdated,
  }) async {
    if (_isSyncing) {
      return SyncBatchReportModel(results: const [], completedAt: DateTime.now());
    }

    await loadAllQueues();
    final items = List<SyncQueueItemModel>.from(itemsForCategory(category));
    if (items.isEmpty) {
      return SyncBatchReportModel(results: const [], completedAt: DateTime.now());
    }

    _isSyncing = true;
    _activeSingleItemKey = null;
    _syncedCount = 0;
    _processedCount = 0;
    _totalToSyncCount = items.length;
    _currentStatusText = 'جاري بدء مزامنة ${category.arabicTitle}...';
    notifyListeners();

    final List<SyncItemResultModel> results = [];
    await _processCategorySequential(category, results);

    await loadAllQueues();
    if (onQueuesUpdated != null) {
      await onQueuesUpdated();
    }

    final report = SyncBatchReportModel(
      results: results,
      completedAt: DateTime.now(),
    );
    _lastSyncReport = report;
    _isSyncing = false;
    notifyListeners();
    return report;
  }

  /// مزامنة جماعية شاملة لجميع العمليات بالترتيب المحاسبي (فواتير -> سندات -> هالك -> جرد)
  Future<SyncBatchReportModel> syncAll({
    Future<void> Function()? onQueuesUpdated,
  }) async {
    if (_isSyncing) {
      return SyncBatchReportModel(results: const [], completedAt: DateTime.now());
    }

    await loadAllQueues();
    final int total = totalPendingCount;
    if (total == 0) {
      return SyncBatchReportModel(results: const [], completedAt: DateTime.now());
    }

    _isSyncing = true;
    _activeSingleItemKey = null;
    _syncedCount = 0;
    _processedCount = 0;
    _totalToSyncCount = total;
    _currentStatusText = 'جاري بدء المزامنة الشاملة ($total عملية)...';
    notifyListeners();

    final List<SyncItemResultModel> results = [];

    for (final category in [
      SyncCategoryType.invoice,
      SyncCategoryType.voucher,
      SyncCategoryType.wastage,
      SyncCategoryType.stocktake,
    ]) {
      await _processCategorySequential(category, results);
    }

    await loadAllQueues();
    if (onQueuesUpdated != null) {
      await onQueuesUpdated();
    }

    final report = SyncBatchReportModel(
      results: results,
      completedAt: DateTime.now(),
    );
    _lastSyncReport = report;
    _isSyncing = false;
    notifyListeners();
    return report;
  }

  Future<void> _processCategorySequential(
    SyncCategoryType category,
    List<SyncItemResultModel> resultsCollector,
  ) async {
    final snapshot =
        await _syncService.loadQueueItemsByCategory(category);
    if (snapshot.isEmpty) return;

    int removedSoFarInCategory = 0;

    for (int i = 0; i < snapshot.length; i++) {
      final originalItem = snapshot[i];
      final int currentStorageIndex =
          originalItem.indexInCategory - removedSoFarInCategory;

      _activeSingleItemKey = originalItem.uniqueKey;
      _currentStatusText =
          'جاري مزامنة: ${originalItem.title} (${_processedCount + 1} من $_totalToSyncCount)...';
      notifyListeners();

      final result = await _syncService.executeApiForItem(originalItem);
      resultsCollector.add(result);
      _processedCount++;

      if (result.success) {
        _syncedCount++;
        await _syncService.removeOrUpdateItemInStorage(
          category: category,
          index: currentStorageIndex,
          remove: true,
        );
        removedSoFarInCategory++;
        _currentStatusText =
            'تمت مزامنة: ${originalItem.title} (#${result.serverReferenceId ?? ''})';
      } else {
        await _syncService.removeOrUpdateItemInStorage(
          category: category,
          index: currentStorageIndex,
          remove: false,
          errorToSave: result.errorMessage,
        );
        _currentStatusText = 'تعذرت مزامنة: ${originalItem.title}';
      }

      await loadAllQueues();
    }
  }

  /// حذف عملية معلقة يدوياً من الطابور
  Future<void> deleteQueueItem(
    SyncQueueItemModel item, {
    Future<void> Function()? onQueuesUpdated,
  }) async {
    await _syncService.removeOrUpdateItemInStorage(
      category: item.category,
      index: item.indexInCategory,
      remove: true,
    );
    await loadAllQueues();
    if (onQueuesUpdated != null) {
      await onQueuesUpdated();
    }
  }
}
