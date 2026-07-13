class UserModel {
  final String name;
  final String email;
  final String mobileNumber;
  final String role;
  final String location;
  final String deviceId;
  final String lastLogin;
  final String profilePhoto;

  UserModel({
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.role,
    required this.location,
    required this.deviceId,
    required this.lastLogin,
    required this.profilePhoto,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? mobileNumber,
    String? role,
    String? location,
    String? deviceId,
    String? lastLogin,
    String? profilePhoto,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      location: location ?? this.location,
      deviceId: deviceId ?? this.deviceId,
      lastLogin: lastLogin ?? this.lastLogin,
      profilePhoto: profilePhoto ?? this.profilePhoto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'mobileNumber': mobileNumber,
      'role': role,
      'location': location,
      'deviceId': deviceId,
      'lastLogin': lastLogin,
      'profilePhoto': profilePhoto,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      role: json['role'] ?? '',
      location: json['location'] ?? '',
      deviceId: json['deviceId'] ?? '',
      lastLogin: json['lastLogin'] ?? '',
      profilePhoto: json['profilePhoto'] ?? '',
    );
  }
}
