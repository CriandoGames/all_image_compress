import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:all_image_compress/all_image_compress.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Creates a minimal in-memory JPEG at the given dimensions.
Uint8List makeJpeg(int width, int height, {int quality = 90}) {
  final image = img.Image(width: width, height: height);
  // Fill with a simple gradient so the encoder has real data to compress.
  for (var pixel in image) {
    pixel
      ..r = pixel.x % 256
      ..g = pixel.y % 256
      ..b = (pixel.x + pixel.y) % 256;
  }
  return img.encodeJpg(image, quality: quality);
}

/// Creates a minimal in-memory PNG at the given dimensions.
Uint8List makePng(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var pixel in image) {
    pixel
      ..r = (pixel.x * 2) % 256
      ..g = (pixel.y * 2) % 256
      ..b = 128
      ..a = 255;
  }
  return img.encodePng(image);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CompressConfig', () {
    test('defaults are sensible', () {
      const config = CompressConfig();
      expect(config.quality, 85);
      expect(config.maxWidth, isNull);
      expect(config.maxHeight, isNull);
      expect(config.rotate, 0);
      expect(config.autoCorrectOrientation, isTrue);
      expect(config.keepExif, isFalse);
    });

    test('copyWith replaces selected fields', () {
      const base = CompressConfig(quality: 80, maxWidth: 1920);
      final copy = base.copyWith(quality: 60, maxHeight: 1080);
      expect(copy.quality, 60);
      expect(copy.maxWidth, 1920); // preserved from base
      expect(copy.maxHeight, 1080);
    });

    test('throws on invalid quality', () {
      expect(() => CompressConfig(quality: -1), throwsA(isA<AssertionError>()));
      expect(
          () => CompressConfig(quality: 101), throwsA(isA<AssertionError>()));
    });

    test('throws on invalid rotate', () {
      expect(() => CompressConfig(rotate: 45), throwsA(isA<AssertionError>()));
    });
  });

  group('CompressFormat', () {
    test('extension has correct file extensions', () {
      expect(CompressFormat.jpeg.extension, 'jpg');
      expect(CompressFormat.png.extension, 'png');
      expect(CompressFormat.gif.extension, 'gif');
      expect(CompressFormat.bmp.extension, 'bmp');
      expect(CompressFormat.tiff.extension, 'tiff');
    });

    test('supportsQuality is true only for JPEG', () {
      expect(CompressFormat.jpeg.supportsQuality, isTrue);
      expect(CompressFormat.png.supportsQuality, isFalse);
      expect(CompressFormat.gif.supportsQuality, isFalse);
    });
  });

  group('CompressResult', () {
    test('compressionRatio and savedPercent are computed correctly', () {
      final result = CompressResult(
        bytes: Uint8List(400),
        width: 100,
        height: 100,
        format: CompressFormat.jpeg,
        originalSizeBytes: 1000,
      );
      expect(result.compressedSizeBytes, 400);
      expect(result.compressionRatio, closeTo(0.4, 0.001));
      expect(result.savedBytes, 600);
      expect(result.savedPercent, closeTo(60.0, 0.1));
    });

    test('summary string is human-readable', () {
      final result = CompressResult(
        bytes: Uint8List(51200), // 50 KB
        width: 1280,
        height: 720,
        format: CompressFormat.jpeg,
        originalSizeBytes: 512000, // 500 KB
      );
      expect(result.summary, contains('JPEG'));
      expect(result.summary, contains('1280×720'));
      expect(result.summary, contains('%'));
    });
  });

  // ─── Integration: real compression ───────────────────────────────────────

  group('AllImageCompress.fromBytesSync — JPEG', () {
    late Uint8List sourceJpeg;

    setUp(() => sourceJpeg = makeJpeg(2000, 1500));

    test('compresses and returns valid JPEG bytes', () {
      final result = AllImageCompress.fromBytesSync(bytes: sourceJpeg);
      expect(result.bytes, isNotEmpty);
      expect(result.format, CompressFormat.jpeg);
      // Output should be decodable
      expect(img.decodeJpg(result.bytes), isNotNull);
    });

    test('respects maxWidth / maxHeight constraints', () {
      final result = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(maxWidth: 800, maxHeight: 600),
      );
      expect(result.width, lessThanOrEqualTo(800));
      expect(result.height, lessThanOrEqualTo(600));
    });

    test('preserves aspect ratio on resize', () {
      // Source is 2000×1500 (4:3). Constrain to 800×800 → expect ~800×600
      final result = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(maxWidth: 800, maxHeight: 800),
      );
      final ratio = result.width / result.height;
      expect(ratio, closeTo(4 / 3, 0.05));
    });

    test('no resize when image is within constraints', () {
      final result = AllImageCompress.fromBytesSync(
        bytes: makeJpeg(400, 300),
        config: const CompressConfig(maxWidth: 1920, maxHeight: 1080),
      );
      expect(result.width, 400);
      expect(result.height, 300);
    });

    test('lower quality produces smaller output', () {
      final highQ = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(quality: 95),
      );
      final lowQ = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(quality: 20),
      );
      expect(lowQ.compressedSizeBytes, lessThan(highQ.compressedSizeBytes));
    });

    test('rotate 90 swaps width and height', () {
      final base = AllImageCompress.fromBytesSync(
        bytes: makeJpeg(400, 200),
        config: const CompressConfig(rotate: 0),
      );
      final rotated = AllImageCompress.fromBytesSync(
        bytes: makeJpeg(400, 200),
        config: const CompressConfig(rotate: 90),
      );
      // After 90° rotation, width and height are swapped
      expect(rotated.width, base.height);
      expect(rotated.height, base.width);
    });

    test('output format can be changed to PNG', () {
      final result = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(outputFormat: CompressFormat.png),
      );
      expect(result.format, CompressFormat.png);
      expect(img.decodePng(result.bytes), isNotNull);
    });
  });

  group('AllImageCompress.fromBytesSync — PNG', () {
    late Uint8List sourcePng;

    setUp(() => sourcePng = makePng(800, 600));

    test('compresses PNG and auto-detects format', () {
      final result = AllImageCompress.fromBytesSync(bytes: sourcePng);
      expect(result.format, CompressFormat.png);
      expect(img.decodePng(result.bytes), isNotNull);
    });

    test('higher quality (lower compression level) is larger for PNG', () {
      final loose = AllImageCompress.fromBytesSync(
        bytes: sourcePng,
        config: const CompressConfig(quality: 100), // level 0, no compression
      );
      final tight = AllImageCompress.fromBytesSync(
        bytes: sourcePng,
        config: const CompressConfig(quality: 0), // level 9, max compression
      );
      // Tight compression should produce smaller (or equal) output
      expect(tight.compressedSizeBytes,
          lessThanOrEqualTo(loose.compressedSizeBytes));
    });
  });

  group('AllImageCompress.fromBytesSync — GIF', () {
    test('encodes a GIF from a JPEG source', () {
      final sourceJpeg = makeJpeg(100, 100);
      final result = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(outputFormat: CompressFormat.gif),
      );
      expect(result.format, CompressFormat.gif);
      expect(img.decodeGif(result.bytes), isNotNull);
    });
  });

  group('AllImageCompress.fromBytesSync — BMP', () {
    test('encodes a BMP from a JPEG source', () {
      final sourceJpeg = makeJpeg(100, 100);
      final result = AllImageCompress.fromBytesSync(
        bytes: sourceJpeg,
        config: const CompressConfig(outputFormat: CompressFormat.bmp),
      );
      expect(result.format, CompressFormat.bmp);
      expect(img.decodeBmp(result.bytes), isNotNull);
    });
  });

  group('AllImageCompress.fromBytesSync — error cases', () {
    test('throws ArgumentError on empty bytes', () {
      expect(
        () => AllImageCompress.fromBytesSync(bytes: Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError on non-image bytes', () {
      // A sequence that matches no image magic bytes and will never decode.
      final notAnImage = Uint8List.fromList(
        'Hello, I am not an image!'.codeUnits,
      );
      expect(
        () => AllImageCompress.fromBytesSync(bytes: notAnImage),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('AllImageCompress.fromBytes (async / isolate)', () {
    test('returns same logical result as sync version', () async {
      final source = makeJpeg(500, 400);
      const config = CompressConfig(quality: 75, maxWidth: 300);

      final asyncResult =
          await AllImageCompress.fromBytes(bytes: source, config: config);
      final syncResult =
          AllImageCompress.fromBytesSync(bytes: source, config: config);

      expect(asyncResult.width, syncResult.width);
      expect(asyncResult.height, syncResult.height);
      expect(asyncResult.format, syncResult.format);
    });
  });

  group('AllImageCompress.batchUniform', () {
    test('processes all images', () async {
      final images = List.generate(3, (i) => makeJpeg(200 + i * 50, 150));
      final results = await AllImageCompress.batchUniform(
        images: images,
        config: const CompressConfig(quality: 70, maxWidth: 100),
      );
      expect(results, hasLength(3));
      for (final result in results) {
        expect(result, isNotNull);
        expect(result!.width, lessThanOrEqualTo(100));
      }
    });

    test('reports progress correctly', () async {
      final images = List.generate(4, (_) => makeJpeg(100, 100));
      final progressLog = <int>[];

      await AllImageCompress.batchUniform(
        images: images,
        config: const CompressConfig(),
        onProgress: (done, total) => progressLog.add(done),
      );

      expect(progressLog.length, 4);
      expect(progressLog.last, 4);
    });
  });
}
