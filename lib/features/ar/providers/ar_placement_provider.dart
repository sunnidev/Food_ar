import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../../domain/entities/food_item.dart';
import '../../menu/providers/menu_providers.dart';
import '../domain/entities/placed_item.dart';

/// Maximum dishes allowed simultaneously in the AR scene to guarantee 60 FPS performance.
const int kMaxPlacedDishes = 10;

/// Base dining table area per detected horizontal plane surface (cm²).
/// 8,000 cm² corresponds to an average 4-person restaurant dining table (~90cm x 90cm).
const double kBasePlaneAreaCm2 = 8000.0;

/// State notifier managing the list of dishes placed on the AR table surface.
class PlacedItemsNotifier extends Notifier<List<PlacedItem>> {
  @override
  List<PlacedItem> build() => const [];

  /// Returns true if another dish can be placed without exceeding the 10-item limit.
  bool get canAddMore => state.length < kMaxPlacedDishes;

  /// Attempts to add a new placed item. Returns true if successful, false if limit reached.
  bool addItem(PlacedItem item) {
    if (state.length >= kMaxPlacedDishes) {
      return false;
    }
    state = [...state, item];
    return true;
  }

  /// Checks if placing a dish at [testPosition] would overlap with any existing dish.
  /// Returns the colliding [PlacedItem] if collision found, or null if clear.
  PlacedItem? checkCollision(vector.Vector3 testPosition, FoodItem candidateFood) {
    final candidateRadius = candidateFood.footprintRadiusMeters;
    for (final existing in state) {
      if (existing.intersectsWith(testPosition, candidateRadius)) {
        return existing;
      }
    }
    return null;
  }

  /// Removes and returns the most recently placed item for the "Undo last" action.
  PlacedItem? removeLast() {
    if (state.isEmpty) return null;
    final last = state.last;
    state = state.sublist(0, state.length - 1);
    return last;
  }

  /// Removes a specific placed item by its unique ID.
  PlacedItem? removeById(String id) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) return null;
    final item = state[index];
    final updated = List<PlacedItem>.from(state)..removeAt(index);
    state = updated;
    return item;
  }

  /// Removes an item associated with the ARNode name or item ID.
  PlacedItem? removeByNodeName(String nodeName) {
    final index = state.indexWhere((item) => item.node?.name == nodeName || item.id == nodeName);
    if (index == -1) return null;
    final item = state[index];
    final updated = List<PlacedItem>.from(state)..removeAt(index);
    state = updated;
    return item;
  }

  /// Updates the physical position and rotation of a moved or rotated node.
  void updateItemTransform({
    required String nodeName,
    required vector.Vector3 position,
    required vector.Vector4 rotation,
  }) {
    final index = state.indexWhere((item) => item.node?.name == nodeName || item.id == nodeName);
    if (index != -1) {
      final updated = List<PlacedItem>.from(state);
      updated[index] = updated[index].copyWith(
        position: position,
        rotation: rotation,
      );
      state = updated;
    }
  }

  /// Clears all placed items and returns the removed list.
  List<PlacedItem> clearAll() {
    final current = List<PlacedItem>.from(state);
    state = const [];
    return current;
  }
}

/// Provider for placed dishes in the AR session.
final placedItemsProvider =
    NotifierProvider<PlacedItemsNotifier, List<PlacedItem>>(
  PlacedItemsNotifier.new,
);

/// Notifier tracking the ID of the currently selected/highlighted placed dish.
class SelectedItemIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
  void deselect() => state = null;
  void toggle(String id) => state = (state == id) ? null : id;
}

final selectedItemIdProvider =
    NotifierProvider<SelectedItemIdNotifier, String?>(
  SelectedItemIdNotifier.new,
);

/// Notifier tracking the active dish selected in the bottom horizontal picker for subsequent taps.
class ActiveDishNotifier extends Notifier<FoodItem?> {
  @override
  FoodItem? build() => null;

  void setActive(FoodItem food) => state = food;
  void clear() => state = null;
}

final activeDishProvider = NotifierProvider<ActiveDishNotifier, FoodItem?>(
  ActiveDishNotifier.new,
);

/// Notifier tracking horizontal plane detection status and count of detected plane surfaces.
class DetectedPlanesCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void updateCount(int count) => state = count;
  void reset() => state = 0;
}

final detectedPlanesCountProvider =
    NotifierProvider<DetectedPlanesCountNotifier, int>(
  DetectedPlanesCountNotifier.new,
);

final isPlaneDetectedProvider = Provider<bool>((ref) {
  return ref.watch(detectedPlanesCountProvider) > 0;
});

/// Notifier tracking 3D model downloading/caching state.
class DownloadingModelNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setDownloading(bool downloading) => state = downloading;
}

final isDownloadingModelProvider =
    NotifierProvider<DownloadingModelNotifier, bool>(
  DownloadingModelNotifier.new,
);

/// Notifier tracking status & hint messages for the AR overlay.
class ArStatusMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? message) => state = message;
  void clear() => state = null;
}

final arStatusMessageProvider =
    NotifierProvider<ArStatusMessageNotifier, String?>(
  ArStatusMessageNotifier.new,
);

/// Computed Provider: Total count of placed dishes.
final totalPlacedCountProvider = Provider<int>((ref) {
  return ref.watch(placedItemsProvider).length;
});

/// Computed Provider: Total price of all placed dishes.
final totalPlacedPriceProvider = Provider<double>((ref) {
  final items = ref.watch(placedItemsProvider);
  return items.fold(0.0, (sum, item) => sum + item.foodItem.price);
});

/// Computed Provider: Whether the table reached the 10-dish capacity limit.
final isTableFullProvider = Provider<bool>((ref) {
  return ref.watch(placedItemsProvider).length >= kMaxPlacedDishes;
});

/// Computed Provider: Resolves the currently selected PlacedItem object.
final selectedPlacedItemProvider = Provider<PlacedItem?>((ref) {
  final selectedId = ref.watch(selectedItemIdProvider);
  if (selectedId == null) return null;
  final items = ref.watch(placedItemsProvider);
  try {
    return items.firstWhere((item) => item.id == selectedId);
  } catch (_) {
    return null;
  }
});

// =============================================================================
// Smart Features: Table Fit & Used Surface Area Analytics
// =============================================================================

/// Estimated total usable surface area of the detected dining table in cm².
final availableTableAreaCm2Provider = Provider<double>((ref) {
  final planeCount = ref.watch(detectedPlanesCountProvider);
  if (planeCount <= 0) return kBasePlaneAreaCm2;
  // Each additional recognized plane segment expands available table area
  final dynamicArea = kBasePlaneAreaCm2 + ((planeCount - 1) * 3500.0);
  return dynamicArea.clamp(kBasePlaneAreaCm2, 22000.0);
});

/// Cumulative surface area currently occupied by placed dishes on the table in cm².
final usedTableAreaCm2Provider = Provider<double>((ref) {
  final items = ref.watch(placedItemsProvider);
  return items.fold(0.0, (sum, item) => sum + item.footprintAreaCm2);
});

/// Used table area percentage (0% - 100%).
final tableCapacityPercentageProvider = Provider<int>((ref) {
  final used = ref.watch(usedTableAreaCm2Provider);
  final available = ref.watch(availableTableAreaCm2Provider);
  if (available <= 0) return 0;
  return ((used / available) * 100.0).clamp(0.0, 100.0).round();
});

/// Helper checking if the candidate dish fits in the remaining table area.
final candidateDishFitsProvider = Provider.family<bool, FoodItem>((ref, candidate) {
  final used = ref.watch(usedTableAreaCm2Provider);
  final available = ref.watch(availableTableAreaCm2Provider);
  return (used + candidate.footprintAreaCm2) <= (available * 1.05); // 5% reasonable tolerance
});

// =============================================================================
// Smart Features: Combo Suggestions
// =============================================================================

/// Resolves recommended complementary dishes that pair with the currently active or selected dish.
final comboSuggestionsProvider = Provider<List<FoodItem>>((ref) {
  final selectedItem = ref.watch(selectedPlacedItemProvider);
  final activeDish = ref.watch(activeDishProvider);
  final targetDish = selectedItem?.foodItem ?? activeDish;

  if (targetDish == null || targetDish.pairsWith.isEmpty) {
    return const [];
  }

  final allFoods = ref.watch(foodListProvider).asData?.value ?? [];
  return allFoods.where((f) => targetDish.pairsWith.contains(f.id)).toList();
});
