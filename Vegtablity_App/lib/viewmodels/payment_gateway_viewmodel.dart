import 'package:flutter/foundation.dart';
import '../models/integration_models.dart';
import '../services/integrations/integration_service.dart';

/// ViewModel (MVVM) for Payment Gateway Invoices, Links, Pagination, and Quick Creation
class PaymentGatewayViewModel extends ChangeNotifier {
  final IntegrationPosService _service;

  PaymentGatewayViewModel([IntegrationPosService? service])
      : _service = service ?? IntegrationPosService();

  bool _isLoading = false;
  bool _isCreatingLink = false;
  bool _isLookingUpInvoice = false;
  final Set<int> _busyLinkIds = <int>{};

  List<IntegrationProviderModel> _configuredGateways = [];
  IntegrationProviderModel? _selectedCreateProvider;
  List<PaymentLinkRecordModel> _links = [];
  List<GatewayCustomerModel> _customers = [];
  GatewayCustomerModel? _selectedCustomer;

  // KPIs & Server Pagination
  double _summaryPaid = 0.0;
  double _summaryPending = 0.0;
  double _summaryRefunded = 0.0;
  int _totalCount = 0;
  int _pageNumber = 1;
  int _pageSize = 15;

  // Filters
  String _filterProviderCode = 'ALL';
  String _filterStatus = 'ALL';
  String _searchText = '';

  // Collapsible card states (hidden until triggered from header buttons)
  bool _isCreateCardExpanded = false;
  bool _isFilterCardExpanded = false;

  // Consolidated invoices builder
  bool _isConsolidatedMode = false;
  final List<ConsolidatedInvoiceDraftItem> _consolidatedItems = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isCreatingLink => _isCreatingLink;
  bool get isLookingUpInvoice => _isLookingUpInvoice;
  bool isLinkBusy(int linkId) => _busyLinkIds.contains(linkId);

  List<IntegrationProviderModel> get configuredGateways => _configuredGateways;
  IntegrationProviderModel? get selectedCreateProvider => _selectedCreateProvider;
  List<PaymentLinkRecordModel> get links => _links;
  List<GatewayCustomerModel> get customers => _customers;
  GatewayCustomerModel? get selectedCustomer => _selectedCustomer;

  double get summaryPaid => _summaryPaid;
  double get summaryPending => _summaryPending;
  double get summaryRefunded => _summaryRefunded;
  int get totalCount => _totalCount;
  int get pageNumber => _pageNumber;
  int get pageSize => _pageSize;
  int get totalPages => _totalCount <= 0 ? 1 : ((_totalCount + _pageSize - 1) ~/ _pageSize);
  bool get hasPrevPage => _pageNumber > 1;
  bool get hasNextPage => _pageNumber < totalPages;

  String get filterProviderCode => _filterProviderCode;
  String get filterStatus => _filterStatus;
  String get searchText => _searchText;

  bool get isCreateCardExpanded => _isCreateCardExpanded;
  bool get isFilterCardExpanded => _isFilterCardExpanded;

  bool get isConsolidatedMode => _isConsolidatedMode;
  List<ConsolidatedInvoiceDraftItem> get consolidatedItems =>
      List.unmodifiable(_consolidatedItems);
  double get consolidatedTotalAmount =>
      _consolidatedItems.fold<double>(0.0, (s, e) => s + e.amount);

  IntegrationProviderModel? findProviderForRecord(PaymentLinkRecordModel item) {
    for (final g in _configuredGateways) {
      if (g.providerId == item.providerId ||
          g.providerCode.toUpperCase() == item.providerCode.toUpperCase()) {
        return g;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadGateways(),
        _loadCustomers(),
        loadLinks(goToPage: 1),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadGateways() async {
    final summary = await _service.fetchProvidersSummary();
    final all = (summary['providers'] as List<IntegrationProviderModel>?) ?? [];
    _configuredGateways = all
        .where((p) =>
            p.isPaymentGateway &&
            p.isEnabledInCompany &&
            (p.isConfigured || p.isConnectionVerified))
        .toList();
    if (_configuredGateways.isNotEmpty) {
      if (_selectedCreateProvider == null ||
          !_configuredGateways
              .any((g) => g.providerId == _selectedCreateProvider!.providerId)) {
        _selectedCreateProvider = _configuredGateways.first;
      }
    } else {
      _selectedCreateProvider = null;
    }
  }

  Future<void> _loadCustomers() async {
    _customers = await _service.fetchGatewayCustomers();
  }

  Future<void> loadLinks({int? goToPage}) async {
    if (goToPage != null) {
      _pageNumber = goToPage < 1 ? 1 : goToPage;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final paged = await _service.fetchPaymentLinksPaged(
        providerCode: _filterProviderCode,
        status: _filterStatus,
        searchText: _searchText,
        pageNumber: _pageNumber,
        pageSize: _pageSize,
      );
      _links = paged.items;
      _totalCount = paged.totalCount;
      _summaryPaid = paged.summaryPaid;
      _summaryPending = paged.summaryPending;
      _summaryRefunded = paged.summaryRefunded;
      _pageNumber = paged.pageNumber;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleCreateCard() {
    _isCreateCardExpanded = !_isCreateCardExpanded;
    notifyListeners();
  }

  void toggleFilterCard() {
    _isFilterCardExpanded = !_isFilterCardExpanded;
    notifyListeners();
  }

  void setCreateProvider(IntegrationProviderModel? provider) {
    _selectedCreateProvider = provider;
    notifyListeners();
  }

  void setSelectedCustomer(GatewayCustomerModel? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setConsolidatedMode(bool value) {
    _isConsolidatedMode = value;
    notifyListeners();
  }

  void addConsolidatedInvoice(int invId, double amount) {
    if (invId <= 0 || amount <= 0) return;
    final existingIdx = _consolidatedItems.indexWhere((e) => e.invId == invId);
    if (existingIdx >= 0) {
      _consolidatedItems[existingIdx] =
          ConsolidatedInvoiceDraftItem(invId: invId, amount: amount);
    } else {
      _consolidatedItems
          .add(ConsolidatedInvoiceDraftItem(invId: invId, amount: amount));
    }
    notifyListeners();
  }

  void removeConsolidatedInvoice(int index) {
    if (index >= 0 && index < _consolidatedItems.length) {
      _consolidatedItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearConsolidatedInvoices() {
    _consolidatedItems.clear();
    notifyListeners();
  }

  void setFilterProviderCode(String code) {
    _filterProviderCode = code;
    loadLinks(goToPage: 1);
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    loadLinks(goToPage: 1);
  }

  void setSearchText(String text) {
    _searchText = text;
  }

  void setPageSize(int size) {
    _pageSize = size;
    loadLinks(goToPage: 1);
  }

  void nextPage() {
    if (hasNextPage) loadLinks(goToPage: _pageNumber + 1);
  }

  void prevPage() {
    if (hasPrevPage) loadLinks(goToPage: _pageNumber - 1);
  }

  Future<InvoiceQuickInfoModel?> lookupInvoiceQuickInfo(int invId) async {
    if (invId <= 0) return null;
    _isLookingUpInvoice = true;
    notifyListeners();
    try {
      final info = await _service.fetchInvoiceQuickInfo(invId);
      if (info != null && info.partnerId != null) {
        final match = _customers.where((c) => c.partnerId == info.partnerId).toList();
        if (match.isNotEmpty) {
          _selectedCustomer = match.first;
        }
      }
      return info;
    } finally {
      _isLookingUpInvoice = false;
      notifyListeners();
    }
  }

  Future<GatewayOperationResult<PaymentLinkRecordModel>> createPaymentLink({
    required int invId,
    required double amount,
    required String customerName,
    required String customerPhone,
    String? notes,
    required int createdByUserId,
    int? shiftId,
    int paperSize = 80,
    String defaultCustomerName = 'عميل نقدي',
    bool isAr = true,
  }) async {
    final provider = _selectedCreateProvider;
    if (provider == null) {
      return GatewayOperationResult(
        success: false,
        messageAr: '⚠️ لا توجد بوابة دفع إلكتروني مفعلة ومختبرة حالياً.',
        messageEn: '⚠️ No active and verified payment gateway configured.',
      );
    }

    int targetInvId = invId;
    double targetAmount = amount;
    String? csv;

    if (_isConsolidatedMode) {
      if (_consolidatedItems.isEmpty) {
        return GatewayOperationResult(
          success: false,
          messageAr: '⚠️ أضف فاتورة واحدة على الأقل إلى قائمة الرابط المجمع.',
          messageEn: '⚠️ Add at least one invoice to the consolidated list.',
        );
      }
      targetInvId = _consolidatedItems.first.invId;
      targetAmount = consolidatedTotalAmount;
      csv = _consolidatedItems
          .map((e) => '${e.invId}:${e.amount.toStringAsFixed(3)}')
          .join(',');
    } else {
      if (targetInvId <= 0) {
        return GatewayOperationResult(
          success: false,
          messageAr: '⚠️ يرجى إدخال رقم الفاتورة الصحيح.',
          messageEn: '⚠️ Please enter a valid invoice number.',
        );
      }
      if (targetAmount <= 0) {
        return GatewayOperationResult(
          success: false,
          messageAr: '⚠️ يجب أن يكون المبلغ المطلوب أكبر من صفر.',
          messageEn: '⚠️ Amount must be greater than zero.',
        );
      }
    }

    _isCreatingLink = true;
    notifyListeners();
    try {
      final finalName = customerName.trim().isNotEmpty
          ? customerName.trim()
          : (_selectedCustomer?.partnerName.isNotEmpty == true
              ? _selectedCustomer!.partnerName
              : defaultCustomerName);
      final finalPhone = customerPhone.trim().isNotEmpty
          ? customerPhone.trim()
          : (_selectedCustomer?.phone ?? '');

      final res = await _service.createPaymentLinkWithFeedback(
        invId: targetInvId,
        partnerId: _selectedCustomer?.partnerId,
        providerId: provider.providerId,
        providerCode: provider.providerCode,
        amount: targetAmount,
        currencyCode: provider.defaultCurrency,
        customerName: finalName,
        customerPhone: finalPhone,
        sendViaWhatsApp: provider.autoSendWhatsApp,
        sendViaSms: provider.autoSendSms,
        printQrMode: paperSize == 58 ? '58mm' : '80mm',
        shiftId: shiftId,
        createdByUserId: createdByUserId,
        notes: notes?.trim(),
        isConsolidated: _isConsolidatedMode,
        consolidatedInvoicesCsv: csv,
        providerConfig: provider,
        isAr: isAr,
      );

      if (res.success) {
        _consolidatedItems.clear();
        await loadLinks(goToPage: 1);
      }
      return res;
    } finally {
      _isCreatingLink = false;
      notifyListeners();
    }
  }

  Future<GatewayOperationResult<String>> refreshLinkStatus(
      PaymentLinkRecordModel item) async {
    _busyLinkIds.add(item.linkId);
    notifyListeners();
    try {
      final res = await _service.refreshPaymentLinkStatusWithFeedback(item.linkId);
      if (res.success) {
        await loadLinks();
      }
      return res;
    } finally {
      _busyLinkIds.remove(item.linkId);
      notifyListeners();
    }
  }

  Future<GatewayOperationResult<bool>> refundLink({
    required PaymentLinkRecordModel item,
    required double refundAmount,
    required String reason,
    required int userId,
  }) async {
    _busyLinkIds.add(item.linkId);
    notifyListeners();
    try {
      final res = await _service.refundPaymentLinkWithFeedback(
        linkId: item.linkId,
        refundAmount: refundAmount,
        reason: reason,
        userId: userId,
      );
      if (res.success) {
        await loadLinks();
      }
      return res;
    } finally {
      _busyLinkIds.remove(item.linkId);
      notifyListeners();
    }
  }
}
