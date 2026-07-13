class ValidationModel {
  final int id;
  final int deviceId;
  final String deviceName;
  final int platformId;
  final String platformName;
  final String version;
  final String appId;
  final String apiUrl;
  final String appName;
  final String softwareVersion;
  final String status;
  final String createdAt;

  ValidationModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platformId,
    required this.platformName,
    required this.version,
    required this.appId,
    required this.apiUrl,
    required this.appName,
    required this.softwareVersion,
    required this.status,
    required this.createdAt,
  });

  factory ValidationModel.fromJson(Map<String, dynamic> json) {
    return ValidationModel(
      id: json['id'] ?? 0,
      deviceId: json['deviceId'] ?? 0,
      deviceName: json['deviceName'] ?? 'unknown',
      platformId: json['platformId'] ?? 0,
      platformName: json['platformName'] ?? 'unknown',
      version: json['version'] ?? '1.0.0',
      appId: json['appId'] ?? '',
      apiUrl:
          json['apiUrl'] ??
          'https://mobilevalidation.srivagroups.in/api/UserAppData',
      appName: json['appName'] ?? 'Payment App',
      softwareVersion: json['softwareVersion'] ?? '1.4.1',
      status: json['status'] ?? 'Active',
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platformId': platformId,
      'platformName': platformName,
      'version': version,
      'appId': appId,
      'apiUrl': apiUrl,
      'appName': appName,
      'softwareVersion': softwareVersion,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
