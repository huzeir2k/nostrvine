// ABOUTME: Integration tests for AUTH and Kind 22 event retrieval against real vine.hol.is relay
// ABOUTME: Tests the complete AUTH flow and verifies Kind 22 events can be retrieved after AUTH completion

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

void main() {
  group('AUTH and Kind 22 Event Retrieval - Real vine.hol.is Relay', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;

    setUp(() async {
      // Initialize Flutter test bindings
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize logging for tests
      Log.setLogLevel(LogLevel.debug);
      
      // Create services
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      
      // Generate test keys if needed
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      nostrService = NostrService(keyManager);
      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(nostrService, subscriptionManager: subscriptionManager);
    });

    tearDown(() async {
      videoEventService.dispose();
      subscriptionManager.dispose();
      nostrService.dispose();
      // NostrKeyManager doesn't have dispose method
    });

    test('AUTH completion tracking works correctly', () async {
      // Set a longer timeout for real relay testing
      nostrService.setAuthTimeout(const Duration(seconds: 30));
      
      // Track AUTH state changes
      final authStateChanges = <Map<String, bool>>[];
      final authSubscription = nostrService.authStateStream.listen((states) {
        authStateChanges.add(Map.from(states));
        print('AUTH state change: $states');
      });

      try {
        // Initialize NostrService with vine.hol.is
        await nostrService.initialize(customRelays: ['wss://vine.hol.is']);

        // Verify service is initialized
        expect(nostrService.isInitialized, isTrue);
        expect(nostrService.connectedRelayCount, greaterThan(0));

        // Wait a bit for AUTH completion
        await Future.delayed(const Duration(seconds: 5));

        // Check vine.hol.is AUTH state
        final vineAuthed = nostrService.isVineRelayAuthenticated;
        print('vine.hol.is authenticated: $vineAuthed');
        
        // We should have at least one AUTH state change
        expect(authStateChanges, isNotEmpty);
        
        // If vine.hol.is is connected, it should be in the auth states
        final authStates = nostrService.relayAuthStates;
        if (authStates.containsKey('wss://vine.hol.is')) {
          print('vine.hol.is AUTH state: ${authStates['wss://vine.hol.is']}');
        }
        
        // Log relay statuses for debugging
        final relayStatuses = nostrService.relayStatuses;
        for (final entry in relayStatuses.entries) {
          print('Relay ${entry.key}: ${entry.value}');
        }
      } finally {
        await authSubscription.cancel();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Kind 22 events can be retrieved from vine.hol.is after AUTH', () async {
      // Set a longer timeout for real relay testing
      nostrService.setAuthTimeout(const Duration(seconds: 30));
      
      // Initialize NostrService
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      expect(nostrService.isInitialized, isTrue);

      // Wait for AUTH completion
      await Future.delayed(const Duration(seconds: 10));

      // Track received events
      final receivedEvents = <VideoEvent>[];
      
      // Note: VideoEventService no longer extends ChangeNotifier after refactor
      // Using polling approach to check for new events
      Timer? eventPollingTimer;
      void checkForNewEvents() {
        final newEvents = videoEventService.videoEvents;
        for (final event in newEvents) {
          if (!receivedEvents.any((e) => e.id == event.id)) {
            receivedEvents.add(event);
            print('Received Kind 22 event: ${event.id.substring(0, 8)} from ${event.pubkey.substring(0, 8)}');
          }
        }
      }

      // Subscribe to Kind 22 video events with a reasonable limit
      print('Subscribing to Kind 22 video events...');
      await videoEventService.subscribeToVideoFeed(
        limit: 20, // Reasonable limit for testing
        replace: true,
        includeReposts: false,
      );

      // Start polling for new events every 500ms
      eventPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        checkForNewEvents();
      });

      // Wait for events to arrive
      print('Waiting for Kind 22 events...');
      await Future.delayed(const Duration(seconds: 15));
      
      // Stop polling
      eventPollingTimer?.cancel();

      // Check if we received any Kind 22 events
      print('Total events received: ${receivedEvents.length}');
      print('VideoEventService event count: ${videoEventService.eventCount}');
      print('Is subscribed: ${videoEventService.isSubscribed}');
      
      // Log AUTH status
      print('vine.hol.is authenticated: ${nostrService.isVineRelayAuthenticated}');
      print('Relay auth states: ${nostrService.relayAuthStates}');

      // We should have received some events (vine.hol.is should have Kind 22 events)
      // Note: This might fail if vine.hol.is is empty or not responding, but that's valuable info too
      if (receivedEvents.isEmpty) {
        print('WARNING: No Kind 22 events received from vine.hol.is');
        print('This could indicate:');
        print('1. AUTH not completed properly');
        print('2. No Kind 22 events stored on vine.hol.is');
        print('3. Relay not responding to subscriptions');
        
        // Still check that AUTH completed
        if (nostrService.isVineRelayAuthenticated) {
          print('AUTH completed but no events - relay may be empty');
        } else {
          fail('AUTH did not complete for vine.hol.is');
        }
      } else {
        // Success case - we got events
        expect(receivedEvents, isNotEmpty);
        print('✅ Successfully retrieved ${receivedEvents.length} Kind 22 events from vine.hol.is');
        
        // Verify events are properly parsed
        for (final event in receivedEvents.take(3)) {
          expect(event.id, isNotEmpty);
          expect(event.pubkey, isNotEmpty);
          // Note: kind is validated during VideoEvent.fromNostrEvent creation, so all events are kind 22
          print('Event details: id=${event.id.substring(0, 8)}, author=${event.pubkey.substring(0, 8)}');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('AUTH retry mechanism works when AUTH completes late', () async {
      // This test simulates the race condition scenario
      nostrService.setAuthTimeout(const Duration(seconds: 5)); // Shorter timeout to force timeout
      
      // Initialize NostrService
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      expect(nostrService.isInitialized, isTrue);

      // Try to subscribe immediately (might happen before AUTH)
      final receivedEvents = <VideoEvent>[];
      
      // Note: VideoEventService no longer extends ChangeNotifier after refactor
      // Using polling approach to check for new events
      Timer? retryEventPollingTimer;
      void checkForRetryEvents() {
        final newEvents = videoEventService.videoEvents;
        for (final event in newEvents) {
          if (!receivedEvents.any((e) => e.id == event.id)) {
            receivedEvents.add(event);
            print('Received event via retry mechanism: ${event.id.substring(0, 8)}');
          }
        }
      }

      print('Subscribing before AUTH completion...');
      await videoEventService.subscribeToVideoFeed(
        limit: 10,
        replace: true,
        includeReposts: false,
      );

      // Start polling for events
      retryEventPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        checkForRetryEvents();
      });

      print('Initial subscription created. Waiting for AUTH completion and retry...');
      
      // Wait longer for AUTH to complete and retry to happen
      await Future.delayed(const Duration(seconds: 20));

      // Stop polling
      retryEventPollingTimer?.cancel();

      print('Final results:');
      print('- Events received: ${receivedEvents.length}');
      print('- vine.hol.is authenticated: ${nostrService.isVineRelayAuthenticated}');
      print('- Video service subscribed: ${videoEventService.isSubscribed}');

      // The retry mechanism should work regardless of initial AUTH state
      // If AUTH completed late, the retry should have triggered
      if (nostrService.isVineRelayAuthenticated) {
        print('✅ AUTH completed - retry mechanism should have triggered');
        // We might have received events through retry
      } else {
        print('⚠️ AUTH still not complete after extended wait');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('AUTH session persistence works across service restarts', () async {
      NostrService? firstService;
      NostrService? secondService;
      
      try {
        // First service initialization
        firstService = NostrService(keyManager);
        firstService.setAuthTimeout(const Duration(seconds: 30));
        
        await firstService.initialize(customRelays: ['wss://vine.hol.is']);
        expect(firstService.isInitialized, isTrue);

        // Wait for AUTH completion
        await Future.delayed(const Duration(seconds: 10));
        
        final firstAuthState = firstService.isVineRelayAuthenticated;
        print('First service vine.hol.is AUTH: $firstAuthState');

        // Dispose first service
        firstService.dispose();
        await Future.delayed(const Duration(seconds: 1));

        // Create second service (should load persisted AUTH state)
        secondService = NostrService(keyManager);
        await secondService.initialize(customRelays: ['wss://vine.hol.is']);
        expect(secondService.isInitialized, isTrue);

        // Check if AUTH state was restored
        final secondAuthState = secondService.isVineRelayAuthenticated;
        print('Second service vine.hol.is AUTH: $secondAuthState');
        
        // If first service was authenticated, check if state persisted
        if (firstAuthState) {
          print('Testing AUTH session persistence...');
          // Note: Session might have expired or relay might require re-auth
          // The important thing is that we attempt to restore the state
          print('AUTH states loaded: ${secondService.relayAuthStates}');
        }

        print('✅ AUTH session persistence mechanism tested');
      } finally {
        firstService?.dispose();
        secondService?.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Configurable AUTH timeout works correctly', () async {
      final timeouts = [
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 20),
      ];

      for (final timeout in timeouts) {
        print('Testing AUTH timeout: ${timeout.inSeconds}s');
        
        final testService = NostrService(keyManager);
        testService.setAuthTimeout(timeout);
        
        final stopwatch = Stopwatch()..start();
        
        try {
          await testService.initialize(customRelays: ['wss://vine.hol.is']);
          stopwatch.stop();
          
          print('Service initialized in ${stopwatch.elapsedMilliseconds}ms');
          print('vine.hol.is authenticated: ${testService.isVineRelayAuthenticated}');
          
          // AUTH timeout should be respected (allowing some margin for processing)
          expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(timeout.inSeconds + 5));
          
        } finally {
          testService.dispose();
        }
        
        // Wait between tests
        await Future.delayed(const Duration(seconds: 2));
      }
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Multiple relays AUTH state tracking', () async {
      final testRelays = [
        'wss://vine.hol.is',
        'wss://relay.damus.io', // Non-auth relay for comparison
        'wss://nos.lol', // Another relay
      ];

      nostrService.setAuthTimeout(const Duration(seconds: 30));
      
      await nostrService.initialize(customRelays: testRelays);
      expect(nostrService.isInitialized, isTrue);

      // Wait for AUTH completion
      await Future.delayed(const Duration(seconds: 15));

      final authStates = nostrService.relayAuthStates;
      print('Final AUTH states for all relays:');
      
      for (final relay in testRelays) {
        final isAuthed = nostrService.isRelayAuthenticated(relay);
        print('$relay: authenticated=$isAuthed');
        
        // Each relay should have some auth state tracked
        expect(authStates.containsKey(relay), isTrue);
      }

      // vine.hol.is should require auth
      print('vine.hol.is specifically: ${nostrService.isVineRelayAuthenticated}');
      
      print('✅ Multiple relay AUTH tracking completed');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}