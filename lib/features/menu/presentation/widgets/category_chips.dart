import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/menu_providers.dart';

/// Horizontal scrollable selector for filtering dishes by category.
class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.toLowerCase() == selectedCategory.toLowerCase();

          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                ref
                    .read(selectedCategoryProvider.notifier)
                    .selectCategory(category);
              }
            },
            showCheckmark: false,
            elevation: isSelected ? 2 : 0,
            pressElevation: 1,
            labelStyle: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
            backgroundColor: isDark
                ? const Color(0xFF1E222B)
                : const Color(0xFFF1EDE6),
            selectedColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? const Color(0xFF2C323F) : const Color(0xFFE4DDD4)),
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}
