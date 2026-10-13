import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/mock_food_repository.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/repositories/food_repository.dart';

/// Provider for the FoodRepository contract.
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return MockFoodRepository();
});

/// AsyncNotifier managing the full food items dataset and refresh lifecycle.
class FoodListNotifier extends AsyncNotifier<List<FoodItem>> {
  @override
  Future<List<FoodItem>> build() async {
    final repository = ref.watch(foodRepositoryProvider);
    return repository.getFoods();
  }

  /// Manually triggers a reload for pull-to-refresh interactions.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(foodRepositoryProvider);
      return repository.getFoods();
    });
  }
}

/// Provider for the async food list state.
final foodListProvider =
    AsyncNotifierProvider<FoodListNotifier, List<FoodItem>>(
  FoodListNotifier.new,
);

/// Notifier tracking the currently selected category filter chip.
class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => AppConstants.categoryAll;

  void selectCategory(String category) {
    state = category;
  }
}

/// Provider for the selected category filter.
final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String>(
  SelectedCategoryNotifier.new,
);

/// Computed Provider filtering dishes based on selected category.
final filteredFoodsProvider = Provider<AsyncValue<List<FoodItem>>>((ref) {
  final foodsAsync = ref.watch(foodListProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return foodsAsync.whenData((foods) {
    if (selectedCategory == AppConstants.categoryAll) {
      return foods;
    }
    return foods
        .where((item) =>
            item.category.trim().toLowerCase() ==
            selectedCategory.trim().toLowerCase())
        .toList();
  });
});

/// Computes the unique categories available based on actual loaded items.
final categoriesProvider = Provider<List<String>>((ref) {
  final foodsAsync = ref.watch(foodListProvider);
  return foodsAsync.maybeWhen(
    data: (foods) {
      final categories = <String>{AppConstants.categoryAll};
      for (final f in foods) {
        categories.add(f.category);
      }
      return categories.toList();
    },
    orElse: () => AppConstants.defaultCategories,
  );
});
