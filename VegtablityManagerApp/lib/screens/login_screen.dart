import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_provider.dart';
import 'manager_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isSidebarOpen = false; // الافتراضي هو الإغلاق (Closed by default)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final reports = Provider.of<ReportsProvider>(context, listen: false);
        final auth = Provider.of<AuthProvider>(context, listen: false);
        auth.fetchCompanySettings(database: reports.selectedCompany.id);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll("#", "");
      return Color(int.parse("0xFF$clean"));
    } catch (_) {
      return Colors.amber;
    }
  }

  IconData _getCompanyIcon(String iconName) {
    switch (iconName) {
      case "local_car_wash":
        return Icons.local_car_wash_rounded;
      case "diamond":
        return Icons.diamond_rounded;
      case "eco":
        return Icons.eco_rounded;
      case "restaurant":
        return Icons.restaurant_rounded;
      case "public":
        return Icons.public_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportsProvider = Provider.of<ReportsProvider>(context, listen: false);
    final activeCompany = reportsProvider.selectedCompany;

    final success = await authProvider.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      database: activeCompany.id,
    );

    if (success && mounted) {
      reportsProvider.loadAllCurrentTab();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ManagerMainScreen()),
      );
    }
  }

  void _showCompanySelector(
    BuildContext context,
    ReportsProvider reportsProvider,
    AuthProvider authProvider,
    Color brandColor,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    Widget buildCompanyList() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "اختر المنشأة / الشركة",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...AppConfig.companies.map((comp) {
            final isSelected = comp.id == reportsProvider.selectedCompany.id;
            final compColor = _parseColor(comp.colorHex);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    reportsProvider.setSelectedCompany(comp);
                    authProvider.fetchCompanySettings(database: comp.id, force: true);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? compColor.withValues(alpha: 0.15)
                          : const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? compColor : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: compColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: compColor.withValues(alpha: 0.4)),
                          ),
                          child: Icon(_getCompanyIcon(comp.iconName), color: compColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comp.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comp.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: compColor, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF131D31),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: brandColor.withValues(alpha: 0.3)),
          ),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            child: buildCompanyList(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF131D31),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: buildCompanyList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reportsProvider = Provider.of<ReportsProvider>(context);
    final activeCompany = reportsProvider.selectedCompany;
    final brandColor = _parseColor(activeCompany.colorHex);
    final liveSettings = authProvider.companySettings;
    final isSettingsLoading = authProvider.isLoadingCompanySettings;

    final displayName = (liveSettings != null && liveSettings.companyName.trim().isNotEmpty)
        ? liveSettings.companyName
        : activeCompany.name;
    final logoBytes = liveSettings?.logoBytes;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1D),
          gradient: RadialGradient(
            center: const Alignment(0.6, -0.6),
            radius: 1.3,
            colors: [
              brandColor.withValues(alpha: 0.12),
              const Color(0xFF0A0F1D),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;
              final isWideDesktop = availableWidth >= 880 && availableHeight >= 500;
              final isMobile = availableWidth < 550;
              final isCompact = availableWidth < 460 || availableHeight < 700;
              final isShortHeight = availableHeight < 560;

              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : (isCompact ? 16 : 24),
                    vertical: isShortHeight ? 10 : 20,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      constraints: BoxConstraints(
                        maxWidth: isWideDesktop ? 1000 : (isMobile ? double.infinity : 460),
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131D31),
                          borderRadius: BorderRadius.circular(isCompact ? 18 : 26),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withValues(alpha: 0.14),
                              blurRadius: isCompact ? 20 : 35,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: isWideDesktop
                            ? _buildWideLayout(
                                context,
                                authProvider,
                                reportsProvider,
                                activeCompany,
                                brandColor,
                                displayName,
                                logoBytes,
                                isSettingsLoading,
                              )
                            : _buildCompactLayout(
                                context,
                                authProvider,
                                reportsProvider,
                                activeCompany,
                                brandColor,
                                displayName,
                                logoBytes,
                                isCompact: isCompact,
                                isShortHeight: isShortHeight,
                                isSettingsLoading: isSettingsLoading,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. WIDE LAYOUT (DESKTOP & LARGE TABLETS)
  // ==========================================
  Widget _buildWideLayout(
    BuildContext context,
    AuthProvider authProvider,
    ReportsProvider reportsProvider,
    CompanyInfoModel activeCompany,
    Color brandColor,
    String displayName,
    Uint8List? logoBytes,
    bool isSettingsLoading,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left (or Right in RTL): Hero Showcase & Dynamic Company Brand
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      brandColor.withValues(alpha: 0.18),
                      const Color(0xFF0F172A),
                    ],
                  ),
                  border: Border(
                    left: BorderSide(color: brandColor.withValues(alpha: 0.2)),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Logo + Dynamic Brand Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogoBadge(
                          brandColor,
                          activeCompany,
                          logoBytes,
                          size: 76,
                          isLoading: isSettingsLoading,
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            displayName,
                            key: ValueKey(displayName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeCompany.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Company Selector Trigger
                        InkWell(
                          onTap: () => _showCompanySelector(context, reportsProvider, authProvider, brandColor),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: brandColor.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz_rounded, color: brandColor, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "تغيير المنشأة / الشركة",
                                  style: TextStyle(
                                    color: brandColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Middle: Feature Highlights
                    Column(
                      children: [
                        _buildFeaturePill(
                          icon: Icons.insights_rounded,
                          title: "لوحات تحكم لحظية",
                          subtitle: "تحليلات مالية وتقارير أرباح وفواتير حية",
                          color: brandColor,
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePill(
                          icon: Icons.shield_rounded,
                          title: "حماية وحوكمة مشددة",
                          subtitle: "عزل قواعد البيانات وتشفير كامل للعمليات",
                          color: const Color(0xFF06B6D4),
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturePill(
                          icon: Icons.cloud_sync_rounded,
                          title: "مزامنة سحابية مركزية",
                          subtitle: "ربط نقاط البيع والفروع السحابية بكفاءة عالية",
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Bottom System Version Info
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 14, color: brandColor.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Text(
                          "Vegtablity Enterprise v2.5",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Right (or Left in RTL): Login Form
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(36),
                color: const Color(0xFF131D31),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _buildLoginForm(
                      context,
                      authProvider,
                      reportsProvider,
                      brandColor,
                      isCompact: false,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. COMPACT / MOBILE / TABLET PORTRAIT
  // ==========================================
  Widget _buildCompactLayout(
    BuildContext context,
    AuthProvider authProvider,
    ReportsProvider reportsProvider,
    CompanyInfoModel activeCompany,
    Color brandColor,
    String displayName,
    Uint8List? logoBytes, {
    required bool isCompact,
    required bool isShortHeight,
    required bool isSettingsLoading,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: isCompact ? 20 : 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Company Logo (from database)
          Center(
            child: _buildLogoBadge(
              brandColor,
              activeCompany,
              logoBytes,
              size: isShortHeight ? 52 : (isCompact ? 64 : 78),
              isLoading: isSettingsLoading,
            ),
          ),
          SizedBox(height: isShortHeight ? 8 : (isCompact ? 12 : 16)),

          // Dynamic Company Name (from database)
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                displayName,
                key: ValueKey(displayName),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Company Switcher & Badge Pill
          Center(
            child: InkWell(
              onTap: () => _showCompanySelector(context, reportsProvider, authProvider, brandColor),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: brandColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: brandColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "بوابة الإدارة التنفيذية",
                      style: TextStyle(
                        color: brandColor,
                        fontSize: isCompact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.unfold_more_rounded, size: 14, color: brandColor),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: isShortHeight ? 8 : (isCompact ? 10 : 14)),

          // Animated Collapsible Features Showcase Toggle
          Center(
            child: InkWell(
              onTap: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: _isSidebarOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: brandColor.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSidebarOpen ? "إخفاء مميزات المنظومة" : "استعراض مميزات المنظومة",
                      style: TextStyle(
                        color: brandColor.withValues(alpha: 0.9),
                        fontSize: isCompact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Animated Expandable Features Panel
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            child: _isSidebarOpen
                ? Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: brandColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _buildFeaturePill(
                          icon: Icons.auto_graph_rounded,
                          title: "لوحات تحكم لحظية",
                          subtitle: "تقارير أرباح وهوامش ربح وإحصائيات ورديات حية",
                          color: brandColor,
                        ),
                        const SizedBox(height: 8),
                        _buildFeaturePill(
                          icon: Icons.shield_rounded,
                          title: "حوكمة وفصل قواعد البيانات",
                          subtitle: "عزل كامل لبيانات المنشآت مع صلاحيات إدارية مشددة",
                          color: brandColor,
                        ),
                        const SizedBox(height: 8),
                        _buildFeaturePill(
                          icon: Icons.cloud_sync_rounded,
                          title: "مزامنة سحابية فورية",
                          subtitle: "تكامل مباشر مع نقاط البيع POS والمخازن",
                          color: brandColor,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          SizedBox(height: isShortHeight ? 8 : (isCompact ? 12 : 16)),

          // The Form
          _buildLoginForm(
            context,
            authProvider,
            reportsProvider,
            brandColor,
            isCompact: isCompact,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. COMMON FORM FIELDS & ACTIONS
  // ==========================================
  Widget _buildLoginForm(
    BuildContext context,
    AuthProvider authProvider,
    ReportsProvider reportsProvider,
    Color brandColor, {
    required bool isCompact,
  }) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header for form in wide mode
            if (MediaQuery.of(context).size.width >= 920 && MediaQuery.of(context).size.height >= 550) ...[
              const Text(
                "تسجيل الدخول",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "أدخل بيانات حسابك المعتمد للوصول إلى التقارير",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Error Alert (if any)
            if (authProvider.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        authProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isCompact ? 12 : 16),
            ],

            // Username Input Field
            TextFormField(
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              keyboardType: TextInputType.text,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              enableInteractiveSelection: true,
              mouseCursor: SystemMouseCursors.text,
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 13 : 14),
              decoration: InputDecoration(
                labelText: "اسم المستخدم",
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: Icon(Icons.person_outline_rounded, color: brandColor, size: 20),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: brandColor, width: 2),
                ),
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'يرجى إدخال اسم المستخدم' : null,
            ),
            SizedBox(height: isCompact ? 12 : 16),

            // Password Input Field
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enableInteractiveSelection: true,
              mouseCursor: SystemMouseCursors.text,
              style: TextStyle(color: Colors.white, fontSize: isCompact ? 13 : 14),
              decoration: InputDecoration(
                labelText: "كلمة المرور",
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: brandColor, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: brandColor, width: 2),
                ),
              ),
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'يرجى إدخال كلمة المرور' : null,
            ),
            SizedBox(height: isCompact ? 16 : 22),

            // Submit Button
            SizedBox(
              height: isCompact ? 46 : 50,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: const Color(0xFF0A0F1D),
                  disabledBackgroundColor: brandColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: brandColor.withValues(alpha: 0.5),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0A0F1D),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "تسجيل الدخول",
                            style: TextStyle(
                              fontSize: isCompact ? 14 : 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: isCompact ? 14 : 18),

            // Security Footer
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Icon(Icons.lock_rounded, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                Text(
                  "اتصال مشفر 256-bit SSL | Vegtablity Enterprise",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCompact ? 9.5 : 10.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. HELPER WIDGETS
  // ==========================================
  Widget _buildLogoBadge(
    Color brandColor,
    CompanyInfoModel activeCompany,
    Uint8List? logoBytes, {
    required double size,
    bool isLoading = false,
  }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(
          color: brandColor.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          'assets/lettuce.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.eco_rounded, color: Colors.green, size: size * 0.5),
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
