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
  });

  /// Formatted price with dollar currency symbol
  String get formattedPrice => '\$${price.toStringAsFixed(2)}';

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
          isAvailable == other.isAvailable;

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
      isAvailable.hashCode;

  @override
  String toString() => 'FoodItem(id: $id, name: $name, price: $price, category: $category)';
}
