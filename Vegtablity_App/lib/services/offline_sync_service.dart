import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_models.dart';
import 'api_service.dart';
import 'printer_service.dart';

class OfflineSyncService {
  final ApiService _apiService;

  OfflineSyncService(this._apiService);

  // ===========================================================================
  // 1. Queue Persistence Helpers (Read / Write SharedPreferences)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getRawInvoicesQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('unsynced_invoices');
      if (encoded != null && encoded.isNotEmpty) {
        final List<dynamic> decoded = json.decode(encoded);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveRawInvoicesQueue(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unsynced_invoices', json.encode(list));
  }

  Future<List<Map<String, dynamic>>> getRawVouchersQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('unsynced_vouchers');
      if (encoded != null && encoded.isNotEmpty) {
        final List<dynamic> decoded = json.decode(encoded);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveRawVouchersQueue(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unsynced_vouchers', json.encode(list));
  }

  Future<List<Map<String, dynamic>>> getRawWastagesQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('unsynced_wastages') ?? [];
      return list
          .map((s) => Map<String, dynamic>.from(json.decode(s) as Map))
          .toList();
    } catch (_) {}
    return [];
  }

  Future<void> saveRawWastagesQueue(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = list.map((m) => json.encode(m)).toList();
    await prefs.setStringList('unsynced_wastages', encoded);
  }

  Future<List<Map<String, dynamic>>> getRawStockTakesQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list =
          prefs.getStringList('unsynced_stocktakes') ?? [];
      return list
          .map((s) => Map<String, dynamic>.from(json.decode(s) as Map))
          .toList();
    } catch (_) {}
    return [];
  }

  Future<void> saveRawStockTakesQueue(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = list.map((m) => json.encode(m)).toList();
    await prefs.setStringList('unsynced_stocktakes', encoded);
  }

  /// إضافة فاتورة إلى طابور الأوفلاين (تُستخدم مثلاً في شاشة فواتير عروض الأسعار عند انقطاع الإنترنت)
  static Future<void> EnqueueOfflineInvoiceStatic(
      Map<String, dynamic> invoicePayload) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> current = [];
    final String? encoded = prefs.getString('unsynced_invoices');
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(encoded);
        current =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    current.add(Map<String, dynamic>.from(invoicePayload));
    await prefs.setString('unsynced_invoices', json.encode(current));
  }

  /// إضافة سند مباشر عام إلى طابور السندات الأوفلاين عند انقطاع الإنترنت
  static Future<void> EnqueueOfflineGeneralVoucherStatic(
      Map<String, dynamic> voucherPayload) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> current = [];
    final String? encoded = prefs.getString('unsynced_vouchers');
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(encoded);
        current =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    current.add({
      ...voucherPayload,
      'IsGeneral': true,
    });
    await prefs.setString('unsynced_vouchers', json.encode(current));
  }

  // ===========================================================================
  // 2. Build Structured Queue Models for the ViewModel
  // ===========================================================================

  Future<Map<int, String>> _loadCachedPartnersMap() async {
    final Map<int, String> result = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['cached_customers', 'cached_vendors']) {
        final String? raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final List<dynamic> list = json.decode(raw);
          for (final p in list) {
            if (p is Map) {
              final int? id = (p['PartnerID'] ?? p['id']) is num
                  ? ((p['PartnerID'] ?? p['id']) as num).toInt()
                  : int.tryParse((p['PartnerID'] ?? p['id'])?.toString() ?? '');
              final String name =
                  (p['PartnerName'] ?? p['name'] ?? '').toString();
              if (id != null && name.isNotEmpty) {
                result[id] = name;
              }
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  Future<Map<int, String>> _loadCachedAccountsMap() async {
    final Map<int, String> result = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('cached_accounts');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = json.decode(raw);
        for (final a in list) {
          if (a is Map) {
            final int? id = (a['AccountID'] ?? a['id']) is num
                ? ((a['AccountID'] ?? a['id']) as num).toInt()
                : int.tryParse((a['AccountID'] ?? a['id'])?.toString() ?? '');
            final String name =
                (a['AccountName'] ?? a['name'] ?? '').toString();
            if (id != null && name.isNotEmpty) {
              result[id] = name;
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  Future<List<SyncQueueItemModel>> loadQueueItemsByCategory(
      SyncCategoryType category) async {
    final partnersMap = await _loadCachedPartnersMap();
    final accountsMap = await _loadCachedAccountsMap();

    switch (category) {
      case SyncCategoryType.invoice:
        final rawList = await getRawInvoicesQueue();
        return List.generate(rawList.length, (i) {
          final inv = Map<String, dynamic>.from(rawList[i]);
          final bool isPurchase = inv['InvType'] == 'Purchase';
          final String typeTitle =
              isPurchase ? 'فاتورة مشتريات' : 'فاتورة مبيعات';
          final List<dynamic> details =
              (inv['Details'] is List) ? inv['Details'] : [];
          final double netAmount =
              ((inv['NetAmount'] ?? inv['TotalAmount'] ?? 0) as num).toDouble();

          final int? pId = (inv['PartnerID'] is num)
              ? (inv['PartnerID'] as num).toInt()
              : int.tryParse(inv['PartnerID']?.toString() ?? '');
          String partnerName = inv['_partnerName']?.toString() ??
              inv['PartnerName']?.toString() ??
              inv['TempCustomerName']?.toString() ??
              (pId != null ? (partnersMap[pId] ?? '') : '');
          if (partnerName.isNotEmpty) {
            inv['_resolvedPartnerName'] = partnerName;
          }

          final int? accId = (inv['PaymentAccountID'] is num)
              ? (inv['PaymentAccountID'] as num).toInt()
              : int.tryParse(inv['PaymentAccountID']?.toString() ?? '');
          if (accId != null && accountsMap.containsKey(accId)) {
            inv['_resolvedPaymentAccountName'] = accountsMap[accId];
          }

          final String notes = inv['Notes']?.toString() ?? '';
          final String sub = [
            if (partnerName.isNotEmpty) 'الشريك: $partnerName',
            if (notes.isNotEmpty) notes,
          ].join(' | ');

          return SyncQueueItemModel(
            category: SyncCategoryType.invoice,
            indexInCategory: i,
            uniqueKey: 'invoice_${i}_${inv['InvDate'] ?? ''}',
            title: '$typeTitle (${details.length} أصناف)',
            subtitle: sub.isEmpty ? 'عملية محفوظة محلياً (غير معتمدة)' : sub,
            amount: netAmount,
            date: _formatDateString(inv['InvDate']?.toString()),
            itemsCount: details.length,
            rawPayload: inv,
            lastError: inv['_lastSyncError']?.toString(),
          );
        });

      case SyncCategoryType.voucher:
        final rawList = await getRawVouchersQueue();
        return List.generate(rawList.length, (i) {
          final v = Map<String, dynamic>.from(rawList[i]);
          final bool isReceipt = v['VoucherType'] == 'Receipt';
          final bool isGeneral = v['IsGeneral'] == true;
          final String typeTitle = isGeneral
              ? (isReceipt ? 'سند قبض مباشر (عام)' : 'سند صرف مباشر (عام)')
              : (isReceipt ? 'سند قبض عميل' : 'سند صرف مورد');
          final double amount =
              ((v['TotalAmount'] ?? v['Amount'] ?? 0) as num).toDouble();

          final int? pId = (v['PartnerID'] is num)
              ? (v['PartnerID'] as num).toInt()
              : int.tryParse(v['PartnerID']?.toString() ?? '');
          final int? accId = (v['AccountID'] is num)
              ? (v['AccountID'] as num).toInt()
              : int.tryParse(v['AccountID']?.toString() ?? '');
          final int? cashAccId = int.tryParse(v['PaymentMethod']?.toString() ?? '');

          final String partnerOrAcc = v['PartnerName']?.toString() ??
              v['TargetAccountName']?.toString() ??
              (isGeneral
                  ? (accId != null ? (accountsMap[accId] ?? 'حساب #$accId') : '')
                  : (pId != null ? (partnersMap[pId] ?? 'شريك #$pId') : ''));

          v['_resolvedTargetName'] = partnerOrAcc;
          if (isGeneral) {
            v['_resolvedCashAccountName'] =
                (cashAccId != null && accountsMap.containsKey(cashAccId))
                    ? accountsMap[cashAccId]!
                    : (v['PaymentMethod']?.toString() ?? 'الصندوق الرئيسي');
          } else {
            v['_resolvedCashAccountName'] =
                (accId != null && accountsMap.containsKey(accId))
                    ? accountsMap[accId]!
                    : 'حساب نقدية #${accId ?? 1}';
          }

          final String desc = v['Description']?.toString() ?? '';
          final List<dynamic> allocs =
              (v['Allocations'] is List) ? v['Allocations'] : [];
          final String sub = [
            if (partnerOrAcc.isNotEmpty) partnerOrAcc,
            if (desc.isNotEmpty) desc,
          ].join(' - ');

          return SyncQueueItemModel(
            category: SyncCategoryType.voucher,
            indexInCategory: i,
            uniqueKey: 'voucher_${i}_${v['VoucherDate'] ?? ''}',
            title: typeTitle,
            subtitle: sub.isEmpty ? 'سند محفوظ محلياً (غير معتمد)' : sub,
            amount: amount,
            date: _formatDateString(v['VoucherDate']?.toString()),
            itemsCount: allocs.length,
            rawPayload: v,
            lastError: v['_lastSyncError']?.toString(),
          );
        });

      case SyncCategoryType.wastage:
        final rawList = await getRawWastagesQueue();
        return List.generate(rawList.length, (i) {
          final w = Map<String, dynamic>.from(rawList[i]);
          final List<dynamic> details =
              (w['Details'] is List) ? w['Details'] : [];
          final double totalValue =
              ((w['TotalValue'] ?? 0) as num).toDouble();
          final String notes = w['Notes']?.toString() ?? '';

          return SyncQueueItemModel(
            category: SyncCategoryType.wastage,
            indexInCategory: i,
            uniqueKey: 'wastage_${i}_${w['WastageDate'] ?? ''}',
            title: 'مسودة هالك (${details.length} أصناف)',
            subtitle:
                notes.isEmpty ? 'مستودع رقم #${w['WarehouseID'] ?? 1}' : notes,
            amount: totalValue,
            date: _formatDateString(w['WastageDate']?.toString()),
            itemsCount: details.length,
            rawPayload: w,
            lastError: w['_lastSyncError']?.toString(),
          );
        });

      case SyncCategoryType.stocktake:
        final rawList = await getRawStockTakesQueue();
        return List.generate(rawList.length, (i) {
          final st = Map<String, dynamic>.from(rawList[i]);
          final List<dynamic> details =
              (st['Details'] is List) ? st['Details'] : [];
          final double diffVal =
              ((st['TotalDifferenceValue'] ?? 0) as num).toDouble();
          final String notes = st['Notes']?.toString() ?? '';

          return SyncQueueItemModel(
            category: SyncCategoryType.stocktake,
            indexInCategory: i,
            uniqueKey: 'stocktake_${i}_${st['StockTakeDate'] ?? ''}',
            title: 'مسودة جرد مخزني (${details.length} أصناف)',
            subtitle: notes.isEmpty
                ? 'مستودع رقم #${st['WarehouseID'] ?? 1}'
                : notes,
            amount: diffVal,
            date: _formatDateString(st['StockTakeDate']?.toString()),
            itemsCount: details.length,
            rawPayload: st,
            lastError: st['_lastSyncError']?.toString(),
          );
        });
    }
  }

  // ===========================================================================
  // 3. Offline Receipt Printing (With Prominent Unapproved / Unsynced Banner)
  // ===========================================================================

  Future<bool> printOfflineQueueItem(
    SyncQueueItemModel item,
    PrinterService printerService,
  ) async {
    final raw = Map<String, dynamic>.from(item.rawPayload);

    switch (item.category) {
      case SyncCategoryType.invoice:
        final List<dynamic> rawDetails =
            (raw['Details'] is List) ? raw['Details'] : [];
        final List<Map<String, dynamic>> formattedItems = rawDetails.map((d) {
          final m = Map<String, dynamic>.from(d as Map);
          final pid = m['ProductID'] ?? m['product_id'] ?? '';
          final pName = m['ProductName'] ??
              m['product_name'] ??
              m['name'] ??
              'صنف #$pid';
          return {
            ...m,
            'ProductName': pName,
            'product_name': pName,
            'name': pName,
            'UnitName': m['UnitName'] ?? m['unit_name'] ?? '',
            'Quantity': m['Quantity'] ?? m['quantity'] ?? 1,
            'UnitPrice': m['UnitPrice'] ?? m['Price'] ?? m['price'] ?? 0,
            'TotalPrice': m['TotalPrice'] ?? m['Total'] ?? m['total'] ?? 0,
          };
        }).toList();

        final double netAmt =
            ((raw['NetAmount'] ?? raw['TotalAmount'] ?? 0) as num).toDouble();
        final double discAmt =
            ((raw['Discount'] ?? raw['TotalDiscount'] ?? 0) as num).toDouble();
        final double paidAmt = ((raw['PaidAmount'] ?? 0) as num).toDouble();
        final double remAmt = ((raw['Remainder'] ??
                ((netAmt - paidAmt) > 0 ? (netAmt - paidAmt) : 0.0)) as num)
            .toDouble();

        final Map<String, dynamic> printInvoice = {
          ...raw,
          'is_offline_unapproved': true,
          'id': 'غير معتمدة (لم تُزامن)',
          'InvID': 'غير معتمدة (لم تُزامن)',
          'invoice_type': raw['InvType'] ?? 'Sales',
          'InvType': raw['InvType'] ?? 'Sales',
          'partner_name': raw['_resolvedPartnerName'] ??
              raw['_partnerName'] ??
              raw['TempCustomerName'] ??
              'عميل نقدي',
          'PartnerName': raw['_resolvedPartnerName'] ??
              raw['_partnerName'] ??
              raw['TempCustomerName'] ??
              'عميل نقدي',
          'created_at': raw['InvDate'] ?? DateTime.now().toIso8601String(),
          'items': formattedItems,
          'Details': formattedItems,
          'total_amount': netAmt,
          'NetAmount': netAmt,
          'total_discount': discAmt,
          'original_total': netAmt + discAmt,
          'paid_amount': paidAmt,
          'PaidAmount': paidAmt,
          'remainder': remAmt,
          'Remainder': remAmt,
          'PaymentAccountName': raw['_resolvedPaymentAccountName'] ??
              raw['PaymentMethod'] ??
              'نقدي',
        };
        return await printerService.printReceipt(printInvoice, isReprint: true);

      case SyncCategoryType.voucher:
        final bool isGeneral = raw['IsGeneral'] == true;
        final String targetName =
            raw['_resolvedTargetName']?.toString() ?? 'غير محدد';
        final String cashName =
            raw['_resolvedCashAccountName']?.toString() ?? 'الصندوق الرئيسي';

        if (isGeneral) {
          final Map<String, dynamic> printGenVoucher = {
            ...raw,
            'is_offline_unapproved': true,
            'VoucherID': 'غير معتمد (لم يُزامن)',
            'id': 'غير معتمد (لم يُزامن)',
            'type': raw['VoucherType'] ?? 'Receipt',
            'amount': raw['TotalAmount'] ?? raw['Amount'] ?? 0.0,
            'Amount': raw['TotalAmount'] ?? raw['Amount'] ?? 0.0,
            'notes': raw['Description'] ?? '',
            'Notes': raw['Description'] ?? '',
          };
          return await printerService.printGeneralVoucher(
            printGenVoucher,
            targetName,
            cashName,
            isReprint: true,
          );
        } else {
          final List<dynamic> rawAllocs =
              (raw['Allocations'] is List) ? raw['Allocations'] : [];
          final List<Map<String, dynamic>> paidInvs = rawAllocs.map((a) {
            final m = Map<String, dynamic>.from(a as Map);
            return {
              'InvoiceID': m['InvID'] ?? m['InvoiceID'] ?? '--',
              'PaidAmount': m['AllocatedAmount'] ?? m['PaidAmount'] ?? 0.0,
            };
          }).toList();

          final Map<String, dynamic> printVoucher = {
            ...raw,
            'is_offline_unapproved': true,
            'VoucherID': 'غير معتمد (لم يُزامن)',
            'id': 'غير معتمد (لم يُزامن)',
            'VoucherType': raw['VoucherType'] ?? 'Receipt',
            'type': (raw['VoucherType'] == 'Payment') ? 'payment' : 'receipt',
            'PartnerName': targetName,
            'partner_name': targetName,
            'VoucherDate': item.date,
            'date': item.date,
            'Amount': raw['TotalAmount'] ?? raw['Amount'] ?? 0.0,
            'amount': raw['TotalAmount'] ?? raw['Amount'] ?? 0.0,
            'PaymentMethod': cashName,
            'payment_method': cashName,
            'Notes': raw['Description'] ?? '',
            'notes': raw['Description'] ?? '',
          };
          return await printerService.printVoucher(
            printVoucher,
            paidInvs,
            isReprint: true,
          );
        }

      case SyncCategoryType.wastage:
        final List<dynamic> rawDetails =
            (raw['Details'] is List) ? raw['Details'] : [];
        final List<Map<String, dynamic>> formattedItems = rawDetails.map((d) {
          final m = Map<String, dynamic>.from(d as Map);
          final pid = m['ProductID'] ?? '';
          final pName = m['ProductName'] ??
              m['product_name'] ??
              m['name'] ??
              'صنف #$pid';
          return {
            ...m,
            'ProductName': pName,
            'product_name': pName,
            'name': pName,
            'Quantity': m['Quantity'] ?? 0,
            'UnitName': m['UnitName'] ?? '',
          };
        }).toList();

        final Map<String, dynamic> printWastage = {
          ...raw,
          'is_offline_unapproved': true,
          'WastageID': 'غير معتمد (لم يُزامن)',
          'id': 'غير معتمد (لم يُزامن)',
          'Reason': raw['Notes'] ?? 'إتلاف محفوظ محلياً',
          'Date': item.date,
          'date': item.date,
          'items': formattedItems,
          'details': formattedItems,
        };
        return await printerService.printWastageReceipt(
          printWastage,
          isReprint: true,
        );

      case SyncCategoryType.stocktake:
        final List<dynamic> rawDetails =
            (raw['Details'] is List) ? raw['Details'] : [];
        final List<Map<String, dynamic>> formattedItems = rawDetails.map((d) {
          final m = Map<String, dynamic>.from(d as Map);
          final pid = m['ProductID'] ?? '';
          final pName = m['ProductName'] ??
              m['product_name'] ??
              m['name'] ??
              'صنف #$pid';
          return {
            ...m,
            'ProductName': pName,
            'product_name': pName,
            'name': pName,
            'CountedQty': m['ActualQuantity'] ?? m['CountedQty'] ?? 0,
            'counted': m['ActualQuantity'] ?? m['CountedQty'] ?? 0,
            'UnitName': m['UnitName'] ?? '',
          };
        }).toList();

        final Map<String, dynamic> printStockTake = {
          ...raw,
          'is_offline_unapproved': true,
          'StockTakeID': 'غير معتمد (لم يُزامن)',
          'id': 'غير معتمد (لم يُزامن)',
          'Date': item.date,
          'date': item.date,
          'items': formattedItems,
          'details': formattedItems,
        };
        return await printerService.printStockTakeReceipt(
          printStockTake,
          isReprint: true,
        );
    }
  }

  // ===========================================================================
  // 4. Core Sync Execution (Single Item & Batch Helper)
  // ===========================================================================

  bool isNetworkConnectionError(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
    }
    return false;
  }

  String extractReadableError(Object e) {
    if (e is DioException) {
      if (isNetworkConnectionError(e)) {
        return 'تعذر الاتصال بالخادم (تحقق من الاتصال بالإنترنت)';
      }
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (data != null && data.toString().isNotEmpty) {
        return data.toString();
      }
      return 'خطأ من الخادم (${e.response?.statusCode ?? e.message})';
    }
    return e.toString();
  }

  /// إرسال عملية واحدة للخادم دون حذفها تلقائياً من القائمة (يتم الحذف في الدالة المستدعية)
  Future<SyncItemResultModel> executeApiForItem(SyncQueueItemModel item) async {
    try {
      switch (item.category) {
        case SyncCategoryType.invoice:
          final cleanPayload = Map<String, dynamic>.from(item.rawPayload);
          cleanPayload.remove('_lastSyncError');
          cleanPayload.remove('_partnerName');
          cleanPayload.remove('_resolvedPartnerName');
          cleanPayload.remove('_resolvedPaymentAccountName');

          if (cleanPayload['Details'] is List) {
            cleanPayload['Details'] = (cleanPayload['Details'] as List).map((d) {
              final m = Map<String, dynamic>.from(d as Map);
              return {
                'ProductID': m['ProductID'],
                'UnitPrice': m['UnitPrice'],
                'Quantity': m['Quantity'],
                'TotalPrice': m['TotalPrice'],
                'CostPrice': m['CostPrice'] ?? 0.0,
              };
            }).toList();
          }

          final response = await _apiService.saveInvoice(cleanPayload);
          if (response.statusCode == 200 || response.statusCode == 201) {
            final dynamic data = response.data;
            final int? invId =
                (data is Map ? (data['InvID'] ?? data['id']) : null) as int?;
            return SyncItemResultModel(
              success: true,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              serverReferenceId: invId,
              amount: item.amount,
              date: item.date,
            );
          } else {
            return SyncItemResultModel(
              success: false,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              amount: item.amount,
              date: item.date,
              errorMessage: 'استجابة غير متوقعة (${response.statusCode})',
            );
          }

        case SyncCategoryType.voucher:
          final raw = item.rawPayload;
          final bool isGeneral = raw['IsGeneral'] == true;
          final Response response;

          if (isGeneral) {
            response = await _apiService.saveGeneralVoucher(
              voucherType: raw['VoucherType']?.toString() ?? 'Receipt',
              totalAmount: ((raw['TotalAmount'] ?? 0) as num).toDouble(),
              accountId: (raw['AccountID'] as num).toInt(),
              description: raw['Description']?.toString() ?? '',
              paymentMethod: raw['PaymentMethod']?.toString() ?? '1',
              shiftId: (raw['ShiftID'] as num?)?.toInt(),
            );
          } else {
            final List<dynamic> rawAllocs =
                (raw['Allocations'] is List) ? raw['Allocations'] : [];
            final List<Map<String, dynamic>> typedAllocs = rawAllocs
                .map((a) => Map<String, dynamic>.from(a as Map))
                .toList();

            response = await _apiService.bulkPay(
              partnerId: (raw['PartnerID'] as num).toInt(),
              voucherType: raw['VoucherType']?.toString() ?? 'Receipt',
              totalAmount: ((raw['TotalAmount'] ?? 0) as num).toDouble(),
              accountId: (raw['AccountID'] as num).toInt(),
              shiftId: (raw['ShiftID'] as num?)?.toInt() ?? 0,
              allocations: typedAllocs,
              description: raw['Description']?.toString() ?? '',
            );
          }

          if (response.statusCode == 200 || response.statusCode == 201) {
            final dynamic data = response.data;
            final int? voucherId = (data is Map
                ? (data['VoucherID'] ?? data['VoucherNo'] ?? data['id'])
                : null) as int?;
            return SyncItemResultModel(
              success: true,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              serverReferenceId: voucherId,
              amount: item.amount,
              date: item.date,
            );
          } else {
            return SyncItemResultModel(
              success: false,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              amount: item.amount,
              date: item.date,
              errorMessage: 'استجابة غير متوقعة (${response.statusCode})',
            );
          }

        case SyncCategoryType.wastage:
          final cleanPayload = Map<String, dynamic>.from(item.rawPayload);
          cleanPayload.remove('_lastSyncError');
          if (cleanPayload['Details'] is List) {
            cleanPayload['Details'] = (cleanPayload['Details'] as List).map((d) {
              final m = Map<String, dynamic>.from(d as Map);
              return {
                'ProductID': m['ProductID'],
                'Quantity': m['Quantity'],
                'CostPrice': m['CostPrice'] ?? 0.0,
                'StockBefore': m['StockBefore'] ?? 0.0,
              };
            }).toList();
          }

          final response = await _apiService.saveWastage(cleanPayload);
          if (response.statusCode == 200 || response.statusCode == 201) {
            final dynamic data = response.data;
            final int? wastageId =
                (data is Map ? (data['WastageID'] ?? data['id']) : null) as int?;
            return SyncItemResultModel(
              success: true,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              serverReferenceId: wastageId,
              amount: item.amount,
              date: item.date,
            );
          } else {
            return SyncItemResultModel(
              success: false,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              amount: item.amount,
              date: item.date,
              errorMessage: 'استجابة غير متوقعة (${response.statusCode})',
            );
          }

        case SyncCategoryType.stocktake:
          final cleanPayload = Map<String, dynamic>.from(item.rawPayload);
          cleanPayload.remove('_lastSyncError');
          if (cleanPayload['Details'] is List) {
            cleanPayload['Details'] = (cleanPayload['Details'] as List).map((d) {
              final m = Map<String, dynamic>.from(d as Map);
              return {
                'ProductID': m['ProductID'],
                'SystemQuantity': m['SystemQuantity'],
                'ActualQuantity': m['ActualQuantity'],
                'CostPrice': m['CostPrice'] ?? 0.0,
              };
            }).toList();
          }

          final response = await _apiService.saveStockTake(cleanPayload);
          if (response.statusCode == 200 || response.statusCode == 201) {
            final dynamic data = response.data;
            final int? stockTakeId = (data is Map
                ? (data['StockTakeID'] ?? data['id'])
                : null) as int?;
            return SyncItemResultModel(
              success: true,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              serverReferenceId: stockTakeId,
              amount: item.amount,
              date: item.date,
            );
          } else {
            return SyncItemResultModel(
              success: false,
              category: item.category,
              title: item.title,
              subtitle: item.subtitle,
              amount: item.amount,
              date: item.date,
              errorMessage: 'استجابة غير متوقعة (${response.statusCode})',
            );
          }
      }
    } catch (e) {
      return SyncItemResultModel(
        success: false,
        category: item.category,
        title: item.title,
        subtitle: item.subtitle,
        amount: item.amount,
        date: item.date,
        errorMessage: extractReadableError(e),
      );
    }
  }

  /// حذف عنصر محدد أو تحديث رسالة الخطأ الخاصة به في التخزين المحلي
  Future<void> removeOrUpdateItemInStorage({
    required SyncCategoryType category,
    required int index,
    required bool remove,
    String? errorToSave,
  }) async {
    switch (category) {
      case SyncCategoryType.invoice:
        final list = await getRawInvoicesQueue();
        if (index >= 0 && index < list.length) {
          if (remove) {
            list.removeAt(index);
          } else if (errorToSave != null) {
            list[index]['_lastSyncError'] = errorToSave;
          }
          await saveRawInvoicesQueue(list);
        }
        break;

      case SyncCategoryType.voucher:
        final list = await getRawVouchersQueue();
        if (index >= 0 && index < list.length) {
          if (remove) {
            list.removeAt(index);
          } else if (errorToSave != null) {
            list[index]['_lastSyncError'] = errorToSave;
          }
          await saveRawVouchersQueue(list);
        }
        break;

      case SyncCategoryType.wastage:
        final list = await getRawWastagesQueue();
        if (index >= 0 && index < list.length) {
          if (remove) {
            list.removeAt(index);
          } else if (errorToSave != null) {
            list[index]['_lastSyncError'] = errorToSave;
          }
          await saveRawWastagesQueue(list);
        }
        break;

      case SyncCategoryType.stocktake:
        final list = await getRawStockTakesQueue();
        if (index >= 0 && index < list.length) {
          if (remove) {
            list.removeAt(index);
          } else if (errorToSave != null) {
            list[index]['_lastSyncError'] = errorToSave;
          }
          await saveRawStockTakesQueue(list);
        }
        break;
    }
  }

  String _formatDateString(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '-';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    final y = parsed.year.toString();
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }
}
