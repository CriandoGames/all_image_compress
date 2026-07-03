import 'dart:io';
import 'dart:typed_data';

import 'all_image_compress_base.dart';
import 'compress_config.dart';
import 'compress_result.dart';

/// File-based compression helpers. Available on Android, iOS, macOS,
/// Windows, and Linux. Not available on the web — use
/// [AllImageCompress.fromBytes] there.
extension AllImageCompressFileExtension on AllImageCompress {
  // Extensions on abstract classes cannot be called as static methods,
  // so we expose these as top-level functions below.
}

/// Compresses an image file at [path].
///
/// Reads the file on the calling isolate, then delegates compression to a
/// background [Isolate] via [AllImageCompress.fromBytes].
///
/// Example:
/// ```dart
/// import 'package:all_image_compress/all_image_compress_io.dart';
///
/// final result = await compressFile(
///   path: file.path,
///   config: CompressConfig(quality: 80, maxWidth: 1920),
/// );
/// await File(outputPath).writeAsBytes(result.bytes);
/// ```
Future<CompressResult> compressFile({
  required String path,
  CompressConfig config = const CompressConfig(),
}) async {
  final Uint8List bytes = await File(path).readAsBytes();
  return AllImageCompress.fromBytes(bytes: bytes, config: config);
}

/// Compresses [inputFile] and writes the result to [outputFile].
///
/// The parent directory of [outputFile] must already exist.
/// Returns the [CompressResult] for inspection (e.g. compression ratio).
///
/// Example:
/// ```dart
/// final result = await compressFileToFile(
///   inputFile: File('/photos/large.jpg'),
///   outputFile: File('/photos/thumb.jpg'),
///   config: CompressConfig(quality: 75, maxWidth: 800, maxHeight: 600),
/// );
/// print(result.summary);
/// ```
Future<CompressResult> compressFileToFile({
  required File inputFile,
  required File outputFile,
  CompressConfig config = const CompressConfig(),
}) async {
  final Uint8List inputBytes = await inputFile.readAsBytes();
  final result = await AllImageCompress.fromBytes(bytes: inputBytes, config: config);
  await outputFile.writeAsBytes(result.bytes, flush: true);
  return result;
}
