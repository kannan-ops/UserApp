class GoogleUserModel {
  final String email;
  final String displayName;
  final String photoUrl;

  GoogleUserModel({
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  Map<String, dynamic> toJson() {
    return {'email': email, 'displayName': displayName, 'photoUrl': photoUrl};
  }

  factory GoogleUserModel.fromJson(Map<String, dynamic> json) {
    return GoogleUserModel(
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
    );
  }
}
