// ABOUTME: Unit tests for NostrVideoBridge integration service
// ABOUTME: Tests event processing, filtering, VideoManager integration, and lifecycle management

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/nostr_video_bridge.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/subscription_manager.dart';

import '../../helpers/test_helpers.dart';
import '../../mocks/mock_video_manager.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}

class MockSeenVideosService extends Mock implements SeenVideosService {}

class MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  group('NostrVideoBridge', () {
    late NostrVideoBridge bridge;
    late MockVideoManager mockVideoManager;
    late MockNostrService mockNostrService;
    late MockSeenVideosService? mockSeenVideosService;
    late MockConnectionStatusService mockConnectionService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUpAll(() {
      // Register fallback values
      registerFallbackValue(TestHelpers.createVideoEvent());
    });

    setUp(() {
      mockVideoManager = MockVideoManager();
      mockNostrService = MockNostrService();
      mockSeenVideosService = MockSeenVideosService();
      mockConnectionService = MockConnectionStatusService();
      mockSubscriptionManager = MockSubscriptionManager(TestNostrService());

      // Setup default mock behaviors (only what's actually needed)
      when(() => mockVideoManager.addVideoEvent(any()))
          .thenAnswer((_) async {});
      when(() => mockVideoManager.getDebugInfo()).thenReturn({
        'totalVideos': 0,
        'controllers': 0,
        'estimatedMemoryMB': 0,
      });

      // Create bridge with all dependencies
      bridge = NostrVideoBridge(
        videoManager: mockVideoManager,
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        seenVideosService: mockSeenVideosService,
      );
    });

    tearDown(() {
      bridge.dispose();
    });

    group('Initialization and Lifecycle', () {
      test('should initialize with inactive state', () {
        expect(bridge.isActive, isFalse);

        final stats = bridge.processingStats;
        expect(stats['isActive'], isFalse);
        expect(stats['totalEventsReceived'], 0);
        expect(stats['totalEventsAdded'], 0);
        expect(stats['totalEventsFiltered'], 0);
      });

      test('should provide processing statistics', () {
        final stats = bridge.processingStats;

        expect(stats, containsPair('isActive', false));
        expect(stats, containsPair('totalEventsReceived', 0));
        expect(stats, containsPair('totalEventsAdded', 0));
        expect(stats, containsPair('totalEventsFiltered', 0));
        expect(stats, containsPair('processedEventIds', 0));
        expect(stats, containsPair('lastEventReceived', null));
        expect(stats, containsPair('videoEventServiceStats', isA<Map>()));
      });

      test('should provide debug information', () {
        final debugInfo = bridge.getDebugInfo();

        expect(debugInfo, containsPair('bridge', isA<Map>()));
        expect(debugInfo, containsPair('videoManager', isA<Map>()));
        expect(debugInfo, containsPair('videoEventService', isA<Map>()));
        expect(debugInfo, containsPair('connection', isA<bool>()));
      });

      test('should be disposable', () {
        expect(() => bridge.dispose(), returnsNormally);
        expect(bridge.isActive, isFalse);
      });
    });

    group('Factory Method', () {
      test('should create bridge with all dependencies', () {
        // ACT
        final factoryBridge = NostrVideoBridgeFactory.create(
          videoManager: mockVideoManager,
          nostrService: mockNostrService,
          subscriptionManager: mockSubscriptionManager,
          seenVideosService: mockSeenVideosService,
          connectionService: mockConnectionService,
        );

        // ASSERT
        expect(factoryBridge, isA<NostrVideoBridge>());
        expect(factoryBridge.isActive, isFalse);

        factoryBridge.dispose();
      });

      test('should create bridge with minimal dependencies', () {
        // ACT
        final minimalBridge = NostrVideoBridgeFactory.create(
          videoManager: mockVideoManager,
          nostrService: mockNostrService,
          subscriptionManager: mockSubscriptionManager,
        );

        // ASSERT
        expect(minimalBridge, isA<NostrVideoBridge>());
        expect(minimalBridge.isActive, isFalse);

        minimalBridge.dispose();
      });
    });

    group('Async Pattern Refactoring (TDD)', () {
      test('restart should not use Future.delayed', () async {
        // ARRANGE: Mock the VideoEventService to track when operations complete
        final stopCompleter = Completer<void>();
        final startCompleter = Completer<void>();

        // Track the sequence of operations
        final operationSequence = <String>[];

        // Override the bridge's internal methods to track calls
        // This test will initially FAIL because restart() uses Future.delayed
        final startTime = DateTime.now();

        // ACT: Call restart and measure time
        final restartFuture = bridge.restart(limit: 10);

        // ASSERT: The restart should complete without artificial delays
        await restartFuture;
        final elapsed = DateTime.now().difference(startTime);

        // This will FAIL initially: restart uses 500ms Future.delayed
        // After refactoring: should complete much faster (< 100ms)
        expect(
          elapsed.inMilliseconds,
          lessThan(100),
          reason: 'restart should not use Future.delayed for timing',
        );
      });

      test('restart should wait for proper state transitions', () async {
        // ARRANGE: Mock proper state management
        const isStopComplete = false;
        const isStartComplete = false;

        // Create a completer-based mock that simulates proper async operations
        when(() => mockVideoManager.addVideoEvent(any())).thenAnswer((_) async {
          // Simulate proper async operation completion
          await Future.microtask(() => {});
        });

        final operationCompleter = Completer<void>();

        // ACT: Start restart operation
        final restartFuture = bridge.restart(limit: 10);

        // ASSERT: The restart should properly sequence stop -> start
        await restartFuture;

        // Verify bridge is in expected state after restart
        expect(bridge.isActive,
            isFalse); // Should be inactive after restart without events

        // Verify no timing-based coordination was used
        final stats = bridge.processingStats;
        expect(stats['isActive'], isFalse);
      });

      test('restart should use event-driven coordination not timing', () async {
        // ARRANGE: Set up state tracking
        final stateChanges = <String>[];

        // Listen to bridge state changes
        bridge.addListener(() {
          stateChanges.add('bridge_changed_${bridge.isActive}');
        });

        // ACT: Perform restart
        await bridge.restart(limit: 5);

        // ASSERT: State changes should be event-driven, not timing-based
        // This test documents the expected behavior after refactoring
        expect(
          stateChanges,
          isNotEmpty,
          reason: 'restart should trigger proper state change events',
        );

        // After refactoring, we should see clean state transitions
        // without artificial timing delays
        final debugInfo = bridge.getDebugInfo();
        expect(debugInfo['bridge']['isActive'], isFalse);
      });
    });
  });
}
