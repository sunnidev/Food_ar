import '../entities/food_item.dart';

/// Abstract contract for fetching culinary dishes and ordering metadata.
abstract class FoodRepository {
  /// Fetches the full list of available food items.
  Future<List<FoodItem>> getFoods();

  /// Fetches a specific food item by its unique ID.
  Future<FoodItem?> getFoodById(String id);

  /// Fetches all unique menu categories.
  Future<List<String>> getCategories();

  /// Submits an order payload to the kitchen/backend.
  Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderPayload);
}
