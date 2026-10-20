import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages the state of the interactive bubble tour for the main Vault screen
class VaultTourService {
  static const _fileName = 'vault_tour_completed.flag';

  /// Optional override for automated testing
  static bool? testOverride;

  /// Check if the user has completed or skipped the interactive vault tour
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

  /// Mark the interactive tour as completed
  static Future<void> markCompleted() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, _fileName));
      await file.writeAsString('completed');
    } catch (_) {}
  }

  /// Reset tour (so it can be replayed on demand from Settings)
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
