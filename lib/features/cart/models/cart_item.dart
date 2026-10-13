import 'package:flutter/foundation.dart';
import '../../../domain/entities/food_item.dart';

/// Item stored in the user's order cart.
@immutable
class CartItem {
  final FoodItem food;
  final int quantity;

  const CartItem({
    required this.food,
    this.quantity = 1,
  });

  double get totalPrice => food.price * quantity;

  CartItem copyWith({
    FoodItem? food,
    int? quantity,
  }) {
    return CartItem(
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          food.id == other.food.id &&
          quantity == other.quantity;

  @override
  int get hashCode => food.id.hashCode ^ quantity.hashCode;
}
