import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slip_vault/core/database/app_database.dart';
import 'package:slip_vault/core/database/tables.dart';
import 'package:slip_vault/core/providers/database_provider.dart';
import 'package:slip_vault/features/import/data/image_storage_service.dart';
import 'package:slip_vault/features/import/data/ocr_service.dart';
import 'package:slip_vault/features/import/domain/generic_parser.dart';

class ImportItemStatus {
  final String filename;
  final String? imagePath;
  final bool isDuplicate;
  final bool isDone;
  final bool isFailed;
  final String? recognizedText;

  ImportItemStatus({
    required this.filename,
    this.imagePath,
    this.isDuplicate = false,
    this.isDone = false,
    this.isFailed = false,
    this.recognizedText,
  });

  ImportItemStatus copyWith({
    String? filename,
    String? imagePath,
    bool? isDuplicate,
    bool? isDone,
    bool? isFailed,
    String? recognizedText,
  }) {
    return ImportItemStatus(
      filename: filename ?? this.filename,
      imagePath: imagePath ?? this.imagePath,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      isDone: isDone ?? this.isDone,
      isFailed: isFailed ?? this.isFailed,
      recognizedText: recognizedText ?? this.recognizedText,
    );
  }
}

class BatchImportState {
  final bool isProcessing;
  final bool isCancelled;
  final int totalCount;
  final int completedCount;
  final List<ImportItemStatus> items;

  const BatchImportState({
    this.isProcessing = false,
    this.isCancelled = false,
    this.totalCount = 0,
    this.completedCount = 0,
    this.items = const [],
  });

  BatchImportState copyWith({
    bool? isProcessing,
    bool? isCancelled,
    int? totalCount,
    int? completedCount,
    List<ImportItemStatus>? items,
  }) {
    return BatchImportState(
      isProcessing: isProcessing ?? this.isProcessing,
      isCancelled: isCancelled ?? this.isCancelled,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
      items: items ?? this.items,
    );
  }
}

class BatchImportNotifier extends Notifier<BatchImportState> {
  OcrService? _ocrService;
  bool _cancelRequested = false;

  @override
  BatchImportState build() {
    _ocrService = OcrService();
    ref.onDispose(() {
      _ocrService?.dispose();
    });
    return const BatchImportState();
  }

  void cancel() {
    _cancelRequested = true;
    state = state.copyWith(isCancelled: true, isProcessing: false);
  }

  void reset() {
    _cancelRequested = false;
    state = const BatchImportState();
  }

  Future<void> processImages(List<File> imageFiles) async {
    if (imageFiles.isEmpty) return;
    _cancelRequested = false;

    final db = ref.read(databaseProvider);
    final initialItems = imageFiles.map((f) => ImportItemStatus(filename: f.path.split(Platform.pathSeparator).last)).toList();

    state = BatchImportState(
      isProcessing: true,
      isCancelled: false,
      totalCount: imageFiles.length,
      completedCount: 0,
      items: initialItems,
    );

    const batchSize = 10;
    for (int i = 0; i < imageFiles.length; i += batchSize) {
      if (_cancelRequested) break;

      final currentBatch = imageFiles.skip(i).take(batchSize).toList();
      for (int j = 0; j < currentBatch.length; j++) {
        if (_cancelRequested) break;

        final index = i + j;
        final file = currentBatch[j];

        try {
          final hash = await ImageStorageService.computeSha256(file);
          final existing = await (db.select(db.entries)..where((tbl) => tbl.imageHash.equals(hash))).getSingleOrNull();

          if (existing != null) {
            final updated = List<ImportItemStatus>.from(state.items);
            updated[index] = updated[index].copyWith(
              isDuplicate: true,
              isDone: true,
              imagePath: existing.imagePath,
            );
            state = state.copyWith(
              completedCount: state.completedCount + 1,
              items: updated,
            );
            continue;
          }

          final savedFile = await ImageStorageService.saveAndDownscaleImage(file);
          final recognizedText = await _ocrService!.recognizeText(savedFile);
          final parsed = GenericParser().parse(recognizedText);

          Direction dir = Direction.unknown;
          if (parsed.direction == 'received') dir = Direction.received;
          if (parsed.direction == 'sent') dir = Direction.sent;

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
                  occurredAt: drift.Value(parsed.occurredAt ?? DateTime.now()),
                  ocrText: drift.Value(recognizedText),
                  needsReview: drift.Value(parsed.needsReview),
                ),
              );

          final updated = List<ImportItemStatus>.from(state.items);
          updated[index] = updated[index].copyWith(
            isDone: true,
            imagePath: savedFile.path,
            recognizedText: recognizedText,
          );
          state = state.copyWith(
            completedCount: state.completedCount + 1,
            items: updated,
          );
        } catch (_) {
          final updated = List<ImportItemStatus>.from(state.items);
          updated[index] = updated[index].copyWith(isFailed: true, isDone: true);
          state = state.copyWith(
            completedCount: state.completedCount + 1,
            items: updated,
          );
        }
      }
    }

    state = state.copyWith(isProcessing: false);
  }
}

final batchImportProvider = NotifierProvider<BatchImportNotifier, BatchImportState>(
  BatchImportNotifier.new,
);
