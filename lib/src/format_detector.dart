import 'dart:typed_data';

import 'compress_format.dart';

/// Detects the image format from the first bytes of raw image data.
///
/// Returns `null` if the format cannot be determined.
CompressFormat? detectFormat(Uint8List bytes) {
  if (bytes.length < 4) return null;

  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return CompressFormat.jpeg;
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return CompressFormat.png;
  }

  // GIF: 47 49 46 38 (GIF8)
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
    return CompressFormat.gif;
  }

  // BMP: 42 4D (BM)
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return CompressFormat.bmp;
  }

  // TIFF: 49 49 2A 00 (little-endian) or 4D 4D 00 2A (big-endian)
  if ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
      (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A)) {
    return CompressFormat.tiff;
  }

  // WebP: RIFF????WEBP (bytes 0-3 = RIFF, bytes 8-11 = WEBP)
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46 && // F
      bytes[8] == 0x57 && // W
      bytes[9] == 0x45 && // E
      bytes[10] == 0x42 && // B
      bytes[11] == 0x50) { // P
    // WebP decode is supported; output will be converted to JPEG/PNG
    return null; // signals "webp input" — caller handles format selection
  }

  return null;
}

/// Like [detectFormat] but returns a human-readable label including WebP.
String detectFormatLabel(Uint8List bytes) {
  // Check WebP explicitly here
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp';
  }
  return detectFormat(bytes)?.name ?? 'unknown';
}

/// Returns true if the bytes appear to be a WebP image.
bool isWebP(Uint8List bytes) {
  if (bytes.length < 12) return false;
  return bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}
