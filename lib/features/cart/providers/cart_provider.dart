import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/food_item.dart';
import '../models/cart_item.dart';

/// StateNotifier/Notifier managing cart items, quantities, and subtotal calculation.
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  void addItem(FoodItem food) {
    final index = state.indexWhere((item) => item.food.id == food.id);
    if (index >= 0) {
      final existing = state[index];
      final updatedList = List<CartItem>.from(state);
      updatedList[index] = existing.copyWith(quantity: existing.quantity + 1);
      state = updatedList;
    } else {
      state = [...state, CartItem(food: food, quantity: 1)];
    }
  }

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
