import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slip_vault/core/database/app_database.dart';

/// Global provider for the Drift AppDatabase singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
