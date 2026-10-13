import '../entities/food_item.dart';

/// Abstract contract for fetching culinary dishes and metadata.
abstract class FoodRepository {
  /// Fetches the full list of available food items.
  Future<List<FoodItem>> getFoods();

  /// Fetches a specific food item by its unique ID.
  Future<FoodItem?> getFoodById(String id);

  /// Fetches all unique menu categories.
  Future<List<String>> getCategories();
}
