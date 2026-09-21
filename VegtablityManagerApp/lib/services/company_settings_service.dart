import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/company_settings_model.dart';

class CompanySettingsService {
  final ApiClient _client = ApiClient();

  Future<CompanySettingsModel?> getCompanySettings({String? database}) async {
    try {
      final response = await _client.dio.get(
        '/settings/company',
        queryParameters: {
          if (database != null && database.isNotEmpty) 'database': database,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data.isNotEmpty) {
          return CompanySettingsModel.fromJson(data);
        }
      }
      return null;
    } on DioException catch (e) {
      print('Error fetching company settings: ${e.message}');
      return null;
    } catch (e) {
      print('Error fetching company settings: $e');
      return null;
    }
  }
}
