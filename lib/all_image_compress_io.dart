/// dart:io extensions for all_image_compress.
///
/// Import this in addition to the main library on non-web platforms
/// (Android, iOS, macOS, Windows, Linux) to get file-based helpers:
///
/// ```dart
/// import 'package:all_image_compress/all_image_compress.dart';
/// import 'package:all_image_compress/all_image_compress_io.dart';
///
/// final result = await compressFile(
///   path: '/path/to/photo.jpg',
///   config: CompressConfig(quality: 80),
/// );
/// ```
library all_image_compress_io;

export 'src/all_image_compress_io.dart';
