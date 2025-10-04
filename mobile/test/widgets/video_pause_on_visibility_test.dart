// ABOUTME: Widget test verifying videos pause when scrolled out of view
// ABOUTME: Tests the core visibility-based pause behavior using VisibilityDetector

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_feed_item.dart';

void main() {
  group('Video Pause on Visibility Change', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('video pauses when scrolled out of view', (tester) async {
      // Create two test videos
      final now = DateTime.now();
      // Create two test videos
      final video1 = VideoEvent(
        id: 'test-video-1',
        pubkey: 'test-pubkey',
        content: 'Test Video 1',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video1.mp4',
        timestamp: now,
      );

      final video2 = VideoEvent(
        id: 'test-video-2',
        pubkey: 'test-pubkey',
        content: 'Test Video 2',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video2.mp4',
        timestamp: now,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ListView(
                  children: [
                    // First video - initially visible
                    SizedBox(
                      height: 600,
                      child: VideoFeedItem(video: video1, index: 0),
                    ),
                    // Second video - initially off-screen
                    SizedBox(
                      height: 600,
                      child: VideoFeedItem(video: video2, index: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify video1 is initially active
      final initialActiveState = container.read(activeVideoProvider);
      expect(initialActiveState.currentVideoId, equals('test-video-1'),
          reason: 'First video should be active initially');

      // Check that video1 is considered active
      final isVideo1Active = container.read(isVideoActiveProvider('test-video-1'));
      expect(isVideo1Active, isTrue,
          reason: 'Video 1 should be marked as active');

      // Scroll down to show video2 and hide video1
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Wait for visibility detector to process
      await tester.pump(const Duration(milliseconds: 100));

      // Verify active video changed to video2
      final afterScrollActiveState = container.read(activeVideoProvider);
      expect(afterScrollActiveState.currentVideoId, equals('test-video-2'),
          reason: 'Second video should be active after scrolling');
      expect(afterScrollActiveState.previousVideoId, equals('test-video-1'),
          reason: 'First video should be tracked as previous');

      // Verify video1 is no longer active
      final isVideo1StillActive = container.read(isVideoActiveProvider('test-video-1'));
      expect(isVideo1StillActive, isFalse,
          reason: 'Video 1 should not be active after scrolling away');

      // Verify video2 is now active
      final isVideo2Active = container.read(isVideoActiveProvider('test-video-2'));
      expect(isVideo2Active, isTrue,
          reason: 'Video 2 should be active after scrolling to it');
    });

    testWidgets('video pauses when another video is tapped', (tester) async {
      final now = DateTime.now();
      final video1 = VideoEvent(
        id: 'test-video-1',
        pubkey: 'test-pubkey',
        content: 'Test Video 1',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video1.mp4',
        timestamp: now,
      );

      final video2 = VideoEvent(
        id: 'test-video-2',
        pubkey: 'test-pubkey',
        content: 'Test Video 2',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        videoUrl: 'https://example.com/video2.mp4',
        timestamp: now,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: VideoFeedItem(video: video1, index: 0),
                  ),
                  Expanded(
                    child: VideoFeedItem(video: video2, index: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Wait for visibility to settle
      await tester.pump(const Duration(milliseconds: 500));

      // One of the videos should be active (whichever visibility detector fired first)
      final initialActiveState = container.read(activeVideoProvider);
      final initialActiveId = initialActiveState.currentVideoId;
      expect(initialActiveId, isNotNull, reason: 'One video should be active initially');

      // Tap the other video
      final videoToTap = initialActiveId == video1.id ? video2 : video1;
      final tapFinder = find.byKey(Key('video_${videoToTap.id}'));

      await tester.tap(tapFinder);
      await tester.pumpAndSettle();

      // Verify active video changed
      final afterTapActiveState = container.read(activeVideoProvider);
      expect(afterTapActiveState.currentVideoId, equals(videoToTap.id),
          reason: 'Tapped video should become active');
      expect(afterTapActiveState.previousVideoId, equals(initialActiveId),
          reason: 'Previous video should be tracked');

      // Verify previous video is no longer active
      final isPreviousStillActive = container.read(isVideoActiveProvider(initialActiveId!));
      expect(isPreviousStillActive, isFalse,
          reason: 'Previous video should not be active after tapping different video');
    });

    test('activeVideoProvider tracks previous video ID correctly', () {
      final notifier = container.read(activeVideoProvider.notifier);

      // Initially no active video
      expect(container.read(activeVideoProvider).currentVideoId, isNull);
      expect(container.read(activeVideoProvider).previousVideoId, isNull);

      // Set first video as active
      notifier.setActiveVideo('video-1');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-1'));
      expect(container.read(activeVideoProvider).previousVideoId, isNull,
          reason: 'No previous video on first activation');

      // Set second video as active
      notifier.setActiveVideo('video-2');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-2'));
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-1'),
          reason: 'Previous video should be tracked');

      // Set third video as active
      notifier.setActiveVideo('video-3');
      expect(container.read(activeVideoProvider).currentVideoId, equals('video-3'));
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-2'),
          reason: 'Previous video should update to most recent');

      // Clear active video
      notifier.clearActiveVideo();
      expect(container.read(activeVideoProvider).currentVideoId, isNull);
      expect(container.read(activeVideoProvider).previousVideoId, equals('video-3'),
          reason: 'Previous video should be tracked even after clearing');
    });

    test('setActiveVideo ignores duplicate calls', () {
      final notifier = container.read(activeVideoProvider.notifier);

      notifier.setActiveVideo('video-1');
      final stateAfterFirst = container.read(activeVideoProvider);

      // Try to set the same video again
      notifier.setActiveVideo('video-1');
      final stateAfterDuplicate = container.read(activeVideoProvider);

      expect(stateAfterDuplicate, equals(stateAfterFirst),
          reason: 'State should not change when setting same video as active');
      expect(stateAfterDuplicate.currentVideoId, equals('video-1'));
      expect(stateAfterDuplicate.previousVideoId, isNull,
          reason: 'Previous should still be null since no actual transition occurred');
    });
  });
}
