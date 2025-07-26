// ABOUTME: Tests for VideoSubscriptionService focusing on subscription lifecycle
// ABOUTME: Validates subscription creation, cancellation, and parameter tracking

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_subscription_service.dart';

// Minimal mock for NostrService
class MockNostrService extends Fake implements INostrService {
  int _connectedRelayCount = 3;

  @override
  int get connectedRelayCount => _connectedRelayCount;

  void simulateDisconnection() {
    _connectedRelayCount = 0;
  }
}

// Mock subscription manager
class MockSubscriptionManager extends Fake implements SubscriptionManager {
  final Map<String, List<Filter>> _activeSubscriptions = {};
  int _counter = 0;

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
    final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
    _activeSubscriptions[subId] = filters;
    return subId;
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    _activeSubscriptions.remove(subscriptionId);
  }
}

void main() {
  group('VideoSubscriptionService', () {
    late VideoSubscriptionService subscriptionService;
    late MockNostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrService();
      mockSubscriptionManager = MockSubscriptionManager(TestNostrService());

      subscriptionService = VideoSubscriptionService(
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    group('createVideoSubscription', () {
      test('should throw when not connected to any relays', () async {
        // Arrange
        mockNostrService.simulateDisconnection();

        // Act & Assert
        expect(
          () => subscriptionService.createVideoSubscription(
            onEvent: (_) {},
          ),
          throwsA(isA<ConnectionException>()),
        );
      });

      test('should create subscription with correct filters', () async {
        // Arrange
        final receivedEvents = <Event>[];

        // Act
        final subId = await subscriptionService.createVideoSubscription(
          hashtags: ['nostr', 'bitcoin'],
          limit: 25,
          onEvent: receivedEvents.add,
        );

        // Assert
        expect(subId, isNotEmpty);
        expect(subscriptionService.isSubscribed, isTrue);
        expect(subscriptionService.activeSubscriptionId, subId);
      });

      test('should prevent duplicate subscriptions with same parameters',
          () async {
        // Arrange
        await subscriptionService.createVideoSubscription(
          hashtags: ['bitcoin'],
          limit: 50,
          onEvent: (_) {},
        );

        // Act & Assert
        expect(
          () => subscriptionService.createVideoSubscription(
            hashtags: ['bitcoin'],
            limit: 50,
            onEvent: (_) {},
          ),
          throwsA(isA<DuplicateSubscriptionException>()),
        );
      });

      test('should cancel existing subscription before creating new one',
          () async {
        // Arrange
        final firstSubId = await subscriptionService.createVideoSubscription(
          hashtags: ['nostr'],
          onEvent: (_) {},
        );

        // Act
        final secondSubId = await subscriptionService.createVideoSubscription(
          hashtags: ['bitcoin'],
          onEvent: (_) {},
        );

        // Assert
        expect(secondSubId, isNot(equals(firstSubId)));
        expect(subscriptionService.activeSubscriptionId, secondSubId);
      });

      test('should build correct filters for video and reposts', () async {
        // Arrange
        final filters = <Filter>[];

        // Create a custom mock to capture filters
        final capturingMock = MockSubscriptionManager(TestNostrService());
        subscriptionService = VideoSubscriptionService(
          nostrService: mockNostrService,
          subscriptionManager: capturingMock,
        );

        // Act
        await subscriptionService.createVideoSubscription(
          includeReposts: true,
          hashtags: ['vine'],
          limit: 100,
          onEvent: (_) {},
        );

        // Assert - we expect 2 filters (video + repost)
        expect(capturingMock._activeSubscriptions.values.first.length, 2);

        final videoFilter = capturingMock._activeSubscriptions.values.first[0];
        expect(videoFilter.kinds, contains(22));
        expect(videoFilter.t, contains('vine'));
        expect(videoFilter.limit, 100);

        final repostFilter = capturingMock._activeSubscriptions.values.first[1];
        expect(repostFilter.kinds, contains(6));
        expect(repostFilter.limit, 50); // Half of video limit
      });
    });

    group('cancelSubscription', () {
      test('should cancel active subscription', () async {
        // Arrange
        await subscriptionService.createVideoSubscription(
          onEvent: (_) {},
        );
        expect(subscriptionService.isSubscribed, isTrue);

        // Act
        await subscriptionService.cancelSubscription();

        // Assert
        expect(subscriptionService.isSubscribed, isFalse);
        expect(subscriptionService.activeSubscriptionId, isNull);
      });

      test('should handle cancelling when no active subscription', () async {
        // Act & Assert - should not throw
        await subscriptionService.cancelSubscription();
      });
    });

    group('dispose', () {
      test('should cancel subscription on dispose', () async {
        // Arrange
        await subscriptionService.createVideoSubscription(
          onEvent: (_) {},
        );

        // Act
        await subscriptionService.dispose();

        // Assert
        expect(subscriptionService.isSubscribed, isFalse);
      });
    });
  });
}
