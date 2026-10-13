import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../providers/menu_providers.dart';

/// Empty state display shown when no dishes match selected category filters.
class EmptyFoodsView extends ConsumerWidget {
  const EmptyFoodsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222632) : const Color(0xFFF1EBE3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.no_meals_outlined,
                size: 52,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No items in "$selectedCategory"',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not find any dishes in this category. Try selecting another category or view all dishes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () {
                ref
                    .read(selectedCategoryProvider.notifier)
                    .selectCategory(AppConstants.categoryAll);
              },
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Show All Dishes'),
            ),
          ],
        ),
      ),
    );
  }
}
