import 'dart:math' as math;
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../../../domain/entities/food_item.dart';

/// Represents a distinct food dish placed on the detected real-world table surface in AR.
/// Holds the item's identity, food metadata, AR anchor, 3D model node, rotation, and position.
class PlacedItem {
  final String id;
  final FoodItem foodItem;
  final ARPlaneAnchor? anchor;
  final ARNode? node;
  final vector.Vector4 rotation;
  final vector.Vector3 position; // World coordinate position on the detected surface (meters)
  final DateTime placedAt;

  PlacedItem({
    required this.id,
    required this.foodItem,
    this.anchor,
    this.node,
    required this.rotation,
    required this.position,
    DateTime? placedAt,
  }) : placedAt = placedAt ?? DateTime.now();

  /// Radial physical boundary in meters on the horizontal table plane
  double get footprintRadiusMeters => foodItem.footprintRadiusMeters;

  /// Footprint area occupied on table surface in cm²
  double get footprintAreaCm2 => foodItem.footprintAreaCm2;

  /// Checks if this placed item's circular footprint intersects with another position and radius
  bool intersectsWith(
    vector.Vector3 testPosition,
    double testRadiusMeters, {
    double clearanceBufferMeters = 0.02, // 2cm clearance buffer for close dining placement
  }) {
    final dx = position.x - testPosition.x;
    final dz = position.z - testPosition.z;
    final distance = math.sqrt(dx * dx + dz * dz);
    final minSafeDistance = footprintRadiusMeters + testRadiusMeters - clearanceBufferMeters;
    return distance < minSafeDistance;
  }

  PlacedItem copyWith({
    String? id,
    FoodItem? foodItem,
    ARPlaneAnchor? anchor,
    ARNode? node,
    vector.Vector4? rotation,
    vector.Vector3? position,
    DateTime? placedAt,
  }) {
    return PlacedItem(
      id: id ?? this.id,
      foodItem: foodItem ?? this.foodItem,
      anchor: anchor ?? this.anchor,
      node: node ?? this.node,
      rotation: rotation ?? this.rotation,
      position: position ?? this.position,
      placedAt: placedAt ?? this.placedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacedItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
