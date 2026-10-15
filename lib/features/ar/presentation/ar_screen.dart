import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../../domain/entities/food_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../menu/providers/menu_providers.dart';
import '../domain/entities/placed_item.dart';
import '../providers/ar_placement_provider.dart';
import 'controllers/ar_screen_controller.dart';
import 'widgets/ar_permission_denied_view.dart';

/// Clean, Unobstructed AR Table Dining Screen:
/// - 100% full-screen live camera view with no bulky cards or banners blocking the table.
/// - Selected food dish appears directly on the real table with realistic ceramic plate & soft shadow.
/// - Drag dish anywhere across the table with your finger, pinch to scale or rotate.
/// - Super minimal bottom dish selector: 1-tap on any food icon to instantly place that dish on the table.
class ArScreen extends ConsumerStatefulWidget {
  final String? foodId;
  final FoodItem? initialFood;

  const ArScreen({
    super.key,
    this.foodId,
    this.initialFood,
  });

  @override
  ConsumerState<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends ConsumerState<ArScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _cameraErrorMessage = '';

  PermissionStatus _cameraPermission = PermissionStatus.denied;
  bool _isCheckingPermission = true;

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  late final ArScreenController _controller;

  // Track dish dragging positions (pixel coordinates) and rotation / scale
  final Map<String, Offset> _dishScreenOffsets = {};
  final Map<String, double> _dishRotations = {};
  final Map<String, double> _dishScaleMultipliers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ArScreenController(ref: ref, context: context);

    _initCameraAndPermissions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndAutoPlaceDish();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isCameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCameraAndPermissions() async {
    setState(() => _isCheckingPermission = true);

    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _cameraPermission = status;
      _isCheckingPermission = false;
    });

    if (status.isGranted) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraError = true;
            _cameraErrorMessage = 'No camera found on this device.';
          });
        }
        return;
      }

      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _isCameraError = false;
      });

      ref.read(detectedPlanesCountNotifierProvider.notifier).updateCount(1);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Camera initialization failed: $e';
        });
      }
    }
  }

  /// Automatically places the user's chosen dish cleanly on the table in the camera center
  void _initializeAndAutoPlaceDish() {
    ref.read(detectedPlanesCountNotifierProvider.notifier).reset();
    ref.read(placedItemsProvider.notifier).clearAll();
    ref.read(selectedItemIdProvider.notifier).deselect();
    _dishScreenOffsets.clear();
    _dishRotations.clear();
    _dishScaleMultipliers.clear();

    FoodItem? targetFood = widget.initialFood;

    if (targetFood == null && widget.foodId != null) {
      final foods = ref.read(foodListProvider).asData?.value ?? [];
      targetFood = foods.cast<FoodItem?>().firstWhere(
            (item) => item?.id == widget.foodId,
            orElse: () => null,
          );
    }

    targetFood ??= ref.read(foodListProvider).asData?.value.firstOrNull;

    if (targetFood != null) {
      ref.read(activeDishProvider.notifier).setActive(targetFood);
      _selectOrPlaceDish(targetFood);
    }
  }

  /// Places or selects a specific dish on the table
  void _selectOrPlaceDish(FoodItem food) {
    final screenSize = MediaQuery.of(context).size;
    final currentPlaced = ref.read(placedItemsProvider);

    // If this dish is already placed, select it and bring to center if needed
    final existingIndex = currentPlaced.indexWhere((item) => item.foodItem.id == food.id);
    if (existingIndex != -1) {
      ref.read(selectedItemIdProvider.notifier).select(currentPlaced[existingIndex].id);
      HapticFeedback.selectionClick();
      return;
    }

    if (currentPlaced.length >= kMaxPlacedDishes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Table is full! Tap on a dish to replace or remove it.'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Position dish in lower-middle table area
    final count = currentPlaced.length;
    final offsetX = (count == 0) ? 0.0 : ((count % 2 == 1) ? -50.0 * count : 50.0 * count);
    final targetX = (screenSize.width * 0.5) + offsetX;
    final targetY = (screenSize.height * 0.52);

    final uniqueId = 'dish_${food.id}_${DateTime.now().millisecondsSinceEpoch}';
    final initialRot = vector.Vector4(1.0, 0.0, 0.0, 0.0);
    final normPos = vector.Vector3(targetX / screenSize.width, 0.0, targetY / screenSize.height);

    final placedItem = PlacedItem(
      id: uniqueId,
      foodItem: food,
      rotation: initialRot,
      position: normPos,
    );

    ref.read(placedItemsProvider.notifier).addItem(placedItem);
    ref.read(selectedItemIdProvider.notifier).select(uniqueId);
    _dishScreenOffsets[uniqueId] = Offset(targetX, targetY);
    _dishRotations[uniqueId] = 0.0;
    _dishScaleMultipliers[uniqueId] = 1.0;

    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5722)),
        ),
      );
    }

    if (!_cameraPermission.isGranted) {
      return ArPermissionDeniedView(onRetry: _initCameraAndPermissions);
    }

    final placedItems = ref.watch(placedItemsProvider);
    final selectedId = ref.watch(selectedItemIdProvider);
    final allFoods = ref.watch(foodListProvider).asData?.value ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ===================================================================
          // Layer 1: 100% Fullscreen Camera + Dishes (Screenshot Boundary)
          // ===================================================================
          RepaintBoundary(
            key: _repaintBoundaryKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Clean Wide Camera Stream (Zero UI overlays on camera)
                if (_isCameraInitialized && _cameraController != null)
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? screenSize.width,
                        height: _cameraController!.value.previewSize?.width ?? screenSize.height,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else if (_isCameraError)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF161616),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_rounded, color: Color(0xFFFF5722), size: 44),
                            const SizedBox(height: 12),
                            Text(
                              _cameraErrorMessage,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5722)),
                              onPressed: _initCamera,
                              child: const Text('Retry Camera'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                      ),
                    ),
                  ),

                // Tap background to deselect active highlight
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (selectedId != null) {
                        ref.read(selectedItemIdProvider.notifier).deselect();
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),

                // Realistic Dishes Placed Directly on the Table
                for (final item in placedItems)
                  _buildPlacedDish(item, screenSize, selectedId == item.id),
              ],
            ),
          ),

          // ===================================================================
          // Layer 2: Ultra Minimal Top Navigation (Discreet & Translucent)
          // ===================================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Back Button
                    _buildGlassCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => context.pop(),
                      tooltip: 'Back to Menu',
                    ),
                    const Spacer(),

                    // Camera Snap & Share Photo of Table
                    _buildGlassCircleButton(
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFFFF5722),
                      onTap: () => _controller.captureAndShareScreenshot(boundaryKey: _repaintBoundaryKey),
                      tooltip: 'Snap Table Photo',
                    ),
                    const SizedBox(width: 10),

                    // Cart / Checkout Button
                    _buildGlassCircleButton(
                      icon: Icons.shopping_bag_outlined,
                      onTap: () {
                        if (placedItems.isNotEmpty) {
                          ref.read(cartProvider.notifier).addItemsFromPlacedDishes(placedItems);
                        }
                        context.push('/cart');
                      },
                      tooltip: 'Cart',
                      badgeCount: placedItems.length,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===================================================================
          // Layer 3: Ultra Minimal Bottom Dish Selector
          // Allows instant 1-tap switching without blocking the table!
          // ===================================================================
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 10,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: allFoods.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final food = allFoods[index];
                  final isPlaced = placedItems.any((item) => item.foodItem.id == food.id);

                  return InkWell(
                    onTap: () {
                      _selectOrPlaceDish(food);
                    },
                    borderRadius: BorderRadius.circular(26),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPlaced
                            ? const Color(0xFFFF5722)
                            : Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: isPlaced ? Colors.white : Colors.white24,
                          width: isPlaced ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: CachedNetworkImage(
                                imageUrl: food.thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white12),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.restaurant, color: Colors.white70, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            food.name.split(' ').take(2).join(' '),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: isPlaced ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the realistic 3D dish placed directly on the table
  /// (Exact same 3D model as shown in details screen, natural plate, no red borders!)
  Widget _buildPlacedDish(PlacedItem item, Size screenSize, bool isSelected) {
    final currentOffset = _dishScreenOffsets[item.id] ??
        Offset(
          item.position.x * screenSize.width,
          item.position.z * screenSize.height,
        );

    final normalizedDepth = (currentOffset.dy / screenSize.height).clamp(0.20, 0.85);
    final perspectiveScale = 0.70 + (normalizedDepth * 0.45);
    final userScale = _dishScaleMultipliers[item.id] ?? 1.0;

    final dishWidth = (screenSize.width * 0.80 * perspectiveScale * userScale).clamp(240.0, 360.0);
    final dishHeight = dishWidth * 0.80;

    return Positioned(
      left: currentOffset.dx - (dishWidth / 2),
      top: currentOffset.dy - (dishHeight / 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(selectedItemIdProvider.notifier).toggle(item.id);
          HapticFeedback.selectionClick();
        },
        onDoubleTap: () {
          ref.read(placedItemsProvider.notifier).removeById(item.id);
          _dishScreenOffsets.remove(item.id);
          _dishRotations.remove(item.id);
          _dishScaleMultipliers.remove(item.id);
          HapticFeedback.mediumImpact();
        },
        onPanUpdate: (details) {
          setState(() {
            final newDx = (currentOffset.dx + details.delta.dx)
                .clamp(dishWidth / 3, screenSize.width - (dishWidth / 3));
            final newDy = (currentOffset.dy + details.delta.dy)
                .clamp(screenSize.height * 0.10, screenSize.height * 0.80);

            _dishScreenOffsets[item.id] = Offset(newDx, newDy);
          });
        },
        child: SizedBox(
          width: dishWidth,
          height: dishHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 1. Realistic Table Contact Shadow (Deep directional dining shadow)
              Positioned(
                bottom: 8,
                child: Container(
                  width: dishWidth * 0.90,
                  height: dishHeight * 0.45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(dishWidth * 0.90, dishHeight * 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 32 * perspectiveScale,
                        spreadRadius: 6,
                        offset: Offset(0, 14 * perspectiveScale),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Realistic 3D Perspective Ceramic Dining Platter (Natural, No Red Borders)
              Positioned(
                bottom: 12,
                child: Container(
                  width: dishWidth * 0.92,
                  height: dishHeight * 0.72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(dishWidth * 0.92, dishHeight * 0.72),
                    ),
                    // Fine porcelain / ceramic shaded plate rim
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF3F3F3),
                        Color(0xFFE2E2E2),
                        Color(0xFFCACACA),
                      ],
                      stops: [0.0, 0.35, 0.75, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: dishWidth * 0.05,
                      vertical: dishHeight * 0.04,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(dishWidth * 0.82, dishHeight * 0.64),
                        ),
                        // Inner plate basin depth shadow
                        gradient: const RadialGradient(
                          center: Alignment(0.0, -0.1),
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFEFEFEF),
                            Color(0xFFDCDCDC),
                          ],
                          stops: [0.0, 0.75, 1.0],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(dishWidth * 0.80, dishHeight * 0.62),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: item.foodItem.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.white24,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Discreet Drag Handle at the bottom
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_indicator_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        item.foodItem.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Minimal glass translucent circle button
  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
    int? badgeCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (color ?? Colors.black).withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
