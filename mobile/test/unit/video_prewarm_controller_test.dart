// ABOUTME: Unit tests for video prewarming logic without widget/timer dependencies
// ABOUTME: Tests the controller creation logic for active and prewarmed videos

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/individual_video_providers.dart';

void main() {
  group('Video Prewarming Logic', () {
    test('PrewarmManager stores prewarmed video IDs with cap', () {
      final manager = PrewarmManager();

      // Set prewarmed videos with cap of 3
      manager.setPrewarmed(['video1', 'video2', 'video3', 'video4'], cap: 3);

      // Should only keep first 3
      expect(manager.state.length, 3);
      expect(manager.state.contains('video1'), isTrue);
      expect(manager.state.contains('video2'), isTrue);
      expect(manager.state.contains('video3'), isTrue);
      expect(manager.state.contains('video4'), isFalse);
    });

    test('PrewarmManager handles empty list', () {
      final manager = PrewarmManager();

      manager.setPrewarmed(['video1', 'video2']);
      expect(manager.state.length, 2);

      // Clear by setting empty list
      manager.setPrewarmed([]);
      expect(manager.state.isEmpty, isTrue);
    });

    test('PrewarmManager clear() removes all prewarmed videos', () {
      final manager = PrewarmManager();

      manager.setPrewarmed(['video1', 'video2', 'video3']);
      expect(manager.state.length, 3);

      manager.clear();
      expect(manager.state.isEmpty, isTrue);
    });

    test('PrewarmManager does not update state if same videos', () {
      final manager = PrewarmManager();

      manager.setPrewarmed(['video1', 'video2'], cap: 3);
      final firstState = manager.state;

      // Set same videos again
      manager.setPrewarmed(['video1', 'video2'], cap: 3);
      final secondState = manager.state;

      // State should be identical (same object reference)
      expect(identical(firstState, secondState), isTrue);
    });

    test('ActiveVideoNotifier tracks current and previous video', () {
      final notifier = ActiveVideoNotifier();

      expect(notifier.state.currentVideoId, isNull);
      expect(notifier.state.previousVideoId, isNull);

      // Set first video
      notifier.setActiveVideo('video1');
      expect(notifier.state.currentVideoId, 'video1');
      expect(notifier.state.previousVideoId, isNull);

      // Set second video
      notifier.setActiveVideo('video2');
      expect(notifier.state.currentVideoId, 'video2');
      expect(notifier.state.previousVideoId, 'video1');

      // Clear active video
      notifier.clearActiveVideo();
      expect(notifier.state.currentVideoId, isNull);
      expect(notifier.state.previousVideoId, 'video2');
    });

    test('ActiveVideoNotifier does not update if same video set as active', () {
      final notifier = ActiveVideoNotifier();

      notifier.setActiveVideo('video1');
      final firstState = notifier.state;

      // Set same video again
      notifier.setActiveVideo('video1');
      final secondState = notifier.state;

      // State should be identical (not updated)
      expect(identical(firstState, secondState), isTrue);
    });
  });
}
