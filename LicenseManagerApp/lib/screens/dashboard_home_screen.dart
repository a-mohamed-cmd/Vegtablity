import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/update_service.dart';
import 'license_manager_screen.dart';
import 'company_settings_screen.dart';
import 'login_screen.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateSilently();
    });
  }

  Future<void> _checkUpdateSilently() async {
    final updateInfo = await _updateService.checkForUpdate();
    if (updateInfo.hasUpdate && mounted) {
      UpdateService.showUpdateDialog(context, updateInfo);
    }
  }

  Future<void> _manualCheckUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final updateInfo = await _updateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (updateInfo.hasUpdate) {
      UpdateService.showUpdateDialog(context, updateInfo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text("أنت تستخدم أحدث إصدار من تطبيق إدارة التراخيص! ✅"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text("لوحة التحكم الرئيسية للمشرفين"),
        backgroundColor: const Color(0xFF252538),
        elevation: 0,
        actions: [
          _isCheckingUpdate
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: "فحص التحديثات",
                  icon: const Icon(Icons.system_update_alt_rounded, color: Colors.amber),
                  onPressed: _manualCheckUpdate,
                ),
          IconButton(
            tooltip: "تسجيل الخروج",
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              LoginScreen.navigate(context);
            },
          ),
        ],
      ),

      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Header Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF252538),
                          const Color(0xFF2D2D44),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "مرحباً بك في منظومة التحكم والترخيص 👑",
                                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "اختر الخدمات الرئيسية للتحكم بتراخيص الأجهزة أو تفضيلات وخيارات النظام.",
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2 Compact Cards Section
                  isMobile
                      ? Column(
                          children: [
                            _buildCompactCard(
                              context: context,
                              icon: Icons.admin_panel_settings_rounded,
                              iconColor: Colors.amber,
                              badgeColor: Colors.amber.withValues(alpha: 0.15),
                              title: "إدارة تراخيص الأجهزة",
                              subtitle: "تفعيل وتغيير تراخيص الهاند هيلد والأجهزة المسموح بها",
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const LicenseManagerScreen()),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildCompactCard(
                              context: context,
                              icon: Icons.vpn_key_rounded,
                              iconColor: Colors.tealAccent,
                              badgeColor: Colors.tealAccent.withValues(alpha: 0.15),
                              title: "الخصائص وتفضيلات النظام",
                              subtitle: "التحكم في خيارات التصنيع [ProductionMode] والفواتير",
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const CompanySettingsScreen()),
                                );
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildCompactCard(
                                context: context,
                                icon: Icons.admin_panel_settings_rounded,
                                iconColor: Colors.amber,
                                badgeColor: Colors.amber.withValues(alpha: 0.15),
                                title: "إدارة تراخيص الأجهزة",
                                subtitle: "تفعيل وتغيير تراخيص الهاند هيلد والأجهزة المسموح بها",
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const LicenseManagerScreen()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildCompactCard(
                                context: context,
                                icon: Icons.vpn_key_rounded,
                                iconColor: Colors.tealAccent,
                                badgeColor: Colors.tealAccent.withValues(alpha: 0.15),
                                title: "الخصائص وتفضيلات النظام",
                                subtitle: "التحكم في خيارات التصنيع [ProductionMode] والفواتير",
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const CompanySettingsScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF252538),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: iconColor.withValues(alpha: 0.6), size: 18),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
