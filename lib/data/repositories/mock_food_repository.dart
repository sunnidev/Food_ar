import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_repository.dart';
import '../models/food_item_model.dart';

/// Concrete repository implementation loading local mock data from assets/foods.json.
class MockFoodRepository implements FoodRepository {
  final String assetPath;
  List<FoodItem>? _cachedFoods;

  MockFoodRepository({this.assetPath = AppConstants.foodsJsonPath});

  @override
  Future<List<FoodItem>> getFoods() async {
    // Simulate brief network latency for realistic UX feel and pull-to-refresh feedback
    await Future.delayed(const Duration(milliseconds: 550));

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

      final foods = jsonList
          .map((item) => FoodItemModel.fromJson(item as Map<String, dynamic>))
          .toList();

      _cachedFoods = foods;
      return foods;
    } catch (e) {
      throw Exception('Failed to load foods from asset $assetPath: $e');
    }
  }

  @override
  Future<FoodItem?> getFoodById(String id) async {
    final list = _cachedFoods ?? await getFoods();
    try {
      return list.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> getCategories() async {
    final list = _cachedFoods ?? await getFoods();
    final uniqueCategories = <String>{AppConstants.categoryAll};
    for (final item in list) {
      uniqueCategories.add(item.category);
    }
    return uniqueCategories.toList();
  }
}
