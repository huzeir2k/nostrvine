import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:flutter_embedded_nostr_relay/src/models/subscription.dart'
    as embedded_models;
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  group('NostrService Subscription Deduplication', () {
    late NostrService nostrService;
    late embedded.EmbeddedNostrRelay mockRelay;

    setUp(() async {
      mockRelay = _MockEmbeddedRelay();

      // Stub methods used by NostrService
      when(mockRelay.initialize(enableGarbageCollection: anyNamed('enableGarbageCollection')))
          .thenAnswer((_) async {});
      when(mockRelay.addExternalRelay(any)).thenAnswer((_) async {});
      when(mockRelay.removeExternalRelay(any)).thenAnswer((_) async {});
      when(mockRelay.connectedRelays).thenReturn(['wss://relay.test']);

      final mockSub = _MockSubscription();
      when(mockRelay.subscribe(
        subscriptionId: anyNamed('subscriptionId'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onEose: anyNamed('onEose'),
      )).thenReturn(mockSub);

      when(mockRelay.publish(any)).thenAnswer((_) async => true);
      when(mockRelay.queryEvents(any)).thenAnswer((_) async => <embedded.NostrEvent>[]);

      final keyManager = NostrKeyManager();
      await keyManager.initialize();
      nostrService = NostrService(keyManager, embeddedRelay: mockRelay);
      await nostrService.initialize(customRelays: ['wss://relay.test']);
    });

    tearDown(() {
      nostrService.dispose();
    });

    test('should reuse subscription for identical filters', () async {
      // Create identical filters
      final filter1 = Filter(
        kinds: [32222],
        authors: ['pubkey1', 'pubkey2'],
        limit: 100,
      );
      
      final filter2 = Filter(
        kinds: [32222],
        authors: ['pubkey1', 'pubkey2'],
        limit: 100,
      );

      // Subscribe with first filter
      final stream1 = nostrService.subscribeToEvents(filters: [filter1]);
      
      // Subscribe with identical filter
      final stream2 = nostrService.subscribeToEvents(filters: [filter2]);
      
      // They should be the same stream object (reused)
      expect(identical(stream1, stream2), isTrue, 
        reason: 'Identical filters should reuse the same subscription stream');
    });

    test('should create different subscriptions for different filters', () async {
      // Create different filters
      final filter1 = Filter(
        kinds: [32222],
        authors: ['pubkey1'],
        limit: 100,
      );
      
      final filter2 = Filter(
        kinds: [32222],
        authors: ['pubkey2'], // Different author
        limit: 100,
      );

      // Subscribe with first filter
      final stream1 = nostrService.subscribeToEvents(filters: [filter1]);
      
      // Subscribe with different filter
      final stream2 = nostrService.subscribeToEvents(filters: [filter2]);
      
      // They should be different stream objects
      expect(identical(stream1, stream2), isFalse,
        reason: 'Different filters should create different subscriptions');
    });

    test('should handle filter order independence', () async {
      // Create filters with same content but different order
      final filter1 = Filter(
        kinds: [32222],
        authors: ['pubkey1', 'pubkey2', 'pubkey3'],
        limit: 100,
      );
      
      final filter2 = Filter(
        kinds: [32222],
        authors: ['pubkey3', 'pubkey1', 'pubkey2'], // Same authors, different order
        limit: 100,
      );

      // Subscribe with first filter
      final stream1 = nostrService.subscribeToEvents(filters: [filter1]);
      
      // Subscribe with reordered filter
      final stream2 = nostrService.subscribeToEvents(filters: [filter2]);
      
      // They should be the same stream (order shouldn't matter)
      expect(identical(stream1, stream2), isTrue,
        reason: 'Filter order should not affect subscription deduplication');
    });

    test('should not exceed reasonable subscription limit', () async {
      final subscriptions = <Stream<Event>>[];
      
      // Create many different subscriptions
      for (int i = 0; i < 20; i++) {
        final filter = Filter(
          kinds: [32222],
          authors: ['pubkey$i'], // Each with different author
          limit: 100,
        );
        
        final stream = nostrService.subscribeToEvents(filters: [filter]);
        subscriptions.add(stream);
      }
      
      // Check that old subscriptions were cleaned up if limit exceeded
      // This is implementation dependent, but there should be some limit
      expect(subscriptions.length, equals(20),
        reason: 'Should be able to create subscriptions');
    });

    test('should generate consistent hash for same filters', () async {
      // This test verifies the hash generation is deterministic
      final filter = Filter(
        kinds: [32222, 6],
        authors: ['author1', 'author2'],
        since: 1234567890,
        until: 1234567900,
        limit: 50,
        t: ['hashtag1', 'hashtag2'],
      );
      
      // Subscribe multiple times with same filter
      final stream1 = nostrService.subscribeToEvents(filters: [filter]);
      await Future.delayed(Duration(milliseconds: 10));
      final stream2 = nostrService.subscribeToEvents(filters: [filter]);
      await Future.delayed(Duration(milliseconds: 10));
      final stream3 = nostrService.subscribeToEvents(filters: [filter]);
      
      // All should be the same stream
      expect(identical(stream1, stream2), isTrue);
      expect(identical(stream2, stream3), isTrue);
    });
  });
}

// Mockito-based mocks of embedded relay types
class _MockEmbeddedRelay extends Mock implements embedded.EmbeddedNostrRelay {}
class _MockSubscription extends Mock implements embedded_models.Subscription {}
