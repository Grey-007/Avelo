import 'dart:io';

class NotificationService {
  static Future<void> show(String title, String body) async {
    try {
      if (Platform.isLinux) {
        await Process.run('notify-send', [
          '-a',
          'Pebble',
          '-t',
          '5000', // 5 seconds
          title,
          body
        ]);
      } else if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'display notification "$body" with title "$title"'
        ]);
      } else if (Platform.isWindows) {
        // Minimal fallback for Windows via PowerShell BurntToast or msg
        // requires specific modules, so we'll just print for now
        print('Windows Notification: $title - $body');
      }
    } catch (e) {
      // Gracefully fail if commands are not found
      print('Failed to show notification: $e');
    }
  }
}
