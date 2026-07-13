import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:enquiry_app/models/google_user_model.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '316605580809-m7cp3810um66qnpt3eh2bmvhvn8k937m.apps.googleusercontent.com',
  );

  Future<GoogleUserModel?> signInWithGoogle() async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        debugPrint(
          'DEBUG [GoogleAuthService]: Native google_sign_in is only supported on Android/iOS/Web.',
        );
        return null;
      }
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        return GoogleUserModel(
          email: account.email,
          displayName: account.displayName ?? 'Google User',
          photoUrl: account.photoUrl ?? '',
        );
      }
    } catch (e) {
      debugPrint(
        'DEBUG [GoogleAuthService]: google_sign_in native flow failed: $e',
      );
      rethrow;
    }
    return null;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint(
        'DEBUG [GoogleAuthService]: google_sign_in signOut failed: $e',
      );
    }
  }
}
