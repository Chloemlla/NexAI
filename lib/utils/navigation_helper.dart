import 'package:flutter/material.dart';

/// Helper class for navigation between pages
class NavigationHelper {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Callback to navigate to settings page
  static VoidCallback? navigateToSettings;
  
  /// Navigate to settings page
  static void goToSettings() {
    navigateToSettings?.call();
  }
}
