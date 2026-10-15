import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/food_item.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../providers/ar_placement_provider.dart';
import '../controllers/ar_screen_controller.dart';

/// Floating card that appears when a 3D dish on the table is tapped & selected.
/// Provides visual highlighting, dish dimensions, a trash button to delete it,
/// and an Add to Cart shortcut.
class ArSelectedItemBar extends ConsumerWidget {
  final ArScreenController controller;

  const ArSelectedItemBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedItem = ref.watch(selectedPlacedItemProvider);

    if (selectedItem == null) return const SizedBox.shrink();

    final FoodItem food = selectedItem.foodItem;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151822).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF5722).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dish Thumbnail with glowing selected badge
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: CachedNetworkImage(
                imageUrl: food.thumbnailUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Dish Info & Interaction Hint
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5722),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'SELECTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${food.formattedPrice} • 1:1 scale (${food.realWorldSizeCm.width}cm)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Drag to reposition • 2 fingers to rotate',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Quick Add to Cart
          IconButton(
            tooltip: 'Add to Cart',
            icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
            onPressed: () {
              ref.read(cartProvider.notifier).addItem(food);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${food.name} to cart!'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // Trash Button to Delete Selected Dish
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Delete from Table',
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252)),
              onPressed: controller.deleteSelected,
            ),
          ),

          // Deselect button
          IconButton(
            tooltip: 'Deselect',
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            onPressed: () {
              ref.read(selectedItemIdProvider.notifier).deselect();
            },
          ),
        ],
      ),
    );
  }
}
