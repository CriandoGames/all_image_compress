// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:all_image_compress/all_image_compress.dart';
import 'package:image/image.dart' as img;

void main() async {
  final cases = <_PhoneBenchmarkCase>[
    const _PhoneBenchmarkCase(
      name: 'iphone_48mp_8064x6048_to_1920',
      width: 8064,
      height: 6048,
      sourceQuality: 68,
      config: CompressConfig(
        quality: 82,
        maxWidth: 1920,
        outputFormat: CompressFormat.jpeg,
      ),
    ),
    const _PhoneBenchmarkCase(
      name: 'samsung_50mp_8160x6120_to_1920',
      width: 8160,
      height: 6120,
      sourceQuality: 76,
      config: CompressConfig(
        quality: 82,
        maxWidth: 1920,
        outputFormat: CompressFormat.jpeg,
      ),
    ),
  ];

  print('large phone image benchmark');
  print(
      'Synthetic high-detail JPEG fixtures. Run on the same machine to compare.');
  print('');

  for (final benchmarkCase in cases) {
    await _runCase(benchmarkCase);
    print('');
  }
}

Future<void> _runCase(_PhoneBenchmarkCase benchmarkCase) async {
  final sourceStopwatch = Stopwatch()..start();
  final source = _makeHighDetailJpeg(
    benchmarkCase.width,
    benchmarkCase.height,
    quality: benchmarkCase.sourceQuality,
    seed: benchmarkCase.width ^ benchmarkCase.height,
  );
  sourceStopwatch.stop();

  final syncStopwatch = Stopwatch()..start();
  final syncResult = AllImageCompress.fromBytesSync(
    bytes: source,
    config: benchmarkCase.config,
  );
  syncStopwatch.stop();

  final asyncStopwatch = Stopwatch()..start();
  final asyncResult = await AllImageCompress.fromBytes(
    bytes: source,
    config: benchmarkCase.config,
  );
  asyncStopwatch.stop();

  _printResult(
    benchmarkCase.name,
    'sync',
    source,
    syncResult,
    sourceStopwatch.elapsedMilliseconds,
    syncStopwatch.elapsedMilliseconds,
  );
  _printResult(
    benchmarkCase.name,
    'async',
    source,
    asyncResult,
    sourceStopwatch.elapsedMilliseconds,
    asyncStopwatch.elapsedMilliseconds,
  );
}

void _printResult(
  String name,
  String mode,
  Uint8List source,
  CompressResult result,
  int sourceMs,
  int elapsedMs,
) {
  final savedPercent = result.savedPercent.toStringAsFixed(1);
  print(
    '$name [$mode] '
    '${result.width}x${result.height} ${result.format.name} '
    '${_formatBytes(source.length)} -> ${_formatBytes(result.compressedSizeBytes)} '
    'saved $savedPercent% in ${elapsedMs}ms '
    '(fixture generated in ${sourceMs}ms)',
  );
}

Uint8List _makeHighDetailJpeg(
  int width,
  int height, {
  required int quality,
  required int seed,
}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    final noise = _noise(pixel.x, pixel.y, seed);
    pixel
      ..r = (pixel.x * 7 + pixel.y * 3 + noise) & 0xff
      ..g = (pixel.x * 5 + pixel.y * 11 + (noise >> 8)) & 0xff
      ..b = (pixel.x * 13 + pixel.y * 17 + (noise >> 16)) & 0xff;
  }
  return img.encodeJpg(image, quality: quality);
}

int _noise(int x, int y, int seed) {
  var value = x * 374761393 + y * 668265263 + seed * 1442695041;
  value = (value ^ (value >> 13)) * 1274126177;
  return value ^ (value >> 16);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
}

class _PhoneBenchmarkCase {
  const _PhoneBenchmarkCase({
    required this.name,
    required this.width,
    required this.height,
    required this.sourceQuality,
    required this.config,
  });

  final String name;
  final int width;
  final int height;
  final int sourceQuality;
  final CompressConfig config;
}
