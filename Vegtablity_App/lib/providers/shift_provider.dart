import 'package:flutter/material.dart';
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

  ShiftProvider(this._apiService);

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
      final response = await _apiService.openShift(startingCash);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _isShiftOpen = true;
        _startingCash = startingCash;
        _shiftStartTime = DateTime.now().toIso8601String();
        _shiftId = response.data['ShiftID'];
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
      final response = await _apiService.getActiveShift();
      if (response.statusCode == 200) {
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
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Quietly ignore and set status to not open (no active shift found)
      _isShiftOpen = false;
      _startingCash = null;
      _shiftStartTime = null;
      _shiftId = null;
    }

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
      _isShiftOpen = false;
      _startingCash = null;
      _shiftStartTime = null;
      _shiftId = null;
      _shiftSummary = null;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
