/// A powerful, pure-Dart image compression library for Flutter.
///
/// Runs compression in background [Isolate]s to keep the UI responsive.
/// No native code, no platform channels — works on Android, iOS, macOS,
/// Windows, Linux, and Web.
///
/// ### Supported input formats
/// JPEG, PNG, GIF, BMP, TIFF, WebP, TGA, ICO, PVR
///
/// ### Supported output formats
/// JPEG, PNG, GIF, BMP, TIFF
///
/// ### Basic usage
/// ```dart
/// import 'package:all_image_compress/all_image_compress.dart';
///
/// final result = await AllImageCompress.fromBytes(
///   bytes: rawImageBytes,
///   config: CompressConfig(
///     quality: 80,
///     maxWidth: 1920,
///     maxHeight: 1080,
///     outputFormat: CompressFormat.jpeg,
///   ),
/// );
///
/// print(result.summary);
/// // → "3.20MB → 410.50KB (-87.5%) 1920×1080px [JPEG]"
///
/// final Image widget = Image.memory(result.bytes);
/// ```
///
/// ### File access (non-web platforms only)
/// ```dart
/// import 'package:all_image_compress/all_image_compress_io.dart';
///
/// final result = await compressFile(
///   path: '/path/to/photo.jpg',
///   config: CompressConfig(quality: 75),
/// );
/// ```
library;

export 'src/all_image_compress_base.dart';
export 'src/compress_config.dart';
export 'src/compress_format.dart';
export 'src/compress_result.dart';
