import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ar_placement_provider.dart';

/// Floating guidance overlay informing the user to scan the surface or tap to place dishes.
class ArGuidanceOverlay extends ConsumerWidget {
  const ArGuidanceOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaneDetected = ref.watch(isPlaneDetectedProvider);
    final count = ref.watch(totalPlacedCountProvider);
    final isDownloading = ref.watch(isDownloadingModelProvider);
    final activeDish = ref.watch(activeDishProvider);
    final isTableFull = ref.watch(isTableFullProvider);

    // Initial state: Table not yet detected
    if (!isPlaneDetected) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 70,
        left: 24,
        right: 24,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.screen_rotation_outlined,
                  color: Color(0xFFFFB300),
                  size: 20,
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Move your phone slowly to detect your table',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // When plane is detected, but no dishes placed yet or table is full or downloading
    if (isDownloading) return const SizedBox.shrink();

    if (isTableFull) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 70,
        left: 24,
        right: 24,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Table is full (10 dishes maximum)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (count == 0 && activeDish != null) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 70,
        left: 24,
        right: 24,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap on the table to place ${activeDish.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
