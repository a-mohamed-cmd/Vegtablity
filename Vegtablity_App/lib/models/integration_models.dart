class IntegrationProviderModel {
  final int providerId;
  final String providerCode;
  final String providerNameAr;
  final String providerNameEn;
  final String providerCategory;
  final bool isEnabledInCompany;
  final bool isConfigured;
  final String connectionStatus;
  final String defaultCurrency;
  final String environmentMode;
  final String baseUrl;
  final String secretKey;
  final String callbackUrl;
  final int? linkedAccountId;
  final String linkedAccountCode;
  final String linkedAccountName;
  final int? defaultCreditAccountId;
  final double commissionPercent;
  final double fixedFee;
  final bool autoSendLinkOnInvoiceSave;
  final bool autoSendWhatsApp;
  final bool autoSendSms;
  final bool enableConsolidatedLinks;
  final bool deductCommissionOnShiftClose;
  final bool enableGatewayRefunds;
  final bool allowPartialRefunds;
  final bool printQrOnPos80mm;
  final bool printQrOnPos58mm;
  final bool printQrOnWpfInvoice;

  bool get isPaymentGateway => providerCategory.toUpperCase() == 'PAYMENT_GATEWAY';
  bool get isConnectionVerified =>
      connectionStatus == 'SandboxVerified' || connectionStatus == 'LiveVerified';

  IntegrationProviderModel({
    required this.providerId,
    required this.providerCode,
    required this.providerNameAr,
    this.providerNameEn = '',
    required this.providerCategory,
    required this.isEnabledInCompany,
    required this.isConfigured,
    required this.connectionStatus,
    required this.defaultCurrency,
    this.environmentMode = 'Sandbox',
    this.baseUrl = '',
    this.secretKey = '',
    this.callbackUrl = '',
    this.linkedAccountId,
    this.linkedAccountCode = '',
    this.linkedAccountName = '',
    this.defaultCreditAccountId,
    this.commissionPercent = 0.0,
    this.fixedFee = 0.0,
    this.autoSendLinkOnInvoiceSave = false,
    this.autoSendWhatsApp = true,
    this.autoSendSms = false,
    this.enableConsolidatedLinks = true,
    this.deductCommissionOnShiftClose = false,
    required this.enableGatewayRefunds,
    required this.allowPartialRefunds,
    required this.printQrOnPos80mm,
    required this.printQrOnPos58mm,
    required this.printQrOnWpfInvoice,
  });

  factory IntegrationProviderModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic v, [bool fallback = false]) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v == 1;
      final s = v.toString().toLowerCase().trim();
      return s == 'true' || s == '1';
    }

    return IntegrationProviderModel(
      providerId: int.tryParse(json['ProviderID']?.toString() ?? '0') ?? 0,
      providerCode: json['ProviderCode']?.toString() ?? '',
      providerNameAr: json['ProviderNameAr']?.toString() ?? '',
      providerNameEn: json['ProviderNameEn']?.toString() ?? '',
      providerCategory: json['ProviderCategory']?.toString() ?? 'PAYMENT_GATEWAY',
      isEnabledInCompany: parseBool(json['IsEnabledInCompany']),
      isConfigured: parseBool(json['IsConfigured']),
      connectionStatus: json['ConnectionStatus']?.toString() ?? 'Disconnected',
      defaultCurrency: json['DefaultCurrency']?.toString() ?? 'KWD',
      environmentMode: json['EnvironmentMode']?.toString() ?? 'Sandbox',
      baseUrl: json['BaseUrl']?.toString() ?? '',
      secretKey: json['SecretKeyEncrypted']?.toString() ?? '',
      callbackUrl: json['CallbackUrl']?.toString() ?? '',
      linkedAccountId: json['LinkedAccountID'] != null
          ? int.tryParse(json['LinkedAccountID'].toString())
          : null,
      linkedAccountCode: json['LinkedAccountCode']?.toString() ?? '',
      linkedAccountName: json['LinkedAccountName']?.toString() ?? '',
      defaultCreditAccountId: json['DefaultCreditAccountID'] != null
          ? int.tryParse(json['DefaultCreditAccountID'].toString())
          : null,
      commissionPercent: double.tryParse(json['CommissionPercent']?.toString() ?? '0') ?? 0.0,
      fixedFee: double.tryParse(json['FixedFee']?.toString() ?? '0') ?? 0.0,
      autoSendLinkOnInvoiceSave: parseBool(json['AutoSendLinkOnInvoiceSave'], false),
      autoSendWhatsApp: parseBool(json['AutoSendWhatsApp'], true),
      autoSendSms: parseBool(json['AutoSendSms'], false),
      enableConsolidatedLinks: parseBool(json['EnableConsolidatedLinks'], true),
      deductCommissionOnShiftClose: parseBool(json['DeductCommissionOnShiftClose'], false),
      enableGatewayRefunds: parseBool(json['EnableGatewayRefunds']),
      allowPartialRefunds: parseBool(json['AllowPartialRefunds'], true),
      printQrOnPos80mm: parseBool(json['PrintQrOnPos80mm'], true),
      printQrOnPos58mm: parseBool(json['PrintQrOnPos58mm'], false),
      printQrOnWpfInvoice: parseBool(json['PrintQrOnWpfInvoice'], false),
    );
  }
}

class PaymentLinkRecordModel {
  final int linkId;
  final int invId;
  final int? partnerId;
  final int providerId;
  final String providerCode;
  final String providerNameAr;
  final String externalChargeId;
  final String externalInvoiceId;
  final String paymentUrl;
  final double amount;
  final double refundedAmount;
  final String currencyCode;
  final String linkStatus;
  final String customerName;
  final String customerPhone;
  final bool enableGatewayRefunds;
  final bool allowPartialRefunds;
  final bool isConsolidated;
  final String notes;
  final double invoiceNetAmount;
  final double invoicePaidAmount;
  final double invoiceRemainder;
  final String createdAt;

  PaymentLinkRecordModel({
    required this.linkId,
    required this.invId,
    this.partnerId,
    required this.providerId,
    required this.providerCode,
    required this.providerNameAr,
    this.externalChargeId = '',
    this.externalInvoiceId = '',
    required this.paymentUrl,
    required this.amount,
    required this.refundedAmount,
    required this.currencyCode,
    required this.linkStatus,
    required this.customerName,
    required this.customerPhone,
    required this.enableGatewayRefunds,
    required this.allowPartialRefunds,
    this.isConsolidated = false,
    this.notes = '',
    this.invoiceNetAmount = 0.0,
    this.invoicePaidAmount = 0.0,
    this.invoiceRemainder = 0.0,
    required this.createdAt,
  });

  bool get canRefund =>
      enableGatewayRefunds &&
      (linkStatus.toLowerCase() == 'paid' || linkStatus.toLowerCase() == 'partiallyrefunded') &&
      (amount - refundedAmount) > 0;

  double get remainingRefundable => (amount - refundedAmount) > 0 ? (amount - refundedAmount) : 0.0;

  factory PaymentLinkRecordModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic v, [bool fallback = false]) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v == 1;
      final s = v.toString().toLowerCase().trim();
      return s == 'true' || s == '1';
    }

    return PaymentLinkRecordModel(
      linkId: int.tryParse(json['LinkID']?.toString() ?? '0') ?? 0,
      invId: int.tryParse(json['InvID']?.toString() ?? '0') ?? 0,
      partnerId: json['PartnerID'] != null ? int.tryParse(json['PartnerID'].toString()) : null,
      providerId: int.tryParse(json['ProviderID']?.toString() ?? '0') ?? 0,
      providerCode: json['ProviderCode']?.toString() ?? '',
      providerNameAr: json['ProviderNameAr']?.toString() ?? '',
      externalChargeId: json['ExternalChargeID']?.toString() ?? '',
      externalInvoiceId: json['ExternalInvoiceID']?.toString() ?? '',
      paymentUrl: json['PaymentUrl']?.toString() ?? '',
      amount: double.tryParse(json['Amount']?.toString() ?? '0') ?? 0.0,
      refundedAmount: double.tryParse(json['RefundedAmount']?.toString() ?? '0') ?? 0.0,
      currencyCode: json['CurrencyCode']?.toString() ?? 'KWD',
      linkStatus: json['LinkStatus']?.toString() ?? 'Pending',
      customerName: json['DisplayCustomerName']?.toString() ?? json['CustomerName']?.toString() ?? 'عميل نقدي',
      customerPhone: json['DisplayCustomerPhone']?.toString() ?? json['CustomerPhone']?.toString() ?? '',
      enableGatewayRefunds: parseBool(json['EnableGatewayRefunds']),
      allowPartialRefunds: parseBool(json['AllowPartialRefunds'], true),
      isConsolidated: parseBool(json['IsConsolidated'], false),
      notes: json['Notes']?.toString() ?? '',
      invoiceNetAmount: double.tryParse(json['InvoiceNetAmount']?.toString() ?? '0') ?? 0.0,
      invoicePaidAmount: double.tryParse(json['InvoicePaidAmount']?.toString() ?? '0') ?? 0.0,
      invoiceRemainder: double.tryParse(json['InvoiceRemainder']?.toString() ?? '0') ?? 0.0,
      createdAt: json['CreatedAt']?.toString() ?? '',
    );
  }
}

class PaymentLinksPagedResult {
  final List<PaymentLinkRecordModel> items;
  final int totalCount;
  final double summaryPaid;
  final double summaryPending;
  final double summaryRefunded;
  final int pageNumber;
  final int pageSize;

  PaymentLinksPagedResult({
    required this.items,
    required this.totalCount,
    required this.summaryPaid,
    required this.summaryPending,
    required this.summaryRefunded,
    required this.pageNumber,
    required this.pageSize,
  });

  int get totalPages => totalCount <= 0 ? 1 : ((totalCount + pageSize - 1) ~/ pageSize);
}

class InvoiceQuickInfoModel {
  final int invId;
  final double netAmount;
  final double remainder;
  final int? partnerId;
  final String partnerName;
  final String phone;

  InvoiceQuickInfoModel({
    required this.invId,
    required this.netAmount,
    required this.remainder,
    this.partnerId,
    required this.partnerName,
    required this.phone,
  });

  factory InvoiceQuickInfoModel.fromJson(Map<String, dynamic> json) {
    return InvoiceQuickInfoModel(
      invId: int.tryParse(json['InvID']?.toString() ?? '0') ?? 0,
      netAmount: double.tryParse(json['NetAmount']?.toString() ?? '0') ?? 0.0,
      remainder: double.tryParse(json['Remainder']?.toString() ?? '0') ?? 0.0,
      partnerId: json['PartnerID'] != null ? int.tryParse(json['PartnerID'].toString()) : null,
      partnerName: json['PartnerName']?.toString() ?? '',
      phone: json['Phone']?.toString() ?? '',
    );
  }
}

class GatewayOperationResult<T> {
  final bool success;
  final String messageAr;
  final String messageEn;
  final T? data;

  GatewayOperationResult({
    required this.success,
    required this.messageAr,
    this.messageEn = '',
    this.data,
  });

  String localizedMessage(bool isAr) =>
      isAr ? messageAr : (messageEn.trim().isNotEmpty ? messageEn : messageAr);
}

class ConsolidatedInvoiceDraftItem {
  final int invId;
  final double amount;

  ConsolidatedInvoiceDraftItem({required this.invId, required this.amount});
}

class GatewayCustomerModel {
  final int partnerId;
  final String partnerName;
  final String phone;

  GatewayCustomerModel({
    required this.partnerId,
    required this.partnerName,
    required this.phone,
  });

  factory GatewayCustomerModel.fromJson(Map<String, dynamic> json) {
    return GatewayCustomerModel(
      partnerId: int.tryParse((json['PartnerID'] ?? json['id'] ?? json['partner_id'])?.toString() ?? '0') ?? 0,
      partnerName: (json['PartnerName'] ?? json['name'] ?? json['Name'] ?? '').toString(),
      phone: (json['Phone'] ?? json['phone'] ?? '').toString(),
    );
  }
}

class TalabatOrderModel {
  final int talabatOrderId;
  final String orderToken;
  final String orderCode;
  final String shortCode;
  final String expeditionType;
  final String paymentType;
  final double grandTotal;
  final String currencyCode;
  final String orderStatus;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String comments;
  final String itemsJson;
  final int? invId;
  final String createdAt;

  TalabatOrderModel({
    required this.talabatOrderId,
    required this.orderToken,
    required this.orderCode,
    required this.shortCode,
    required this.expeditionType,
    required this.paymentType,
    required this.grandTotal,
    required this.currencyCode,
    required this.orderStatus,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.comments,
    required this.itemsJson,
    this.invId,
    required this.createdAt,
  });

  factory TalabatOrderModel.fromJson(Map<String, dynamic> json) {
    return TalabatOrderModel(
      talabatOrderId: int.tryParse(json['TalabatOrderID']?.toString() ?? '0') ?? 0,
      orderToken: json['OrderToken']?.toString() ?? '',
      orderCode: json['OrderCode']?.toString() ?? '',
      shortCode: json['ShortCode']?.toString() ?? '',
      expeditionType: json['ExpeditionType']?.toString() ?? 'delivery',
      paymentType: json['PaymentType']?.toString() ?? 'ONLINE',
      grandTotal: double.tryParse(json['GrandTotal']?.toString() ?? '0') ?? 0.0,
      currencyCode: json['CurrencyCode']?.toString() ?? 'KWD',
      orderStatus: json['OrderStatus']?.toString() ?? 'Received',
      customerName: json['CustomerName']?.toString() ?? 'عميل Talabat',
      customerPhone: json['CustomerPhone']?.toString() ?? '',
      deliveryAddress: json['DeliveryAddress']?.toString() ?? '',
      comments: json['Comments']?.toString() ?? '',
      itemsJson: json['ItemsJson']?.toString() ?? '[]',
      invId: json['InvID'] != null ? int.tryParse(json['InvID'].toString()) : null,
      createdAt: json['CreatedAt']?.toString() ?? '',
    );
  }
}

