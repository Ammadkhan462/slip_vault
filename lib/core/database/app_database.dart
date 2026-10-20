import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:slip_vault/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Entries, Tags, EntryTags, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Create FTS5 virtual table for full-text search
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
              ocr_text,
              counterparty_name,
              transaction_id,
              note,
              content='entries',
              content_rowid='id'
            );
          ''');

          // Keep FTS5 table in sync with entries table triggers
          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
              INSERT INTO entries_fts(rowid, ocr_text, counterparty_name, transaction_id, note)
              VALUES (new.id, new.ocr_text, new.counterparty_name, new.transaction_id, new.note);
            END;
          ''');

          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
              INSERT INTO entries_fts(entries_fts, rowid, ocr_text, counterparty_name, transaction_id, note)
              VALUES('delete', old.id, old.ocr_text, old.counterparty_name, old.transaction_id, old.note);
            END;
          ''');

          await customStatement('''
            CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
              INSERT INTO entries_fts(entries_fts, rowid, ocr_text, counterparty_name, transaction_id, note)
              VALUES('delete', old.id, old.ocr_text, old.counterparty_name, old.transaction_id, old.note);
              INSERT INTO entries_fts(rowid, ocr_text, counterparty_name, transaction_id, note)
              VALUES (new.id, new.ocr_text, new.counterparty_name, new.transaction_id, new.note);
            END;
          ''');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(entries, entries.category);
          }
        },
      );

  // Full-text search over OCR text, counterparties, TID, notes
  Future<List<Entry>> searchEntries(String query) async {
    if (query.trim().isEmpty) return [];
    final sanitized = query.replaceAll('"', '""');
    final rows = await customSelect(
      '''
      SELECT e.* FROM entries e
      JOIN entries_fts fts ON e.id = fts.rowid
      WHERE entries_fts MATCH ?
      ORDER BY rank
      ''',
      variables: [Variable.withString('"$sanitized"*')],
      readsFrom: {entries},
    ).get();

    return rows.map((row) => entries.map(row.data)).toList();
  }

  // Monthly aggregated totals
  Future<Map<String, int>> getMonthlyTotals(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final receivedQuery = selectOnly(entries)
      ..addColumns([entries.amountMinor.sum()])
      ..where(
        entries.occurredAt.isBiggerOrEqualValue(start) &
            entries.occurredAt.isSmallerThanValue(end) &
            entries.direction.equals(Direction.received.name),
      );

    final sentQuery = selectOnly(entries)
      ..addColumns([entries.amountMinor.sum()])
      ..where(
        entries.occurredAt.isBiggerOrEqualValue(start) &
            entries.occurredAt.isSmallerThanValue(end) &
            entries.direction.equals(Direction.sent.name),
      );

    final receivedSum = await receivedQuery.map((row) => row.read(entries.amountMinor.sum())).getSingle();
    final sentSum = await sentQuery.map((row) => row.read(entries.amountMinor.sum())).getSingle();

    return {
      'received': receivedSum ?? 0,
      'sent': sentSum ?? 0,
    };
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'slip_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
