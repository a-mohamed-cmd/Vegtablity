import 'package:dio/dio.dart';
import '../../models/integration_models.dart';

/// Isolated MyFatoorah API v2 client for Flutter (mirrors Tap Payments parity).
/// Supports: InitiatePayment, SendPayment, ExecutePayment, GetPaymentStatus, GetRefundStatus.
class MyFatoorahGatewayService {
  static const String sandboxBaseUrl = 'https://apitest.myfatoorah.com';
  static const String liveKuwaitBaseUrl = 'https://api.myfatoorah.com';

  String resolveBaseUrl(IntegrationProviderModel provider) {
    final configured = provider.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (configured.isNotEmpty) return configured;
    final isLive = provider.environmentMode.toLowerCase() == 'live';
    return isLive ? liveKuwaitBaseUrl : sandboxBaseUrl;
  }

  Dio _buildGatewayDio(String secretKey) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Authorization': 'Bearer ${secretKey.trim()}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  String extractErrorDetails(dynamic data) {
    if (data is! Map) return data?.toString() ?? '';
    final map = Map<String, dynamic>.from(data);
    final parts = <String>[];

    final msg = (map['Message'] ?? map['message'] ?? '').toString().trim();
    if (msg.isNotEmpty) parts.add(msg);

    for (final key in const ['ValidationErrors', 'FieldsErrors']) {
      final list = map[key];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            final name = (item['Name'] ?? '').toString().trim();
            final detail = (item['Error'] ?? '').toString().trim();
            if (detail.isNotEmpty) {
              parts.add(name.isEmpty ? detail : '$name: $detail');
            }
          }
        }
      }
    }
    return parts.join(' | ');
  }

  Future<List<Map<String, dynamic>>> initiatePayment({
    required IntegrationProviderModel provider,
    double invoiceAmount = 1.0,
    String currencyIso = 'KWD',
  }) async {
    final secret = provider.secretKey.trim();
    if (secret.isEmpty) {
      throw Exception('المفتاح السري (API Token) لبوابة MyFatoorah غير متوفر.');
    }

    final dio = _buildGatewayDio(secret);
    final baseUrl = resolveBaseUrl(provider);
    final res = await dio.post(
      '$baseUrl/v2/InitiatePayment',
      data: {
        'InvoiceAmount': double.parse(invoiceAmount.toStringAsFixed(3)),
        'CurrencyIso': currencyIso.isEmpty ? 'KWD' : currencyIso,
      },
    );

    if (res.data is Map) {
      final map = Map<String, dynamic>.from(res.data);
      if (map['IsSuccess'] == false) {
        throw Exception(extractErrorDetails(map));
      }
      final dObj = map['Data'] is Map
          ? Map<String, dynamic>.from(map['Data'])
          : <String, dynamic>{};
      final rawMethods = dObj['PaymentMethods'];
      if (rawMethods is List) {
        return rawMethods
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, String>?> createPaymentLink({
    required IntegrationProviderModel provider,
    required int invId,
    required double amount,
    required String currencyCode,
    required String customerName,
    required String phoneDigits,
    required String callbackUrl,
    String? description,
    int? paymentMethodId,
    int expiryHours = 72,
  }) async {
    final secret = provider.secretKey.trim();
    if (secret.isEmpty) return null;

    final dio = _buildGatewayDio(secret);
    final baseUrl = resolveBaseUrl(provider);
    final expiryIso = DateTime.now()
        .toUtc()
        .add(Duration(hours: expiryHours))
        .toIso8601String()
        .split('.')
        .first;

    final payload = <String, dynamic>{
      'CustomerName': customerName,
      'DisplayCurrencyIso': currencyCode.isEmpty ? 'KWD' : currencyCode,
      'MobileCountryCode': '+965',
      'CustomerMobile': phoneDigits,
      'InvoiceValue': double.parse(amount.toStringAsFixed(3)),
      'Language': 'ar',
      'CallBackUrl': callbackUrl,
      'ErrorUrl': callbackUrl,
      'CustomerReference': 'INV_$invId',
      'UserDefinedField': (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : 'INV_$invId',
      'ExpiryDate': expiryIso,
    };

    final endpoint = (paymentMethodId != null && paymentMethodId > 0)
        ? '/v2/ExecutePayment'
        : '/v2/SendPayment';
    if (paymentMethodId != null && paymentMethodId > 0) {
      payload['PaymentMethodId'] = paymentMethodId;
    } else {
      payload['NotificationOption'] = 'LNK';
    }

    final res = await dio.post('$baseUrl$endpoint', data: payload);
    if (res.data is Map) {
      final map = Map<String, dynamic>.from(res.data);
      if (map['IsSuccess'] == false) {
        throw Exception(extractErrorDetails(map));
      }
      final dObj = map['Data'] is Map
          ? Map<String, dynamic>.from(map['Data'])
          : <String, dynamic>{};
      final payUrl = (dObj['InvoiceURL'] ?? dObj['PaymentURL'] ?? '').toString();
      final extId = (dObj['InvoiceId'] ?? '').toString();
      if (payUrl.isNotEmpty && extId.isNotEmpty) {
        return {
          'PaymentUrl': payUrl,
          'ExternalChargeID': extId,
          'ExternalInvoiceID': extId,
        };
      }
    }
    return null;
  }

  Future<String> checkPaymentStatus({
    required IntegrationProviderModel provider,
    required String externalInvoiceId,
  }) async {
    final secret = provider.secretKey.trim();
    if (secret.isEmpty || externalInvoiceId.trim().isEmpty) return 'Pending';

    final dio = _buildGatewayDio(secret);
    final baseUrl = resolveBaseUrl(provider);
    final res = await dio.post(
      '$baseUrl/v2/GetPaymentStatus',
      data: {
        'Key': externalInvoiceId.trim(),
        'KeyType': 'InvoiceId',
      },
    );

    if (res.data is Map) {
      final map = Map<String, dynamic>.from(res.data);
      if (map['IsSuccess'] == false) return 'Pending';
      final dObj = map['Data'] is Map
          ? Map<String, dynamic>.from(map['Data'])
          : <String, dynamic>{};
      final invStatus = (dObj['InvoiceStatus'] ?? '').toString().trim().toUpperCase();
      final txs = dObj['InvoiceTransactions'];
      var hasSuccessTx = false;
      var hasAnyTx = false;
      var allFailed = true;

      if (txs is List && txs.isNotEmpty) {
        hasAnyTx = true;
        for (final tx in txs) {
          if (tx is Map) {
            final st = (tx['TransactionStatus'] ?? '').toString().trim().toUpperCase();
            if (st == 'SUCCSS' || st == 'SUCCESS' || st == 'PAID' || st == 'CAPTURED') {
              hasSuccessTx = true;
              allFailed = false;
            } else if (st != 'FAILED' && st != 'ERROR' && st != 'DECLINED') {
              allFailed = false;
            }
          }
        }
      } else {
        allFailed = false;
      }

      if (invStatus == 'PAID' || invStatus == 'CAPTURED' || invStatus == 'SUCCESS' || hasSuccessTx) {
        return 'Paid';
      }
      if (invStatus == 'REFUNDED') return 'Refunded';
      if (invStatus == 'PARTIALLYREFUNDED' || invStatus == 'PARTIALLY_REFUNDED') {
        return 'PartiallyRefunded';
      }
      if (invStatus == 'CANCELED' || invStatus == 'CANCELLED' || invStatus == 'EXPIRED') {
        return 'Expired';
      }
      if (invStatus == 'FAILED' || invStatus == 'DECLINED' || (hasAnyTx && allFailed)) {
        return 'Failed';
      }
    }
    return 'Pending';
  }

  Future<Map<String, dynamic>?> getRefundStatus({
    required IntegrationProviderModel provider,
    required String key,
    String keyType = 'InvoiceId',
  }) async {
    final secret = provider.secretKey.trim();
    if (secret.isEmpty || key.trim().isEmpty) return null;

    final dio = _buildGatewayDio(secret);
    final baseUrl = resolveBaseUrl(provider);
    final res = await dio.post(
      '$baseUrl/v2/GetRefundStatus',
      data: {'Key': key.trim(), 'KeyType': keyType},
    );
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return null;
  }
}
