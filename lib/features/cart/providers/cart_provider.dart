import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/food_item.dart';
import '../../ar/domain/entities/placed_item.dart';
import '../../menu/providers/menu_providers.dart';
import '../models/cart_item.dart';

/// State notifier managing the cart items, quantities, and bulk additions from AR.
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  /// Adds a single dish or increments quantity
  void addItem(FoodItem food, {int quantity = 1}) {
    if (quantity <= 0) return;
    final index = state.indexWhere((item) => item.food.id == food.id);
    if (index >= 0) {
      final existing = state[index];
      final updatedList = List<CartItem>.from(state);
      updatedList[index] = existing.copyWith(quantity: existing.quantity + quantity);
      state = updatedList;
    } else {
      state = [...state, CartItem(food: food, quantity: quantity)];
    }
  }

  /// Converts all dishes placed on the AR table into cart items with consolidated quantities.
  /// Example: 2 Margherita Pizzas and 1 Burger placed in AR -> adds quantity 2 for Pizza and 1 for Burger.
  void addItemsFromPlacedDishes(List<PlacedItem> placedItems) {
    if (placedItems.isEmpty) return;

    // Group placed dishes by food ID
    final Map<String, int> counts = {};
    final Map<String, FoodItem> foodMap = {};

    for (final item in placedItems) {
      counts[item.foodItem.id] = (counts[item.foodItem.id] ?? 0) + 1;
      foodMap[item.foodItem.id] = item.foodItem;
    }

    final updatedList = List<CartItem>.from(state);

    counts.forEach((foodId, quantity) {
      final food = foodMap[foodId]!;
      final existingIndex = updatedList.indexWhere((item) => item.food.id == foodId);
      if (existingIndex >= 0) {
        final existing = updatedList[existingIndex];
        updatedList[existingIndex] = existing.copyWith(
          quantity: existing.quantity + quantity,
        );
      } else {
        updatedList.add(CartItem(food: food, quantity: quantity));
      }
    });

    state = updatedList;
  }

  /// Sets absolute quantity for an item
  void updateQuantity(String foodId, int newQuantity) {
    final index = state.indexWhere((item) => item.food.id == foodId);
    if (index >= 0) {
      final updatedList = List<CartItem>.from(state);
      if (newQuantity > 0) {
        updatedList[index] = updatedList[index].copyWith(quantity: newQuantity);
      } else {
        updatedList.removeAt(index);
      }
      state = updatedList;
    }
  }

  /// Decrements quantity or removes if quantity reaches 0
  void removeItem(String foodId) {
    final index = state.indexWhere((item) => item.food.id == foodId);
    if (index >= 0) {
      final existing = state[index];
      final updatedList = List<CartItem>.from(state);
      if (existing.quantity > 1) {
        updatedList[index] = existing.copyWith(quantity: existing.quantity - 1);
      } else {
        updatedList.removeAt(index);
      }
      state = updatedList;
    }
  }

  /// Removes an item completely regardless of quantity
  void deleteItem(String foodId) {
    state = state.where((item) => item.food.id != foodId).toList();
  }

  /// Empties all items from the cart
  void clearCart() {
    state = const [];
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

final cartTotalCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

final cartTotalPriceProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
});

// =============================================================================
// Order Placement State Management
// =============================================================================

/// Notifier handling kitchen order dispatch lifecycle via Dio POST /orders
class OrderPlacementNotifier extends Notifier<AsyncValue<Map<String, dynamic>?>> {
  @override
  AsyncValue<Map<String, dynamic>?> build() => const AsyncData(null);

  Future<Map<String, dynamic>?> placeOrder({
    required int tableNumber,
    String? specialInstructions,
  }) async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return null;

    final subtotal = ref.read(cartTotalPriceProvider);
    final tax = subtotal * 0.0825;
    final total = subtotal + tax;

    state = const AsyncLoading();

    try {
      final payload = {
        'tableNumber': tableNumber,
        'items': cartItems
            .map((c) => {
                  'foodId': c.food.id,
                  'name': c.food.name,
                  'price': c.food.price,
                  'quantity': c.quantity,
                  'total': c.totalPrice,
                })
            .toList(),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'specialInstructions': specialInstructions ?? '',
      };

      final repository = ref.read(foodRepositoryProvider);
      final result = await repository.submitOrder(payload);

      // Clear cart upon successful order submission
      ref.read(cartProvider.notifier).clearCart();
      state = AsyncData(result);
      return result;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final orderPlacementProvider =
    NotifierProvider<OrderPlacementNotifier, AsyncValue<Map<String, dynamic>?>>(
  OrderPlacementNotifier.new,
);
