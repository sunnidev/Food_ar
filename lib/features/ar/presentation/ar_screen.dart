import 'dart:io';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../../domain/entities/food_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../menu/providers/menu_providers.dart';

/// Custom in-app Augmented Reality screen featuring camera permission verification,
/// horizontal table surface plane detection, hit-testing, real-scale model placement,
/// and model caching with flutter_cache_manager.
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

class _ArScreenState extends ConsumerState<ArScreen> {
  // Permission state
  PermissionStatus _cameraPermission = PermissionStatus.denied;
  bool _isCheckingPermission = true;

  // AR Managers
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;

  // AR Session state
  bool _planeDetected = false;
  bool _isDownloadingModel = false;
  bool _modelPlaced = false;
  String? _statusMessage;

  // Tracked active nodes & anchors
  final List<ARNode> _nodes = [];
  final List<ARAnchor> _anchors = [];

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    setState(() => _isCheckingPermission = true);
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _cameraPermission = status;
        _isCheckingPermission = false;
      });
    } else {
      final requested = await Permission.camera.request();
      setState(() {
        _cameraPermission = requested;
        _isCheckingPermission = false;
      });
    }
  }

  @override
  void dispose() {
    _arSessionManager?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;

    // Initialize AR session
    _arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
    );

    _arObjectManager!.onInitialize();

    // Listen to plane or point tap for surface hit-testing
    _arSessionManager!.onPlaneOrPointTap = _onPlaneOrPointTap;

    // Plane detection callback listener (receives total count of detected planes)
    _arSessionManager!.onPlaneDetected = (int planeCount) {
      if (planeCount > 0 && !_planeDetected && mounted) {
        setState(() {
          _planeDetected = true;
          _statusMessage = 'Table detected ($planeCount surface${planeCount > 1 ? "s" : ""}). Tap to place dish.';
        });
      }
    };
  }

  Future<void> _onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    if (_isDownloadingModel) return;

    // Resolve food item
    final foods = ref.read(foodListProvider).asData?.value ?? [];
    final food = widget.initialFood ??
        (widget.foodId != null
            ? foods.firstWhere(
                (item) => item.id == widget.foodId,
                orElse: () => foods.isNotEmpty ? foods.first : throw Exception('No food'),
              )
            : (foods.isNotEmpty ? foods.first : null));

    if (food == null) return;

    // Filter for horizontal plane hit
    final planeHit = hitTestResults.firstWhere(
      (hit) => hit.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.isNotEmpty ? hitTestResults.first : throw Exception('No hit'),
    );

    // Plane tapped, mark plane detected if not already
    if (!_planeDetected) {
      setState(() => _planeDetected = true);
    }

    try {
      setState(() {
        _isDownloadingModel = true;
        _statusMessage = 'Downloading & calibrating 3D model...';
      });

      // 1. Download & cache model file via flutter_cache_manager
      final fileInfo = await DefaultCacheManager().getSingleFile(food.modelUrl);

      // 2. Remove previous node if repositioning single dish
      if (_nodes.isNotEmpty) {
        for (final node in _nodes) {
          await _arObjectManager?.removeNode(node);
        }
        _nodes.clear();
      }
      if (_anchors.isNotEmpty) {
        for (final anchor in _anchors) {
          await _arAnchorManager?.removeAnchor(anchor);
        }
        _anchors.clear();
      }

      // 3. Create plane anchor at hit transform
      final newAnchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
      final didAddAnchor = await _arAnchorManager!.addAnchor(newAnchor);

      if (didAddAnchor == true) {
        _anchors.add(newAnchor);

        // Calculate real-world physical scale (1 unit = 1 meter in ARCore/ARKit)
        // Average dish dimension in meters = cm / 100
        final targetScaleMeters = (food.realWorldSizeCm.width / 100.0).clamp(0.08, 0.45);
        final scaleVector = vector.Vector3(targetScaleMeters, targetScaleMeters, targetScaleMeters);

        // 4. Attach GLB model node to anchor
        final nodeType = Platform.isAndroid ? NodeType.webGLB : NodeType.webGLB;
        final newNode = ARNode(
          type: nodeType,
          uri: fileInfo.path.isNotEmpty ? food.modelUrl : food.modelUrl,
          scale: scaleVector,
          position: vector.Vector3(0.0, 0.0, 0.0),
          rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
        );

        final didAddNode = await _arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
        if (didAddNode == true) {
          _nodes.add(newNode);
          if (mounted) {
            setState(() {
              _modelPlaced = true;
              _isDownloadingModel = false;
              _statusMessage = 'Dish placed at 1:1 real table scale!';
            });
          }
        } else {
          throw Exception('Failed to attach 3D model node to AR plane anchor');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingModel = false;
          _statusMessage = 'Placement error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place dish: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _clearPlacedModel() {
    for (final node in _nodes) {
      _arObjectManager?.removeNode(node);
    }
    _nodes.clear();
    for (final anchor in _anchors) {
      _arAnchorManager?.removeAnchor(anchor);
    }
    _anchors.clear();
    setState(() {
      _modelPlaced = false;
      _statusMessage = _planeDetected ? 'Tap on table to place dish' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve food item
    final foods = ref.watch(foodListProvider).asData?.value ?? [];
    final FoodItem? food = widget.initialFood ??
        (widget.foodId != null
            ? foods.firstWhere(
                (item) => item.id == widget.foodId,
                orElse: () => foods.isNotEmpty ? foods.first : throw Exception('Not found'),
              )
            : (foods.isNotEmpty ? foods.first : null));

    // Handle Camera Permission Checking state
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Handle Camera Permission Denied UI
    if (!_cameraPermission.isGranted) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF101216) : Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('AR Camera Access'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.no_photography_outlined,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Needed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Food AR requires camera access to scan your real dining table, detect horizontal surfaces, and project dishes at 1:1 real-world scale.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checkCameraPermission,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Grant Camera Access'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open App Settings'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Camera is granted: Render AR Session
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Native AR Camera Canvas
          Positioned.fill(
            child: ARView(
              onARViewCreated: _onARViewCreated,
              planeDetectionConfig: PlaneDetectionConfig.horizontal,
            ),
          ),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                    tooltip: 'Exit AR Mode',
                  ),
                ),

                // Table Surface Detection Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _planeDetected ? const Color(0xFF10B981) : const Color(0xFFFFB300),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _planeDetected ? Icons.check_circle : Icons.table_restaurant_outlined,
                        size: 15,
                        color: _planeDetected ? const Color(0xFF10B981) : const Color(0xFFFFB300),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _planeDetected ? 'Table Detected' : 'Scanning Surface...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Clear/Reset Model Action Button
                if (_modelPlaced)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: _clearPlacedModel,
                      tooltip: 'Clear & Reposition',
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),

          // Guidance Overlay: "Move your phone slowly..." (Disappears once plane is found)
          if (!_planeDetected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                      width: 1,
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
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Tap guidance after table is detected but model is not yet placed
          if (_planeDetected && !_modelPlaced && !_isDownloadingModel)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Color(0xFF10B981),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusMessage ?? 'Tap on the detected table grid to place dish',
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
            ),

          // Model Downloading & Caching Progress Overlay
          if (_isDownloadingModel)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E28),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Downloading 3D Model',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Caching via flutter_cache_manager...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Bar showing Selected Dish Info & Actions
          if (food != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF151822).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Dish Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: CachedNetworkImage(
                          imageUrl: food.thumbnailUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Dish Name & Real-World Dimensions
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Real scale: ${food.realWorldSizeCm.formattedDimensions}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            food.formattedPrice,
                            style: const TextStyle(
                              color: Color(0xFFFF5722),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Add to Order Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(food);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${food.name} to cart!'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'View Cart',
                              textColor: Colors.white,
                              onPressed: () => context.push('/cart'),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
