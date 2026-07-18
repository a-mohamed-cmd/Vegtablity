import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_license.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import 'login_screen.dart';

class LicenseManagerScreen extends StatefulWidget {
  const LicenseManagerScreen({super.key});

  @override
  State<LicenseManagerScreen> createState() => _LicenseManagerScreenState();
}

class _LicenseManagerScreenState extends State<LicenseManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LicenseProvider>(context, listen: false).fetchDatabases();
    });
  }

  void _showEditDialog(DeviceLicense? license) {
    final bool isEdit = license != null;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController(text: license?.machineName ?? '');
    final TextEditingController hwidController = TextEditingController(text: license?.machineHwid ?? '');
    final TextEditingController keyController = TextEditingController(text: license?.licenseKey ?? '');
    final TextEditingController expiryController = TextEditingController(
      text: license?.expiryDate != null && license!.expiryDate.length >= 10
          ? license.expiryDate.substring(0, 10)
          : DateTime.now().add(const Duration(days: 365)).toString().substring(0, 10),
    );
    bool isActive = license?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF252538),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(
                  isEdit ? "تعديل ترخيص الجهاز" : "إضافة ترخيص جهاز جديد",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "اسم الجهاز / الوصف",
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: hwidController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "المعرف المادي للجهاز (HWID)",
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: keyController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "مفتاح الترخيص (License Key)",
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: expiryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "تاريخ الانتهاء (YYYY-MM-DD)",
                            labelStyle: TextStyle(color: Colors.grey),
                            suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                          ),
                          onTap: () async {
                            FocusScope.of(context).requestFocus(FocusNode());
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(expiryController.text) ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                            );
                            if (date != null) {
                              expiryController.text = date.toString().substring(0, 10);
                            }
                          },
                          validator: (v) => v == null || v.isEmpty ? "مطلوب" : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text("الحالة: ", style: TextStyle(color: Colors.white)),
                            Checkbox(
                              value: isActive,
                              activeColor: Colors.amber,
                              onChanged: (val) {
                                setDialogState(() {
                                  isActive = val ?? true;
                                });
                              },
                            ),
                            Text(
                              isActive ? "نشط ومفعل" : "معطل وغير نشط",
                              style: TextStyle(color: isActive ? Colors.green : Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final provider = Provider.of<LicenseProvider>(context, listen: false);
                        final newLicense = DeviceLicense(
                          licenseId: license?.licenseId ?? 0,
                          machineName: nameController.text.trim(),
                          machineHwid: hwidController.text.trim(),
                          licenseKey: keyController.text.trim(),
                          isActive: isActive,
                          expiryDate: expiryController.text.trim(),
                        );
                        final res = await provider.saveDevice(newLicense);
                        if (res && mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("تم حفظ البيانات بنجاح")),
                          );
                        }
                      }
                    },
                    child: const Text("حفظ", style: TextStyle(color: Color(0xFF1E1E2E))),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(int licenseId) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF252538),
            title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white)),
            content: const Text("هل أنت متأكد من رغبتك في حذف هذا الجهاز؟", style: TextStyle(color: Colors.grey)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  final provider = Provider.of<LicenseProvider>(context, listen: false);
                  final res = await provider.deleteDevice(licenseId);
                  if (res && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("تم حذف الجهاز")),
                    );
                  }
                },
                child: const Text("حذف"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenseProvider = Provider.of<LicenseProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    // Database Dropdown selector widget
    final dropdownWidget = licenseProvider.databases.isEmpty
        ? const Text("لا توجد قواعد بيانات متاحة أو قيد التحميل...", style: TextStyle(color: Colors.grey))
        : DropdownButton<String>(
            value: licenseProvider.selectedDatabase,
            dropdownColor: const Color(0xFF252538),
            iconEnabledColor: Colors.amber,
            isExpanded: true,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            underline: const SizedBox(),
            items: licenseProvider.databases.map((db) {
              return DropdownMenuItem<String>(
                value: db,
                child: Text(db),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                licenseProvider.selectDatabase(value);
              }
            },
          );

    final refreshButton = IconButton(
      icon: const Icon(Icons.refresh, color: Colors.amber),
      onPressed: () {
        licenseProvider.fetchDatabases();
      },
    );

    // Add Device Button
    final addDeviceButton = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: const Color(0xFF1E1E2E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _showEditDialog(null),
      icon: const Icon(Icons.add, size: 20),
      label: const Text("إضافة جهاز جديد", style: TextStyle(fontWeight: FontWeight.bold)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text("لوحة تحكم التراخيص والمشرفين"),
        backgroundColor: const Color(0xFF252538),
        elevation: 0,
        actions: [
          IconButton(
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
            constraints: const BoxConstraints(maxWidth: 1000), // Constraint width for premium desktop/tablet view
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Database Selection Card (Adaptive Layout)
                  Card(
                    color: const Color(0xFF252538),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: isSmallScreen
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "قاعدة البيانات المستهدفة:",
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: dropdownWidget),
                                    refreshButton,
                                  ],
                                )
                              ],
                            )
                          : Row(
                              children: [
                                const Text(
                                  "قاعدة البيانات المستهدفة:  ",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: dropdownWidget),
                                refreshButton,
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Header Row with Add Button (Adaptive Layout)
                  isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "الأجهزة المرخصة المسجلة:",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            addDeviceButton,
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "الأجهزة المرخصة المسجلة:",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            addDeviceButton,
                          ],
                        ),
                  const SizedBox(height: 16),

                  if (licenseProvider.errorMessage != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        licenseProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      ),
                    ),
                  ],

                  // Device Licenses List
                  Expanded(
                    child: licenseProvider.isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                        : licenseProvider.licenses.isEmpty
                            ? const Center(
                                child: Text(
                                  "لا توجد تراخيص مسجلة في قاعدة البيانات هذه.",
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                itemCount: licenseProvider.licenses.length,
                                itemBuilder: (context, index) {
                                  final item = licenseProvider.licenses[index];
                                  
                                  // Adaptive Card Layout (Standard Row vs Mobile Card)
                                  if (isSmallScreen) {
                                    return Card(
                                      color: const Color(0xFF252538),
                                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.machineName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: item.isActive 
                                                        ? Colors.green.withValues(alpha: 0.2) 
                                                        : Colors.red.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    item.isActive ? "نشط" : "معطل",
                                                    style: TextStyle(
                                                      color: item.isActive ? Colors.green : Colors.red,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(color: Color(0xFF1E1E2E), height: 20),
                                            Text("HWID: ${item.machineHwid}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text("مفتاح الترخيص: ${item.licenseKey}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text(
                                              "ينتهي في: ${item.expiryDate.length >= 10 ? item.expiryDate.substring(0, 10) : item.expiryDate}",
                                              style: TextStyle(
                                                color: DateTime.tryParse(item.expiryDate)?.isBefore(DateTime.now()) == true 
                                                    ? Colors.redAccent 
                                                    : Colors.amber,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  icon: const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                                                  label: const Text("تعديل", style: TextStyle(color: Colors.blueAccent)),
                                                  onPressed: () => _showEditDialog(item),
                                                ),
                                                const SizedBox(width: 12),
                                                TextButton.icon(
                                                  icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                                  label: const Text("حذف", style: TextStyle(color: Colors.redAccent)),
                                                  onPressed: () => _confirmDelete(item.licenseId),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  // Desktop Layout (ListTile style)
                                  return Card(
                                    color: const Color(0xFF252538),
                                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: item.isActive 
                                            ? Colors.green.withValues(alpha: 0.2) 
                                            : Colors.red.withValues(alpha: 0.2),
                                        child: Icon(
                                          item.isActive ? Icons.verified_user : Icons.gpp_bad,
                                          color: item.isActive ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      title: Text(
                                        item.machineName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text("HWID: ${item.machineHwid}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          Text("مفتاح الترخيص: ${item.licenseKey}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                          Text(
                                            "ينتهي في: ${item.expiryDate.length >= 10 ? item.expiryDate.substring(0, 10) : item.expiryDate}",
                                            style: TextStyle(
                                              color: DateTime.tryParse(item.expiryDate)?.isBefore(DateTime.now()) == true 
                                                  ? Colors.redAccent 
                                                  : Colors.amber,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                            onPressed: () => _showEditDialog(item),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                                            onPressed: () => _confirmDelete(item.licenseId),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
