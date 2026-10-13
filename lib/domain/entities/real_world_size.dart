import 'package:flutter/foundation.dart';

/// Represents real-world physical dimensions in centimeters (cm)
/// used for 1:1 real-scale Augmented Reality placement on tables.
@immutable
class RealWorldSize {
  final double width;
  final double depth;
  final double height;

  const RealWorldSize({
    required this.width,
    required this.depth,
    required this.height,
  });

  /// Formatted string like "28.0 × 28.0 × 3.0 cm"
  String get formattedDimensions =>
      '${width.toStringAsFixed(1)} × ${depth.toStringAsFixed(1)} × ${height.toStringAsFixed(1)} cm';

  /// Scale vector representation (normalized relative to meter scale for 3D engines)
  double get scaleFactorMeters => 0.01;

  Map<String, dynamic> toJson() => {
        'width': width,
        'depth': depth,
        'height': height,
      };

  factory RealWorldSize.fromJson(Map<String, dynamic> json) {
    return RealWorldSize(
      width: (json['width'] as num).toDouble(),
      depth: (json['depth'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealWorldSize &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          depth == other.depth &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ depth.hashCode ^ height.hashCode;

  @override
  String toString() => 'RealWorldSize($formattedDimensions)';
}
