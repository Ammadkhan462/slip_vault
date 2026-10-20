import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final bool permissionDenied;
  final List<String> errors;

  const GallerySyncResult({
    required this.scannedCount,
    required this.importedCount,
    required this.skippedDuplicates,
    required this.skippedNonReceipts,
    this.permissionDenied = false,
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

  /// Request runtime storage/photos permissions on Android/iOS
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      if (Platform.isAndroid) {
        final photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted || photosStatus.isLimited) return true;

        final requestedPhotos = await Permission.photos.request();
        if (requestedPhotos.isGranted || requestedPhotos.isLimited) return true;

        // Fallback for Android 12 and below
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;
        final requestedStorage = await Permission.storage.request();
        return requestedStorage.isGranted;
      }
    } catch (_) {}
    return true;
  }

  /// Locate possible screenshot and banking directories on device
  List<Directory> _getScreenshotDirectories() {
    final dirs = <Directory>[];
    final seen = <String>{};

    void addDir(String path) {
      if (seen.contains(path)) return;
      seen.add(path);
      final dir = Directory(path);
      try {
        if (dir.existsSync()) {
          dirs.add(dir);
        }
      } catch (_) {}
    }

    final explicitPaths = [
      // Infinix, Tecno, Transsion, Xiaomi, MIUI (often singular 'Screenshot')
      '/storage/emulated/0/Pictures/Screenshot',
      '/storage/emulated/0/DCIM/Screenshot',
      '/sdcard/Pictures/Screenshot',
      '/sdcard/DCIM/Screenshot',
      // Samsung, Pixel, stock Android (plural 'Screenshots')
      '/storage/emulated/0/Pictures/Screenshots',
      '/storage/emulated/0/DCIM/Screenshots',
      '/sdcard/Pictures/Screenshots',
      '/sdcard/DCIM/Screenshots',
      // ScreenCapture & other vendor naming
      '/storage/emulated/0/Pictures/ScreenCapture',
      '/storage/emulated/0/Pictures/Capture',
      '/sdcard/Pictures/ScreenCapture',
      // Pakistani / international banking receipts saved to gallery
      '/storage/emulated/0/DCIM/Easypaisa',
      '/storage/emulated/0/DCIM/JazzCash',
      '/storage/emulated/0/Pictures/JazzcashBusiness',
      '/storage/emulated/0/Pictures/myABL',
      '/sdcard/DCIM/Easypaisa',
      '/sdcard/DCIM/JazzCash',
      '/sdcard/Pictures/JazzcashBusiness',
      '/sdcard/Pictures/myABL',
      // WhatsApp receipts
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
      '/storage/emulated/0/DCIM/WhatsApp',
      '/storage/emulated/0/Pictures/WhatsApp',
    ];

    for (final p in explicitPaths) {
      addDir(p);
    }

    // Dynamic search in parent Pictures & DCIM directories
    for (final parentPath in ['/storage/emulated/0/Pictures', '/storage/emulated/0/DCIM', '/sdcard/Pictures', '/sdcard/DCIM']) {
      final parent = Directory(parentPath);
      try {
        if (parent.existsSync()) {
          addDir(parentPath);
          for (final sub in parent.listSync(followLinks: false)) {
            if (sub is Directory) {
              final name = sub.path.toLowerCase();
              if (name.contains('screenshot') ||
                  name.contains('capture') ||
                  name.contains('receipt') ||
                  name.contains('jazz') ||
                  name.contains('easy') ||
                  name.contains('bank')) {
                addDir(sub.path);
              }
            }
          }
        }
      } catch (_) {}
    }

    return dirs;
  }

  /// Process an explicit list of files (from directory scan or picker fallback)
  Future<GallerySyncResult> importFiles(
    List<File> files, {
    void Function(int current, int total)? onProgress,
  }) async {
    // Sort by modified date descending (newest first)
    final sorted = List<File>.from(files);
    try {
      sorted.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });
    } catch (_) {}

    final candidates = sorted.take(50).toList();

    int imported = 0;
    int duplicates = 0;
    int nonReceipts = 0;
    final parser = GenericParser();

    for (int i = 0; i < candidates.length; i++) {
      final file = candidates[i];
      onProgress?.call(i + 1, candidates.length);

      try {
        if (!file.existsSync()) continue;

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

        // Check duplicate by TID / amount & date
        if (parsed.transactionId != null && parsed.transactionId!.isNotEmpty) {
          final dupByTid = await (db.select(db.entries)..where((tbl) => tbl.transactionId.equals(parsed.transactionId!))).getSingleOrNull();
          if (dupByTid != null) {
            duplicates++;
            continue;
          }
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

        DateTime slipDate = DateTime.now();
        try {
          slipDate = parsed.occurredAt ?? file.lastModifiedSync();
        } catch (_) {}

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
                occurredAt: drift.Value(slipDate),
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

  Future<GallerySyncResult> syncScreenshots({
    void Function(int current, int total)? onProgress,
  }) async {
    final hasPerm = await requestStoragePermission();
    if (!hasPerm) {
      return const GallerySyncResult(
        scannedCount: 0,
        importedCount: 0,
        skippedDuplicates: 0,
        skippedNonReceipts: 0,
        permissionDenied: true,
        errors: ['Storage or Photos permission was not granted.'],
      );
    }

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
            final path = entity.path.toLowerCase();
            final dot = path.lastIndexOf('.');
            if (dot != -1) {
              final ext = path.substring(dot);
              if (validExtensions.contains(ext)) {
                imageFiles.add(entity);
              }
            }
          }
        }
      } catch (_) {}
    }

    return importFiles(imageFiles, onProgress: onProgress);
  }
}

final gallerySyncServiceProvider = Provider<GallerySyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = GallerySyncService(db);
  ref.onDispose(() => service.dispose());
  return service;
});
