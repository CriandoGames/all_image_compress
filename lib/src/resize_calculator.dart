import 'dart:math' as math;

/// Result of a resize calculation.
class ResizeDimensions {
  const ResizeDimensions({required this.width, required this.height});
  final int width;
  final int height;

  @override
  String toString() => '$width×$height';
}

/// Calculates target dimensions for an image resize operation.
///
/// The original aspect ratio is always preserved. The image is only ever
/// scaled **down** — if the original is already within the constraints,
/// the original dimensions are returned unchanged.
///
/// The algorithm:
/// 1. Compute the scale factor required to satisfy each constraint.
/// 2. Use the larger of the two scale factors (most aggressive reduction).
/// 3. If scale <= 1.0, no resize is needed.
///
/// Example:
/// ```dart
/// // 4000×2000 image, maxWidth: 1920, maxHeight: 1080
/// // scaleW = 4000/1920 = 2.08
/// // scaleH = 2000/1080 = 1.85
/// // scale  = max(2.08, 1.85) = 2.08
/// // result = 4000/2.08 × 2000/2.08 ≈ 1923×962  (rounded to nearest even for codec compat)
/// ```
ResizeDimensions calculateResize({
  required int srcWidth,
  required int srcHeight,
  int? maxWidth,
  int? maxHeight,
}) {
  if (maxWidth == null && maxHeight == null) {
    return ResizeDimensions(width: srcWidth, height: srcHeight);
  }

  final double scaleW = maxWidth != null ? srcWidth / maxWidth : 1.0;
  final double scaleH = maxHeight != null ? srcHeight / maxHeight : 1.0;
  final double scale = math.max(1.0, math.max(scaleW, scaleH));

  if (scale <= 1.0) {
    // Already within constraints — no resize needed.
    return ResizeDimensions(width: srcWidth, height: srcHeight);
  }

  // Round to nearest int, clamp to at least 1 pixel.
  final int targetW = math.max(1, (srcWidth / scale).round());
  final int targetH = math.max(1, (srcHeight / scale).round());

  return ResizeDimensions(width: targetW, height: targetH);
}
