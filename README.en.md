<p align="center">
  <img src="assets/all_image_compress.svg" alt="all_image_compress banner" width="100%"/>
</p>

<h1 align="center">all_image_compress</h1>

<p align="center">
  🗜️ Powerful image compression, 100% pure Dart — no native code, no platform channels.
</p>

<p align="center">
  🌐 <a href="README.md">Ler em Português</a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/all_image_compress"><img src="https://img.shields.io/pub/v/all_image_compress.svg?label=pub.dev" alt="pub version"></a>
  <a href="https://pub.dev/packages/all_image_compress/score"><img src="https://img.shields.io/pub/likes/all_image_compress?label=likes" alt="pub likes"></a>
  <a href="https://pub.dev/packages/all_image_compress/score"><img src="https://img.shields.io/pub/points/all_image_compress?label=pub%20points" alt="pub points"></a>
  <a href="https://github.com/CriandoGames/all_image_compress/blob/main/LICENSE"><img src="https://img.shields.io/github/license/CriandoGames/all_image_compress" alt="license"></a>
  <img src="https://img.shields.io/badge/platforms-6%2F6-brightgreen" alt="6 platforms">
</p>

---

## 🚀 Project Description

**all_image_compress** is a Dart/Flutter library for image compression built on four pillars:

- **100% pure Dart** — no Kotlin, no Objective-C, no platform channels. Works on every Flutter platform (Android, iOS, Web, macOS, Windows, Linux).
- **Isolate-powered** — all compression runs on a background `Isolate`, never blocking the UI thread.
- **Multi-format** — input: JPEG, PNG, GIF, BMP, TIFF, WebP, TGA, ICO, PVR (auto-detected via magic bytes). Output: JPEG, PNG, GIF, BMP, TIFF.
- **Simple, powerful API** — single compression, batch with progress, quality control, smart resize, rotation, and EXIF auto-correction.

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  all_image_compress: ^1.0.0
```

Then run:

```bash
flutter pub get
```

And import it in your code:

```dart
import 'package:all_image_compress/all_image_compress.dart';
```

---

## ⚙️ Quick Usage

```dart
import 'package:all_image_compress/all_image_compress.dart';

// Compresses bytes — runs in an Isolate automatically
final result = await AllImageCompress.fromBytes(
  bytes: rawImageBytes,
  config: CompressConfig(
    quality: 80,
    maxWidth: 1920,
    maxHeight: 1080,
    outputFormat: CompressFormat.jpeg,
  ),
);

print(result.summary);
// → "3.20MB → 410.50KB (-87.5%) 1920×1080px [JPEG]"

// Use the bytes directly
final widget = Image.memory(result.bytes);
await File(outputPath).writeAsBytes(result.bytes);
```

---

## Resize Helpers

Use these shortcuts when you want to express the resize intent without manually building `CompressConfig`:

```dart
final thumb = await AllImageCompress.fitWidth(
  bytes: rawImageBytes,
  maxWidth: 320,
  config: CompressConfig(quality: 80),
);

final preview = await AllImageCompress.fitHeight(
  bytes: rawImageBytes,
  maxHeight: 720,
);

final contained = await AllImageCompress.contain(
  bytes: rawImageBytes,
  maxWidth: 1280,
  maxHeight: 720,
);
```

Synchronous variants are also available: `fitWidthSync`, `fitHeightSync`, and `containSync` for use outside the UI thread.

Format note: WebP is decode-only in this version. If `outputFormat` is `null`, WebP inputs are re-encoded as JPEG. AVIF and HEIC are not currently supported by the pure-Dart codec backend used by this package.

---

## 📱 File Helpers (non-web)

```dart
import 'package:all_image_compress/all_image_compress.dart';
import 'package:all_image_compress/all_image_compress_io.dart';

// From a file path
final result = await compressFile(
  path: '/storage/photos/large.jpg',
  config: CompressConfig(quality: 75, maxWidth: 1280),
);

// File → File
await compressFileToFile(
  inputFile: File('/photos/original.png'),
  outputFile: File('/photos/thumbnail.jpg'),
  config: CompressConfig(quality: 85, maxWidth: 400, maxHeight: 400),
);
```

---

## 🗂️ Batch with Progress

```dart
final results = await AllImageCompress.batchUniform(
  images: [img1, img2, img3],
  config: CompressConfig(quality: 70, maxWidth: 800),
  maxConcurrent: 3, // limit of simultaneous isolates (default: 3)
  onProgress: (done, total) => print('$done/$total'),
);

// Different config per image
final results = await AllImageCompress.batch(
  items: [
    (profilePhoto, CompressConfig(quality: 90, maxWidth: 512)),
    (coverPhoto,   CompressConfig(quality: 75, maxWidth: 1920)),
    (thumbnail,    CompressConfig(quality: 60, maxWidth: 200)),
  ],
  maxConcurrent: 2, // for large galleries, keep 2–4
);
```

---

## 🎛️ CompressConfig — Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-----------|
| `quality` | `int` | `85` | 0–100. JPEG: visual quality. PNG: zlib compression level (100=smaller file/slower, 0=larger file/faster). |
| `maxWidth` | `int?` | `null` | Downscales if width exceeds this value. `null` = no limit. |
| `maxHeight` | `int?` | `null` | Downscales if height exceeds this value. `null` = no limit. |
| `outputFormat` | `CompressFormat?` | `null` | Output format. `null` = same as input (WebP → JPEG). |
| `rotate` | `int` | `0` | Clockwise rotation: `0`, `90`, `180`, or `270`. |
| `autoCorrectOrientation` | `bool` | `true` | Applies and strips the EXIF orientation tag. |
| `interpolation` | `CompressInterpolation` | `linear` | Resize algorithm: `nearest`, `linear`, `cubic`, `average`. |
| `keepExif` | `bool` | `false` | Preserves EXIF metadata (JPEG only; orientation tag always stripped). |

---

## 📊 CompressResult — Statistics

```dart
result.bytes               // Uint8List — compressed image
result.width               // int — width in pixels
result.height              // int — height in pixels
result.format              // CompressFormat — output format
result.originalSizeBytes   // int — original size
result.compressedSizeBytes // int — compressed size
result.compressionRatio    // double — compressed/original (0.13 = 87% smaller)
result.savedBytes          // int — bytes saved
result.savedPercent        // double — percentage reduction
result.summary             // String — human-readable one-line summary
```

---

## 🖼️ Supported Formats

| Format | Input | Output | Quality |
|---------|---------|-------|-----------|
| JPEG    | ✅      | ✅    | ✅ lossy  |
| PNG     | ✅      | ✅    | compression level |
| GIF     | ✅      | ✅    | ignored  |
| BMP     | ✅      | ✅    | ignored  |
| TIFF    | ✅      | ✅    | ignored  |
| WebP    | ✅      | ❌ → JPEG | — |
| TGA     | ✅      | ❌    | —         |
| ICO     | ✅      | ❌    | —         |

---

## 🔄 Synchronous API (outside the UI thread)

For use inside `Isolate.run()`, `compute()`, CLIs, or tests:

```dart
final result = AllImageCompress.fromBytesSync(
  bytes: imageBytes,
  config: CompressConfig(quality: 80),
);
```

> ⚠️ **Never call this method on the Flutter UI thread.** Use `fromBytes()` for that.

---

## 🏗️ Why Pure Dart?

Most compression libraries (flutter_image_compress, fast_image_compress) rely on native Kotlin/ObjC code — limiting them to Android and iOS, and requiring `Podfile`/`build.gradle` configuration.

**all_image_compress** uses the [`image`](https://pub.dev/packages/image) package (3.9M+ downloads) as its codec engine and delegates all the work to Dart's native `Isolate.run()`:

- ✅ Universal support (including **Web** and **Desktop**)
- ✅ No JNI/FFI/platform-channel overhead
- ✅ `flutter pub add all_image_compress` — ready to go, no native setup

---

## 👥 Contributors

[![Contributors](https://contrib.rocks/image?repo=CriandoGames/all_image_compress)](https://github.com/CriandoGames/all_image_compress/graphs/contributors)

Made with [contrib.rocks](https://contrib.rocks).

Contributions are welcome! Read [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

---

## 📄 License

Distributed under the MIT license. See [LICENSE](LICENSE) for details.

---

<p align="center">💻 Built with ❤️ to make Flutter development easier on every platform.</p>
