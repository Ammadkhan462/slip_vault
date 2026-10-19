import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  /// Exports SQLite database and downscaled images into a single zip archive
  static Future<File> createBackupZip({
    Directory? targetDirectory,
    Directory? sourceDirectory,
  }) async {
    final docsDir = sourceDirectory ?? await getApplicationDocumentsDirectory();
    final archive = Archive();

    // 1. Add database file if exists
    final dbFile = File(p.join(docsDir.path, 'slip_vault.sqlite'));
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('slip_vault.sqlite', dbBytes.length, dbBytes));
    }

    // 2. Add vault_images
    final imagesDir = Directory(p.join(docsDir.path, 'vault_images'));
    if (await imagesDir.exists()) {
      final files = imagesDir.listSync(recursive: true);
      for (final entity in files) {
        if (entity is File) {
          final relPath = p.relative(entity.path, from: docsDir.path);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    final dir = targetDirectory ?? await getTemporaryDirectory();
    final backupFile = File(p.join(dir.path, 'SlipVault_Backup_${DateTime.now().millisecondsSinceEpoch}.zip'));
    return backupFile.writeAsBytes(zipBytes);
  }
}
