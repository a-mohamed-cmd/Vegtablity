class DeviceLicense {
  final int licenseId;
  final String machineName;
  final String machineHwid;
  final String licenseKey;
  final bool isActive;
  final String expiryDate; // Format: 'YYYY-MM-DD'
  final String? createdDate;

  DeviceLicense({
    required this.licenseId,
    required this.machineName,
    required this.machineHwid,
    required this.licenseKey,
    required this.isActive,
    required this.expiryDate,
    this.createdDate,
  });

  factory DeviceLicense.fromJson(Map<String, dynamic> json) {
    return DeviceLicense(
      licenseId: json['LicenseID'] ?? 0,
      machineName: json['MachineName'] ?? '',
      machineHwid: json['MachineHWID'] ?? '',
      licenseKey: json['LicenseKey'] ?? '',
      isActive: json['IsActive'] == true || json['IsActive'] == 1,
      expiryDate: json['ExpiryDate'] ?? '',
      createdDate: json['CreatedDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'LicenseID': licenseId,
      'MachineName': machineName,
      'MachineHWID': machineHwid,
      'LicenseKey': licenseKey,
      'IsActive': isActive,
      'ExpiryDate': expiryDate,
    };
  }

  DeviceLicense copyWith({
    int? licenseId,
    String? machineName,
    String? machineHwid,
    String? licenseKey,
    bool? isActive,
    String? expiryDate,
    String? createdDate,
  }) {
    return DeviceLicense(
      licenseId: licenseId ?? this.licenseId,
      machineName: machineName ?? this.machineName,
      machineHwid: machineHwid ?? this.machineHwid,
      licenseKey: licenseKey ?? this.licenseKey,
      isActive: isActive ?? this.isActive,
      expiryDate: expiryDate ?? this.expiryDate,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
