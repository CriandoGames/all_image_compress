// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'compress_config.dart';
import 'compress_format.dart';
import 'compress_result.dart';
import 'format_detector.dart';
import 'resize_calculator.dart';

/// Parameters passed into the isolate. Must be sendable (no closures, no
/// non-transferable objects).
class _WorkerParams {
  const _WorkerParams({required this.bytes, required this.config});
  final Uint8List bytes;
  final CompressConfig config;
}

/// Top-level function that runs the compression pipeline synchronously.
/// This is called either directly (sync API) or from [Isolate.run] (async API).
///
/// Throws [ArgumentError] if the image cannot be decoded.
/// Throws [UnsupportedError] if an unsupported output format is requested.
CompressResult runCompress(Uint8List inputBytes, CompressConfig config) {
  return _doCompress(_WorkerParams(bytes: inputBytes, config: config));
}

CompressResult _doCompress(_WorkerParams p) {
  final inputBytes = p.bytes;
  final config = p.config;

  // ── 1. Decode ──────────────────────────────────────────────────────────────
  img.Image? decoded = img.decodeImage(inputBytes);
  if (decoded == null) {
    throw ArgumentError(
      'Could not decode image. '
      'Supported input formats: JPEG, PNG, GIF, BMP, TIFF, WebP, TGA, ICO, PVR.',
    );
  }

  // ── 2. EXIF orientation correction ─────────────────────────────────────────
  if (config.autoCorrectOrientation) {
    decoded = img.bakeOrientation(decoded);
  }

  // ── 3. Resize ───────────────────────────────────────────────────────────────
  if (config.maxWidth != null || config.maxHeight != null) {
    final dims = calculateResize(
      srcWidth: decoded.width,
      srcHeight: decoded.height,
      maxWidth: config.maxWidth,
      maxHeight: config.maxHeight,
    );

    if (dims.width != decoded.width || dims.height != decoded.height) {
      decoded = img.copyResize(
        decoded,
        width: dims.width,
        height: dims.height,
        interpolation: _mapInterpolation(config.interpolation),
      );
    }
  }

  // ── 4. Additional rotation ──────────────────────────────────────────────────
  if (config.rotate != 0) {
    decoded = img.copyRotate(decoded, angle: config.rotate.toDouble());
  }

  // ── 5. Determine output format ─────────────────────────────────────────────
  final inputLabel = detectFormatLabel(inputBytes);
  final outFormat = _resolveOutputFormat(config.outputFormat, inputLabel);

  // ── 6. Encode ───────────────────────────────────────────────────────────────
  final Uint8List outputBytes = _encode(decoded, outFormat, config);

  return CompressResult(
    bytes: outputBytes,
    width: decoded.width,
    height: decoded.height,
    format: outFormat,
    originalSizeBytes: inputBytes.length,
  );
}

/// Maps our [CompressFormat] to an encoded [Uint8List].
Uint8List _encode(
    img.Image image, CompressFormat format, CompressConfig config) {
  switch (format) {
    case CompressFormat.jpeg:
      return img.encodeJpg(image, quality: config.quality);
    case CompressFormat.png:
      // quality 100 → level 0 (no compression), quality 0 → level 9 (max compression)
      final level = ((100 - config.quality) * 9 / 100).round().clamp(0, 9);
      return img.encodePng(image, level: level);
    case CompressFormat.gif:
      return img.encodeGif(image);
    case CompressFormat.bmp:
      return img.encodeBmp(image);
    case CompressFormat.tiff:
      return img.encodeTiff(image);
  }
}

/// Resolves the output format based on user preference and detected input.
CompressFormat _resolveOutputFormat(
    CompressFormat? requested, String inputLabel) {
  if (requested != null) return requested;

  // Map input format to output format
  switch (inputLabel) {
    case 'jpeg':
      return CompressFormat.jpeg;
    case 'png':
      return CompressFormat.png;
    case 'gif':
      return CompressFormat.gif;
    case 'bmp':
      return CompressFormat.bmp;
    case 'tiff':
      return CompressFormat.tiff;
    case 'webp':
      // WebP output is not supported in pure Dart — default to JPEG
      return CompressFormat.jpeg;
    default:
      // Unknown input → default to JPEG (best compression for photos)
      return CompressFormat.jpeg;
  }
}

/// Maps our [CompressInterpolation] to the image package's [img.Interpolation].
img.Interpolation _mapInterpolation(CompressInterpolation interp) {
  switch (interp) {
    case CompressInterpolation.nearest:
      return img.Interpolation.nearest;
    case CompressInterpolation.linear:
      return img.Interpolation.linear;
    case CompressInterpolation.cubic:
      return img.Interpolation.cubic;
    case CompressInterpolation.average:
      return img.Interpolation.average;
  }
}
