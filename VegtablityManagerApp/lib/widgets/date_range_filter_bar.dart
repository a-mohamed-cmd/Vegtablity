import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';

class DateRangeFilterBar extends StatelessWidget {
  const DateRangeFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ReportsProvider>(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(context, "اليوم", DatePreset.today, provider),
          const SizedBox(width: 8),
          _buildFilterChip(context, "هذا الأسبوع", DatePreset.thisWeek, provider),
          const SizedBox(width: 8),
          _buildFilterChip(context, "هذا الشهر", DatePreset.thisMonth, provider),
          const SizedBox(width: 8),
          _buildFilterChip(context, "هذا العام", DatePreset.thisYear, provider),
          const SizedBox(width: 8),
          _buildCustomDateChip(context, provider),
          const SizedBox(width: 14),
          // Refresh Button
          IconButton(
            tooltip: "تحديث البيانات اللحظية",
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            onPressed: provider.isLoading ? null : () => provider.loadAllCurrentTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, DatePreset preset, ReportsProvider provider) {
    final isSelected = provider.datePreset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.amber,
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? Colors.amber : Colors.white12),
      ),
      onSelected: (val) {
        if (val) provider.setDatePreset(preset);
      },
    );
  }

  Widget _buildCustomDateChip(BuildContext context, ReportsProvider provider) {
    final isSelected = provider.datePreset == DatePreset.custom;
    final text = isSelected
        ? "${provider.startDateFormatted} إلى ${provider.endDateFormatted}"
        : "تاريخ مخصص 📅";

    return ActionChip(
      label: Text(text),
      backgroundColor: isSelected ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.amber : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? Colors.amber : Colors.white12),
      ),
      onPressed: () async {
        final result = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDateRange: DateTimeRange(start: provider.startDate, end: provider.endDate),
          builder: (ctx, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.amber,
                  onPrimary: Color(0xFF0F172A),
                  surface: Color(0xFF1E293B),
                ),
              ),
              child: child!,
            );
          },
        );

        if (result != null) {
          provider.setCustomDateRange(result.start, result.end);
        }
      },
    );
  }
}
