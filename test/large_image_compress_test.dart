import 'dart:typed_data';

import 'package:all_image_compress/all_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _runLargeImageTests = bool.fromEnvironment('RUN_LARGE_IMAGE_TESTS');

void main() {
  group('large phone image compression', () {
    test(
      'compresses a 50MB+ phone-like JPEG to a small 1920px output',
      () {
        final source = _makeHighDetailJpeg(
          8064,
          6048,
          quality: 68,
          seed: 8064 ^ 6048,
        );

        expect(
          source.length,
          greaterThan(50 * 1024 * 1024),
          reason: 'fixture should represent a 50MB+ phone photo',
        );

        final result = AllImageCompress.containSync(
          bytes: source,
          maxWidth: 1920,
          maxHeight: 1920,
          config: const CompressConfig(
            quality: 82,
            outputFormat: CompressFormat.jpeg,
          ),
        );

        expect(result.width, lessThanOrEqualTo(1920));
        expect(result.height, lessThanOrEqualTo(1920));
        expect(result.compressedSizeBytes, lessThan(5 * 1024 * 1024));
        expect(result.savedPercent, greaterThan(90));
      },
      skip: _runLargeImageTests
          ? false
          : 'Large performance test. Run with '
              '--dart-define=RUN_LARGE_IMAGE_TESTS=true.',
    );
  });
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
