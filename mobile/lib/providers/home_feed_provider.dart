// ABOUTME: Home feed provider that shows videos only from people you follow
// ABOUTME: Filters video events by the user's following list for a personalized feed

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'home_feed_provider.g.dart';

/// Home feed provider - shows videos only from people you follow
/// keepAlive: true ensures videos persist across tab switches and rebuilds
///
/// Rebuilds occur when:
/// - Contact list changes (follow/unfollow)
/// - 10 minutes have passed since last refresh
/// - User pulls to refresh
@Riverpod(keepAlive: true)
class HomeFeed extends _$HomeFeed {
  Timer? _profileFetchTimer;
  Timer? _autoRefreshTimer;
  static int _buildCounter = 0;
  static DateTime? _lastBuildTime;
  static const _autoRefreshInterval = Duration(minutes: 10);

  @override
  Future<VideoFeedState> build() async {
    _buildCounter++;
    final buildId = _buildCounter;
    final now = DateTime.now();
    final timeSinceLastBuild = _lastBuildTime != null
        ? now.difference(_lastBuildTime!).inMilliseconds
        : null;

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId START at ${now.millisecondsSinceEpoch}ms'
      '${timeSinceLastBuild != null ? ' (${timeSinceLastBuild}ms since last build)' : ''}',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (timeSinceLastBuild != null && timeSinceLastBuild < 2000) {
      Log.warning(
        '⚠️  HomeFeed: RAPID REBUILD DETECTED! Only ${timeSinceLastBuild}ms since last build. '
        'This may indicate a provider dependency issue.',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }

    _lastBuildTime = now;

    // Clean up timers on dispose
    ref.onDispose(() {
      Log.info('🏠 HomeFeed: BUILD #$buildId DISPOSED', name: 'HomeFeedProvider', category: LogCategory.video);
      _profileFetchTimer?.cancel();
      _autoRefreshTimer?.cancel();
    });

    // Set up auto-refresh timer (10 minutes)
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer(_autoRefreshInterval, () {
      Log.info(
        '🏠 HomeFeed: Auto-refresh triggered after ${_autoRefreshInterval.inMinutes} minutes',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
      ref.invalidateSelf();
    });

    // Listen for changes to following list and invalidate when it changes
    ref.listen(social.socialProvider, (previous, next) {
      final prevFollowing = previous?.followingPubkeys ?? [];
      final nextFollowing = next.followingPubkeys;

      if (prevFollowing.length != nextFollowing.length) {
        Log.info(
          '🏠 HomeFeed: Following list changed from ${prevFollowing.length} to ${nextFollowing.length} - invalidating feed',
          name: 'HomeFeedProvider',
          category: LogCategory.video,
        );
        ref.invalidateSelf();
      }
    });

    Log.info('🏠 HomeFeed: BUILD #$buildId reading socialProvider (one-time read)...', name: 'HomeFeedProvider', category: LogCategory.video);

    // Read social data once without creating reactive dependency
    // Using ref.read() instead of ref.watch() prevents rebuilds when social state changes
    final socialData = ref.read(social.socialProvider);
    final followingPubkeys = socialData.followingPubkeys;

    Log.info(
      '🏠 HomeFeed: BUILD #$buildId - User is following ${followingPubkeys.length} people (social initialized: ${socialData.isInitialized})',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (followingPubkeys.isEmpty) {
      // Return empty state if not following anyone
      return VideoFeedState(
        videos: [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      );
    }

    // Get video event service and subscribe to following feed
    final videoEventService = ref.watch(videoEventServiceProvider);

    // Subscribe to home feed videos from followed authors using dedicated subscription type
    // NostrService now handles deduplication automatically
    await videoEventService.subscribeToHomeFeed(followingPubkeys, limit: 100);

    // Wait for initial batch of videos to arrive from relay
    // Videos arrive in rapid succession, so we wait for the count to stabilize
    final completer = Completer<void>();
    int stableCount = 0;
    Timer? stabilityTimer;

    void checkStability() {
      final currentCount = videoEventService.homeFeedVideos.length;
      if (currentCount != stableCount) {
        // Count changed, reset stability timer
        stableCount = currentCount;
        stabilityTimer?.cancel();
        stabilityTimer = Timer(const Duration(milliseconds: 300), () {
          // Count stable for 300ms, we're done
          if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }
    }

    videoEventService.addListener(checkStability);

    // Also set a maximum wait time
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Trigger initial check
    checkStability();

    await completer.future;

    // Clean up
    videoEventService.removeListener(checkStability);
    stabilityTimer?.cancel();

    // Get videos from the dedicated home feed list (server-side filtered to only following)
    final followingVideos =
        List<VideoEvent>.from(videoEventService.homeFeedVideos);

    Log.info(
      '🏠 HomeFeed: Server-side filtered to ${followingVideos.length} videos from following',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Reorder to show unseen videos first
    final seenVideosState = ref.watch(seenVideosProvider);

    final unseen = <VideoEvent>[];
    final seen = <VideoEvent>[];

    for (final video in followingVideos) {
      if (seenVideosState.seenVideoIds.contains(video.id)) {
        seen.add(video);
      } else {
        unseen.add(video);
      }
    }

    // Sort each list by creation time (newest first)
    unseen.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    seen.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Combine: unseen videos first, then seen videos
    final reorderedVideos = [...unseen, ...seen];

    Log.info(
      '🏠 HomeFeed: Reordered to show ${unseen.length} unseen first, then ${seen.length} seen',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Auto-fetch profiles for new videos and wait for completion
    await _scheduleBatchProfileFetch(reorderedVideos);

    final feedState = VideoFeedState(
      videos: reorderedVideos,
      hasMoreContent: reorderedVideos.length >= 10,
      isLoadingMore: false,
      error: null,
      lastUpdated: DateTime.now(),
    );

    final buildDuration = DateTime.now().difference(now).inMilliseconds;

    Log.info(
      '✅ HomeFeed: BUILD #$buildId COMPLETE - ${reorderedVideos.length} videos from following in ${buildDuration}ms',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    return feedState;
  }

  Future<void> _scheduleBatchProfileFetch(List<VideoEvent> videos) async {
    // Cancel any existing timer
    _profileFetchTimer?.cancel();

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    // Fetch profiles immediately - no delay needed as provider handles batching internally
    final profilesProvider = ref.read(userProfileProvider.notifier);

    final newPubkeys = videos
        .map((v) => v.pubkey)
        .where((pubkey) => !profilesProvider.hasProfile(pubkey))
        .toSet()
        .toList();

    if (newPubkeys.isNotEmpty) {
      Log.debug(
        'HomeFeed: Fetching ${newPubkeys.length} new profiles immediately and waiting for completion',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Wait for profiles to be fetched before continuing
      await profilesProvider.fetchMultipleProfiles(newPubkeys);

      Log.debug(
        'HomeFeed: Profile fetching completed for ${newPubkeys.length} profiles',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        'HomeFeed: All ${videos.length} video profiles already cached',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );
    }
  }

  /// Load more historical events from followed authors
  Future<void> loadMore() async {
    final currentState = await future;

    // Check if provider is still mounted after async gap
    if (!ref.mounted) return;

    Log.info(
      'HomeFeed: loadMore() called - isLoadingMore: ${currentState.isLoadingMore}',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    if (currentState.isLoadingMore) {
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videoEventService = ref.read(videoEventServiceProvider);
      final socialData = ref.read(social.socialProvider);
      final followingPubkeys = socialData.followingPubkeys;

      if (followingPubkeys.isEmpty) {
        // No one to load more from
        if (!ref.mounted) return;
        state = AsyncData(currentState.copyWith(
          isLoadingMore: false,
          hasMoreContent: false,
        ));
        return;
      }

      final eventCountBefore =
          videoEventService.getEventCount(SubscriptionType.homeFeed);

      // Load more events for home feed subscription type
      await videoEventService.loadMoreEvents(SubscriptionType.homeFeed,
          limit: 50);

      // Check if provider is still mounted after async gap
      if (!ref.mounted) return;

      final eventCountAfter =
          videoEventService.getEventCount(SubscriptionType.homeFeed);
      final newEventsLoaded = eventCountAfter - eventCountBefore;

      Log.info(
        'HomeFeed: Loaded $newEventsLoaded new events from following (total: $eventCountAfter)',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      // Reset loading state - state will auto-update via dependencies
      final newState = await future;
      if (!ref.mounted) return;
      state = AsyncData(newState.copyWith(
        isLoadingMore: false,
        hasMoreContent: newEventsLoaded > 0,
      ));
    } catch (e) {
      Log.error(
        'HomeFeed: Error loading more: $e',
        name: 'HomeFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted) return;
      final currentState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(
          isLoadingMore: false,
          error: e.toString(),
        ),
      );
    }
  }

  /// Refresh the home feed
  Future<void> refresh() async {
    Log.info(
      'HomeFeed: Refreshing home feed (following only)',
      name: 'HomeFeedProvider',
      category: LogCategory.video,
    );

    // Invalidate self to rebuild with current following list
    ref.invalidateSelf();
  }
}

/// Provider to check if home feed is loading
@riverpod
bool homeFeedLoading(Ref ref) {
  final asyncState = ref.watch(homeFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current home feed video count
@riverpod
int homeFeedCount(Ref ref) {
  final asyncState = ref.watch(homeFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}

/// Provider to check if we have home feed videos
@riverpod
bool hasHomeFeedVideos(Ref ref) {
  final count = ref.watch(homeFeedCountProvider);
  return count > 0;
}
