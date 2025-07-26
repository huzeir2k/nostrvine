// ABOUTME: Tests for VideoNetworkService extracted from VideoEventService
// ABOUTME: Verifies network operations are properly isolated and functional

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_network_service.dart';

// Minimal mock that focuses on what we need
class MockNostrService extends Fake implements INostrService {
  final StreamController<Event> _eventController =
      StreamController<Event>.broadcast();
  int _connectedRelayCount = 3;

  @override
  int get connectedRelayCount => _connectedRelayCount;

  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
  }) =>
      _eventController.stream;

  void simulateEvent(Event event) {
    _eventController.add(event);
  }

  void simulateDisconnection() {
    _connectedRelayCount = 0;
  }

  void simulateConnection() {
    _connectedRelayCount = 3;
  }

  @override
  void dispose() {
    _eventController.close();
  }
}

// Query-specific mock for testing video lookup
class QueryMockNostrService extends MockNostrService {
  QueryMockNostrService(this.expectedVineId);
  final String expectedVineId;

  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
  }) {
    // Verify the filter is correct
    expect(filters.length, 1);
    expect(filters.first.kinds, contains(22));
    expect(filters.first.ids, contains(expectedVineId));

    // Return a stream with the expected event
    return Stream.value(
      Event(
        'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd', // 64-char hex pubkey
        22,
        [
          ['url', 'https://example.com/video.mp4']
        ],
        '{"url": "https://example.com/video.mp4"}',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      )..id = expectedVineId,
    );
  }
}

class MockSubscriptionManager extends Fake implements SubscriptionManager {
  final Map<String, List<Filter>> _activeSubscriptions = {};

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    _activeSubscriptions[subId] = filters;
    return subId;
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    _activeSubscriptions.remove(subscriptionId);
  }

  @override
  Future<void> unsubscribeByTag(String tag) async {
    // Not needed for these tests
  }

  bool hasSubscription(String subId) => _activeSubscriptions.containsKey(subId);

  List<Filter>? getFilters(String subId) => _activeSubscriptions[subId];
}

// Extension for capturing subscriptions
class CapturingMockSubscriptionManager extends MockSubscriptionManager {
  String? capturedSubId;
  List<Filter>? capturedFilters;

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    capturedFilters = filters;
    capturedSubId = await super.createSubscription(
      name: name,
      filters: filters,
      onEvent: onEvent,
      onError: onError,
      onComplete: onComplete,
      timeout: timeout,
      priority: priority,
    );
    return capturedSubId!;
  }
}

void main() {
  group('VideoNetworkService', () {
    late VideoNetworkService networkService;
    late MockNostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      mockSubscriptionManager = MockSubscriptionManager(TestNostrService());

      networkService = VideoNetworkService(
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      networkService.dispose();
      mockNostrService.dispose();
    });

    group('subscribeToVideoFeed', () {
      test('should throw when not connected to any relays', () async {
        // Arrange
        mockNostrService.simulateDisconnection();

        // Act & Assert
        expect(
          () => networkService.subscribeToVideoFeed(),
          throwsA(isA<ConnectionException>()),
        );
      });

      test('should create subscription with correct filters for hashtags',
          () async {
        // Arrange
        final capturingMock = CapturingMockSubscriptionManager(TestNostrService());

        networkService = VideoNetworkService(
          nostrService: mockNostrService,
          subscriptionManager: capturingMock,
        );

        // Act
        await networkService.subscribeToVideoFeed(
          hashtags: ['nostr', 'bitcoin'],
          limit: 25,
        );

        // Assert
        expect(capturingMock.capturedSubId, isNotNull);
        expect(capturingMock.capturedFilters, isNotNull);
        expect(capturingMock.capturedFilters!.length, 1);
        expect(capturingMock.capturedFilters!.first.kinds, contains(22));
        expect(capturingMock.capturedFilters!.first.t,
            containsAll(['nostr', 'bitcoin']));
        expect(capturingMock.capturedFilters!.first.limit, 25);
      });

      test('should handle video events correctly', () async {
        // Arrange
        final receivedEvents = <VideoEvent>[];
        networkService.videoEventStream.listen(receivedEvents.add);

        await networkService.subscribeToVideoFeed();

        // Create a test event with proper constructor
        final testEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // 64-char hex pubkey
          22, // kind
          [
            ['t', 'nostr'],
            ['url', 'https://example.com/video.mp4'],
          ],
          '{"url": "https://example.com/video.mp4"}',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        )..id = 'test_event_id';

        // Act
        mockNostrService.simulateEvent(testEvent);
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(receivedEvents.length, 1);
        expect(receivedEvents.first.pubkey,
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
        expect(receivedEvents.first.videoUrl, 'https://example.com/video.mp4');
      });

      test(
        'should handle subscription errors',
        () async {
          // Arrange
          final errors = <String>[];
          networkService.errorStream.listen(errors.add);

          // We need to modify our mock to support error simulation
          // For now, we'll skip this test
        },
        skip: 'Need to implement error simulation in mock',
      );

      test('should prevent duplicate subscriptions', () async {
        // Arrange
        await networkService.subscribeToVideoFeed(
          hashtags: ['bitcoin'],
          limit: 50,
        );

        // Act & Assert
        expect(
          () => networkService.subscribeToVideoFeed(
            hashtags: ['bitcoin'],
            limit: 50,
          ),
          throwsA(isA<DuplicateSubscriptionException>()),
        );
      });
    });

    group('unsubscribe', () {
      test('should cancel active subscriptions', () async {
        // Arrange
        await networkService.subscribeToVideoFeed();
        expect(networkService.isSubscribed, isTrue);

        // Act
        await networkService.unsubscribe();

        // Assert
        expect(networkService.isSubscribed, isFalse);
      });
    });

    group('queryVideoByVineId', () {
      test('should query for specific video event', () async {
        // Arrange
        const vineId = 'test_vine_id';
        final customMock = QueryMockNostrService(vineId);

        networkService = VideoNetworkService(
          nostrService: customMock,
          subscriptionManager: mockSubscriptionManager,
        );

        // Act
        final video = await networkService.queryVideoByVineId(vineId);

        // Assert
        expect(video, isNotNull);
        expect(video!.pubkey,
            'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd');
        expect(video.videoUrl, 'https://example.com/video.mp4');

        customMock.dispose();
      });
    });
  });
}
