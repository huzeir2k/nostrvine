// ABOUTME: Real world test to verify VideoEventService works with actual vine.hol.is relay
// ABOUTME: This test connects to the real relay to debug why videos aren't showing in app

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

void main() {
  // Initialize Flutter bindings and mock platform dependencies for test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  const MethodChannel prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    prefsChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      if (methodCall.method == 'setString' || methodCall.method == 'setStringList') return true;
      return null;
    },
  );

  // Mock connectivity
  const MethodChannel connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    connectivityChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'check') return ['wifi'];
      return null;
    },
  );

  // Mock secure storage
  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    secureStorageChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'write') return null;
      if (methodCall.method == 'read') return null;
      if (methodCall.method == 'readAll') return <String, String>{};
      return null;
    },
  );

  group('Real Video Subscription Test', () {
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late NostrKeyManager keyManager;

    setUpAll(() async {
      keyManager = NostrKeyManager();
      await keyManager.initialize();
      
      nostrService = NostrService(keyManager);
      await nostrService.initialize(customRelays: ['wss://vine.hol.is']);
      
      // Wait for connection to stabilize
      print('⏳ Waiting for relay connection...');
      await Future.delayed(Duration(seconds: 3));
      print('✅ Connection status: ${nostrService.connectedRelayCount} relays connected');
      
      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(nostrService, subscriptionManager: subscriptionManager);
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
      videoEventService.dispose();
      subscriptionManager.dispose();
    });

    test('VideoEventService should receive videos from vine.hol.is relay', () async {
      print('🔍 Testing VideoEventService with real vine.hol.is relay...');
      
      final receivedVideos = <VideoEvent>[];
      final completer = Completer<void>();
      
      // Listen to VideoEventService changes
      void onVideoEventChange() {
        final events = videoEventService.videoEvents;
        print('📹 VideoEventService updated: ${events.length} total events');
        
        for (final event in events) {
          if (!receivedVideos.any((v) => v.id == event.id)) {
            receivedVideos.add(event);
            print('✅ New video: ${event.title ?? event.id.substring(0, 8)} (hasVideo: ${event.hasVideo})');
            print('   - URL: ${event.videoUrl}');
            print('   - Author: ${event.pubkey.substring(0, 8)}');
            print('   - Hashtags: ${event.hashtags}');
          }
        }
        
        if (receivedVideos.length >= 2 && !completer.isCompleted) {
          completer.complete();
        }
      }
      
      // Note: VideoEventService no longer extends ChangeNotifier after refactor
      // Using polling approach to check for new events instead of listener
      Timer? eventPollingTimer;
      eventPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        onVideoEventChange();
      });
      
      try {
        // Subscribe to video feed (same as app does)
        print('📡 Subscribing to video feed...');
        await videoEventService.subscribeToVideoFeed(
          limit: 10,
          includeReposts: false,
        );
        
        print('📡 Subscription created. Waiting for events...');
        print('📡 VideoEventService isSubscribed: ${videoEventService.isSubscribed}');
        print('📡 VideoEventService isLoading: ${videoEventService.isLoading}');
        print('📡 VideoEventService error: ${videoEventService.error}');
        
        // Wait for events with reasonable timeout
        await completer.future.timeout(Duration(seconds: 15));
        
        print('🎉 SUCCESS! Received ${receivedVideos.length} videos from real relay');
        
        // Verify we got videos
        expect(receivedVideos.length, greaterThan(0), 
          reason: 'Should receive videos from vine.hol.is relay');
        
        // Verify the videos have proper URLs
        final videosWithUrls = receivedVideos.where((v) => v.hasVideo).toList();
        expect(videosWithUrls.length, greaterThan(0), 
          reason: 'Should receive videos with valid URLs');
        
        print('✅ Test passed! ${videosWithUrls.length} videos have valid URLs');
        
      } catch (e) {
        print('❌ Test failed: $e');
        print('🔍 Final state:');
        print('  - VideoEventService isSubscribed: ${videoEventService.isSubscribed}');
        print('  - VideoEventService eventCount: ${videoEventService.eventCount}');
        print('  - VideoEventService hasEvents: ${videoEventService.hasEvents}');
        print('  - VideoEventService error: ${videoEventService.error}');
        print('  - Received videos: ${receivedVideos.length}');
        print('  - NostrService connectedRelayCount: ${nostrService.connectedRelayCount}');
        
        rethrow;
      } finally {
        // Cancel the polling timer instead of removing listener
        eventPollingTimer?.cancel();
      }
    });
  });
}