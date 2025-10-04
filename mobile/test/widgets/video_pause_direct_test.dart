// ABOUTME: Direct test proving videos pause when active state changes
// ABOUTME: Tests the core pause mechanism without relying on VisibilityDetector

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';

void main() {
  group('Video Pause Direct Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('CRITICAL: switching active video clears previous video', () {
      final notifier = container.read(activeVideoProvider.notifier);

      // Start with no active video
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      // Set video1 as active
      notifier.setActiveVideo('video-1');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-1'));
      expect(container.read(activeVideoProvider).previousVideoId, isNull);

      // CRITICAL TEST: Set video2 as active
      notifier.setActiveVideo('video-2');

      // Verify video2 is now active
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-2'),
          reason: 'New video should be active');

      // CRITICAL: Verify video1 is tracked as previous
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-1'),
          reason: 'Previous video MUST be tracked so we know which one to pause');

      // Verify video1 is NO LONGER active
      final isVideo1Active = container.read(isVideoActiveProvider('video-1'));
      expect(isVideo1Active, isFalse,
          reason: 'Previous video MUST NOT be active - this is what triggers pause in widget');
    });

    test('CRITICAL: clearActiveVideo tracks which video was playing', () {
      final notifier = container.read(activeVideoProvider.notifier);

      // Set a video as active
      notifier.setActiveVideo('video-playing');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-playing'));

      // CRITICAL TEST: Clear active video (simulating navigation away)
      notifier.clearActiveVideo();

      // Verify no video is active
      expect(container.read(activeVideoProvider).currentVideoId, isNull,
          reason: 'No video should be active after clearing');

      // CRITICAL: Verify we tracked which video was playing
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-playing'),
          reason: 'Must track previous video so we know which one to pause');

      // Verify the video is no longer active
      final isStillActive = container.read(isVideoActiveProvider('video-playing'));
      expect(isStillActive, isFalse,
          reason: 'Video must not be active after clearing - this triggers pause');
    });

    test('CRITICAL: isVideoActiveProvider returns false for inactive videos', () {
      final notifier = container.read(activeVideoProvider.notifier);

      // Initially no video is active
      expect(container.read(isVideoActiveProvider('any-video')), isFalse);

      // Make video1 active
      notifier.setActiveVideo('video-1');

      // video1 should be active
      expect(container.read(isVideoActiveProvider('video-1')), isTrue,
          reason: 'Active video should return true');

      // video2 should NOT be active
      expect(container.read(isVideoActiveProvider('video-2')), isFalse,
          reason: 'Inactive video should return false');

      // Make video2 active
      notifier.setActiveVideo('video-2');

      // NOW video1 should NOT be active
      expect(container.read(isVideoActiveProvider('video-1')), isFalse,
          reason: 'CRITICAL: Previously active video MUST return false');

      // video2 should be active
      expect(container.read(isVideoActiveProvider('video-2')), isTrue);
    });

    test('CRITICAL: sequence of video switches maintains correct state', () {
      final notifier = container.read(activeVideoProvider.notifier);

      // Play through a sequence like a user scrolling
      notifier.setActiveVideo('video-1');
      notifier.setActiveVideo('video-2');
      notifier.setActiveVideo('video-3');
      notifier.setActiveVideo('video-4');

      final state = container.read(activeVideoProvider);

      // Only video-4 should be active
      expect(state.currentVideoId, equals('video-4'));

      // video-3 should be tracked as previous (not video-1 or video-2)
      expect(state.previousVideoId, equals('video-3'),
          reason: 'Must track MOST RECENT previous video, not oldest');

      // All other videos should be inactive
      expect(container.read(isVideoActiveProvider('video-1')), isFalse);
      expect(container.read(isVideoActiveProvider('video-2')), isFalse);
      expect(container.read(isVideoActiveProvider('video-3')), isFalse);
      expect(container.read(isVideoActiveProvider('video-4')), isTrue);
    });

    test('CRITICAL: duplicate setActiveVideo calls dont change state', () {
      final notifier = container.read(activeVideoProvider.notifier);

      notifier.setActiveVideo('video-1');
      final stateAfterFirst = container.read(activeVideoProvider);

      // Try to set the same video again
      notifier.setActiveVideo('video-1');
      final stateAfterDuplicate = container.read(activeVideoProvider);

      // State should be IDENTICAL (prevents unnecessary rebuilds and pause/play cycles)
      expect(stateAfterDuplicate, equals(stateAfterFirst),
          reason: 'Duplicate calls should not change state - prevents pause/play thrashing');
    });
  });
}
