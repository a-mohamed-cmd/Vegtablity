class UserSessionModel {
  final String accessToken;
  final String tokenType;
  final String username;
  final int userId;
  final String roleName;
  final String? database;
  final String? companyName;

  UserSessionModel({
    required this.accessToken,
    required this.tokenType,
    required this.username,
    required this.userId,
    required this.roleName,
    this.database,
    this.companyName,
  });

  factory UserSessionModel.fromJson(Map<String, dynamic> json) {
    return UserSessionModel(
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      username: json['username']?.toString() ?? '',
      userId: json['user_id'] is int ? json['user_id'] : (int.tryParse(json['user_id']?.toString() ?? '0') ?? 0),
      roleName: json['role_name']?.toString() ?? 'admin',
      database: json['database']?.toString(),
      companyName: json['company_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'username': username,
      'user_id': userId,
      'role_name': roleName,
      'database': database,
      'company_name': companyName,
    };
  }
}
