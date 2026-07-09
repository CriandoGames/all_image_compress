import 'dart:isolate';
import 'dart:typed_data';

import 'compress_config.dart';
import 'compress_result.dart';
import 'compress_worker.dart';
import 'semaphore.dart';

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

  /// Compresses an image and scales it down to fit [maxWidth].
  ///
  /// The original aspect ratio is preserved and the image is never upscaled.
  static Future<CompressResult> fitWidth({
    required Uint8List bytes,
    required int maxWidth,
    CompressConfig config = const CompressConfig(),
  }) {
    return fromBytes(
      bytes: bytes,
      config: config.copyWith(maxWidth: maxWidth),
    );
  }

  /// Compresses an image and scales it down to fit [maxHeight].
  ///
  /// The original aspect ratio is preserved and the image is never upscaled.
  static Future<CompressResult> fitHeight({
    required Uint8List bytes,
    required int maxHeight,
    CompressConfig config = const CompressConfig(),
  }) {
    return fromBytes(
      bytes: bytes,
      config: config.copyWith(maxHeight: maxHeight),
    );
  }

  /// Compresses an image so it fits inside [maxWidth] and [maxHeight].
  ///
  /// The original aspect ratio is preserved and the image is never upscaled.
  static Future<CompressResult> contain({
    required Uint8List bytes,
    required int maxWidth,
    required int maxHeight,
    CompressConfig config = const CompressConfig(),
  }) {
    return fromBytes(
      bytes: bytes,
      config: config.copyWith(maxWidth: maxWidth, maxHeight: maxHeight),
    );
  }

  /// Compresses multiple images with a bounded concurrency pool.
  ///
  /// Each element of [items] é um record `(bytes, config)` — útil quando
  /// imagens diferentes precisam de configurações distintas.
  ///
  /// [maxConcurrent] limita quantos isolates rodam ao mesmo tempo (default: 3).
  /// Valores maiores aumentam a velocidade mas consomem mais RAM. Para galerias
  /// grandes, mantenha entre 2–4.
  ///
  /// [onProgress] é chamado na thread chamadora após cada item completar.
  ///
  /// Se algum item falhar, [BatchCompressException] é lançado após todos
  /// completarem. Resultados bem-sucedidos ficam disponíveis em
  /// [BatchCompressException.results].
  static Future<List<CompressResult?>> batch({
    required List<(Uint8List bytes, CompressConfig config)> items,
    int maxConcurrent = 3,
    BatchProgressCallback? onProgress,
  }) async {
    assert(maxConcurrent > 0, 'maxConcurrent must be at least 1');

    final results = List<CompressResult?>.filled(items.length, null);
    final errors = <int, Object>{};
    int completed = 0;
    final sem = Semaphore(maxConcurrent);

    await Future.wait(
      List.generate(items.length, (i) async {
        final (bytes, config) = items[i];
        await sem.run(() async {
          try {
            results[i] = await fromBytes(bytes: bytes, config: config);
          } catch (e) {
            errors[i] = e;
          } finally {
            completed++;
            onProgress?.call(completed, items.length);
          }
        });
      }),
    );

    if (errors.isNotEmpty) {
      throw BatchCompressException(errors: errors, results: results);
    }

    return results;
  }

  /// Convenience variant of [batch] com a mesma [config] para todas as imagens.
  static Future<List<CompressResult?>> batchUniform({
    required List<Uint8List> images,
    CompressConfig config = const CompressConfig(),
    int maxConcurrent = 3,
    BatchProgressCallback? onProgress,
  }) {
    return batch(
      items: images.map((b) => (b, config)).toList(),
      maxConcurrent: maxConcurrent,
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

  /// Synchronous variant of [fitWidth].
  static CompressResult fitWidthSync({
    required Uint8List bytes,
    required int maxWidth,
    CompressConfig config = const CompressConfig(),
  }) {
    return fromBytesSync(
      bytes: bytes,
      config: config.copyWith(maxWidth: maxWidth),
    );
  }

  /// Synchronous variant of [fitHeight].
  static CompressResult fitHeightSync({
    required Uint8List bytes,
    required int maxHeight,
    CompressConfig config = const CompressConfig(),
  }) {
    return fromBytesSync(
      bytes: bytes,
      config: config.copyWith(maxHeight: maxHeight),
    );
  }

  /// Synchronous variant of [contain].
  static CompressResult containSync({
    required Uint8List bytes,
    required int maxWidth,
    required int maxHeight,
    CompressConfig config = const CompressConfig(),
  }) {
    return fromBytesSync(
      bytes: bytes,
      config: config.copyWith(maxWidth: maxWidth, maxHeight: maxHeight),
    );
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
    final lines =
        errors.entries.map((e) => '  [${e.key}]: ${e.value}').join('\n');
    return 'BatchCompressException: ${errors.length} item(s) failed:\n$lines';
  }
}
