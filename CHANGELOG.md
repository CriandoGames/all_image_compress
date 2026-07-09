## Unreleased

- Added convenience resize APIs: `fitWidth`, `fitHeight`, `contain` and sync variants.
- Added regression tests for PNG transparency, portrait/panoramic aspect ratio, and partial batch failures.
- Documented WebP decode-only behavior and current AVIF/HEIC limitation.
- Added a local benchmark script for large-image compression checks.
- Added optional 50MB+ phone-image performance test and phone-sized benchmark cases.

## 1.0.1

- Added `topics` to `pubspec.yaml` (image, compression, image-processing, flutter, dart) for pub.dev discoverability
- Added English documentation (`README.en.md`), with language links between it and the Portuguese `README.md`

## 1.0.0

- Initial release
- `AllImageCompress.fromBytes` — async, isolate-based compression from `Uint8List`
- `AllImageCompress.fromBytesSync` — sync compression for off-UI contexts
- `AllImageCompress.batch` / `batchUniform` — parallel batch compression with progress callback
- `compressFile` / `compressFileToFile` — file-based helpers (non-web)
- Output formats: JPEG, PNG, GIF, BMP, TIFF
- Input formats: JPEG, PNG, GIF, BMP, TIFF, WebP, TGA, ICO, PVR (auto-detected)
- `CompressConfig` — quality, maxWidth/maxHeight, outputFormat, rotate, autoCorrectOrientation, interpolation, keepExif
- `CompressResult` — bytes, dimensions, format, compressionRatio, savedPercent, summary
- 100% pure Dart, no native code required
