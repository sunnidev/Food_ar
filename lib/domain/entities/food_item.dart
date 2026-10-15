import 'package:flutter/foundation.dart';
import 'real_world_size.dart';

/// Domain entity representing a culinary dish available in the AR food menu.
@immutable
class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String thumbnailUrl;
  final String modelUrl; // GLB 3D model URL
  final String? modelUrlIos; // USDZ 3D model URL for iOS Quick Look (optional)
  final RealWorldSize realWorldSizeCm;
  final bool isAvailable;
  final List<String> pairsWith; // IDs of complementary dishes/beverages
  final int version; // 3D model version for intelligent cache invalidation

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.thumbnailUrl,
    required this.modelUrl,
    this.modelUrlIos,
    required this.realWorldSizeCm,
    this.isAvailable = true,
    this.pairsWith = const [],
    this.version = 1,
  });

  /// Formatted price with dollar currency symbol
  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

  /// Model cache key combining ID and version
  String get modelCacheKey => 'model_${id}_v$version';

  /// Horizontal footprint area occupied on the table surface in cm²
  double get footprintAreaCm2 {
    return 3.141592653589793 * (realWorldSizeCm.width / 2.0) * (realWorldSizeCm.depth / 2.0);
  }

  /// Physical radial boundary in real-world meters for overlap and collision checks
  double get footprintRadiusMeters {
    final maxDim = realWorldSizeCm.width > realWorldSizeCm.depth
        ? realWorldSizeCm.width
        : realWorldSizeCm.depth;
    return (maxDim / 2.0) / 100.0;
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    String? thumbnailUrl,
    String? modelUrl,
    String? modelUrlIos,
    RealWorldSize? realWorldSizeCm,
    bool? isAvailable,
    List<String>? pairsWith,
    int? version,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      modelUrl: modelUrl ?? this.modelUrl,
      modelUrlIos: modelUrlIos ?? this.modelUrlIos,
      realWorldSizeCm: realWorldSizeCm ?? this.realWorldSizeCm,
      isAvailable: isAvailable ?? this.isAvailable,
      pairsWith: pairsWith ?? this.pairsWith,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          price == other.price &&
          category == other.category &&
          thumbnailUrl == other.thumbnailUrl &&
          modelUrl == other.modelUrl &&
          modelUrlIos == other.modelUrlIos &&
          realWorldSizeCm == other.realWorldSizeCm &&
          isAvailable == other.isAvailable &&
          listEquals(pairsWith, other.pairsWith) &&
          version == other.version;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      price.hashCode ^
      category.hashCode ^
      thumbnailUrl.hashCode ^
      modelUrl.hashCode ^
      modelUrlIos.hashCode ^
      realWorldSizeCm.hashCode ^
      isAvailable.hashCode ^
      version.hashCode ^
      Object.hashAll(pairsWith);

  @override
  String toString() => 'FoodItem(id: $id, name: $name, price: $price, version: $version)';
}
