// ABOUTME: Riverpod stream provider for managing Nostr video event subscriptions
// ABOUTME: Handles real-time video feed updates based on current feed mode

import 'dart:async';

import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_mode_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'video_events_providers.g.dart';

/// Provider for NostrService instance (Video Events specific)
@riverpod
INostrService videoEventsNostrService(Ref ref) {
  throw UnimplementedError(
      'VideoEventsNostrService must be overridden in ProviderScope');
}

/// Provider for SubscriptionManager instance (Video Events specific)
@riverpod
SubscriptionManager videoEventsSubscriptionManager(
    Ref ref) {
  throw UnimplementedError(
      'VideoEventsSubscriptionManager must be overridden in ProviderScope');
}

/// Stream provider for video events from Nostr
@riverpod
class VideoEvents extends _$VideoEvents {
  final List<VideoEvent> _events = [];
  final Set<String> _seenEventIds = {};

  @override
  Stream<List<VideoEvent>> build() {
    _events.clear();
    _seenEventIds.clear();

    // Use existing VideoEventService instead of duplicating subscription logic
    final videoEventService = ref.watch(videoEventServiceProvider);

    Log.info(
      'VideoEvents: Using VideoEventService as source (${videoEventService.videoEvents.length} events)',
      name: 'VideoEventsProvider', 
      category: LogCategory.video,
    );

    // CRITICAL: Start video event subscription if not already subscribed
    if (!videoEventService.isSubscribed) {
      Log.info(
        'VideoEvents: Starting video feed subscription',
        name: 'VideoEventsProvider', 
        category: LogCategory.video,
      );
      // Start subscription for general video feed
      videoEventService.subscribeToVideoFeed(
        limit: 100,
        includeReposts: true,
      );
    }

    // Create stream controller to transform VideoEventService data
    final controller = StreamController<List<VideoEvent>>.broadcast();
    
    // Add current events immediately
    final currentEvents = List<VideoEvent>.from(videoEventService.videoEvents);
    _events.addAll(currentEvents);
    controller.add(currentEvents);

    // Listen for new events from VideoEventService  
    void onVideoEventServiceChange() {
      final newEvents = videoEventService.videoEvents;
      if (newEvents.length != _events.length) {
        Log.debug(
          'VideoEvents: VideoEventService updated (${newEvents.length} events)',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );
        _events.clear();
        _events.addAll(newEvents);
        controller.add(List<VideoEvent>.from(_events));
      }
    }

    // REFACTORED: Service no longer extends ChangeNotifier
    // Instead, we should use proper Riverpod state management
    // For now, just close controller on dispose
    ref.onDispose(() {
      controller.close();
    });

    return controller.stream;
  }

  /// Create filter based on current feed mode
  Filter? _createFilter() {
    final feedMode = ref.read(feedModeNotifierProvider);
    final feedContext = ref.read(feedContextProvider);
    final socialData = ref.read(socialNotifierProvider);

    // Base filter for video events
    final filter = Filter(
      kinds: [22],
      limit: 500,
      // Removed h: ['vine'] restriction to get all video events, not just vine-tagged ones
    );

    switch (feedMode) {
      case FeedMode.following:
        // Use following list or classic vines fallback
        final followingList = socialData.followingPubkeys;
        filter.authors = followingList.isNotEmpty
            ? followingList
            : [AppConstants.classicVinesPubkey];

        Log.info(
          'VideoEvents: Following mode with ${filter.authors!.length} authors',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );

      case FeedMode.curated:
        // Only classic vines curator
        filter.authors = [AppConstants.classicVinesPubkey];
        Log.info(
          'VideoEvents: Curated mode',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );

      case FeedMode.discovery:
        // General feed - no author filter
        Log.info(
          'VideoEvents: Discovery mode',
          name: 'VideoEventsProvider',
          category: LogCategory.video,
        );

      case FeedMode.hashtag:
        // Filter by hashtag
        if (feedContext != null) {
          filter.t = [feedContext];
          Log.info(
            'VideoEvents: Hashtag mode for #$feedContext',
            name: 'VideoEventsProvider',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            'VideoEvents: Hashtag mode but no context',
            name: 'VideoEventsProvider',
            category: LogCategory.video,
          );
          return null;
        }

      case FeedMode.profile:
        // Filter by specific author
        if (feedContext != null) {
          filter.authors = [feedContext];
          Log.info(
            'VideoEvents: Profile mode for $feedContext',
            name: 'VideoEventsProvider',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            'VideoEvents: Profile mode but no context',
            name: 'VideoEventsProvider',
            category: LogCategory.video,
          );
          return null;
        }
    }

    return filter;
  }

  /// Load more historical events
  Future<void> loadMoreEvents() async {
    final nostrService = ref.read(videoEventsNostrServiceProvider);
    if (!nostrService.isInitialized) return;

    // Get oldest event timestamp
    final oldestTimestamp = _events.isEmpty
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000
        : _events.map((e) => e.createdAt).reduce((a, b) => a < b ? a : b);

    // Create filter for older events
    final filter = _createFilter();
    if (filter == null) return;

    filter.until = oldestTimestamp - 1;
    filter.limit = 50;

    Log.info(
      'VideoEvents: Loading more events before timestamp $oldestTimestamp',
      name: 'VideoEventsProvider',
      category: LogCategory.video,
    );

    try {
      final stream = nostrService.subscribeToEvents(filters: [filter]);

      await for (final event in stream) {
        if (event.kind == 22 && !_seenEventIds.contains(event.id)) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            _events.add(videoEvent);
            _seenEventIds.add(event.id);
          } catch (e) {
            Log.error(
              'VideoEvents: Failed to parse historical event: $e',
              name: 'VideoEventsProvider',
              category: LogCategory.video,
            );
          }
        }
      }

      // Sort events by timestamp (newest first)
      _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Notify listeners with updated list
      ref.notifyListeners();
    } catch (e) {
      Log.error(
        'VideoEvents: Error loading more: $e',
        name: 'VideoEventsProvider',
        category: LogCategory.video,
      );
    }
  }

  /// Clear all events and refresh
  Future<void> refresh() async {
    _events.clear();
    _seenEventIds.clear();
    ref.invalidateSelf();
  }
}

/// Provider to check if video events are loading
@riverpod
bool videoEventsLoading(Ref ref) =>
    ref.watch(videoEventsProvider).isLoading;

/// Provider to get video event count
@riverpod
int videoEventCount(Ref ref) =>
    ref.watch(videoEventsProvider).valueOrNull?.length ?? 0;
