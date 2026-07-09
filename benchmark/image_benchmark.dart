// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:all_image_compress/all_image_compress.dart';
import 'package:image/image.dart' as img;

void main() async {
  final cases = <_BenchmarkCase>[
    _BenchmarkCase(
      name: 'jpeg_photo_4000x3000_to_1920',
      bytes: _makeJpeg(4000, 3000, quality: 92),
      config: const CompressConfig(
        quality: 80,
        maxWidth: 1920,
        outputFormat: CompressFormat.jpeg,
      ),
    ),
    _BenchmarkCase(
      name: 'png_alpha_2500x2500_to_1000',
      bytes: _makePngWithAlpha(2500, 2500),
      config: const CompressConfig(
        quality: 90,
        maxWidth: 1000,
        maxHeight: 1000,
        outputFormat: CompressFormat.png,
      ),
    ),
  ];

  print('all_image_compress benchmark');
  print('Run more than once and compare medians on the same machine.');
  print('');

  for (final benchmarkCase in cases) {
    _runSync(benchmarkCase);
    await _runAsync(benchmarkCase);
    print('');
  }
}

void _runSync(_BenchmarkCase benchmarkCase) {
  final stopwatch = Stopwatch()..start();
  final result = AllImageCompress.fromBytesSync(
    bytes: benchmarkCase.bytes,
    config: benchmarkCase.config,
  );
  stopwatch.stop();

  _printResult('sync', benchmarkCase, result, stopwatch.elapsedMilliseconds);
}

Future<void> _runAsync(_BenchmarkCase benchmarkCase) async {
  final stopwatch = Stopwatch()..start();
  final result = await AllImageCompress.fromBytes(
    bytes: benchmarkCase.bytes,
    config: benchmarkCase.config,
  );
  stopwatch.stop();

  _printResult('async', benchmarkCase, result, stopwatch.elapsedMilliseconds);
}

void _printResult(
  String mode,
  _BenchmarkCase benchmarkCase,
  CompressResult result,
  int elapsedMs,
) {
  final original = _formatBytes(benchmarkCase.bytes.length);
  final compressed = _formatBytes(result.compressedSizeBytes);
  print(
    '${benchmarkCase.name} [$mode] '
    '${result.width}x${result.height} ${result.format.name} '
    '$original -> $compressed in ${elapsedMs}ms',
  );
}

Uint8List _makeJpeg(int width, int height, {required int quality}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel
      ..r = (pixel.x * 3 + pixel.y) % 256
      ..g = (pixel.x + pixel.y * 2) % 256
      ..b = (pixel.x * 2 + pixel.y * 5) % 256;
  }
  return img.encodeJpg(image, quality: quality);
}

Uint8List _makePngWithAlpha(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (final pixel in image) {
    final inTransparentBand = pixel.x < width ~/ 3;
    pixel
      ..r = (pixel.x * 7) % 256
      ..g = (pixel.y * 5) % 256
      ..b = (pixel.x + pixel.y) % 256
      ..a = inTransparentBand ? 0 : 255;
  }
  return img.encodePng(image, level: 6);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
}

class _BenchmarkCase {
  const _BenchmarkCase({
    required this.name,
    required this.bytes,
    required this.config,
  });

  final String name;
  final Uint8List bytes;
  final CompressConfig config;
}
