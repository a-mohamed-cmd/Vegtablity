import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ShiftProvider extends ChangeNotifier {
  final ApiService _apiService;
  bool _isLoading = false;
  bool _isShiftOpen = false;
  double? _startingCash;
  String? _shiftStartTime;
  String? _errorMessage;
  int? _shiftId;
  Map<String, dynamic>? _shiftSummary;

  List<Map<String, dynamic>> _warehouses = [];
  int? _selectedWarehouseId;
  String? _selectedWarehouseName;

  ShiftProvider(this._apiService);

  List<Map<String, dynamic>> get warehouses => _warehouses;
  int? get selectedWarehouseId => _selectedWarehouseId;
  String? get selectedWarehouseName => _selectedWarehouseName;

  Future<void> loadWarehouses() async {
    try {
      final response = await _apiService.getWarehouses();
      if (response.statusCode == 200) {
        _warehouses = List<Map<String, dynamic>>.from(response.data);
        if (_warehouses.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getInt('selected_warehouse_id');
          if (savedId != null && _warehouses.any((w) => w['WarehouseID'] == savedId)) {
            _selectedWarehouseId = savedId;
            _selectedWarehouseName = _warehouses.firstWhere((w) => w['WarehouseID'] == savedId)['WarehouseName'];
          } else {
            final defaultWh = _warehouses.first;
            _selectedWarehouseId = defaultWh['WarehouseID'];
            _selectedWarehouseName = defaultWh['WarehouseName'];
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _warehouses = [
        {'WarehouseID': 1, 'WarehouseName': 'المستودع الرئيسي'},
        {'WarehouseID': 2, 'WarehouseName': 'مستودع الخضار'},
      ];
      _selectedWarehouseId = 1;
      _selectedWarehouseName = 'المستودع الرئيسي';
      notifyListeners();
    }
  }

  void selectWarehouse(int id, String name) async {
    _selectedWarehouseId = id;
    _selectedWarehouseName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_warehouse_id', id);
    await prefs.setString('selected_warehouse_name', name);
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get isShiftOpen => _isShiftOpen;
  double? get startingCash => _startingCash;
  String? get shiftStartTime => _shiftStartTime;
  String? get errorMessage => _errorMessage;
  int? get shiftId => _shiftId;
  Map<String, dynamic>? get shiftSummary => _shiftSummary;

  Future<bool> openShift(double startingCash) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selectedWarehouseId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('selected_warehouse_id', _selectedWarehouseId!);
        await prefs.setString('selected_warehouse_name', _selectedWarehouseName!);
      }

      final response = await _apiService.openShift(startingCash);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _isShiftOpen = true;
        _startingCash = startingCash;
        _shiftStartTime = DateTime.now().toIso8601String();
        _shiftId = response.data['ShiftID'];

        final prefs = await SharedPreferences.getInstance();
        if (_shiftId != null) {
          await prefs.setInt('active_shift_id', _shiftId!);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'فشل في فتح الوردية. يرجى التحقق من المدخلات';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء فتح الوردية. يرجى المحاولة لاحقاً';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> checkActiveShiftStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedWarehouseId = prefs.getInt('selected_warehouse_id');
      _selectedWarehouseName = prefs.getString('selected_warehouse_name');

      final response = await _apiService.getActiveShift();
      if (response.statusCode == 200 && response.data != null) {
        _isShiftOpen = true;
        _shiftStartTime = response.data['StartTime'];
        _shiftId = response.data['ShiftID'];
        final rawStartingCash = response.data['StartingCash'];
        if (rawStartingCash is num) {
          _startingCash = rawStartingCash.toDouble();
        } else if (rawStartingCash is String) {
          _startingCash = double.tryParse(rawStartingCash);
        } else {
          _startingCash = null;
        }

        if (_shiftId != null) {
          await prefs.setInt('active_shift_id', _shiftId!);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Quietly ignore and set status to not open (no active shift found)
    }

    _isShiftOpen = false;
    _startingCash = null;
    _shiftStartTime = null;
    _shiftId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_shift_id');

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>?> fetchShiftSummary() async {
    if (_shiftId == null) return null;
    try {
      final response = await _apiService.getShiftSummary(_shiftId!);
      if (response.statusCode == 200) {
        _shiftSummary = Map<String, dynamic>.from(response.data);
        notifyListeners();
        return _shiftSummary;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<void> closeShift(int shiftId, double endingCash) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.closeShift(shiftId, endingCash);
      await clearShiftData();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearShiftData() async {
    _isShiftOpen = false;
    _startingCash = null;
    _shiftStartTime = null;
    _shiftId = null;
    _shiftSummary = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_shift_id');
    notifyListeners();
  }
}
