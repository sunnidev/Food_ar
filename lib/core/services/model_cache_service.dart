import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../domain/entities/food_item.dart';

/// Service managing persistent local caching of 3D GLB models with version-based invalidation.
/// Ensures 3D models are downloaded once and re-downloaded ONLY when the dish's version increments.
class ModelCacheService {
  final BaseCacheManager _cacheManager;

  ModelCacheService({BaseCacheManager? cacheManager})
      : _cacheManager = cacheManager ?? DefaultCacheManager();

  /// Retrieves the cached 3D model GLB file for [food].
  /// If the model at [food.version] is already cached locally, it returns the cached file instantly.
  /// If the model is not cached or its version was incremented, it downloads, caches, and returns the new file.
  Future<File> getModelFile(FoodItem food) async {
    final cacheKey = food.modelCacheKey;

    try {
      // 1. Check if the exact version exists in cache
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo != null && await fileInfo.file.exists()) {
        debugPrint('🎯 [ModelCache] Cache HIT for ${food.name} (Key: $cacheKey)');
        return fileInfo.file;
      }

      // 2. Cache MISS or version bumped: Download and store under the versioned cacheKey
      debugPrint('📥 [ModelCache] Cache MISS for ${food.name} (v${food.version}). Downloading GLB...');
      
      // Proactively clean previous versions if version was incremented
      if (food.version > 1) {
        for (int v = 1; v < food.version; v++) {
          final oldKey = 'model_${food.id}_v$v';
          await _cacheManager.removeFile(oldKey);
        }
      }

      final downloaded = await _cacheManager.downloadFile(
        food.modelUrl,
        key: cacheKey,
      );

      debugPrint('✅ [ModelCache] Downloaded and cached ${food.name} at ${downloaded.file.path}');
      return downloaded.file;
    } catch (e) {
      debugPrint('⚠️ [ModelCache] Caching error for ${food.name}: $e');
      // Graceful fallback to standard URL download if custom key download fails
      final fallback = await _cacheManager.getSingleFile(food.modelUrl);
      return fallback;
    }
  }

  /// Checks whether the model for [food] at its current version is cached locally.
  Future<bool> isModelCached(FoodItem food) async {
    final fileInfo = await _cacheManager.getFileFromCache(food.modelCacheKey);
    return fileInfo != null && await fileInfo.file.exists();
  }

  /// Evicts all cached 3D models.
  Future<void> clearAll() async {
    await _cacheManager.emptyCache();
  }
}

/// Global singleton instance of ModelCacheService
final ModelCacheService modelCacheService = ModelCacheService();
