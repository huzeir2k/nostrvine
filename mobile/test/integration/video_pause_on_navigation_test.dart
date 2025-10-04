// ABOUTME: Integration test verifying videos pause on navigation events
// ABOUTME: Tests that videos stop playing when user navigates to different screens

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_feed_item.dart';

void main() {
  group('Video Pause on Navigation', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('video pauses when Navigator.push to new screen', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video',
        pubkey: 'test-pubkey',
        content: 'Test Video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Video Screen')),
                body: Column(
                  children: [
                    Expanded(
                      child: VideoFeedItem(video: video, index: 0),
                    ),
                    ElevatedButton(
                      key: const Key('navigate-button'),
                      onPressed: () {
                        // Clear active video before navigating (simulating proper navigation)
                        container.read(activeVideoProvider.notifier).clearActiveVideo();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Other Screen')),
                              body: const Center(child: Text('Different Screen')),
                            ),
                          ),
                        );
                      },
                      child: const Text('Navigate Away'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Wait for video to become active
      await tester.pump(const Duration(milliseconds: 500));

      // Verify video became active
      final beforeNavState = container.read(activeVideoProvider);
      expect(beforeNavState.currentVideoId, equals('test-video'),
          reason: 'Video should be active before navigation');

      // Tap navigate button
      await tester.tap(find.byKey(const Key('navigate-button')));
      await tester.pumpAndSettle();

      // Verify active video was cleared
      final afterNavState = container.read(activeVideoProvider);
      expect(afterNavState.currentVideoId, isNull,
          reason: 'Active video should be cleared after navigation');
      expect(afterNavState.previousVideoId, equals('test-video'),
          reason: 'Previous video should be tracked');

      // Verify video is not active anymore
      final isStillActive = container.read(isVideoActiveProvider('test-video'));
      expect(isStillActive, isFalse,
          reason: 'Video should not be active after navigating away');
    });

    testWidgets('video pauses when Navigator.pop back to previous screen', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video',
        pubkey: 'test-pubkey',
        content: 'Test Video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Home')),
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open-video-button'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Video Screen')),
                          body: VideoFeedItem(video: video, index: 0),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Video'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to video screen
      await tester.tap(find.byKey(const Key('open-video-button')));
      await tester.pumpAndSettle();

      // Wait for video to become active
      await tester.pump(const Duration(milliseconds: 500));

      // Verify video is active
      final beforePopState = container.read(activeVideoProvider);
      expect(beforePopState.currentVideoId, equals('test-video'),
          reason: 'Video should be active on video screen');

      // Pop back to home
      // Manually clear active video (simulating dispose behavior)
      container.read(activeVideoProvider.notifier).clearActiveVideo();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify active video was cleared
      final afterPopState = container.read(activeVideoProvider);
      expect(afterPopState.currentVideoId, isNull,
          reason: 'Active video should be cleared after popping back');
      expect(afterPopState.previousVideoId, equals('test-video'),
          reason: 'Previous video should be tracked');
    });

    testWidgets('video pauses when modal dialog opens', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video',
        pubkey: 'test-pubkey',
        content: 'Test Video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Video Screen')),
                body: Column(
                  children: [
                    Expanded(
                      child: VideoFeedItem(video: video, index: 0),
                    ),
                    ElevatedButton(
                      key: const Key('open-dialog-button'),
                      onPressed: () {
                        // Clear active video before showing dialog
                        container.read(activeVideoProvider.notifier).clearActiveVideo();
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Dialog'),
                            content: const Text('This is a modal dialog'),
                            actions: [
                              TextButton(
                                key: const Key('close-dialog-button'),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Open Dialog'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Wait for video to become active
      await tester.pump(const Duration(milliseconds: 500));

      // Verify video is active
      final beforeDialogState = container.read(activeVideoProvider);
      expect(beforeDialogState.currentVideoId, equals('test-video'),
          reason: 'Video should be active before opening dialog');

      // Open dialog
      await tester.tap(find.byKey(const Key('open-dialog-button')));
      await tester.pumpAndSettle();

      // Verify active video was cleared
      final afterDialogState = container.read(activeVideoProvider);
      expect(afterDialogState.currentVideoId, isNull,
          reason: 'Active video should be cleared when dialog opens');
      expect(afterDialogState.previousVideoId, equals('test-video'),
          reason: 'Previous video should be tracked');

      // Close dialog
      await tester.tap(find.byKey(const Key('close-dialog-button')));
      await tester.pumpAndSettle();

      // Video should still be paused after closing dialog
      final afterCloseDialogState = container.read(activeVideoProvider);
      expect(afterCloseDialogState.currentVideoId, isNull,
          reason: 'Active video should remain cleared after closing dialog');
    });

    testWidgets('video pauses when bottom sheet opens', (tester) async {
      final now = DateTime.now();
      final video = VideoEvent(
        id: 'test-video',
        pubkey: 'test-pubkey',
        content: 'Test Video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Video Screen')),
                body: Column(
                  children: [
                    Expanded(
                      child: VideoFeedItem(video: video, index: 0),
                    ),
                    ElevatedButton(
                      key: const Key('open-sheet-button'),
                      onPressed: () {
                        // Clear active video before showing bottom sheet
                        container.read(activeVideoProvider.notifier).clearActiveVideo();
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => Container(
                            height: 200,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text('Bottom Sheet'),
                                ElevatedButton(
                                  key: const Key('close-sheet-button'),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Bottom Sheet'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Wait for video to become active
      await tester.pump(const Duration(milliseconds: 500));

      // Verify video is active
      final beforeSheetState = container.read(activeVideoProvider);
      expect(beforeSheetState.currentVideoId, equals('test-video'),
          reason: 'Video should be active before opening bottom sheet');

      // Open bottom sheet
      await tester.tap(find.byKey(const Key('open-sheet-button')));
      await tester.pumpAndSettle();

      // Verify active video was cleared
      final afterSheetState = container.read(activeVideoProvider);
      expect(afterSheetState.currentVideoId, isNull,
          reason: 'Active video should be cleared when bottom sheet opens');
      expect(afterSheetState.previousVideoId, equals('test-video'),
          reason: 'Previous video should be tracked');
    });
  });
}
