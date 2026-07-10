import 'dart:typed_data';

import 'compress_format.dart';

/// The result of an image compression operation.
class CompressResult {
  const CompressResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.originalSizeBytes,
  });

  /// The compressed image data.
  final Uint8List bytes;

  /// Width of the output image in pixels.
  final int width;

  /// Height of the output image in pixels.
  final int height;

  /// Format of the output image.
  final CompressFormat format;

  /// Size of the original input in bytes.
  final int originalSizeBytes;

  /// Size of the compressed output in bytes.
  int get compressedSizeBytes => bytes.length;

  /// Size in mb
  double get compressedSizeMb => (bytes.length / (1024 * 1024));

  /// Ratio of compressed size to original size (0.0–1.0+).
  /// Values below 1.0 indicate size reduction.
  double get compressionRatio =>
      originalSizeBytes > 0 ? compressedSizeBytes / originalSizeBytes : 1.0;

  /// Number of bytes saved compared to the original.
  /// Negative if the output is larger than the input.
  int get savedBytes => originalSizeBytes - compressedSizeBytes;

  /// Percentage of size reduction (0–100).
  /// Negative if the output grew larger than the input.
  double get savedPercent =>
      originalSizeBytes > 0 ? (1.0 - compressionRatio) * 100.0 : 0.0;

  /// Human-readable summary of the compression result.
  String get summary {
    final orig = _formatBytes(originalSizeBytes);
    final comp = _formatBytes(compressedSizeBytes);
    final saved = savedPercent;
    final sign = saved >= 0 ? '-' : '+';
    return '$orig → $comp ($sign${saved.abs().toStringAsFixed(1)}%) '
        '$width×${height}px [${format.name.toUpperCase()}]';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  @override
  String toString() => 'CompressResult($summary)';
}
