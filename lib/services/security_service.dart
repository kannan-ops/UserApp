import 'package:enquiry_app/models/login_history_model.dart';
import 'package:enquiry_app/services/api_service.dart';

class SecurityService {
  final ApiService _apiService;

  static final Set<String> _pendingSaves = {};
  static bool _isSavingHistory = false;
  static bool _hasSavedLoginHistory = false;

  static void resetSessionHistoryState() {
    _hasSavedLoginHistory = false;
  }

  SecurityService(this._apiService);

  Future<Map<String, dynamic>> saveLoginHistory({
    required int userId,
    required String method,
  }) async {
    if (_hasSavedLoginHistory) {
      print("Login history already saved for this session. Skipping...");
      return {'success': true, 'message': 'already saved for this session'};
    }

    if (_isSavingHistory) {
      print("History save already running");
      return {'success': true, 'message': 'blocked concurrent save'};
    }
    _isSavingHistory = true;

    final String lockKey = "${userId}_$method";
    if (_pendingSaves.contains(lockKey)) {
      print("Duplicate saveLoginHistory blocked for: $lockKey");
      _isSavingHistory = false;
      return {'success': true, 'message': 'blocked duplicate concurrent call'};
    }
    _pendingSaves.add(lockKey);

    Future.delayed(const Duration(seconds: 3), () {
      _pendingSaves.remove(lockKey);
    });

    final Map<String, dynamic> requestBody = {'user_id': userId};

    switch (method.toLowerCase()) {
      case 'fingerprint':
        print("Fingerprint login API called");
        print("User ID: $userId");
        print("Sending fingerprint login history");
        requestBody['used_fingerprint'] = 1;
        break;
      case 'grid_card':
        print("Grid Card login API called");
        print("User ID: $userId");
        print("Sending grid card login history");
        requestBody['used_grid_card'] = 1;
        break;
      case 'security_tab':
        print("Security Tab login API called");
        print("User ID: $userId");
        print("Sending security tab login history");
        requestBody['used_security_tab'] = 1;
        break;
      case 'face_lock':
        print("Face Lock login API called");
        print("User ID: $userId");
        print("Sending face lock login history");
        requestBody['used_face_lock'] = 1;
        break;
      case 'pattern':
        print("Pattern login API called");
        print("User ID: $userId");
        print("Sending pattern login history");
        requestBody['used_pattern'] = 1;
        break;
      case 'pincode':
        print("PIN Code login API called");
        print("User ID: $userId");
        print("Sending pincode login history");
        requestBody['used_pincode'] = 1;
        break;
      default:
        print("PIN Code login API called (Fallback)");
        print("User ID: $userId");
        print("Sending pincode login history");
        requestBody['used_pincode'] = 1;
    }

    try {
      final result = await _apiService.request(
        path: '/security/login-history',
        method: 'POST',
        body: requestBody,
      );

      print("Login history API success");
      _pendingSaves.remove(lockKey);
      _hasSavedLoginHistory = true;
      return result is Map<String, dynamic> ? result : {'success': true};
    } catch (e, stackTrace) {
      print("========== EXCEPTION (Save Login History) ==========");
      print("ERROR: $e");
      print("STACKTRACE:");
      print(stackTrace);
      _pendingSaves.remove(lockKey);
      // Fail gracefully: do not rethrow, return a default failure status map
      return {'success': false, 'message': 'Endpoint not supported or server error: $e'};
    } finally {
      _isSavingHistory = false;
    }
  }

  Future<List<LoginHistoryModel>> getLoginHistory(int userId) async {
    print("Fetching login history");
    try {
      final result = await _apiService.request(
        path: '/security/login-history/$userId',
        method: 'GET',
      );

      List<dynamic> rawList = [];
      if (result is List) {
        rawList = result;
      } else if (result is Map && result['history'] is List) {
        rawList = result['history'];
      } else if (result is Map && result['data'] is List) {
        rawList = result['data'];
      } else if (result is Map) {
        final singleItem = LoginHistoryModel.fromJson(
          Map<String, dynamic>.from(result),
        );
        print("Login history API success");
        print("Total records: 1");
        return [singleItem];
      }

      final List<LoginHistoryModel> history = rawList
          .map(
            (item) =>
                LoginHistoryModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      history.sort((a, b) => b.time.compareTo(a.time));

      print("Login history API success");
      print("Total records: ${history.length}");
      return history;
    } catch (e, stackTrace) {
      print("========== EXCEPTION (Get Login History) ==========");
      print("ERROR: $e");
      print("STACKTRACE:");
      print(stackTrace);
      // Fail gracefully: return an empty list when route is not found or server fails
      return [];
    }
  }
}
