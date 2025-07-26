// ABOUTME: Unit test to reproduce duplicate video preload/resume bug in VideoManager
// ABOUTME: Tests the core video manager behavior without UI dependencies

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_manager_providers.dart';
import '../../builders/test_video_event_builder.dart';
// Helper function to create test videos
VideoEvent createTestVideo({String? id, String? title}) {
  return TestVideoEventBuilder.create(id: id, title: title);
}

void main() {
  group('VideoManager Duplicate Bug Reproduction', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('multiple preloadVideo calls should not create duplicate controllers', () async {
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // Verify initial state has no controllers
      var currentState = container.read(videoManagerProvider);
      expect(currentState.controllers.length, equals(0));
      expect(currentState.hasController(testVideo.id), isFalse);
      
      // Call preloadVideo multiple times rapidly (simulating the duplicate bug)
      print('🔍 TEST: Calling preloadVideo multiple times for ${testVideo.id.substring(0, 8)}...');
      
      // This should not create multiple controllers
      await videoManager.preloadVideo(testVideo.id);
      await videoManager.preloadVideo(testVideo.id);
      await videoManager.preloadVideo(testVideo.id);
      
      // Check final state
      currentState = container.read(videoManagerProvider);
      
      print('🔍 TEST: Final controller count: ${currentState.controllers.length}');
      print('🔍 TEST: Controllers for this video: ${currentState.controllers.keys.where((id) => id == testVideo.id).length}');
      
      // Should have exactly one controller for this video
      final videoControllers = currentState.controllers.keys
          .where((id) => id == testVideo.id)
          .length;
      
      expect(
        videoControllers,
        equals(1),
        reason: 'Expected exactly 1 controller for video ${testVideo.id.substring(0, 8)}, '
            'but found $videoControllers controllers. Multiple preloadVideo calls created duplicates.',
      );
      
      // Should have only one controller total
      expect(
        currentState.controllers.length,
        equals(1),
        reason: 'Expected exactly 1 total controller, '
            'but found ${currentState.controllers.length} controllers.',
      );
    });

    test('preload then resume operations should be idempotent', () async {
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // Initial preload
      print('🔍 TEST: Initial preload for ${testVideo.id.substring(0, 8)}...');
      await videoManager.preloadVideo(testVideo.id);
      
      var currentState = container.read(videoManagerProvider);
      final afterPreloadCount = currentState.controllers.length;
      print('🔍 TEST: Controllers after initial preload: $afterPreloadCount');
      
      // Multiple resume calls (this was part of the duplicate pattern in logs)
      print('🔍 TEST: Multiple resume calls...');
      videoManager.resumeVideo(testVideo.id);
      videoManager.resumeVideo(testVideo.id);
      videoManager.resumeVideo(testVideo.id);
      
      // Multiple pause calls
      print('🔍 TEST: Multiple pause calls...');
      videoManager.pauseVideo(testVideo.id);
      videoManager.pauseVideo(testVideo.id);
      
      // More resume calls (like scroll behavior)
      print('🔍 TEST: More resume calls (scroll simulation)...');
      videoManager.resumeVideo(testVideo.id);
      videoManager.resumeVideo(testVideo.id);
      
      currentState = container.read(videoManagerProvider);
      final finalControllerCount = currentState.controllers.length;
      
      print('🔍 TEST: Final controller count: $finalControllerCount');
      
      // Should still have exactly one controller
      expect(
        finalControllerCount,
        equals(afterPreloadCount),
        reason: 'Resume/pause operations should not create additional controllers. '
            'Started with $afterPreloadCount, ended with $finalControllerCount.',
      );
      
      // Should still have exactly one controller for this video
      final videoControllers = currentState.controllers.keys
          .where((id) => id == testVideo.id)
          .length;
      
      expect(
        videoControllers,
        equals(1),
        reason: 'Should still have exactly 1 controller for video after resume/pause operations.',
      );
    });

    test('rapid scroll simulation should not create duplicates', () async {
      // Create multiple videos to simulate scroll behavior
      final videos = List.generate(3, (index) => VideoEvent(
        id: 'scroll-test-$index',
        pubkey: 'test-pubkey',
        content: 'Scroll test video $index',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
        videoUrl: 'https://test.cloudinary.com/scroll$index.mp4',
      ));
      
      final videoManager = container.read(videoManagerProvider.notifier);
      
      print('🔍 TEST: Simulating rapid scroll through ${videos.length} videos...');
      
      // Simulate rapid scrolling - this was the pattern that created duplicates
      for (int i = 0; i < videos.length; i++) {
        final video = videos[i];
        print('🔍 TEST: Scrolling to video $i: ${video.id.substring(0, 8)}...');
        
        // Pause previous videos (like real scroll behavior)
        for (int j = 0; j < i; j++) {
          videoManager.pauseVideo(videos[j].id);
        }
        
        // Preload current video - this could be called multiple times in rapid succession
        await videoManager.preloadVideo(video.id);
        await videoManager.preloadVideo(video.id); // Duplicate call
        
        // Resume current video
        videoManager.resumeVideo(video.id);
        videoManager.resumeVideo(video.id); // Duplicate call
      }
      
      final finalState = container.read(videoManagerProvider);
      
      print('🔍 TEST: Final state after scroll simulation:');
      print('🔍 TEST: Total controllers: ${finalState.controllers.length}');
      
      // Each video should have exactly one controller
      for (int i = 0; i < videos.length; i++) {
        final video = videos[i];
        final videoControllers = finalState.controllers.keys
            .where((id) => id == video.id)
            .length;
        
        print('🔍 TEST: Video $i (${video.id.substring(0, 8)}): $videoControllers controllers');
        
        expect(
          videoControllers,
          equals(1),
          reason: 'Video ${video.id.substring(0, 8)} should have exactly 1 controller, '
              'but found $videoControllers. Rapid scroll created duplicates.',
        );
      }
      
      // Total controllers should equal number of videos
      expect(
        finalState.controllers.length,
        equals(videos.length),
        reason: 'Should have exactly ${videos.length} controllers for ${videos.length} videos, '
            'but found ${finalState.controllers.length} controllers.',
      );
    });

    test('_syncVideosFromFeed equivalent behavior should not create duplicates', () async {
      final testVideo = createTestVideo();
      final videoManager = container.read(videoManagerProvider.notifier);
      
      // Simulate the behavior of _syncVideosFromFeed calling _addVideoEvent multiple times
      // This was suspected to be part of the duplicate issue
      
      print('🔍 TEST: Simulating feed sync behavior...');
      
      // First sync - add video
      await videoManager.preloadVideo(testVideo.id);
      
      var currentState = container.read(videoManagerProvider);
      final afterFirstSync = currentState.controllers.length;
      print('🔍 TEST: Controllers after first sync: $afterFirstSync');
      
      // Second sync - same video (should not duplicate)
      await videoManager.preloadVideo(testVideo.id);
      
      // Third sync - same video (should not duplicate)
      await videoManager.preloadVideo(testVideo.id);
      
      currentState = container.read(videoManagerProvider);
      final afterMultipleSync = currentState.controllers.length;
      
      print('🔍 TEST: Controllers after multiple syncs: $afterMultipleSync');
      
      expect(
        afterMultipleSync,
        equals(afterFirstSync),
        reason: 'Multiple sync operations should not create duplicate controllers. '
            'Started with $afterFirstSync, ended with $afterMultipleSync.',
      );
      
      // Should have exactly one controller for the video
      final videoControllers = currentState.controllers.keys
          .where((id) => id == testVideo.id)
          .length;
      
      expect(
        videoControllers,
        equals(1),
        reason: 'Should have exactly 1 controller for the video after multiple sync operations.',
      );
    });
  });
}