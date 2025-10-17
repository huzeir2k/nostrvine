// ABOUTME: NavigatorObserver that stops videos when modals/dialogs are pushed
// ABOUTME: Only pauses for overlay routes that cover video content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideoStopNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Pause videos when any new route is pushed
    // This handles modals, dialogs, and full-screen navigations
    _stopAllVideos('didPush', route.settings.name);
  }

  void _stopAllVideos(String action, String? routeName) {
    try {
      // Access container from navigator context
      if (navigator?.context != null) {
        final container = ProviderScope.containerOf(navigator!.context);

        // Delay provider modification until after widget tree build is complete
        Future(() {
          // Check if navigating to camera screen - if so, dispose ALL controllers
          final isCameraScreen = routeName?.contains('Camera') ?? false;

          if (isCameraScreen) {
            // Dispose all video controllers when opening camera screen
            disposeAllVideoControllers(container);
            Log.info(
                '📱 Navigation $action to camera route: ${routeName ?? 'unnamed'} - disposed all video controllers',
                name: 'VideoStopNavigatorObserver',
                category: LogCategory.system);
          } else {
            // Router-driven architecture: route changes automatically pause videos via activeVideoIdProvider
            // No manual state management needed
            Log.info(
                '📱 Navigation $action to route: ${routeName ?? 'unnamed'} - videos will pause automatically via router',
                name: 'VideoStopNavigatorObserver',
                category: LogCategory.system);
          }
        });
      }
    } catch (e) {
      Log.error('Failed to handle navigation: $e',
          name: 'VideoStopNavigatorObserver', category: LogCategory.system);
    }
  }
}
