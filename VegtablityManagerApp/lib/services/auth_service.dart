import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/user_session_model.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<UserSessionModel> login({
    required String username,
    required String password,
    String? database,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          if (database != null) 'database': database,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return UserSessionModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception(response.data?['detail'] ?? 'فشل تسجيل الدخول');
      }
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      throw Exception(detail ?? e.message ?? 'خطأ في الاتصال بالخادم');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }
}
