enum SyncCategoryType {
  invoice,
  voucher,
  wastage,
  stocktake,
}

extension SyncCategoryTypeExtension on SyncCategoryType {
  String get arabicTitle {
    switch (this) {
      case SyncCategoryType.invoice:
        return 'الفواتير (مبيعات / مشتريات / عروض أسعار)';
      case SyncCategoryType.voucher:
        return 'السندات (قبض / صرف / سندات مباشرة)';
      case SyncCategoryType.wastage:
        return 'مسودات الهالك';
      case SyncCategoryType.stocktake:
        return 'مسودات الجرد المخزني';
    }
  }

  String get shortTitle {
    switch (this) {
      case SyncCategoryType.invoice:
        return 'فاتورة';
      case SyncCategoryType.voucher:
        return 'سند';
      case SyncCategoryType.wastage:
        return 'هالك';
      case SyncCategoryType.stocktake:
        return 'جرد مخزني';
    }
  }
}

class SyncQueueItemModel {
  final SyncCategoryType category;
  final int indexInCategory;
  final String uniqueKey;
  final String title;
  final String subtitle;
  final double amount;
  final String date;
  final int itemsCount;
  final Map<String, dynamic> rawPayload;
  final String? lastError;

  const SyncQueueItemModel({
    required this.category,
    required this.indexInCategory,
    required this.uniqueKey,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.itemsCount,
    required this.rawPayload,
    this.lastError,
  });
}

class SyncItemResultModel {
  final bool success;
  final SyncCategoryType category;
  final String title;
  final String subtitle;
  final int? serverReferenceId;
  final double amount;
  final String date;
  final String? errorMessage;

  const SyncItemResultModel({
    required this.success,
    required this.category,
    required this.title,
    required this.subtitle,
    this.serverReferenceId,
    required this.amount,
    required this.date,
    this.errorMessage,
  });
}

class SyncBatchReportModel {
  final List<SyncItemResultModel> results;
  final DateTime completedAt;

  const SyncBatchReportModel({
    required this.results,
    required this.completedAt,
  });

  List<SyncItemResultModel> get syncedItems =>
      results.where((r) => r.success).toList();

  List<SyncItemResultModel> get failedItems =>
      results.where((r) => !r.success).toList();

  int get totalAttempted => results.length;
  int get syncedCount => syncedItems.length;
  int get failedCount => failedItems.length;
  bool get isAllSuccess => results.isNotEmpty && failedItems.isEmpty;
}

