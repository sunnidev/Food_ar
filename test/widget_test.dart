import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_ar/core/constants/app_constants.dart';
import 'package:food_ar/domain/entities/food_item.dart';
import 'package:food_ar/domain/repositories/food_repository.dart';
import 'package:food_ar/features/menu/providers/menu_providers.dart';
import 'package:food_ar/main.dart';

class FastTestFoodRepository implements FoodRepository {
  @override
  Future<List<FoodItem>> getFoods() async => const [];

  @override
  Future<FoodItem?> getFoodById(String id) async => null;

  @override
  Future<List<String>> getCategories() async => const [AppConstants.categoryAll];

  @override
  Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> orderPayload) async {
    return {
      'orderId': 'TEST-ORD-001',
      'status': 'confirmed',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

void main() {
  testWidgets('Food AR App smoke test and initial render', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodRepositoryProvider.overrideWithValue(FastTestFoodRepository()),
        ],
        child: const FoodArApp(),
      ),
    );

    // Initial frame renders branding
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('AR READY'), findsOneWidget);

    await tester.pump();
  });
}
