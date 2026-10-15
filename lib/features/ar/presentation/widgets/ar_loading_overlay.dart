import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ar_placement_provider.dart';

/// Progress overlay shown during GLB 3D model downloading and cache verification.
class ArLoadingOverlay extends ConsumerWidget {
  const ArLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloading = ref.watch(isDownloadingModelProvider);
    final activeDish = ref.watch(activeDishProvider);

    if (!isDownloading) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E28),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: Color(0xFFFF5722),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  activeDish != null
                      ? 'Downloading ${activeDish.name}'
                      : 'Preparing 3D Food Model',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Calibrating real-scale GLB via cache...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
