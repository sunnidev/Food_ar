import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../domain/entities/food_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../providers/menu_providers.dart';

/// Detailed view for a single dish featuring interactive 3D ModelViewer,
/// real-world scale breakdown, AR device compatibility banner,
/// and dish ordering actions.
class FoodDetailScreen extends ConsumerStatefulWidget {
  final String foodId;
  final FoodItem? initialFood;

  const FoodDetailScreen({
    super.key,
    required this.foodId,
    this.initialFood,
  });

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  int _retryKey = 0;
  bool _hasModelError = false;
  bool _isModelLoading = true;
  int _orderQuantity = 1;

  void _retryModelLoading() {
    setState(() {
      _hasModelError = false;
      _isModelLoading = true;
      _retryKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalCartItems = ref.watch(cartTotalCountProvider);

    // Resolve food item from initial parameter or AsyncNotifier list
    final foodsAsync = ref.watch(foodListProvider);
    final FoodItem? food = widget.initialFood ??
        foodsAsync.asData?.value.cast<FoodItem?>().firstWhere(
              (item) => item?.id == widget.foodId,
              orElse: () => null,
            );

    if (food == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dish Details')),
        body: const Center(
          child: Text('Dish details could not be loaded.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFFBF9F6),
      appBar: AppBar(
        title: Text(
          food.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // Cart Navigation Icon
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () => context.push('/cart'),
                  icon: const Icon(Icons.shopping_bag_outlined),
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
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // Top Section: 3D ModelViewer with Fallback & Hero Image
            // =================================================================
            SizedBox(
              height: 380,
              width: double.infinity,
              child: Stack(
                children: [
                  // 3D Model Canvas or Fallback Image
                  if (!_hasModelError)
                    Positioned.fill(
                      child: Container(
                        color: isDark ? const Color(0xFF161922) : const Color(0xFFF4EEE6),
                        child: ModelViewer(
                          key: ValueKey('model_viewer_${food.id}_$_retryKey'),
                          backgroundColor:
                              isDark ? const Color(0xFF161922) : const Color(0xFFF4EEE6),
                          src: food.modelUrl,
                          iosSrc: food.modelUrlIos,
                          alt: '3D real-scale model of ${food.name}',
                          ar: true,
                          arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                          arScale: ArScale.fixed,
                          arPlacement: ArPlacement.floor,
                          autoRotate: true,
                          autoRotateDelay: 1200,
                          cameraControls: true,
                          shadowIntensity: 1.0,
                          shadowSoftness: 0.8,
                          exposure: 1.0,
                          loading: Loading.eager,
                          onWebViewCreated: (_) {
                            // Delay dismissal of loading indicator for smooth transition
                            Future.delayed(const Duration(milliseconds: 1400), () {
                              if (mounted) {
                                setState(() => _isModelLoading = false);
                              }
                            });
                          },
                        ),
                      ),
                    )
                  else
                    // Fallback Image with Hero transition if 3D model failed to load
                    Positioned.fill(
                      child: Container(
                        color: isDark ? const Color(0xFF161922) : const Color(0xFFF4EEE6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'food_thumbnail_${food.id}',
                              child: CachedNetworkImage(
                                imageUrl: food.thumbnailUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.55),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFFFB300),
                                    size: 44,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '3D Model Failed to Load',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Please verify your internet connection or check if GLB asset is accessible.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _retryModelLoading,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Retry Loading 3D'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Initial Loading Spinner while 3D view renders
                  if (_isModelLoading && !_hasModelError)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: isDark ? const Color(0xFF161922) : const Color(0xFFF4EEE6),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Loading 3D asset...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating 3D / AR Controls Pill Badge
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.view_in_ar, size: 15, color: Color(0xFFFFB300)),
                          SizedBox(width: 5),
                          Text(
                            'AR 3D Interactive',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Hero Thumbnail Fallback Indicator Button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          _hasModelError = !_hasModelError;
                        });
                      },
                      tooltip: _hasModelError ? 'Switch to 3D' : 'View 2D photo fallback',
                      icon: Icon(
                        _hasModelError ? Icons.view_in_ar : Icons.photo_library_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =================================================================
            // AR Device Support Banner
            // =================================================================
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B2232)
                    : const Color(0xFFEEF3FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C3955)
                      : const Color(0xFFD4E0F8),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.devices_other_rounded,
                    color: Color(0xFF1976D2),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AR Device Compatibility',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Real-scale table AR requires Google Play Services for AR (ARCore) on Android or ARKit on iOS. All devices can rotate, scale, and inspect dishes in 360° 3D mode.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: isDark ? Colors.grey[300] : const Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =================================================================
            // Below Section: Name, Price, Description, Real-World Scale
            // =================================================================
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tag & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          food.category.toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        food.formattedPrice,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Dish Name
                  Text(
                    food.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Real-World Size Dimensions Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF191C25) : const Color(0xFFF3ECE3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF282D3A) : const Color(0xFFE4DAD0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.straighten_rounded,
                            color: Color(0xFFFFB300),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Real-World Dining Table Scale',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${food.realWorldSizeCm.width} cm (W) × ${food.realWorldSizeCm.depth} cm (D) × ${food.realWorldSizeCm.height} cm (H)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Description
                  const Text(
                    'About this dish',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    food.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // =============================================================
                  // "Add to Table" Button (Disabled for Phase 3)
                  // =============================================================
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      // Disabled for now as requested
                      // TODO (Phase 3): Implement multi-model AR anchor placement on real table surface
                      onPressed: null,
                      icon: const Icon(Icons.table_restaurant_outlined, size: 20),
                      label: const Text('Add to Table (Phase 3)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order Quantity & Add to Cart Button
                  Row(
                    children: [
                      // Quantity Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF242A38)
                              : const Color(0xFFF1EBE2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _orderQuantity > 1
                                  ? () => setState(() => _orderQuantity--)
                                  : null,
                            ),
                            Text(
                              '$_orderQuantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _orderQuantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Add to Cart
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            for (var i = 0; i < _orderQuantity; i++) {
                              ref.read(cartProvider.notifier).addItem(food);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added $_orderQuantity × ${food.name} to order!'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'View Order',
                                  textColor: Colors.white,
                                  onPressed: () => context.push('/cart'),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                          label: Text(
                            'Add to Order • \$${(food.price * _orderQuantity).toStringAsFixed(2)}',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
