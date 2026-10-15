import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_repository.dart';
import '../models/food_item_model.dart';

/// Concrete repository implementation loading local mock data from assets/foods.json
/// and simulating order placements offline or during testing.
class MockFoodRepository implements FoodRepository {
  final String assetPath;
  List<FoodItem>? _cachedFoods;

  MockFoodRepository({this.assetPath = AppConstants.foodsJsonPath});

  @override
  Future<List<FoodItem>> getFoods() async {
    // Simulate brief network latency for realistic UX feel and pull-to-refresh feedback
    await Future.delayed(const Duration(milliseconds: 400));

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

  @override
  Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderPayload) async {
    // Simulate kitchen dispatch latency
    await Future.delayed(const Duration(milliseconds: 650));

    final timestamp = DateTime.now();
    final orderId = 'ORD-${timestamp.millisecondsSinceEpoch.toString().substring(7)}';

    return {
      'success': true,
      'orderId': orderId,
      'status': 'received',
      'mode': 'offline_mock',
      'createdAt': timestamp.toIso8601String(),
      'estimatedPrepMinutes': 18,
      ...orderPayload,
    };
  }
}
