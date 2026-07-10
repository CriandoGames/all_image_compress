/// Supported output image formats.
enum CompressFormat {
  /// JPEG — lossy compression, best for photos.
  /// Quality (0–100) controls the compression level.
  jpeg,

  /// PNG — lossless, best for graphics/text/transparency.
  /// Quality maps to compression effort (0=fastest/largest, 100=slowest/smallest).
  /// Visual quality is always identical (lossless).
  png,

  /// GIF — indexed color (max 256 colors), supports animation.
  /// Quality parameter is ignored.
  gif,

  /// BMP — uncompressed bitmap. Large file sizes, no quality loss.
  /// Quality parameter is ignored.
  bmp,

  /// TIFF — flexible format used in professional workflows.
  tiff,

  webp,
}

/// Extension with helpers for [CompressFormat].
extension CompressFormatExtension on CompressFormat {
  /// Returns the canonical file extension for this format.
  String get extension {
    switch (this) {
      case CompressFormat.jpeg:
        return 'jpg';
      case CompressFormat.png:
        return 'png';
      case CompressFormat.gif:
        return 'gif';
      case CompressFormat.bmp:
        return 'bmp';
      case CompressFormat.tiff:
        return 'tiff';
      case CompressFormat.webp:
        return 'webp';
    }
  }

  /// Returns the MIME type for this format.
  String get mimeType {
    switch (this) {
      case CompressFormat.jpeg:
        return 'image/jpeg';
      case CompressFormat.png:
        return 'image/png';
      case CompressFormat.gif:
        return 'image/gif';
      case CompressFormat.bmp:
        return 'image/bmp';
      case CompressFormat.tiff:
        return 'image/tiff';
      case CompressFormat.webp:
        return 'image/webp';
    }
  }

  /// Whether this format supports lossy quality control.
  bool get supportsQuality => this == CompressFormat.jpeg;
}
