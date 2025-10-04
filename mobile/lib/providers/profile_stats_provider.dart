// ABOUTME: Riverpod provider for managing profile statistics with async loading and caching
// ABOUTME: Aggregates user video count, likes, and other metrics from Nostr events

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/profile_stats_cache_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_stats_provider.g.dart';

/// Statistics for a user's profile
class ProfileStats {
  const ProfileStats({
    required this.videoCount,
    required this.totalLikes,
    required this.followers,
    required this.following,
    required this.totalViews,
    required this.lastUpdated,
  });
  final int videoCount;
  final int totalLikes;
  final int followers;
  final int following;
  final int totalViews; // Placeholder for future implementation
  final DateTime lastUpdated;

  ProfileStats copyWith({
    int? videoCount,
    int? totalLikes,
    int? followers,
    int? following,
    int? totalViews,
    DateTime? lastUpdated,
  }) =>
      ProfileStats(
        videoCount: videoCount ?? this.videoCount,
        totalLikes: totalLikes ?? this.totalLikes,
        followers: followers ?? this.followers,
        following: following ?? this.following,
        totalViews: totalViews ?? this.totalViews,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  @override
  String toString() =>
      'ProfileStats(videos: $videoCount, likes: $totalLikes, followers: $followers, following: $following, views: $totalViews)';
}

/// State for profile statistics provider
class ProfileStatsState {
  const ProfileStatsState({
    required this.stats,
    required this.isLoading,
    required this.error,
    required this.lastUpdated,
  });

  final ProfileStats? stats;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  ProfileStatsState copyWith({
    ProfileStats? stats,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) =>
      ProfileStatsState(
        stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  static const initial = ProfileStatsState(
    stats: null,
    isLoading: false,
    error: null,
    lastUpdated: null,
  );

  bool get hasData => stats != null;
  bool get hasError => error != null;
}

// SQLite-based persistent cache
final _cacheService = ProfileStatsCacheService();

/// Get cached stats if available and not expired
Future<ProfileStats?> _getCachedProfileStats(String pubkey) async {
  final stats = await _cacheService.getCachedStats(pubkey);

  if (stats != null) {
    final age = DateTime.now().difference(stats.lastUpdated);
    Log.debug(
        '📱 Using cached stats for ${pubkey.substring(0, 8)} (age: ${age.inMinutes}min)',
        name: 'ProfileStatsProvider',
        category: LogCategory.ui);
  }

  return stats;
}

/// Cache stats for a user
Future<void> _cacheProfileStats(String pubkey, ProfileStats stats) async {
  await _cacheService.saveStats(pubkey, stats);
  Log.debug('📱 Cached stats for ${pubkey.substring(0, 8)}',
      name: 'ProfileStatsProvider', category: LogCategory.ui);
}

/// Clear cache for a specific user
Future<void> _clearProfileStatsCache(String pubkey) async {
  await _cacheService.clearStats(pubkey);
}

/// Clear all cached stats
Future<void> clearAllProfileStatsCache() async {
  await _cacheService.clearAll();
  Log.debug('📱️ Cleared all stats cache',
      name: 'ProfileStatsProvider', category: LogCategory.ui);
}

/// Async provider for loading profile statistics
@riverpod
Future<ProfileStats> fetchProfileStats(Ref ref, String pubkey) async {
  // Check cache first
  final cached = await _getCachedProfileStats(pubkey);
  if (cached != null) {
    return cached;
  }

  // Get the social service from app providers
  final socialService = ref.watch(socialServiceProvider);

  Log.debug('Loading profile stats for: ${pubkey.substring(0, 8)}...',
      name: 'ProfileStatsProvider', category: LogCategory.ui);

  try {
    // Load all stats in parallel for better performance
    final results = await Future.wait<dynamic>([
      socialService.getFollowerStats(pubkey),
      socialService.getUserVideoCount(pubkey),
    ]);

    final followerStats = results[0] as Map<String, int>;
    final videoCount = results[1] as int;

    final stats = ProfileStats(
      videoCount: videoCount,
      totalLikes: 0, // Not showing reactions for now
      followers: followerStats['followers'] ?? 0,
      following: followerStats['following'] ?? 0,
      totalViews: 0, // Placeholder for future implementation
      lastUpdated: DateTime.now(),
    );

    // Cache the results
    await _cacheProfileStats(pubkey, stats);

    Log.info('Profile stats loaded: $stats',
        name: 'ProfileStatsProvider', category: LogCategory.ui);

    return stats;
  } catch (e) {
    Log.error('Error loading profile stats: $e',
        name: 'ProfileStatsProvider', category: LogCategory.ui);
    rethrow;
  }
}

/// Notifier for managing profile stats state
@riverpod
class ProfileStatsNotifier extends _$ProfileStatsNotifier {
  @override
  ProfileStatsState build() {
    return ProfileStatsState.initial;
  }

  /// Load profile stats for a user
  Future<void> loadStats(String pubkey) async {
    // Defer state modification to avoid modifying provider during build
    await Future.microtask(() {
      state = state.copyWith(isLoading: true, error: null);
    });

    try {
      final stats = await ref.read(fetchProfileStatsProvider(pubkey).future);
      state = state.copyWith(
        stats: stats,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh stats by clearing cache and reloading
  Future<void> refreshStats(String pubkey) async {
    await _clearProfileStatsCache(pubkey);
    ref.invalidate(fetchProfileStatsProvider(pubkey));
    await loadStats(pubkey);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Get a formatted string for large numbers (e.g., 1234 -> "1.2k")
/// Delegates to StringUtils.formatCompactNumber for consistent formatting
String formatProfileStatsCount(int count) {
  return StringUtils.formatCompactNumber(count);
}
