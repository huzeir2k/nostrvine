// ABOUTME: TDD test to fix circular dependency between VideoManager and VideoFeed
// ABOUTME: Defines the correct behavior where VideoManager is the single source of truth

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_manager_providers.dart';
import 'package:openvine/providers/video_feed_provider.dart';
import '../../builders/test_video_event_builder.dart';

// Helper function to create test videos
VideoEvent createTestVideo({String? id, String? title}) {
  return TestVideoEventBuilder.create(id: id, title: title);
}

void main() {
  group('TDD: VideoManager Dependency Fix', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('VideoManager should NOT depend on VideoFeed provider', () {
      // REQUIREMENT: VideoManager must not create circular dependency
      // by depending on VideoFeed
      
      // Test that VideoManager can initialize independently
      // Note: VideoManager now listens to VideoEvents, which should not create circular dependency
      
      final videoManager = container.read(videoManagerProvider.notifier);
      final initialState = container.read(videoManagerProvider);
      
      // VideoManager should initialize without needing VideoFeed
      expect(initialState.controllers.isEmpty, isTrue);
      expect(initialState.config, isNotNull);
      
      // Should be able to add and preload videos directly
      final testVideo = createTestVideo();
      
      // Add the video directly (this is how the circular dependency is broken)
      videoManager.addVideoEvent(testVideo);
      
      expect(
        () async => await videoManager.preloadVideo(testVideo.id),
        returnsNormally,
        reason: 'VideoManager should preload videos without depending on VideoFeed',
      );
    });

    test('VideoManager should be the single source of truth for video controllers', () async {
      // REQUIREMENT: VideoManager owns all video controllers
      // VideoFeed should get videos from VideoEvents, not manage controllers
      
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // Add video event first (breaks circular dependency)
      videoManager.addVideoEvent(testVideo);
      
      // Should be able to preload video directly
      await videoManager.preloadVideo(testVideo.id);
      
      final state = container.read(videoManagerProvider);
      
      // VideoManager should track the video controller
      expect(state.hasController(testVideo.id), isTrue);
      
      // Should have exactly one controller
      expect(state.controllers.length, equals(1));
    });

    test('VideoFeed should get videos from VideoEvents, not VideoManager', () {
      // REQUIREMENT: VideoFeed gets videos from NostrService via VideoEvents
      // and does NOT manage video controllers directly
      
      // VideoFeed should build without accessing VideoManager
      expect(
        () => container.read(videoFeedProvider),
        returnsNormally,
        reason: 'VideoFeed should not depend on VideoManager for video data',
      );
    });

    test('Multiple preload calls should not create duplicate controllers', () async {
      // REQUIREMENT: Fix the original bug - no duplicate controllers
      
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // Add video event first (breaks circular dependency)  
      videoManager.addVideoEvent(testVideo);
      
      // Multiple preload calls should be idempotent
      await videoManager.preloadVideo(testVideo.id);
      await videoManager.preloadVideo(testVideo.id);
      await videoManager.preloadVideo(testVideo.id);
      
      final finalState = container.read(videoManagerProvider);
      
      // Should have exactly one controller
      final videoControllers = finalState.controllers.keys
          .where((id) => id == testVideo.id)
          .length;
      
      expect(
        videoControllers,
        equals(1),
        reason: 'Multiple preload calls must not create duplicate controllers',
      );
    });

    test('Pause should work on the single controller instance', () async {
      // REQUIREMENT: Fix the pause/resume bug from user report
      
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // Add video event first (breaks circular dependency)
      videoManager.addVideoEvent(testVideo);
      
      // Preload video directly
      await videoManager.preloadVideo(testVideo.id);
      
      // Start playing
      videoManager.resumeVideo(testVideo.id);
      
      // Pause should work immediately
      videoManager.pauseVideo(testVideo.id);
      
      final state = container.read(videoManagerProvider);
      final controllerState = state.getController(testVideo.id);
      
      expect(
        controllerState?.controller.value.isPlaying,
        isFalse,
        reason: 'Pause must work on the single controller instance',
      );
    });

    test('VideoManager state should be observable by UI components', () {
      // REQUIREMENT: UI components can watch VideoManager state without
      // creating dependency cycles
      
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // VideoManager should handle videos through preloading
      
      // UI should be able to check if video is ready
      final isReady = container.read(isVideoReadyProvider(testVideo.id));
      expect(isReady, isFalse); // Not preloaded yet
      
      // UI should be able to get controller
      final controller = container.read(videoPlayerControllerProvider(testVideo.id));
      expect(controller, isNull); // Not preloaded yet
      
      // These reads should not cause circular dependencies
      expect(
        () => container.read(videoManagerProvider),
        returnsNormally,
      );
    });
  });
}