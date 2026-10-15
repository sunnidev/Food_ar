import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/food_item.dart';
import '../../providers/ar_placement_provider.dart';

/// Horizontal dock displaying smart combo dish suggestions that pair well
/// with the currently active or selected dish.
class ArComboSuggestionsDock extends ConsumerWidget {
  const ArComboSuggestionsDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(comboSuggestionsProvider);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final activeDish = ref.watch(activeDishProvider);
    final selectedItem = ref.watch(selectedPlacedItemProvider);
    final currentTarget = selectedItem?.foodItem ?? activeDish;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161922).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentTarget != null
                      ? 'Chef Pairings for ${currentTarget.name}'
                      : 'Recommended Combos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Text(
                'Tap to place next',
                style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Pairings List
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                final isActive = activeDish?.id == suggestion.id;

                return _ComboItemChip(
                  food: suggestion,
                  isActive: isActive,
                  onTap: () {
                    ref.read(activeDishProvider.notifier).setActive(suggestion);
                    ref.read(arStatusMessageProvider.notifier).setMessage(
                          'Selected combo: ${suggestion.name}! Tap table to place.',
                        );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ComboItemChip extends StatelessWidget {
  final FoodItem food;
  final bool isActive;
  final VoidCallback onTap;

  const _ComboItemChip({
    required this.food,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF5722).withValues(alpha: 0.25)
              : const Color(0xFF222634),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFFF5722) : Colors.white12,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 38,
                height: 38,
                child: CachedNetworkImage(
                  imageUrl: food.thumbnailUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  food.name,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  '${food.formattedPrice} • + Add',
                  style: const TextStyle(
                    color: Color(0xFFFF7043),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
