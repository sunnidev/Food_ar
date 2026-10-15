import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/entities/food_item.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../menu/providers/menu_providers.dart';
import '../../providers/ar_placement_provider.dart';

/// Bottom dock featuring a horizontal food picker and bulk "Order these N dishes" action.
class ArFoodPickerSheet extends ConsumerWidget {
  const ArFoodPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(foodListProvider);
    final activeDish = ref.watch(activeDishProvider);
    final placedItems = ref.watch(placedItemsProvider);
    final isTableFull = ref.watch(isTableFullProvider);
    final totalPlacedPrice = ref.watch(totalPlacedPriceProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141720).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          size: 16,
                          color: Color(0xFFFF5722),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isTableFull
                                ? 'Table capacity reached (10/10)'
                                : (activeDish != null
                                    ? 'Tap table: ${activeDish.name}'
                                    : 'Select dish to place on table'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isTableFull ? Colors.amberAccent : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${placedItems.length}/$kMaxPlacedDishes placed',
                    style: TextStyle(
                      color: isTableFull ? Colors.amberAccent : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // "Order these N dishes" action button (converts placed AR dishes to cart)
              if (placedItems.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      ref.read(cartProvider.notifier).addItemsFromPlacedDishes(placedItems);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Added ${placedItems.length} table dish${placedItems.length == 1 ? "" : "es"} to your cart!',
                          ),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'View Cart',
                            textColor: Colors.white,
                            onPressed: () => context.push('/cart'),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: Text(
                      'Order these ${placedItems.length} dishes • \$${totalPlacedPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Horizontal Food Items Carousel
              foodsAsync.when(
                data: (foods) {
                  if (foods.isEmpty) {
                    return const SizedBox(
                      height: 80,
                      child: Center(
                        child: Text(
                          'No dishes found',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  }

                  // Auto-select first food if none is active
                  if (activeDish == null && foods.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(activeDishProvider.notifier).setActive(foods.first);
                    });
                  }

                  return SizedBox(
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: foods.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final food = foods[index];
                        final isSelected = activeDish?.id == food.id;
                        final countPlaced = placedItems
                            .where((item) => item.foodItem.id == food.id)
                            .length;

                        return _FoodPickerItemCard(
                          food: food,
                          isSelected: isSelected,
                          countPlaced: countPlaced,
                          onTap: () {
                            ref.read(activeDishProvider.notifier).setActive(food);
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 86,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF5722),
                    ),
                  ),
                ),
                error: (err, _) => SizedBox(
                  height: 86,
                  child: Center(
                    child: Text(
                      'Failed to load dishes',
                      style: TextStyle(color: Colors.red[300], fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodPickerItemCard extends StatelessWidget {
  final FoodItem food;
  final bool isSelected;
  final int countPlaced;
  final VoidCallback onTap;

  const _FoodPickerItemCard({
    required this.food,
    required this.isSelected,
    required this.countPlaced,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 170,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF232938)
              : const Color(0xFF1B1E28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF5722)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Thumbnail with quantity badge if placed on table
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CachedNetworkImage(
                      imageUrl: food.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (countPlaced > 0)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$countPlaced',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),

            // Name & Price
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    food.formattedPrice,
                    style: const TextStyle(
                      color: Color(0xFFFF7043),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${food.realWorldSizeCm.width} cm (v${food.version})',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
