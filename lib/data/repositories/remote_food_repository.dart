import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_repository.dart';
import '../models/food_item_model.dart';
import 'mock_food_repository.dart';

/// Concrete repository fetching live menu items and dispatching orders via Dio HTTP REST client.
/// Supports transparent automatic fallback to [MockFoodRepository] when the backend is unreachable or offline.
class RemoteFoodRepository implements FoodRepository {
  final Dio _dio;
  final FoodRepository _fallbackRepository;
  final bool enableFallback;

  RemoteFoodRepository({
    Dio? dio,
    String? baseUrl,
    FoodRepository? fallbackRepository,
    this.enableFallback = true,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? _resolveDefaultBaseUrl(),
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ),
        _fallbackRepository = fallbackRepository ?? MockFoodRepository() {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('🌐 [Dio] $obj'),
        ),
      );
    }
  }

  /// Automatically resolves suitable localhost host based on operating system
  static String _resolveDefaultBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:3000';
    if (Platform.isAndroid) {
      // 10.0.2.2 maps to host machine localhost on Android emulator
      return 'http://10.0.2.2:3000';
    }
    return 'http://127.0.0.1:3000';
  }

  @override
  Future<List<FoodItem>> getFoods() async {
    try {
      debugPrint('📡 [RemoteFoodRepository] Fetching GET /foods from ${_dio.options.baseUrl}...');
      final response = await _dio.get('/foods');

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data as List<dynamic>;
        final foods = data
            .map((item) => FoodItemModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return foods;
      }
      throw Exception('Unexpected response format: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ [RemoteFoodRepository] GET /foods failed ($e).');
      if (enableFallback) {
        debugPrint('🔄 [RemoteFoodRepository] Falling back to MockFoodRepository.');
        return _fallbackRepository.getFoods();
      }
      rethrow;
    }
  }

  @override
  Future<FoodItem?> getFoodById(String id) async {
    try {
      debugPrint('📡 [RemoteFoodRepository] Fetching GET /foods/$id...');
      final response = await _dio.get('/foods/$id');

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return FoodItemModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ [RemoteFoodRepository] GET /foods/$id failed ($e).');
      if (enableFallback) {
        return _fallbackRepository.getFoodById(id);
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      final foods = await getFoods();
      final categories = <String>{AppConstants.categoryAll};
      for (final item in foods) {
        categories.add(item.category);
      }
      return categories.toList();
    } catch (e) {
      if (enableFallback) {
        return _fallbackRepository.getCategories();
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderPayload) async {
    try {
      debugPrint('📡 [RemoteFoodRepository] Dispatching POST /orders...');
      final response = await _dio.post(
        '/orders',
        data: orderPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }
      }
      throw Exception('Server rejected order: ${response.statusCode}');
    } catch (e) {
      debugPrint('⚠️ [RemoteFoodRepository] POST /orders failed ($e).');
      if (enableFallback) {
        debugPrint('🔄 [RemoteFoodRepository] Submitting via offline mock fallback.');
        return _fallbackRepository.submitOrder(orderPayload);
      }
      rethrow;
    }
  }
}
