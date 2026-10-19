import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/settings/data/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BackupService creates a valid zip archive file', () async {
    final tempDir = await Directory.systemTemp.createTemp('slip_backup_test_');

    final zipFile = await BackupService.createBackupZip(
      targetDirectory: tempDir,
      sourceDirectory: tempDir,
    );

    expect(await zipFile.exists(), isTrue);
    final bytes = await zipFile.readAsBytes();
    // Zip file magic bytes: PK\x03\x04 (0x50, 0x4B, 0x03, 0x04) or empty archive
    expect(bytes.length, greaterThanOrEqualTo(22)); // Minimum valid empty zip size is 22 bytes
    expect(bytes[0], equals(0x50));
    expect(bytes[1], equals(0x4B));

    await tempDir.delete(recursive: true);
  });
}
