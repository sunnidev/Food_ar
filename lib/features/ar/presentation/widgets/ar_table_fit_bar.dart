import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ar_placement_provider.dart';

/// Floating visual meter displaying table surface capacity ("Table 62% full"),
/// used vs available surface area, and environmental HDR soft-shadow status.
class ArTableFitBar extends ConsumerWidget {
  const ArTableFitBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaneDetected = ref.watch(isPlaneDetectedProvider);
    if (!isPlaneDetected) return const SizedBox.shrink();

    final percent = ref.watch(tableCapacityPercentageProvider);
    final count = ref.watch(totalPlacedCountProvider);
    final usedArea = ref.watch(usedTableAreaCm2Provider);
    final availableArea = ref.watch(availableTableAreaCm2Provider);

    // Color gradient based on utilization
    final Color barColor = percent >= 85
        ? const Color(0xFFEF4444) // Red alert
        : percent >= 60
            ? const Color(0xFFF59E0B) // Amber warning
            : const Color(0xFF10B981); // Emerald safe

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13161F).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: barColor.withValues(alpha: 0.4),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Table capacity label
              Row(
                children: [
                  Icon(
                    Icons.table_restaurant_rounded,
                    size: 14,
                    color: barColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Table $percent% full',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: barColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (percent >= 85) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEAR CAPACITY',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Soft shadows & HDR lighting status indicator
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'HDR Shadows',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Horizontal progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),

          // Surface dimensions summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count dish${count == 1 ? "" : "es"} occupying ${(usedArea / 100).toStringAsFixed(0)} dm²',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              Text(
                'Total table surface: ${(availableArea / 100).toStringAsFixed(0)} dm²',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
