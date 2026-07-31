import '../core/api_client.dart';
import '../models/device_license.dart';

class LicenseApiService {
  Future<String> login(String username, String password) async {
    final response = await ApiClient.dio.post(
      'auth/login',
      data: {'username': username, 'password': password},
    );
    return response.data['access_token'];
  }

  Future<List<String>> getDatabases() async {
    final response = await ApiClient.dio.get('databases');
    return List<String>.from(response.data);
  }

  Future<List<DeviceLicense>> getLicenses(String dbName) async {
    final response = await ApiClient.dio.get('licenses/$dbName');
    final List<dynamic> data = response.data;
    return data.map((json) => DeviceLicense.fromJson(json)).toList();
  }

  Future<void> saveLicense(String dbName, DeviceLicense license) async {
    await ApiClient.dio.post(
      'licenses/$dbName',
      data: license.toJson(),
    );
  }

  Future<void> deleteLicense(String dbName, int licenseId) async {
    await ApiClient.dio.delete('licenses/$dbName/$licenseId');
  }

  Future<Map<String, dynamic>> getCompanySettings(String dbName) async {
    final response = await ApiClient.dio.get('company_settings/$dbName');
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> saveCompanySettings(String dbName, Map<String, dynamic> settings) async {
    await ApiClient.dio.post(
      'company_settings/$dbName',
      data: settings,
    );
  }
}
