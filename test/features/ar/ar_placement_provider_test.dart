import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ar/domain/entities/food_item.dart';
import 'package:food_ar/domain/entities/real_world_size.dart';
import 'package:food_ar/features/ar/domain/entities/placed_item.dart';
import 'package:food_ar/features/ar/providers/ar_placement_provider.dart';
import 'package:food_ar/features/menu/providers/menu_providers.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  const testFood1 = FoodItem(
    id: 'food_1',
    name: 'Margherita Pizza',
    category: 'Pizza',
    price: 14.99,
    description: 'Classic artisanal pizza',
    thumbnailUrl: 'https://example.com/pizza.jpg',
    modelUrl: 'https://example.com/pizza.glb',
    realWorldSizeCm: RealWorldSize(width: 30, height: 3, depth: 30),
    pairsWith: ['food_2'],
  );

  const testFood2 = FoodItem(
    id: 'food_2',
    name: 'Classic Burger',
    category: 'Burger',
    price: 12.50,
    description: 'Juicy craft burger',
    thumbnailUrl: 'https://example.com/burger.jpg',
    modelUrl: 'https://example.com/burger.glb',
    realWorldSizeCm: RealWorldSize(width: 15, height: 12, depth: 15),
    pairsWith: ['food_1'],
  );

  PlacedItem createDummyPlacedItem(
    String id,
    FoodItem food, {
    vector.Vector3? position,
  }) {
    final pos = position ?? vector.Vector3(0.0, 0.0, 0.0);
    return PlacedItem(
      id: id,
      foodItem: food,
      anchor: ARPlaneAnchor(transformation: vector.Matrix4.identity()),
      node: ARNode(
        name: 'node_$id',
        type: NodeType.webGLB,
        uri: food.modelUrl,
      ),
      rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      position: pos,
    );
  }

  group('PlacedItemsProvider & Multi-dish constraints', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          foodListProvider.overrideWith(
            () => _FakeFoodListNotifier([testFood1, testFood2]),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('starts with empty list, count 0, and price 0.0', () {
      final items = container.read(placedItemsProvider);
      final count = container.read(totalPlacedCountProvider);
      final totalPrice = container.read(totalPlacedPriceProvider);

      expect(items, isEmpty);
      expect(count, 0);
      expect(totalPrice, 0.0);
      expect(container.read(isTableFullProvider), isFalse);
    });

    test('adds items and updates total price accurately', () {
      final notifier = container.read(placedItemsProvider.notifier);

      final item1 = createDummyPlacedItem('item_1', testFood1);
      final item2 = createDummyPlacedItem('item_2', testFood2);

      expect(notifier.addItem(item1), isTrue);
      expect(notifier.addItem(item2), isTrue);

      final items = container.read(placedItemsProvider);
      expect(items.length, 2);
      expect(container.read(totalPlacedCountProvider), 2);
      expect(container.read(totalPlacedPriceProvider), closeTo(27.49, 0.001));
    });

    test('strictly enforces the 10-dish maximum table limit', () {
      final notifier = container.read(placedItemsProvider.notifier);

      // Add 10 items
      for (int i = 0; i < 10; i++) {
        final added = notifier.addItem(createDummyPlacedItem('item_$i', testFood1));
        expect(added, isTrue);
      }

      expect(container.read(totalPlacedCountProvider), 10);
      expect(container.read(isTableFullProvider), isTrue);

      // Attempt to add 11th item
      final eleventhAdded = notifier.addItem(createDummyPlacedItem('item_11', testFood2));
      expect(eleventhAdded, isFalse);
      expect(container.read(totalPlacedCountProvider), 10);
    });

    test('undoLast removes the most recently added dish', () {
      final notifier = container.read(placedItemsProvider.notifier);

      final item1 = createDummyPlacedItem('item_1', testFood1);
      final item2 = createDummyPlacedItem('item_2', testFood2);

      notifier.addItem(item1);
      notifier.addItem(item2);

      final removed = notifier.removeLast();
      expect(removed?.id, 'item_2');
      expect(container.read(totalPlacedCountProvider), 1);
      expect(container.read(placedItemsProvider).first.id, 'item_1');
      expect(container.read(totalPlacedPriceProvider), closeTo(14.99, 0.001));
    });

    test('deleteById removes the selected dish by identifier', () {
      final notifier = container.read(placedItemsProvider.notifier);

      final item1 = createDummyPlacedItem('item_1', testFood1);
      final item2 = createDummyPlacedItem('item_2', testFood2);

      notifier.addItem(item1);
      notifier.addItem(item2);

      final removed = notifier.removeById('item_1');
      expect(removed?.id, 'item_1');
      expect(container.read(totalPlacedCountProvider), 1);
      expect(container.read(placedItemsProvider).first.id, 'item_2');
    });

    test('clearAll removes all dishes and resets total price', () {
      final notifier = container.read(placedItemsProvider.notifier);

      notifier.addItem(createDummyPlacedItem('item_1', testFood1));
      notifier.addItem(createDummyPlacedItem('item_2', testFood2));

      final cleared = notifier.clearAll();
      expect(cleared.length, 2);
      expect(container.read(placedItemsProvider), isEmpty);
      expect(container.read(totalPlacedCountProvider), 0);
      expect(container.read(totalPlacedPriceProvider), 0.0);
    });

    test('selection notifier toggles and resolves selected placed item', () {
      final notifier = container.read(placedItemsProvider.notifier);
      final selectNotifier = container.read(selectedItemIdProvider.notifier);

      final item1 = createDummyPlacedItem('item_1', testFood1);
      notifier.addItem(item1);

      selectNotifier.select('item_1');
      expect(container.read(selectedItemIdProvider), 'item_1');
      expect(container.read(selectedPlacedItemProvider)?.foodItem.name, 'Margherita Pizza');

      selectNotifier.deselect();
      expect(container.read(selectedItemIdProvider), isNull);
      expect(container.read(selectedPlacedItemProvider), isNull);
    });

    test('table fit calculation updates surface area and used percentage', () {
      final notifier = container.read(placedItemsProvider.notifier);

      expect(container.read(tableCapacityPercentageProvider), 0);

      // Place 30cm pizza (area ~706.8 cm²)
      notifier.addItem(createDummyPlacedItem('item_1', testFood1));

      final usedArea = container.read(usedTableAreaCm2Provider);
      expect(usedArea, closeTo(706.8, 1.0));

      final percent = container.read(tableCapacityPercentageProvider);
      expect(percent, greaterThan(0));
      expect(percent, lessThan(20));
    });

    test('overlap collision prevention detects intersecting footprints', () {
      final notifier = container.read(placedItemsProvider.notifier);

      // Place item1 at origin (0, 0, 0). Its radius is 30cm/2 = 15cm = 0.15m.
      final item1 = createDummyPlacedItem('item_1', testFood1, position: vector.Vector3(0.0, 0.0, 0.0));
      notifier.addItem(item1);

      // Candidate 2 is Burger (radius 15cm/2 = 7.5cm = 0.075m).
      // Sum of radii = 0.15m + 0.075m = 0.225m (minus 0.02m buffer = 0.205m).

      // Test position 0.10m away -> Should COLLIDE
      final collidingTestPos = vector.Vector3(0.10, 0.0, 0.0);
      final collision = notifier.checkCollision(collidingTestPos, testFood2);
      expect(collision, isNotNull);
      expect(collision?.id, 'item_1');

      // Test position 0.35m away -> Should NOT collide
      final safeTestPos = vector.Vector3(0.35, 0.0, 0.0);
      final safeResult = notifier.checkCollision(safeTestPos, testFood2);
      expect(safeResult, isNull);
    });

    test('combo suggestions resolves complementary dishes from pairsWith', () async {
      await container.read(foodListProvider.future);
      final activeNotifier = container.read(activeDishProvider.notifier);
      activeNotifier.setActive(testFood1); // testFood1 pairsWith ['food_2']

      final combos = container.read(comboSuggestionsProvider);
      expect(combos.length, 1);
      expect(combos.first.id, 'food_2');
      expect(combos.first.name, 'Classic Burger');
    });
  });
}

class _FakeFoodListNotifier extends FoodListNotifier {
  final List<FoodItem> initial;
  _FakeFoodListNotifier(this.initial);

  @override
  Future<List<FoodItem>> build() async => initial;
}
