import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip_vault/features/import/data/image_storage_service.dart';

void main() {
  test('ImageStorageService computes consistent SHA-256 hash', () async {
    final tempDir = await Directory.systemTemp.createTemp('slip_test_');
    final testFile = File('${tempDir.path}/sample.txt');
    await testFile.writeAsString('Test slip image content bytes');

    final hash1 = await ImageStorageService.computeSha256(testFile);
    final hash2 = await ImageStorageService.computeSha256(testFile);

    expect(hash1, isNotEmpty);
    expect(hash1, equals(hash2));

    await tempDir.delete(recursive: true);
  });
}
