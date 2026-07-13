class LoginHistoryModel {
  final int id;
  final int userId;
  final String method;
  final DateTime time;
  final String status;

  LoginHistoryModel({
    required this.id,
    required this.userId,
    required this.method,
    required this.time,
    required this.status,
  });

  factory LoginHistoryModel.fromJson(Map<String, dynamic> json) {
    String loginMethod = 'Standard Password';

    if (json['used_fingerprint'] == 1 || json['used_fingerprint'] == true) {
      loginMethod = 'Fingerprint';
    } else if (json['used_grid_card'] == 1 || json['used_grid_card'] == true) {
      loginMethod = 'Grid Card';
    } else if (json['used_security_tab'] == 1 ||
        json['used_security_tab'] == true) {
      loginMethod = 'Security Tab';
    } else if (json['used_face_lock'] == 1 || json['used_face_lock'] == true) {
      loginMethod = 'Face Lock';
    } else if (json['used_pattern'] == 1 || json['used_pattern'] == true) {
      loginMethod = 'Pattern Lock';
    } else if (json['used_pincode'] == 1 || json['used_pincode'] == true) {
      loginMethod = 'PIN Code';
    } else if (json['method'] != null && json['method'].toString().isNotEmpty) {
      loginMethod = json['method'].toString();
    }

    String loginStatus = 'Success';
    if (json['status'] != null) {
      final s = json['status'].toString().toLowerCase();
      if (s == '1' || s == 'true' || s == 'success' || s == 'ok') {
        loginStatus = 'Success';
      } else {
        loginStatus = json['status'].toString();
      }
    }

    DateTime parsedTime = DateTime.now();
    if (json['created_at'] != null) {
      parsedTime =
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      parsedTime =
          DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else if (json['time'] != null) {
      parsedTime = DateTime.tryParse(json['time'].toString()) ?? DateTime.now();
    } else if (json['login_time'] != null) {
      parsedTime =
          DateTime.tryParse(json['login_time'].toString()) ?? DateTime.now();
    }

    final int recordId = json['id'] is int
        ? json['id']
        : (int.tryParse(json['id']?.toString() ?? '') ?? 0);

    final int usrId = json['user_id'] is int
        ? json['user_id']
        : (int.tryParse(json['user_id']?.toString() ?? '') ?? 1);

    return LoginHistoryModel(
      id: recordId,
      userId: usrId,
      method: loginMethod,
      time: parsedTime,
      status: loginStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'method': method,
      'time': time.toIso8601String(),
      'status': status,
    };
  }

  @override
  String toString() {
    return 'LoginHistoryModel(id: $id, userId: $userId, method: $method, time: $time, status: $status)';
  }
}
