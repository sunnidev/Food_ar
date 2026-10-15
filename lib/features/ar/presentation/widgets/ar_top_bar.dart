import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/ar_placement_provider.dart';
import '../controllers/ar_screen_controller.dart';
import 'ar_counter_chip.dart';

/// Top bar containing the exit button, live table detection indicator,
/// counter chip (dish count & total price), snapshot & share button, and "Undo last" / "Clear all" actions.
class ArTopBar extends ConsumerWidget {
  final ArScreenController controller;
  final GlobalKey? boundaryKey;

  const ArTopBar({
    super.key,
    required this.controller,
    this.boundaryKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaneDetected = ref.watch(isPlaneDetectedProvider);
    final count = ref.watch(totalPlacedCountProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Exit Button
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                onPressed: () => context.pop(),
                tooltip: 'Exit AR Mode',
              ),
            ),
            const SizedBox(width: 4),

            // Table Detection Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPlaneDetected ? const Color(0xFF10B981) : const Color(0xFFFFB300),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPlaneDetected ? Icons.check_circle : Icons.table_restaurant_outlined,
                    size: 11,
                    color: isPlaneDetected ? const Color(0xFF10B981) : const Color(0xFFFFB300),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isPlaneDetected ? 'Table' : 'Scan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Dishes & Price Counter Chip
            const ArCounterChip(),
            const SizedBox(width: 4),

            // Capture Screenshot & Share Button
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722).withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                onPressed: () => controller.captureAndShareScreenshot(boundaryKey: boundaryKey),
                tooltip: 'Capture & Share AR View',
              ),
            ),
            const SizedBox(width: 4),

            // Undo Last Button (only when dishes placed)
            if (count > 0) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.undo_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  onPressed: controller.undoLast,
                  tooltip: 'Undo last dish',
                ),
              ),
              const SizedBox(width: 4),

              // Clear All Button
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Color(0xFFFF5252),
                    size: 17,
                  ),
                  onPressed: () => _showClearConfirmation(context, controller),
                  tooltip: 'Clear all dishes',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, ArScreenController controller) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212B),
        title: const Text(
          'Clear all dishes?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will remove all 3D food items currently placed on your table.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              controller.clearAll();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
