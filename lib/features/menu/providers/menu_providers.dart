import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/mock_food_repository.dart';
import '../../../data/repositories/remote_food_repository.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/repositories/food_repository.dart';

/// Notifier flag controlling whether mock repository is forced (e.g. offline/testing).
class UseMockApiNotifier extends Notifier<bool> {
  @override
  bool build() => false; // Default: use RemoteFoodRepository with Dio

  void setUseMock(bool value) => state = value;
  void toggle() => state = !state;
}

final useMockApiProvider = NotifierProvider<UseMockApiNotifier, bool>(
  UseMockApiNotifier.new,
);

/// Provider for the FoodRepository contract.
/// Dynamically supplies RemoteFoodRepository (with Dio) or MockFoodRepository based on flag.
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final forceMock = ref.watch(useMockApiProvider);
  if (forceMock) {
    return MockFoodRepository();
  }
  return RemoteFoodRepository();
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

/// Computed Provider returning unique list of food categories plus 'All'.
final categoriesProvider = Provider<List<String>>((ref) {
  final foodsAsync = ref.watch(foodListProvider);
  return foodsAsync.maybeWhen(
    data: (foods) {
      final list = <String>[AppConstants.categoryAll];
      for (final f in foods) {
        if (!list.contains(f.category)) {
          list.add(f.category);
        }
      }
      return list;
    },
    orElse: () => AppConstants.defaultCategories,
  );
});

/// Computed Provider filtering dishes based on selected category.
final filteredFoodsProvider = Provider<AsyncValue<List<FoodItem>>>((ref) {
  final foodsAsync = ref.watch(foodListProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return foodsAsync.whenData((foods) {
    if (selectedCategory == AppConstants.categoryAll) {
      return foods;
    }
    return foods.where((food) => food.category == selectedCategory).toList();
  });
});

