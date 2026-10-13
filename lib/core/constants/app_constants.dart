/// Application-wide constants for Food AR
class AppConstants {
  AppConstants._();

  // App Identity
  static const String appName = 'Food AR';
  static const String appTagline = 'Try on your table before you order';

  // Asset paths
  static const String foodsJsonPath = 'assets/foods.json';

  // Food Categories
  static const String categoryAll = 'All';
  static const List<String> defaultCategories = [
    categoryAll,
    'Healthy',
    'Pizza',
    'Asian',
    'Desserts',
    'Beverages',
  ];

  // AR Settings
  static const List<String> arModes = ['scene-viewer', 'quick-look', 'webxr'];
  static const double defaultShadowIntensity = 1.0;
  static const double defaultExposure = 1.0;

  // Animation & Transition durations
  static const Duration defaultAnimDuration = Duration(milliseconds: 300);
  static const Duration splashDelay = Duration(milliseconds: 1200);

  // Network & Cache
  static const Duration networkTimeout = Duration(seconds: 15);
  static const int maxCacheDays = 7;
}
