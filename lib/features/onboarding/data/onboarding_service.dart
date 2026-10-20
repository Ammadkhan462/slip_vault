import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OnboardingService {
  static const _fileName = 'onboarding_completed.flag';

  /// Optional override for automated widget testing
  static bool? testOverride;

  /// Check if the user has completed or skipped the onboarding tour
  static Future<bool> isCompleted() async {
    if (testOverride != null) return testOverride!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<void> markCompleted() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      await file.writeAsString('completed');
    } catch (_) {}
  }

  /// Reset onboarding (useful for testing or replay)
  static Future<void> reset() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
