import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ar_placement_provider.dart';

/// Counter chip displaying the live count of placed dishes and the cumulative total price.
class ArCounterChip extends ConsumerWidget {
  const ArCounterChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(totalPlacedCountProvider);
    final totalPrice = ref.watch(totalPlacedPriceProvider);
    final isFull = ref.watch(isTableFullProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFull
              ? Colors.amberAccent
              : (count > 0 ? const Color(0xFFFF5722) : Colors.white.withValues(alpha: 0.2)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: 14,
            color: count > 0 ? const Color(0xFFFF5722) : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            '$count dish${count == 1 ? '' : 'es'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 3.5,
            height: 3.5,
            decoration: const BoxDecoration(
              color: Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '\$${totalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              color: count > 0 ? const Color(0xFFFF7043) : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
