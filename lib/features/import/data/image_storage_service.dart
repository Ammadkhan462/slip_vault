import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service responsible for copying screenshots to private app storage,
/// downscaling to max 1600px long edge, and calculating SHA-256 hash.
class ImageStorageService {
  /// Computes SHA-256 hash of a file
  static Future<String> computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Copies source image to app-private directory and downscales to max 1600px long edge
  /// with JPEG quality 85 to prevent UI jank or memory spikes.
  static Future<File> saveAndDownscaleImage(File sourceFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final vaultImagesDir = Directory(p.join(docsDir.path, 'vault_images'));
    if (!await vaultImagesDir.exists()) {
      await vaultImagesDir.create(recursive: true);
    }

    final filename = '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(sourceFile.path)}.jpg';
    final targetPath = p.join(vaultImagesDir.path, filename);

    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourceFile.path,
      targetPath,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      format: CompressFormat.jpeg,
    );

    if (compressed != null) {
      return File(compressed.path);
    }

    // Fallback: copy original if compression was unsupported/skipped
    return sourceFile.copy(targetPath);
  }
}
