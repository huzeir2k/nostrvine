// ABOUTME: Service for managing NIP-51 video curation sets and content discovery
// ABOUTME: Handles fetching, caching, and filtering videos based on curation sets

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class CurationService  {
  CurationService({
    required INostrService nostrService,
    required VideoEventService videoEventService,
    required SocialService socialService,
  })  : _nostrService = nostrService,
        _videoEventService = videoEventService,
        _socialService = socialService {
    _initializeWithSampleData();

    // Listen for video updates and refresh curation data
      // REFACTORED: Service no longer extends ChangeNotifier - use Riverpod ref.watch instead
  }
  final INostrService _nostrService;
  final VideoEventService _videoEventService;
  final SocialService _socialService;

  final Map<String, CurationSet> _curationSets = {};
  final Map<String, List<VideoEvent>> _setVideoCache = {};
  bool _isLoading = false;
  String? _error;
  int _lastEditorVideoCount = -1; // Track video count to reduce duplicate logging

  /// Current curation sets
  List<CurationSet> get curationSets => _curationSets.values.toList();

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error state
  String? get error => _error;

  /// Initialize with sample data while we're developing
  void _initializeWithSampleData() {
    _isLoading = true;

    Log.debug('🔄 CurationService initializing...',
        name: 'CurationService', category: LogCategory.system);
    Log.debug(
        '  VideoEventService has ${_videoEventService.videoEvents.length} videos',
        name: 'CurationService',
        category: LogCategory.system);

    // Load sample curation sets
    for (final sampleSet in SampleCurationSets.all) {
      _curationSets[sampleSet.id] = sampleSet;
    }

    // Populate with actual video data
    _populateSampleSets();

    _isLoading = false;

  }

  /// Populate sample sets with real video data
  void _populateSampleSets() {
    final allVideos = _videoEventService.videoEvents;
    // Populating curation sets silently

    // Always create Editor's Picks with default video, even if no other videos
    final editorsPicks = _selectEditorsPicksVideos(allVideos, allVideos);
    _setVideoCache[CurationSetType.editorsPicks.id] = editorsPicks;

    if (allVideos.isEmpty) {
      return;
    }

    // Sort videos by different criteria for different sets
    final sortedByTime = List<VideoEvent>.from(allVideos)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Sort by reaction count (using cached counts from social service)
    final sortedByReactions = List<VideoEvent>.from(allVideos)
      ..sort((a, b) {
        final aReactions = _socialService.getCachedLikeCount(a.id) ?? 0;
        final bReactions = _socialService.getCachedLikeCount(b.id) ?? 0;
        return bReactions.compareTo(aReactions);
      });

    // Update Editor's Picks with actual data (already created above with default video)
    final updatedEditorsPicks =
        _selectEditorsPicksVideos(sortedByTime, sortedByReactions);
    _setVideoCache[CurationSetType.editorsPicks.id] = updatedEditorsPicks;

    Log.verbose('Populated curation sets:',
        name: 'CurationService', category: LogCategory.system);
    Log.verbose('   Editor\'s Picks: ${updatedEditorsPicks.length} videos',
        name: 'CurationService', category: LogCategory.system);
    Log.verbose('   Total available videos: ${allVideos.length}',
        name: 'CurationService', category: LogCategory.system);
  }

  /// Algorithm for selecting editor's picks
  List<VideoEvent> _selectEditorsPicksVideos(
    List<VideoEvent> byTime,
    List<VideoEvent> byReactions,
  ) {
    final picks = <VideoEvent>[];
    final seenIds = <String>{};

    // Editor's Pick: Only show videos from the classic vines curator pubkey
    const editorPubkey = AppConstants.classicVinesPubkey;

    // Get all videos from the editor's pubkey
    final editorVideos = _videoEventService.videoEvents
        .where((video) => video.pubkey == editorPubkey)
        .toList();

    // Only log on changes to avoid spam
    if (_lastEditorVideoCount != editorVideos.length) {
      Log.debug("🔍 Selecting Editor's Picks...",
          name: 'CurationService', category: LogCategory.system);
      Log.debug('  Editor pubkey: $editorPubkey',
          name: 'CurationService', category: LogCategory.system);
      Log.debug(
          '  Total videos available: ${_videoEventService.videoEvents.length}',
          name: 'CurationService',
          category: LogCategory.system);
      Log.debug("  Found ${editorVideos.length} videos from editor's pubkey",
          name: 'CurationService', category: LogCategory.system);
      
      _lastEditorVideoCount = editorVideos.length;
    }

    // Debug: Check a few videos to see why they might not be from editor
    if (editorVideos.isEmpty && _videoEventService.videoEvents.isNotEmpty) {
      Log.debug('  Sample of available videos:',
          name: 'CurationService', category: LogCategory.system);
      for (var i = 0; i < 3 && i < _videoEventService.videoEvents.length; i++) {
        final video = _videoEventService.videoEvents[i];
        Log.debug(
            '    Video ${i + 1}: pubkey=${video.pubkey.substring(0, 8)}... title="${video.title}"',
            name: 'CurationService',
            category: LogCategory.system);
      }
    }

    // Randomize editor's videos order instead of sorting by time
    editorVideos.shuffle(Random());
    
    // Only log randomization on changes
    if (_lastEditorVideoCount != editorVideos.length) {
      Log.debug('  Randomized order of ${editorVideos.length} editor videos',
          name: 'CurationService', category: LogCategory.system);
    }

    // Add all editor's videos to picks
    for (final video in editorVideos) {
      picks.add(video);
      seenIds.add(video.id);
      Log.verbose(
          '  Added editor video: ${video.title ?? video.id.substring(0, 8)}',
          name: 'CurationService',
          category: LogCategory.system);
    }

    // If no videos from editor, leave picks empty - don't add fallback content
    if (picks.isEmpty) {
      Log.info(
          "No videos found from editor's pubkey - editor's picks will be empty",
          name: 'CurationService',
          category: LogCategory.system);
    }

    // Only log completion on changes
    if (_lastEditorVideoCount == editorVideos.length) {
      Log.verbose("  Editor's picks selection complete: ${picks.length} videos",
          name: 'CurationService', category: LogCategory.system);
    } else {
      Log.debug("  Editor's picks selection complete: ${picks.length} videos",
          name: 'CurationService', category: LogCategory.system);
    }
    
    return picks;
  }


  /// Refresh trending videos from analytics API (call this when user visits trending)
  Future<void> refreshTrendingFromAnalytics() async {
    await _fetchTrendingFromAnalytics();
  }

  /// Fetch trending videos from analytics API
  Future<void> _fetchTrendingFromAnalytics() async {
    try {
      Log.info('📊 Fetching trending videos from analytics API...',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  URL: https://analytics.openvine.co/analytics/trending/vines',
          name: 'CurationService', category: LogCategory.system);

      final response = await http.get(
        Uri.parse('https://analytics.openvine.co/analytics/trending/vines'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OpenVine-Mobile/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      Log.info('📊 Trending API response:',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  Status: ${response.statusCode}',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  Body: ${response.body}',
          name: 'CurationService', category: LogCategory.system);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vinesData = data['vines'] as List<dynamic>?;

        Log.info('  Vines in response: ${vinesData?.length ?? 0}',
            name: 'CurationService', category: LogCategory.system);

        if (vinesData != null && vinesData.isNotEmpty) {
          final trending = <VideoEvent>[];
          final allVideos = _videoEventService.videoEvents;
          final missingEventIds = <String>[];

          Log.info('  Local videos available: ${allVideos.length}',
              name: 'CurationService', category: LogCategory.system);

          // First pass: collect videos we have locally and track missing ones
          for (final vineData in vinesData) {
            final eventId = vineData['eventId'] as String?;
            final viewCount = vineData['views'] ?? 0;

            if (eventId != null) {
              Log.verbose('  Looking for eventId: $eventId ($viewCount views)',
                  name: 'CurationService', category: LogCategory.system);

              // Find the video in our local cache
              final localVideo = allVideos.firstWhere(
                (video) => video.id == eventId,
                orElse: () => VideoEvent(
                  id: '',
                  pubkey: '',
                  createdAt: 0,
                  content: '',
                  timestamp: DateTime.now(),
                ),
              );

              if (localVideo.id.isNotEmpty) {
                trending.add(localVideo);
                Log.info(
                    '✅ Found trending video: ${localVideo.title ?? localVideo.id.substring(0, 8)} ($viewCount views)',
                    name: 'CurationService',
                    category: LogCategory.system);
              } else {
                Log.warning(
                    '❌ Trending video not found locally: $eventId - will fetch from relays',
                    name: 'CurationService',
                    category: LogCategory.system);
                missingEventIds.add(eventId);
              }
            }
          }

          // Fetch missing videos from Nostr relays
          if (missingEventIds.isNotEmpty) {
            Log.info(
                '📡 Fetching ${missingEventIds.length} missing trending videos from relays...',
                name: 'CurationService',
                category: LogCategory.system);

            try {
              // Subscribe to fetch specific video events by ID
              final filter = Filter(
                ids: missingEventIds,
              );
              final eventStream = _nostrService.subscribeToEvents(
                filters: [filter],
              );

              // Collect fetched videos with a timeout
              final fetchedVideos = <VideoEvent>[];
              await for (final event
                  in eventStream.timeout(const Duration(seconds: 5))) {
                try {
                  final video = VideoEvent.fromNostrEvent(event);
                  fetchedVideos.add(video);
                  Log.info(
                      '📹 Fetched trending video from relay: ${video.title ?? video.id.substring(0, 8)}',
                      name: 'CurationService',
                      category: LogCategory.system);

                  // Also add to video event service so it's cached
                  _videoEventService.addVideoEvent(video);
                } catch (e) {
                  Log.error('Failed to parse video event: $e',
                      name: 'CurationService', category: LogCategory.system);
                }
              }

              // Add fetched videos to trending list
              trending.addAll(fetchedVideos);
              Log.info(
                  '✅ Fetched ${fetchedVideos.length} trending videos from relays',
                  name: 'CurationService',
                  category: LogCategory.system);
            } catch (e) {
              if (e.toString().contains('TimeoutException')) {
                Log.info(
                    '⏱️ Timeout fetching videos from relays - continuing with what we have',
                    name: 'CurationService',
                    category: LogCategory.system);
              } else {
                Log.error('❌ Error fetching videos from relays: $e',
                    name: 'CurationService', category: LogCategory.system);
              }
            }
          }

          if (trending.isNotEmpty) {
            // Sort by the order from analytics API
            final orderedTrending = <VideoEvent>[];
            for (final vineData in vinesData) {
              final eventId = vineData['eventId'] as String?;
              if (eventId != null) {
                final video = trending.firstWhere(
                  (v) => v.id == eventId,
                  orElse: () => VideoEvent(
                      id: '',
                      pubkey: '',
                      createdAt: 0,
                      content: '',
                      timestamp: DateTime.now()),
                );
                if (video.id.isNotEmpty) {
                  orderedTrending.add(video);
                }
              }
            }

            // Update the trending cache with analytics data
            // _setVideoCache[CurationSetType.trending.id] = orderedTrending; // Trending now handled by InfiniteFeedService
            Log.info(
                '✅ Updated trending videos from analytics: ${orderedTrending.length} videos',
                name: 'CurationService',
                category: LogCategory.system);

          } else {
            Log.warning(
                '⚠️ No trending videos found after fetching from relays',
                name: 'CurationService',
                category: LogCategory.system);
          }
        } else {
          Log.warning('⚠️ No vines data in analytics response',
              name: 'CurationService', category: LogCategory.system);
        }
      } else {
        Log.warning(
            '❌ Analytics API returned ${response.statusCode}: ${response.body}',
            name: 'CurationService',
            category: LogCategory.system);
      }
    } catch (e) {
      Log.error('❌ Failed to fetch trending from analytics: $e',
          name: 'CurationService', category: LogCategory.system);
      // Continue with local algorithm fallback
    }
  }


  /// Get videos for a specific curation set
  List<VideoEvent> getVideosForSet(String setId) => _setVideoCache[setId] ?? [];

  /// Get videos for a curation set type
  List<VideoEvent> getVideosForSetType(CurationSetType setType) =>
      getVideosForSet(setType.id);

  /// Get a specific curation set
  CurationSet? getCurationSet(String setId) => _curationSets[setId];

  /// Get curation set by type
  CurationSet? getCurationSetByType(CurationSetType setType) =>
      getCurationSet(setType.id);

  /// Refresh curation sets from Nostr
  Future<void> refreshCurationSets({List<String>? curatorPubkeys}) async {
    _isLoading = true;
    _error = null;


    try {
      // TODO: Implement actual Nostr queries for kind 30005 events
      // For now, just refresh sample data
      _populateSampleSets();

      _isLoading = false;

    } catch (e) {
      _error = 'Failed to refresh curation sets: $e';
      _isLoading = false;

      Log.error('Error refreshing curation sets: $e',
          name: 'CurationService', category: LogCategory.system);
    }
  }

  /// Subscribe to curation set updates
  Future<void> subscribeToCurationSets({List<String>? curatorPubkeys}) async {
    try {
      Log.debug('Subscribing to kind 30005 curation sets...',
          name: 'CurationService', category: LogCategory.system);

      // Query for video curation sets (kind 30005)
      final filter = {
        'kinds': [30005],
        'limit': 500,
      };

      // If specific curators provided, filter by them
      if (curatorPubkeys != null && curatorPubkeys.isNotEmpty) {
        filter['authors'] = curatorPubkeys;
      }

      // Subscribe to receive curation set events
      final eventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [30005],
            authors: curatorPubkeys,
            limit: 500,
          ),
        ],
      );

      eventStream.listen(
        (event) {
          try {
            // Debug: Check what kind of event we're receiving
            if (event.kind != 30005) {
              Log.warning(
                  'Received unexpected event kind ${event.kind} in curation subscription (expected 30005)',
                  name: 'CurationService',
                  category: LogCategory.system);
              return;
            }

            final curationSet = CurationSet.fromNostrEvent(event);
            _curationSets[curationSet.id] = curationSet;
            Log.verbose(
                'Received curation set: ${curationSet.title} (${curationSet.videoIds.length} videos)',
                name: 'CurationService',
                category: LogCategory.system);

            // Update the video cache for this set
            _updateVideoCache(curationSet);

          } catch (e) {
            Log.error('Failed to parse curation set from event: $e',
                name: 'CurationService', category: LogCategory.system);
          }
        },
        onError: (error) {
          Log.error('Error in curation set subscription: $error',
              name: 'CurationService', category: LogCategory.system);
        },
      );

      // Also set up periodic refresh for sample data fallback
      Timer.periodic(const Duration(minutes: 5), (_) {
        if (!_isLoading) {
          _populateSampleSets();

        }
      });
    } catch (e) {
      Log.error('Error subscribing to curation sets: $e',
          name: 'CurationService', category: LogCategory.system);
    }
  }

  /// Update video cache for a specific curation set
  void _updateVideoCache(CurationSet curationSet) {
    final allVideos = _videoEventService.videoEvents;
    final setVideos = <VideoEvent>[];

    // Find videos matching the curation set's video IDs
    for (final videoId in curationSet.videoIds) {
      try {
        final video = allVideos.firstWhere(
          (v) => v.id == videoId,
        );
        setVideos.add(video);
      } catch (e) {
        // Video not found, skip it
      }
    }

    _setVideoCache[curationSet.id] = setVideos;
    Log.info(
        'Updated cache for ${curationSet.id}: ${setVideos.length} videos found',
        name: 'CurationService',
        category: LogCategory.system);
  }

  /// Create a new curation set (for future implementation)
  Future<bool> createCurationSet({
    required String id,
    required String title,
    required List<String> videoIds,
    String? description,
    String? imageUrl,
  }) async {
    try {
      // TODO: Implement actual creation and publishing to Nostr
      Log.debug('Creating curation set: $title',
          name: 'CurationService', category: LogCategory.system);
      return true;
    } catch (e) {
      Log.error('Error creating curation set: $e',
          name: 'CurationService', category: LogCategory.system);
      return false;
    }
  }

  /// Check if videos need updating and refresh cache
  void refreshIfNeeded() {
    final currentVideoCount = _videoEventService.videoEvents.length;
    final cachedCount = _setVideoCache.values.fold<int>(
      0,
      (sum, videos) => sum + videos.length,
    );

    // Refresh if we have new videos
    if (currentVideoCount > cachedCount) {
      _populateSampleSets();

    }
  }

  /// Handle video data changes
  void _onVideoDataChanged() {
    Log.debug(
        '📊 CurationService: VideoEventService data changed, updating curation sets...',
        name: 'CurationService',
        category: LogCategory.system);
    Log.debug('  Total videos now: ${_videoEventService.videoEvents.length}',
        name: 'CurationService', category: LogCategory.system);

    // Check for Classic Vines videos specifically
    final classicVinesVideos = _videoEventService.videoEvents
        .where((v) => v.pubkey == AppConstants.classicVinesPubkey)
        .toList();
    Log.debug('  Classic Vines videos: ${classicVinesVideos.length}',
        name: 'CurationService', category: LogCategory.system);

    _populateSampleSets();

  }

  void dispose() {
    // Clean up any subscriptions
      // REFACTORED: Service no longer needs manual listener cleanup
    
  }
}
