import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/integration_models.dart';
import '../api_service.dart';
import 'myfatoorah_gateway_service.dart';

class IntegrationPosService {
  Future<Dio> _buildDio() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? prefs.getString('auth_token');
    return Dio(
      BaseOptions(
        baseUrl: 'http://${ApiService.ipAddress}',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  String _cleanPhoneDigits(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '50000000';
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00965')) digits = digits.substring(5);
    if (digits.startsWith('965') && digits.length > 8) digits = digits.substring(3);
    return digits.isEmpty ? '50000000' : digits;
  }

  Future<Map<String, String>?> _requestDirectGatewayLink({
    required IntegrationProviderModel provider,
    required int invId,
    required double amount,
    required String currencyCode,
    required String customerName,
    required String customerPhone,
  }) async {
    final secret = provider.secretKey.trim();
    if (secret.isEmpty) return null;

    final code = provider.providerCode.toUpperCase();
    final phoneDigits = _cleanPhoneDigits(customerPhone);
    final custName = customerName.trim().isEmpty ? 'عميل نقدي' : customerName.trim();
    final callbackUrl = provider.callbackUrl.trim().isNotEmpty
        ? provider.callbackUrl.trim()
        : 'http://${ApiService.ipAddress}/integrations/webhooks/${code.toLowerCase()}';

    final gwDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Authorization': 'Bearer $secret',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      if (code == 'TAP') {
        final baseUrl = provider.baseUrl.trim().isNotEmpty
            ? provider.baseUrl.trim().replaceAll(RegExp(r'/$'), '')
            : 'https://api.tap.company/v2';
        final res = await gwDio.post(
          '$baseUrl/charges',
          data: {
            'amount': double.parse(amount.toStringAsFixed(3)),
            'currency': currencyCode.isEmpty ? 'KWD' : currencyCode,
            'customer_initiated': true,
            'threeDSecure': true,
            'description': 'فاتورة مبيعات رقم #$invId',
            'reference': {'transaction': 'INV_$invId', 'order': 'ORD_$invId'},
            'receipt': {'email': false, 'sms': true},
            'customer': {
              'first_name': custName,
              'phone': {'country_code': '965', 'number': phoneDigits},
            },
            'source': {'id': 'src_all'},
            'post': {'url': callbackUrl},
            'redirect': {'url': callbackUrl},
          },
        );
        if (res.data is Map) {
          final map = Map<String, dynamic>.from(res.data);
          final tx = map['transaction'] is Map ? Map<String, dynamic>.from(map['transaction']) : <String, dynamic>{};
          final payUrl = (tx['url'] ?? map['url'] ?? '').toString();
          final extId = (map['id'] ?? '').toString();
          if (payUrl.isNotEmpty) {
            return {
              'PaymentUrl': payUrl,
              'ExternalChargeID': extId,
              'ExternalInvoiceID': extId,
            };
          }
        }
      } else if (code == 'MYFATOORAH') {
        return await MyFatoorahGatewayService().createPaymentLink(
          provider: provider,
          invId: invId,
          amount: amount,
          currencyCode: currencyCode,
          customerName: custName,
          phoneDigits: phoneDigits,
          callbackUrl: callbackUrl,
        );
      } else if (code == 'UPAYMENTS') {
        final isLive = provider.environmentMode.toLowerCase() == 'live';
        final baseUrl = provider.baseUrl.trim().isNotEmpty
            ? provider.baseUrl.trim().replaceAll(RegExp(r'/$'), '')
            : (isLive ? 'https://uapi.upayments.com/api/v1' : 'https://sandboxapi.upayments.com/api/v1');
        final orderId = 'ORD_${invId}_${DateTime.now().millisecondsSinceEpoch}';
        final res = await gwDio.post(
          '$baseUrl/charge',
          data: {
            'order': {
              'id': orderId,
              'reference': 'INV_$invId',
              'description': 'Invoice #$invId',
              'currency': currencyCode.isEmpty ? 'KWD' : currencyCode,
              'amount': double.parse(amount.toStringAsFixed(3)),
            },
            'language': 'ar',
            'paymentGateway': {'src': 'create-invoice'},
            'reference': {'id': 'INV_$invId'},
            'customer': {
              'uniqueId': 'CUST_$invId',
              'name': custName,
              'mobile': '+965$phoneDigits',
            },
            'returnUrl': callbackUrl,
            'cancelUrl': callbackUrl,
            'notificationUrl': callbackUrl,
          },
        );
        if (res.data is Map) {
          final map = Map<String, dynamic>.from(res.data);
          final dObj = map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map;
          final payUrl = (dObj['link'] ?? '').toString();
          final extId = (dObj['trackId'] ?? orderId).toString();
          if (payUrl.isNotEmpty) {
            return {
              'PaymentUrl': payUrl,
              'ExternalChargeID': extId,
              'ExternalInvoiceID': extId,
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> fetchProvidersSummary({bool onlyEnabled = true}) async {
    try {
      final dio = await _buildDio();
      final res = await dio.get('/integrations/providers', queryParameters: {'only_enabled': onlyEnabled});
      if (res.statusCode == 200 && res.data is Map) {
        final rawList = (res.data['providers'] as List?) ?? [];
        final providers = rawList
            .map((e) => IntegrationProviderModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        await cacheGatewayAccountIds(providers);
        return {
          'providers': providers,
          'isTalabatConfigured': res.data['is_talabat_configured'] == true,
        };
      }
    } catch (_) {}
    return {'providers': <IntegrationProviderModel>[], 'isTalabatConfigured': false};
  }

  static Future<void> cacheGatewayAccountIds(List<IntegrationProviderModel> providers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('cached_gateway_account_ids') ?? const <String>[];
      final ids = <String>{...existing};
      for (final p in providers) {
        if (p.isPaymentGateway && p.linkedAccountId != null && p.linkedAccountId! > 0) {
          ids.add(p.linkedAccountId!.toString());
        }
      }
      await prefs.setStringList('cached_gateway_account_ids', ids.toList());
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> filterOutGatewayAccounts(
    List<Map<String, dynamic>> accounts, {
    List<IntegrationProviderModel>? knownProviders,
  }) async {
    final ids = <int>{};
    if (knownProviders != null) {
      for (final p in knownProviders) {
        if (p.isPaymentGateway && p.linkedAccountId != null && p.linkedAccountId! > 0) {
          ids.add(p.linkedAccountId!);
        }
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('cached_gateway_account_ids') ?? const <String>[];
      for (final s in cached) {
        final parsed = int.tryParse(s);
        if (parsed != null && parsed > 0) ids.add(parsed);
      }
    } catch (_) {}

    if (ids.isEmpty) return accounts;
    return accounts.where((acc) {
      final raw = acc['AccountID'];
      final accId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      return accId == null || !ids.contains(accId);
    }).toList();
  }

  String _extractErrorMessage(dynamic e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (data is String && data.trim().isNotEmpty) {
        return data;
      }
      if (e.message != null && e.message!.trim().isNotEmpty) {
        return e.message!;
      }
    }
    return fallback;
  }

  Future<List<GatewayCustomerModel>> fetchGatewayCustomers({String search = ''}) async {
    try {
      final dio = await _buildDio();
      final res = await dio.get('/partners/', queryParameters: {
        'type': 'Customer',
        'search': search,
      });
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => GatewayCustomerModel.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.partnerId > 0)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<PaymentLinksPagedResult> fetchPaymentLinksPaged({
    String? providerCode,
    String? status,
    String? searchText,
    int pageNumber = 1,
    int pageSize = 25,
  }) async {
    try {
      final dio = await _buildDio();
      final res = await dio.get('/integrations/payment-links/paged', queryParameters: {
        if (providerCode != null && providerCode != 'ALL' && providerCode.isNotEmpty)
          'provider_code': providerCode,
        if (status != null && status != 'ALL' && status.isNotEmpty) 'status': status,
        if (searchText != null && searchText.trim().isNotEmpty) 'search_text': searchText.trim(),
        'page_number': pageNumber,
        'page_size': pageSize,
      });
      if (res.statusCode == 200 && res.data is Map) {
        final map = Map<String, dynamic>.from(res.data);
        final rawItems = (map['items'] as List?) ?? [];
        return PaymentLinksPagedResult(
          items: rawItems
              .map((e) => PaymentLinkRecordModel.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          totalCount: int.tryParse(map['total_count']?.toString() ?? '0') ?? 0,
          summaryPaid: double.tryParse(map['summary_paid']?.toString() ?? '0') ?? 0.0,
          summaryPending: double.tryParse(map['summary_pending']?.toString() ?? '0') ?? 0.0,
          summaryRefunded: double.tryParse(map['summary_refunded']?.toString() ?? '0') ?? 0.0,
          pageNumber: int.tryParse(map['page_number']?.toString() ?? '$pageNumber') ?? pageNumber,
          pageSize: int.tryParse(map['page_size']?.toString() ?? '$pageSize') ?? pageSize,
        );
      }
    } catch (_) {}
    return PaymentLinksPagedResult(
      items: const [],
      totalCount: 0,
      summaryPaid: 0.0,
      summaryPending: 0.0,
      summaryRefunded: 0.0,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<InvoiceQuickInfoModel?> fetchInvoiceQuickInfo(int invId) async {
    try {
      final dio = await _buildDio();
      final res = await dio.get('/integrations/payment-links/invoice-quick-info/$invId');
      if (res.statusCode == 200 && res.data is Map) {
        return InvoiceQuickInfoModel.fromJson(Map<String, dynamic>.from(res.data));
      }
    } catch (_) {}
    return null;
  }

  Future<List<PaymentLinkRecordModel>> fetchPaymentLinks({String? status, String? searchText}) async {
    try {
      final dio = await _buildDio();
      final res = await dio.get('/integrations/payment-links', queryParameters: {
        if (status != null && status != 'ALL') 'status': status,
        if (searchText != null && searchText.isNotEmpty) 'search_text': searchText,
      });
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => PaymentLinkRecordModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<GatewayOperationResult<PaymentLinkRecordModel>> createPaymentLinkWithFeedback({
    required int invId,
    int? partnerId,
    required int providerId,
    required String providerCode,
    required double amount,
    String currencyCode = 'KWD',
    String? customerName,
    String? customerPhone,
    bool sendViaWhatsApp = true,
    bool sendViaSms = false,
    String printQrMode = '80mm',
    int? shiftId,
    int createdByUserId = 1,
    String? notes,
    bool isConsolidated = false,
    String? consolidatedInvoicesCsv,
    IntegrationProviderModel? providerConfig,
    bool isAr = true,
  }) async {
    try {
      IntegrationProviderModel? cfg = providerConfig;
      if (cfg == null || cfg.secretKey.isEmpty) {
        final summary = await fetchProvidersSummary();
        final list = (summary['providers'] as List<IntegrationProviderModel>?) ?? [];
        for (final p in list) {
          if (p.providerId == providerId || p.providerCode.toUpperCase() == providerCode.toUpperCase()) {
            cfg = p;
            break;
          }
        }
      }

      Map<String, String>? directLink;
      if (cfg != null && cfg.secretKey.isNotEmpty) {
        directLink = await _requestDirectGatewayLink(
          provider: cfg,
          invId: invId,
          amount: amount,
          currencyCode: currencyCode,
          customerName: customerName ?? (isAr ? 'عميل نقدي' : 'Cash Customer'),
          customerPhone: customerPhone ?? '',
        );
      }

      final dio = await _buildDio();
      final res = await dio.post('/integrations/payment-links', data: {
        'InvID': invId,
        if (partnerId != null) 'PartnerID': partnerId,
        'ProviderID': providerId,
        'ProviderCode': providerCode,
        if (directLink != null) ...{
          'PaymentUrl': directLink['PaymentUrl'],
          'QrCodePayload': directLink['PaymentUrl'],
          'ExternalChargeID': directLink['ExternalChargeID'],
          'ExternalInvoiceID': directLink['ExternalInvoiceID'],
        },
        'Amount': amount,
        'CurrencyCode': currencyCode,
        'CustomerName': customerName ?? (isAr ? 'عميل نقدي' : 'Cash Customer'),
        'CustomerPhone': customerPhone ?? '',
        'SendViaWhatsApp': sendViaWhatsApp,
        'SendViaSms': sendViaSms,
        'PrintQrMode': printQrMode,
        'CreatedByUserID': createdByUserId,
        if (shiftId != null) 'ShiftID': shiftId,
        if (notes != null && notes.isNotEmpty) 'Notes': notes,
        'IsConsolidated': isConsolidated,
        if (consolidatedInvoicesCsv != null && consolidatedInvoicesCsv.isNotEmpty)
          'ConsolidatedInvoicesCsv': consolidatedInvoicesCsv,
      });
      if (res.statusCode == 200 && res.data is Map) {
        final model = PaymentLinkRecordModel.fromJson(Map<String, dynamic>.from(res.data));
        return GatewayOperationResult(
          success: true,
          messageAr: '✅ تم إصدار وحفظ رابط الدفع الإلكتروني بنجاح.',
          messageEn: '✅ Payment link generated and saved successfully.',
          data: model,
        );
      }
      return GatewayOperationResult(
        success: false,
        messageAr: '⚠️ تعذر إنشاء رابط الدفع الإلكتروني.',
        messageEn: '⚠️ Could not create payment link.',
      );
    } catch (e) {
      return GatewayOperationResult(
        success: false,
        messageAr: _extractErrorMessage(e, '❌ تعذر إنشاء رابط الدفع الإلكتروني.'),
        messageEn: _extractErrorMessage(e, '❌ Failed to create payment link.'),
      );
    }
  }

  Future<PaymentLinkRecordModel?> createPaymentLink({
    required int invId,
    int? partnerId,
    required int providerId,
    required String providerCode,
    required double amount,
    String currencyCode = 'KWD',
    String? customerName,
    String? customerPhone,
    bool sendViaWhatsApp = true,
    bool sendViaSms = false,
    String printQrMode = '80mm',
    int? shiftId,
    int createdByUserId = 1,
    String? notes,
    bool isConsolidated = false,
    String? consolidatedInvoicesCsv,
    IntegrationProviderModel? providerConfig,
  }) async {
    final result = await createPaymentLinkWithFeedback(
      invId: invId,
      partnerId: partnerId,
      providerId: providerId,
      providerCode: providerCode,
      amount: amount,
      currencyCode: currencyCode,
      customerName: customerName,
      customerPhone: customerPhone,
      sendViaWhatsApp: sendViaWhatsApp,
      sendViaSms: sendViaSms,
      printQrMode: printQrMode,
      shiftId: shiftId,
      createdByUserId: createdByUserId,
      notes: notes,
      isConsolidated: isConsolidated,
      consolidatedInvoicesCsv: consolidatedInvoicesCsv,
      providerConfig: providerConfig,
    );
    return result.data;
  }

  Future<GatewayOperationResult<String>> refreshPaymentLinkStatusWithFeedback(int linkId) async {
    try {
      final dio = await _buildDio();
      final res = await dio.post('/integrations/payment-links/$linkId/refresh');
      if (res.statusCode == 200 && res.data is Map) {
        final map = Map<String, dynamic>.from(res.data);
        final statusText = map['new_status']?.toString() ?? '';
        return GatewayOperationResult(
          success: map['success'] != false,
          messageAr: map['message_ar']?.toString() ?? '✅ تم فحص حالة الرابط.',
          messageEn: map['message_en']?.toString() ??
              (statusText.isNotEmpty
                  ? '✅ Link status checked: $statusText'
                  : '✅ Link status checked.'),
          data: map['new_status']?.toString(),
        );
      }
      return GatewayOperationResult(
        success: false,
        messageAr: '⚠️ تعذر فحص حالة الرابط.',
        messageEn: '⚠️ Could not check link status.',
      );
    } catch (e) {
      return GatewayOperationResult(
        success: false,
        messageAr: _extractErrorMessage(e, '❌ تعذر التحقق من حالة الرابط.'),
        messageEn: _extractErrorMessage(e, '❌ Failed to verify link status.'),
      );
    }
  }

  Future<bool> refreshLinkStatus(int linkId, String newStatus) async {
    try {
      final dio = await _buildDio();
      final res = await dio.post('/integrations/payment-links/$linkId/status', queryParameters: {
        'new_status': newStatus,
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _translateRefundError(dynamic e, {required bool isAr}) {
    int? statusCode;
    String raw = '';
    if (e is DioException) {
      statusCode = e.response?.statusCode;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return isAr
            ? '⏱️ انتهت مهلة الاتصال بالخادم أثناء تنفيذ الاسترداد؛ يرجى فحص حالة الرابط للتأكد قبل إعادة المحاولة.'
            : '⏱️ Connection timed out during refund; please check link status before retrying.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return isAr
            ? '🌐 تعذر الوصول إلى خادم النظام؛ يرجى التحقق من الشبكة وحالة الخادم.'
            : '🌐 Could not reach the server; please check network connectivity.';
      }
    }

    raw = _extractErrorMessage(e, '').trim();
    final lower = raw.toLowerCase();

    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(raw);
    final looksRawJson = raw.contains('{') || raw.contains('errors') || raw.contains('ValidationErrors');

    // If backend already returned a clean Arabic user message without raw JSON dump
    if (isAr && hasArabic && !looksRawJson) {
      return raw;
    }

    if (statusCode == 401 ||
        lower.contains('unauthorized') ||
        lower.contains('invalid token') ||
        lower.contains('invalid key') ||
        lower.contains('authentication') ||
        lower.contains('مفتاح الربط')) {
      return isAr
          ? '🔐 فشل التحقق من الجلسة أو مفتاح الربط السري للبوابة؛ يرجى إعادة تسجيل الدخول أو مراجعة إعدادات البوابة.'
          : '🔐 Authentication failed (expired session or invalid gateway Secret Key).';
    }

    if (statusCode == 403 ||
        lower.contains('permission') ||
        lower.contains('forbidden') ||
        lower.contains('not authorized') ||
        lower.contains('not allowed') ||
        lower.contains('not enabled') ||
        lower.contains('لا تملك صلاحية')) {
      return isAr
          ? '⛔ لا تملك صلاحية تنفيذ الاسترداد، أو أن ميزة الاسترداد غير مفعلة في حساب البوابة.'
          : '⛔ Refund permission denied, or refund is not enabled on the merchant gateway account.';
    }

    if (lower.contains('already refunded') ||
        lower.contains('fully refunded') ||
        lower.contains('مسترد مسبقاً') ||
        lower.contains('تم استرداد كامل')) {
      return isAr
          ? 'ℹ️ تم استرداد كامل مبلغ هذا الرابط مسبقاً لدى بوابة الدفع.'
          : 'ℹ️ This payment has already been fully refunded at the gateway.';
    }

    if (lower.contains('exceed') ||
        lower.contains('greater than') ||
        lower.contains('remaining amount') ||
        lower.contains('refundable amount') ||
        lower.contains('يتجاوز الرصيد المتاح')) {
      return isAr
          ? '⚠️ مبلغ الاسترداد المطلوب يتجاوز الرصيد المتاح للاسترداد في هذه العملية.'
          : '⚠️ Requested refund amount exceeds the remaining refundable amount.';
    }

    if (lower.contains('insufficient') ||
        lower.contains('enough balance') ||
        lower.contains('wallet balance') ||
        lower.contains('غير كاف')) {
      return isAr
          ? '⚠️ الرصيد المتاح في حساب التاجر لدى البوابة غير كافٍ لتنفيذ الاسترداد.'
          : '⚠️ Insufficient merchant balance at the payment gateway to process this refund.';
    }

    if (lower.contains('not captured') ||
        lower.contains('not paid') ||
        lower.contains('cannot be refunded') ||
        lower.contains('unpaid') ||
        lower.contains('غير محصلة') ||
        lower.contains('غير مدفوعة')) {
      return isAr
          ? '⚠️ لا يمكن استرداد هذا الرابط لأن عملية الدفع غير محصلة لدى البوابة؛ يرجى فحص الحالة أولاً.'
          : '⚠️ Cannot refund because the transaction is not captured/paid at the gateway; check status first.';
    }

    if (statusCode == 404 ||
        lower.contains('charge not found') ||
        lower.contains('invoice not found') ||
        lower.contains('order not found') ||
        lower.contains('invalid charge') ||
        lower.contains('invalid invoice') ||
        lower.contains('لم يتم العثور') ||
        lower.contains('محاكاة')) {
      return isAr
          ? '⚠️ لم يتم العثور على عملية الدفع الأصلية لدى البوابة (تأكد من مرجع العملية أو أن الرابط لم يُنشأ تجريبياً).'
          : '⚠️ Original payment transaction was not found at the gateway (verify charge ID or environment mode).';
    }

    if (lower.contains('currency')) {
      return isAr
          ? '⚠️ عملة الاسترداد غير مطابقة لعملة عملية الدفع الأصلية.'
          : '⚠️ Refund currency does not match the original transaction currency.';
    }

    if (statusCode == 429 || lower.contains('rate limit') || lower.contains('too many requests')) {
      return isAr
          ? '⏳ تم تجاوز الحد المؤقت لطلبات البوابة؛ يرجى الانتظار دقيقة ثم المحاولة مجدداً.'
          : '⏳ Gateway rate limit reached; please wait a moment and try again.';
    }

    if (lower.contains('reason') ||
        lower.contains('validation') ||
        statusCode == 422) {
      return isAr
          ? '⚠️ بيانات طلب الاسترداد غير صالحة حسب متطلبات البوابة (تحقق من المبلغ وسبب الاسترداد).'
          : '⚠️ Invalid refund request parameters rejected by the gateway (check amount and reason).';
    }

    if (statusCode != null && statusCode >= 500) {
      return isAr
          ? '🛠️ حدث خطأ مؤقت في الخادم أو بوابة الدفع ($statusCode)؛ يرجى المحاولة لاحقاً.'
          : '🛠️ Temporary server or payment gateway error ($statusCode); please try again shortly.';
    }

    if (!isAr && raw.isNotEmpty && !hasArabic && !looksRawJson) {
      return raw;
    }

    return isAr
        ? '❌ تعذر تنفيذ إرجاع المبلغ عبر البوابة؛ يرجى مراجعة حالة الرابط وإعدادات البوابة.'
        : '❌ Failed to execute refund via gateway; please verify link status and gateway settings.';
  }

  Future<GatewayOperationResult<bool>> refundPaymentLinkWithFeedback({
    required int linkId,
    required double refundAmount,
    required String reason,
    int userId = 1,
  }) async {
    try {
      final dio = await _buildDio();
      final res = await dio.post('/integrations/payment-links/refund', data: {
        'LinkID': linkId,
        'RefundAmount': refundAmount,
        'RefundReason': reason,
        'UserID': userId,
      });
      if (res.statusCode == 200) {
        final msg = (res.data is Map && res.data['message_ar'] != null)
            ? res.data['message_ar'].toString()
            : '✅ تم تنفيذ إرجاع المبلغ بنجاح وتسجيل القيد العكسي.';
        final msgEn = (res.data is Map && res.data['message_en'] != null)
            ? res.data['message_en'].toString()
            : '✅ Refund executed successfully and reversal entry recorded.';
        return GatewayOperationResult(success: true, messageAr: msg, messageEn: msgEn, data: true);
      }
      return GatewayOperationResult(
        success: false,
        messageAr: '⚠️ فشل تنفيذ الاسترداد.',
        messageEn: '⚠️ Refund failed.',
      );
    } catch (e) {
      return GatewayOperationResult(
        success: false,
        messageAr: _translateRefundError(e, isAr: true),
        messageEn: _translateRefundError(e, isAr: false),
        data: false,
      );
    }
  }

  Future<bool> refundPaymentLink({
    required int linkId,
    required double refundAmount,
    required String reason,
    int userId = 1,
  }) async {
    final res = await refundPaymentLinkWithFeedback(
      linkId: linkId,
      refundAmount: refundAmount,
      reason: reason,
      userId: userId,
    );
    return res.success;
  }

  Future<List<TalabatOrderModel>> fetchTalabatOrders({String? status, String? searchText}) async {
    try {
      final dio = await _buildDio();
      final res = await dio.get('/integrations/talabat/orders', queryParameters: {
        if (status != null && status != 'ALL') 'status': status,
        if (searchText != null && searchText.isNotEmpty) 'search_text': searchText,
      });
      if (res.statusCode == 200 && res.data is Map) {
        final rawList = (res.data['orders'] as List?) ?? [];
        return rawList
            .map((e) => TalabatOrderModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> performTalabatAction({
    required String orderToken,
    required String orderCode,
    required String action,
    int prepTimeMinutes = 15,
    String rejectionReason = 'ITEM_UNAVAILABLE',
  }) async {
    try {
      final dio = await _buildDio();
      final res = await dio.post('/integrations/talabat/orders/action', data: {
        'OrderToken': orderToken,
        'OrderCode': orderCode,
        'Action': action,
        'PrepTimeMinutes': prepTimeMinutes,
        'RejectionReason': rejectionReason,
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

