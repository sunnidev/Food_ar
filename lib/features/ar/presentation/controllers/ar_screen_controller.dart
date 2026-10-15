import 'dart:io';
import 'dart:ui' as ui;
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../../../core/services/model_cache_service.dart';
import '../../../../domain/entities/food_item.dart';
import '../../../menu/providers/menu_providers.dart';
import '../../domain/entities/placed_item.dart';
import '../../providers/ar_placement_provider.dart';

/// Centralized controller orchestrating the AR session, multi-model plane anchoring,
/// hit-testing, table fit calculations, overlap collision prevention, model caching,
/// gesture transformations, and screenshot sharing.
class ArScreenController {
  final WidgetRef ref;
  final BuildContext context;

  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  ArScreenController({
    required this.ref,
    required this.context,
  });

  /// Initializes AR managers and session listeners
  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    // Initialize AR session with horizontal plane detection and native gestures
    // Note: handlePans enables surface dragging; handleRotation enables two-finger rotation.
    // Pinch-to-scale is deliberately disabled to strictly enforce 1:1 real-world physical scale.
    arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );

    arObjectManager!.onInitialize();

    // Plane detection listener
    arSessionManager!.onPlaneDetected = (int planeCount) {
      if (planeCount > 0) {
        ref.read(detectedPlanesCountNotifierProvider.notifier).updateCount(planeCount);
        ref.read(arStatusMessageProvider.notifier).setMessage(
              'Table detected ($planeCount surface${planeCount > 1 ? "s" : ""}). Tap to place dish.',
            );
      }
    };

    // Tap on detected plane surface to place selected dish
    arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTap;

    // Tap on existing 3D dish node to select/highlight it
    arObjectManager!.onNodeTap = onNodeTap;

    // Drag / Pan gesture completed: update saved position
    arObjectManager!.onPanEnd = onPanEnd;

    // Two-finger rotation gesture completed: update saved rotation
    arObjectManager!.onRotationEnd = onRotationEnd;
  }

  /// Handles user tapping on a detected horizontal plane with fit check and overlap collision prevention
  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    final isDownloading = ref.read(isDownloadingModelProvider);
    if (isDownloading) return;

    final currentItems = ref.read(placedItemsProvider);
    // 1. Limit to 10 items maximum
    if (currentItems.length >= kMaxPlacedDishes) {
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Maximum limit of 10 dishes reached! Remove an item to place more.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.amber[900],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Resolve candidate food item
    FoodItem? food = ref.read(activeDishProvider);
    if (food == null) {
      final allFoods = ref.read(foodListProvider).asData?.value ?? [];
      if (allFoods.isNotEmpty) {
        food = allFoods.first;
        ref.read(activeDishProvider.notifier).setActive(food);
      }
    }
    if (food == null) return;

    // Find plane hit result
    final planeHit = hitTestResults.firstWhere(
      (hit) => hit.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.isNotEmpty ? hitTestResults.first : throw Exception('No plane hit found'),
    );

    final candidateWorldPosition = planeHit.worldTransform.getTranslation();

    // 2. Overlap Prevention: Check for spatial collision with existing dishes on the table plane
    final collidingItem = ref.read(placedItemsProvider.notifier).checkCollision(
          candidateWorldPosition,
          food,
        );

    if (collidingItem != null) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cannot place ${food.name}: overlaps with ${collidingItem.foodItem.name}! Choose an open spot.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 3. Table Fit Check: Verify candidate dish footprint fits within available surface area
    final usedArea = ref.read(usedTableAreaCm2Provider);
    final availableArea = ref.read(availableTableAreaCm2Provider);
    if ((usedArea + food.footprintAreaCm2) > (availableArea * 1.05)) {
      HapticFeedback.vibrate();
      final currentPercent = ref.read(tableCapacityPercentageProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.table_restaurant_outlined, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Table capacity exceeded ($currentPercent% full)! Not enough open space for ${food.name}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFB71C1C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Passed all validations: proceed with anchor & model placement
    try {
      ref.read(isDownloadingModelProvider.notifier).setDownloading(true);
      ref.read(arStatusMessageProvider.notifier).setMessage('Downloading & caching 3D model...');

      // 4. Download & cache model file via ModelCacheService (with version check)
      final cachedFile = await modelCacheService.getModelFile(food);
      debugPrint('Model cached locally for ${food.name}: ${cachedFile.path}');

      // 5. Create AR plane anchor at hit point
      final newAnchor = ARPlaneAnchor(transformation: planeHit.worldTransform);
      final didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

      if (didAddAnchor == true) {
        // Calculate real-world physical scale (1 unit = 1 meter)
        final targetScaleMeters = (food.realWorldSizeCm.width / 100.0).clamp(0.08, 0.45);
        final scaleVector = vector.Vector3(targetScaleMeters, targetScaleMeters, targetScaleMeters);

        // 6. Attach GLB model node to anchor
        final nodeType = Platform.isAndroid ? NodeType.webGLB : NodeType.webGLB;
        final uniqueNodeName = 'dish_${food.id}_${DateTime.now().millisecondsSinceEpoch}';

        final initialRotation = vector.Vector4(1.0, 0.0, 0.0, 0.0);

        final newNode = ARNode(
          name: uniqueNodeName,
          type: nodeType,
          uri: food.modelUrl,
          scale: scaleVector,
          position: vector.Vector3(0.0, 0.0, 0.0),
          rotation: initialRotation,
        );

        final didAddNode = await arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
        if (didAddNode == true) {
          final placedItem = PlacedItem(
            id: uniqueNodeName,
            foodItem: food,
            anchor: newAnchor,
            node: newNode,
            rotation: initialRotation,
            position: candidateWorldPosition, // Store real-world coordinates for collision tracking
          );

          ref.read(placedItemsProvider.notifier).addItem(placedItem);
          ref.read(selectedItemIdProvider.notifier).select(placedItem.id);
          HapticFeedback.lightImpact();

          final updatedPercent = ref.read(tableCapacityPercentageProvider);
          ref.read(arStatusMessageProvider.notifier).setMessage(
                'Placed ${food.name}! Table $updatedPercent% full.',
              );
        } else {
          throw Exception('Failed to attach 3D model node to AR plane anchor');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place dish: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      ref.read(isDownloadingModelProvider.notifier).setDownloading(false);
    }
  }

  /// Handles tapping on a 3D model node in the AR scene
  void onNodeTap(List<String> nodeNames) {
    if (nodeNames.isEmpty) return;
    final tappedNodeName = nodeNames.first;

    final currentItems = ref.read(placedItemsProvider);
    final tappedItem = currentItems.cast<PlacedItem?>().firstWhere(
          (item) => item?.node?.name == tappedNodeName || item?.id == tappedNodeName,
          orElse: () => null,
        );

    if (tappedItem != null) {
      ref.read(selectedItemIdProvider.notifier).toggle(tappedItem.id);
      final isNowSelected = ref.read(selectedItemIdProvider) == tappedItem.id;
      if (isNowSelected) {
        HapticFeedback.selectionClick();
        ref.read(arStatusMessageProvider.notifier).setMessage(
              'Selected ${tappedItem.foodItem.name}. Drag to move or rotate.',
            );
      }
    }
  }

  /// Handles drag/pan gesture completion
  void onPanEnd(String nodeName, vector.Matrix4 transform) {
    final translation = transform.getTranslation();
    final quat = vector.Quaternion.fromRotation(transform.getRotation());
    final rotationVec4 = vector.Vector4(quat.x, quat.y, quat.z, quat.w);

    ref.read(placedItemsProvider.notifier).updateItemTransform(
          nodeName: nodeName,
          position: translation,
          rotation: rotationVec4,
        );

    final currentItems = ref.read(placedItemsProvider);
    final item = currentItems.cast<PlacedItem?>().firstWhere(
          (i) => i?.node?.name == nodeName || i?.id == nodeName,
          orElse: () => null,
        );
    if (item != null) {
      ref.read(selectedItemIdProvider.notifier).select(item.id);
    }
  }

  /// Handles two-finger rotation gesture completion
  void onRotationEnd(String nodeName, vector.Matrix4 transform) {
    final translation = transform.getTranslation();
    final quat = vector.Quaternion.fromRotation(transform.getRotation());
    final rotationVec4 = vector.Vector4(quat.x, quat.y, quat.z, quat.w);

    ref.read(placedItemsProvider.notifier).updateItemTransform(
          nodeName: nodeName,
          position: translation,
          rotation: rotationVec4,
        );
  }

  /// Captures the AR scene and opens native system share modal via share_plus
  Future<void> captureAndShareScreenshot({GlobalKey? boundaryKey}) async {
    try {
      HapticFeedback.mediumImpact();
      Uint8List? pngBytes;

      // 1. Attempt native AR camera snapshot first
      try {
        final imageProvider = await arSessionManager?.snapshot();
        if (imageProvider is MemoryImage) {
          pngBytes = imageProvider.bytes;
        }
      } catch (e) {
        debugPrint('AR native snapshot unavailable: $e');
      }

      // 2. Fallback to RepaintBoundary if native snapshot is empty
      if ((pngBytes == null || pngBytes.isEmpty) && boundaryKey?.currentContext != null) {
        final boundary = boundaryKey!.currentContext!.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          pngBytes = byteData?.buffer.asUint8List();
        }
      }

      if (pngBytes == null || pngBytes.isEmpty) {
        throw Exception('Unable to capture AR view frame');
      }

      // 3. Write image to app temporary cache
      final tempDir = await getTemporaryDirectory();
      final filename = 'food_ar_dining_table_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pngBytes);

      // 4. Trigger share_plus native modal
      final totalDishes = ref.read(totalPlacedCountProvider);
      final totalPrice = ref.read(totalPlacedPriceProvider);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Visualizing $totalDishes delicious dish${totalDishes == 1 ? "" : "es"} (\$${totalPrice.toStringAsFixed(2)}) in AR! Try before you order with Food AR 🍽️✨',
          subject: 'Food AR Table Visualization',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screenshot capture failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// "Undo last": Removes the most recently placed dish from the AR scene and state
  Future<void> undoLast() async {
    final lastItem = ref.read(placedItemsProvider.notifier).removeLast();
    if (lastItem != null) {
      if (lastItem.node != null) await arObjectManager?.removeNode(lastItem.node!);
      if (lastItem.anchor != null) await arAnchorManager?.removeAnchor(lastItem.anchor!);

      if (ref.read(selectedItemIdProvider) == lastItem.id) {
        ref.read(selectedItemIdProvider.notifier).deselect();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${lastItem.foodItem.name}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// Deletes the currently selected dish from the AR scene
  Future<void> deleteSelected() async {
    final selectedId = ref.read(selectedItemIdProvider);
    if (selectedId == null) return;

    final removed = ref.read(placedItemsProvider.notifier).removeById(selectedId);
    if (removed != null) {
      if (removed.node != null) await arObjectManager?.removeNode(removed.node!);
      if (removed.anchor != null) await arAnchorManager?.removeAnchor(removed.anchor!);
      ref.read(selectedItemIdProvider.notifier).deselect();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${removed.foodItem.name} from table'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// "Clear all": Clears every dish from the AR scene and resets state
  Future<void> clearAll() async {
    final allItems = ref.read(placedItemsProvider.notifier).clearAll();
    ref.read(selectedItemIdProvider.notifier).deselect();

    for (final item in allItems) {
      if (item.node != null) await arObjectManager?.removeNode(item.node!);
      if (item.anchor != null) await arAnchorManager?.removeAnchor(item.anchor!);
    }

    if (allItems.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleared all dishes from table'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Clean disposal
  void dispose() {
    arSessionManager?.dispose();
  }
}

// Aliases for provider references
final detectedPlanesCountNotifierProvider = detectedPlanesCountProvider;
