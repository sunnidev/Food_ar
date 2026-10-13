import '../../domain/entities/food_item.dart';
import '../../domain/entities/real_world_size.dart';

/// Data model representing serialized food item with JSON serialization support.
class FoodItemModel extends FoodItem {
  const FoodItemModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.category,
    required super.thumbnailUrl,
    required super.modelUrl,
    super.modelUrlIos,
    required super.realWorldSizeCm,
    super.isAvailable,
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    return FoodItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Dish',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'General',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      modelUrl: json['modelUrl'] as String? ?? '',
      modelUrlIos: json['modelUrlIos'] as String?,
      realWorldSizeCm: json['realWorldSizeCm'] != null
          ? RealWorldSize.fromJson(json['realWorldSizeCm'] as Map<String, dynamic>)
          : const RealWorldSize(width: 15.0, depth: 15.0, height: 10.0),
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'thumbnailUrl': thumbnailUrl,
      'modelUrl': modelUrl,
      'modelUrlIos': modelUrlIos,
      'realWorldSizeCm': realWorldSizeCm.toJson(),
      'isAvailable': isAvailable,
    };
  }

  factory FoodItemModel.fromEntity(FoodItem entity) {
    return FoodItemModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      price: entity.price,
      category: entity.category,
      thumbnailUrl: entity.thumbnailUrl,
      modelUrl: entity.modelUrl,
      modelUrlIos: entity.modelUrlIos,
      realWorldSizeCm: entity.realWorldSizeCm,
      isAvailable: entity.isAvailable,
    );
  }
}
