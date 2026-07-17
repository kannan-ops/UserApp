import 'package:audioplayers/audioplayers.dart';

class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;

  NotificationSoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playNotificationSound() async {
    print("[Sound] playNotificationSound called");
    try {
      print("[Sound] Service player.play() called");
      await _audioPlayer.play(AssetSource('sounds/new_notification.mp3'));
      print("[Sound] Service player.play() completed");
    } catch (e) {
      print("[Sound] Service Exception: $e");
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
