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
