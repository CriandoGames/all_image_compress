import 'compress_format.dart';

/// Interpolation algorithm used during resize operations.
enum CompressInterpolation {
  /// Nearest-neighbor — fastest, pixelated at large upscales.
  nearest,

  /// Bilinear — good balance of speed and quality. Recommended.
  linear,

  /// Bicubic — smoother result, slower than linear.
  cubic,

  /// Average downsampling — good for reducing images to much smaller sizes.
  average,
}

/// Configuration for an image compression operation.
///
/// Example:
/// ```dart
/// const config = CompressConfig(
///   quality: 80,
///   maxWidth: 1920,
///   maxHeight: 1080,
///   outputFormat: CompressFormat.jpeg,
/// );
/// ```
class CompressConfig {
  const CompressConfig({
    this.quality = 85,
    this.maxWidth,
    this.maxHeight,
    this.outputFormat,
    this.rotate = 0,
    this.autoCorrectOrientation = true,
    this.interpolation = CompressInterpolation.linear,
    this.keepExif = false,
  })  : assert(quality >= 0 && quality <= 100, 'quality must be between 0 and 100'),
        assert(
          rotate == 0 || rotate == 90 || rotate == 180 || rotate == 270,
          'rotate must be 0, 90, 180, or 270',
        ),
        assert(maxWidth == null || maxWidth > 0, 'maxWidth must be positive'),
        assert(maxHeight == null || maxHeight > 0, 'maxHeight must be positive');

  /// Output quality from 0 (worst) to 100 (best). Default: 85.
  ///
  /// - **JPEG**: maps directly to JPEG quality. Values between 70–90
  ///   offer a good size/quality tradeoff.
  /// - **PNG**: maps to zlib compression level (100=fastest/largest,
  ///   0=smallest/slowest). Visual quality is always lossless.
  /// - **GIF/BMP/TIFF**: ignored.
  final int quality;

  /// Maximum output width in pixels. The image will be scaled down
  /// proportionally if its width exceeds this value.
  ///
  /// If `maxHeight` is also set, both constraints are applied simultaneously
  /// while preserving the original aspect ratio.
  ///
  /// `null` means no width constraint.
  final int? maxWidth;

  /// Maximum output height in pixels. See [maxWidth] for details.
  ///
  /// `null` means no height constraint.
  final int? maxHeight;

  /// The output image format. When `null`, the format is inferred from
  /// the input image (WebP inputs fall back to JPEG).
  final CompressFormat? outputFormat;

  /// Clockwise rotation in degrees. Must be 0, 90, 180, or 270.
  /// Applied after EXIF orientation correction. Default: 0.
  final int rotate;

  /// When true (default), reads the EXIF orientation tag and rotates
  /// the image to its canonical upright orientation before applying
  /// any other transforms. The orientation tag is then stripped.
  final bool autoCorrectOrientation;

  /// Interpolation algorithm used when resizing. Default: [CompressInterpolation.linear].
  final CompressInterpolation interpolation;

  /// When true, preserves EXIF metadata in the output (JPEG only).
  /// The orientation tag is always stripped regardless of this flag.
  /// Default: false.
  final bool keepExif;

  /// Returns a copy of this config with the given fields replaced.
  CompressConfig copyWith({
    int? quality,
    int? maxWidth,
    int? maxHeight,
    CompressFormat? outputFormat,
    int? rotate,
    bool? autoCorrectOrientation,
    CompressInterpolation? interpolation,
    bool? keepExif,
  }) {
    return CompressConfig(
      quality: quality ?? this.quality,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      outputFormat: outputFormat ?? this.outputFormat,
      rotate: rotate ?? this.rotate,
      autoCorrectOrientation: autoCorrectOrientation ?? this.autoCorrectOrientation,
      interpolation: interpolation ?? this.interpolation,
      keepExif: keepExif ?? this.keepExif,
    );
  }

  @override
  String toString() => 'CompressConfig('
      'quality: $quality, '
      'maxWidth: $maxWidth, '
      'maxHeight: $maxHeight, '
      'outputFormat: $outputFormat, '
      'rotate: $rotate, '
      'autoCorrectOrientation: $autoCorrectOrientation, '
      'interpolation: $interpolation, '
      'keepExif: $keepExif'
      ')';
}
