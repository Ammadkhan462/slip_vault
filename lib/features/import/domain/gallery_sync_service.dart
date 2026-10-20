import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/categories/domain/category_model.dart';
import 'package:slip_vault/features/import/data/image_storage_service.dart';
import 'package:slip_vault/features/import/data/ocr_service.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';

class GallerySyncResult {
  final int scannedCount;
  final int importedCount;
  final int skippedDuplicates;
  final int skippedNonReceipts;
  final List<String> errors;

  const GallerySyncResult({
    required this.scannedCount,
    required this.importedCount,
    required this.skippedDuplicates,
    required this.skippedNonReceipts,
    this.errors = const [],
  });
}

class GallerySyncService {
  final AppDatabase db;
  final OcrService _ocrService;

  GallerySyncService(this.db) : _ocrService = OcrService();

  void dispose() {
    _ocrService.dispose();
  }

  /// Locate possible screenshot directories on Android device
  List<Directory> _getScreenshotDirectories() {
    final paths = [
      '/storage/emulated/0/Pictures/Screenshots',
      '/storage/emulated/0/DCIM/Screenshots',
      '/sdcard/Pictures/Screenshots',
      '/sdcard/DCIM/Screenshots',
    ];

    final dirs = <Directory>[];
    for (final path in paths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dirs.add(dir);
      }
    }
    return dirs;
  }

  Future<GallerySyncResult> syncScreenshots({
    void Function(int current, int total)? onProgress,
  }) async {
    final dirs = _getScreenshotDirectories();
    if (dirs.isEmpty) {
      return const GallerySyncResult(
        scannedCount: 0,
        importedCount: 0,
        skippedDuplicates: 0,
        skippedNonReceipts: 0,
        errors: ['No screenshot directory found on device.'],
      );
    }

    // Collect all candidate image files
    final imageFiles = <File>[];
    final validExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

    for (final dir in dirs) {
      try {
        final list = dir.listSync(recursive: false);
        for (final entity in list) {
          if (entity is File) {
            final ext = entity.path.toLowerCase().substring(entity.path.lastIndexOf('.'));
            if (validExtensions.contains(ext)) {
              imageFiles.add(entity);
            }
          }
        }
      } catch (_) {}
    }

    // Sort by modified date descending (newest first)
    imageFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    // Limit to latest 50 to maintain fast 2-second processing
    final candidates = imageFiles.take(50).toList();

    int imported = 0;
    int duplicates = 0;
    int nonReceipts = 0;
    final parser = GenericParser();

    for (int i = 0; i < candidates.length; i++) {
      final file = candidates[i];
      onProgress?.call(i + 1, candidates.length);

      try {
        final hash = await ImageStorageService.computeSha256(file);
        final existing = await (db.select(db.entries)..where((tbl) => tbl.imageHash.equals(hash))).getSingleOrNull();

        if (existing != null) {
          duplicates++;
          continue;
        }

        // Run ML OCR
        final recognizedText = await _ocrService.recognizeText(file);
        if (recognizedText.trim().isEmpty) {
          nonReceipts++;
          continue;
        }

        // Parse slip
        final parsed = parser.parse(recognizedText);

        // Strict receipt viability filter: Ignore non-financial screenshots
        if (!parsed.isReceipt && parsed.amountMinor == null) {
          nonReceipts++;
          continue;
        }

        // Downscale and save
        final savedFile = await ImageStorageService.saveAndDownscaleImage(file);

        Direction dir = Direction.unknown;
        if (parsed.direction == 'received') dir = Direction.received;
        if (parsed.direction == 'sent') dir = Direction.sent;

        // Auto-detect category
        final category = SlipCategories.detect(
          ocrText: recognizedText,
          counterparty: parsed.counterpartyName,
          provider: parsed.provider,
          direction: parsed.direction,
        );

        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                imagePath: savedFile.path,
                imageHash: hash,
                amountMinor: drift.Value(parsed.amountMinor),
                currency: drift.Value(parsed.currency),
                direction: drift.Value(dir),
                counterpartyName: drift.Value(parsed.counterpartyName),
                counterpartyAccountMasked: drift.Value(parsed.counterpartyAccountMasked),
                transactionId: drift.Value(parsed.transactionId),
                provider: drift.Value(parsed.provider),
                occurredAt: drift.Value(parsed.occurredAt ?? file.lastModifiedSync()),
                ocrText: drift.Value(recognizedText),
                category: drift.Value(category),
                needsReview: drift.Value(parsed.needsReview),
              ),
            );

        imported++;
      } catch (_) {
        // Continue scanning others on individual file error
      }
    }

    return GallerySyncResult(
      scannedCount: candidates.length,
      importedCount: imported,
      skippedDuplicates: duplicates,
      skippedNonReceipts: nonReceipts,
    );
  }
}

final gallerySyncServiceProvider = Provider<GallerySyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = GallerySyncService(db);
  ref.onDispose(() => service.dispose());
  return service;
});
