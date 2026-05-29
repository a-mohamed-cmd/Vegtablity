import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../viewmodels/language_viewmodel.dart';
import '../core/localization/app_localizations.dart';
import '../models/language_model.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  String _selectedLayout = 'classic';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedLayout = prefs.getString('pref_home_layout') ?? 'classic';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings(String layout) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_home_layout', layout);
      setState(() {
        _selectedLayout = layout;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('settings_save_success'), textAlign: TextAlign.right),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('settings_save_error'), textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings')),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  Text(
                    context.tr('settings_layout_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('settings_layout_desc'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Classic Layout Card Option
                  _buildLayoutCard(
                    title: context.tr('settings_classic_title'),
                    description: context.tr('settings_classic_desc'),
                    layoutValue: 'classic',
                    icon: Icons.grid_view_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  // Partner Offers Layout Card Option
                  _buildLayoutCard(
                    title: context.tr('settings_premium_title'),
                    description: context.tr('settings_premium_desc'),
                    layoutValue: 'partners_offers',
                    icon: Icons.people_alt_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  Text(
                    context.tr('language'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer<LanguageViewModel>(
                    builder: (context, langVm, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: LanguageModel.supportedLanguages.map((lang) {
                          final isSelected = langVm.appLocale.languageCode == lang.languageCode;
                          return ChoiceChip(
                            label: Text(
                              lang.languageCode == 'ar' ? context.tr('arabic') : context.tr('english'),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.teal,
                            onSelected: (selected) {
                              if (selected) {
                                langVm.changeLanguage(lang.languageCode);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLayoutCard({
    required String title,
    required String description,
    required String layoutValue,
    required IconData icon,
    required Color color,
  }) {
    final bool isSelected = _selectedLayout == layoutValue;

    return InkWell(
      onTap: () => _saveSettings(layoutValue),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.teal[800] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.teal : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
