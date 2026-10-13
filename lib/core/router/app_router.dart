import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/food_item.dart';
import '../../features/ar/presentation/ar_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/menu/presentation/food_detail_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../widgets/error_view.dart';

/// Centralized application routing table using go_router.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'menu',
      builder: (context, state) => const MenuScreen(),
    ),
    GoRoute(
      path: '/food/:id',
      name: 'food_detail',
      builder: (context, state) {
        final foodId = state.pathParameters['id'] ?? '';
        final initialFood = state.extra is FoodItem ? state.extra as FoodItem : null;
        return FoodDetailScreen(
          foodId: foodId,
          initialFood: initialFood,
        );
      },
    ),
    GoRoute(
      path: '/ar',
      name: 'ar_custom',
      builder: (context, state) {
        final initialFood = state.extra is FoodItem ? state.extra as FoodItem : null;
        final foodId = state.uri.queryParameters['id'];
        return ArScreen(
          foodId: foodId,
          initialFood: initialFood,
        );
      },
    ),
    GoRoute(
      path: '/ar/:id',
      name: 'ar_viewer',
      builder: (context, state) {
        final foodId = state.pathParameters['id'] ?? '';
        final initialFood = state.extra is FoodItem ? state.extra as FoodItem : null;
        return ArScreen(
          foodId: foodId,
          initialFood: initialFood,
        );
      },
    ),
    GoRoute(
      path: '/cart',
      name: 'cart',
      builder: (context, state) => const CartScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page Not Found')),
    body: ErrorView(
      title: 'Page Not Found',
      message: 'The requested route "${state.uri}" does not exist.',
      onRetry: () => context.go('/'),
    ),
  ),
);
