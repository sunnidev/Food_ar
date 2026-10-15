import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../cart/providers/cart_provider.dart';
import '../providers/menu_providers.dart';
import 'widgets/category_chips.dart';
import 'widgets/empty_foods_view.dart';
import 'widgets/food_card.dart';

/// Main screen showcasing culinary dishes, category filtering, and direct AR preview.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredFoodsAsync = ref.watch(filteredFoodsProvider);
    final totalCartItems = ref.watch(cartTotalCountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AR READY',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              AppConstants.appTagline,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Cart Navigation Button with item badge
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () => context.push('/cart'),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 26),
                  tooltip: 'View Cart',
                ),
                if (totalCartItems > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF101216) : Colors.white,
                          width: 2,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$totalCartItems',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Horizontal Category Filter Chips
          const CategoryChips(),
          const SizedBox(height: 12),

          // Main Content: Pull-to-refresh with 2-Column Grid or States
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(foodListProvider.notifier).refresh();
              },
              color: theme.colorScheme.primary,
              child: filteredFoodsAsync.when(
                loading: () => const LoadingView(
                  message: 'Loading 3D AR menu...',
                ),
                error: (error, _) => ErrorView(
                  title: 'Could Not Load Menu',
                  message: error.toString(),
                  onRetry: () =>
                      ref.read(foodListProvider.notifier).refresh(),
                ),
                data: (foods) {
                  if (foods.isEmpty) {
                    return const SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 400,
                        child: EmptyFoodsView(),
                      ),
                    );
                  }

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.63,
                    ),
                    itemCount: foods.length,
                    itemBuilder: (context, index) {
                      return FoodCard(food: foods[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
