import 'dart:isolate';
import 'dart:typed_data';

import 'compress_config.dart';
import 'compress_result.dart';
import 'compress_worker.dart';

/// A callback invoked during batch compression to report progress.
///
/// [completed] is the number of items finished so far.
/// [total] is the total number of items in the batch.
typedef BatchProgressCallback = void Function(int completed, int total);

/// The main entry point for all image compression operations.
///
/// All async methods run the compression pipeline in a separate [Isolate],
/// so the Flutter UI thread is never blocked.
///
/// ### Quick start
/// ```dart
/// import 'package:all_image_compress/all_image_compress.dart';
///
/// // From raw bytes
/// final result = await AllImageCompress.fromBytes(
///   bytes: imageBytes,
///   config: CompressConfig(quality: 80, maxWidth: 1920, maxHeight: 1080),
/// );
/// print(result.summary); // "3.2MB → 420KB (-87.0%) 1920×1080px [JPEG]"
/// print(result.bytes);   // Uint8List — ready to save or display
///
/// // Batch
/// final results = await AllImageCompress.batchUniform(
///   images: myBytesList,
///   config: CompressConfig(quality: 75, maxWidth: 1280),
///   onProgress: (done, total) => print('$done/$total'),
/// );
/// ```
abstract final class AllImageCompress {
  AllImageCompress._();

  // ─────────────────────────────── Async API ─────────────────────────────────

  /// Compresses an image from raw bytes, running in a background [Isolate].
  ///
  /// The input format is detected automatically from the byte signature.
  ///
  /// **Supported inputs:** JPEG, PNG, GIF, BMP, TIFF, WebP, TGA, ICO, PVR.
  ///
  /// **WebP output** is not currently supported in pure Dart. If the input
  /// is WebP and no [CompressConfig.outputFormat] is set, the output defaults
  /// to JPEG.
  ///
  /// Throws [ArgumentError] if the bytes cannot be decoded as an image.
  static Future<CompressResult> fromBytes({
    required Uint8List bytes,
    CompressConfig config = const CompressConfig(),
  }) {
    return Isolate.run(() => runCompress(bytes, config));
  }

  /// Compresses multiple images in parallel, each on its own [Isolate].
  ///
  /// Each element of [items] is a `(bytes, config)` record — useful when
  /// different images need different settings.
  ///
  /// [onProgress] is called after each item completes (on the calling isolate).
  ///
  /// If any items fail, a [BatchCompressException] is thrown after all
  /// items complete. Successful results are still available via
  /// [BatchCompressException.results].
  static Future<List<CompressResult?>> batch({
    required List<(Uint8List bytes, CompressConfig config)> items,
    BatchProgressCallback? onProgress,
  }) async {
    final results = List<CompressResult?>.filled(items.length, null);
    final errors = <int, Object>{};
    int completed = 0;

    await Future.wait(
      List.generate(items.length, (i) async {
        final (bytes, config) = items[i];
        try {
          results[i] = await fromBytes(bytes: bytes, config: config);
        } catch (e) {
          errors[i] = e;
        } finally {
          completed++;
          onProgress?.call(completed, items.length);
        }
      }),
    );

    if (errors.isNotEmpty) {
      throw BatchCompressException(errors: errors, results: results);
    }

    return results;
  }

  /// Convenience variant of [batch] that applies the same [config] to all items.
  static Future<List<CompressResult?>> batchUniform({
    required List<Uint8List> images,
    CompressConfig config = const CompressConfig(),
    BatchProgressCallback? onProgress,
  }) {
    return batch(
      items: images.map((b) => (b, config)).toList(),
      onProgress: onProgress,
    );
  }

  // ─────────────────────────────── Sync API ──────────────────────────────────

  /// Compresses an image from raw bytes **synchronously** on the calling thread.
  ///
  /// ⚠️ **Do not call this on the Flutter UI thread.** Use [fromBytes] instead,
  /// which offloads work to a background isolate.
  ///
  /// This is intended for use inside `compute()`, `Isolate.run()`, CLI tools,
  /// or tests where the calling context is already off the UI thread.
  static CompressResult fromBytesSync({
    required Uint8List bytes,
    CompressConfig config = const CompressConfig(),
  }) {
    return runCompress(bytes, config);
  }
}

// ─────────────────────────────── Exceptions ────────────────────────────────

/// Thrown by [AllImageCompress.batch] when one or more items fail.
class BatchCompressException implements Exception {
  const BatchCompressException({
    required this.errors,
    required this.results,
  });

  /// Map of item index → thrown error for each failed item.
  final Map<int, Object> errors;

  /// Partial results list. Successful items are non-null; failed items are null.
  final List<CompressResult?> results;

  @override
  String toString() {
    final lines = errors.entries.map((e) => '  [${e.key}]: ${e.value}').join('\n');
    return 'BatchCompressException: ${errors.length} item(s) failed:\n$lines';
  }
}
