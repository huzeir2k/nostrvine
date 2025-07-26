// ABOUTME: Service to provide curated video feeds using the VideoManager pipeline
// ABOUTME: Bridges CurationService with VideoManager for consistent video playback

import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/providers/video_manager_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service that provides curated video collections through VideoManager
///
/// This bridges the CurationService (which provides curated content) with
/// VideoManager (which handles video playback and lifecycle) to ensure
/// consistent video behavior across the app.
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ExploreVideoManager  {
  ExploreVideoManager({
    required CurationService curationService,
    required VideoManager videoManager,
  })  : _curationService = curationService,
        _videoManager = videoManager {
    // Listen to curation service changes
      // REFACTORED: Service no longer extends ChangeNotifier - use Riverpod ref.watch instead

    // Initialize with current content
    _initializeCollections();
  }
  final CurationService _curationService;
  final VideoManager _videoManager;

  // Current collections available in VideoManager
  final Map<CurationSetType, List<VideoEvent>> _availableCollections = {};
  final Map<CurationSetType, int> _lastVideoCount = {}; // Track counts to reduce duplicate logging

  /// Get videos for a specific curation type, ensuring they're in VideoManager
  List<VideoEvent> getVideosForType(CurationSetType type) =>
      _availableCollections[type] ?? [];

  /// Check if videos are loading
  bool get isLoading => _curationService.isLoading;

  /// Get any error
  String? get error => _curationService.error;

  /// Initialize collections by ensuring curated videos are in VideoManager
  Future<void> _initializeCollections() async {
    await _syncAllCollections();
  }

  /// Handle changes from curation service
  void _onCurationChanged() {
    Log.verbose('CurationService changed, syncing collections...',
        name: 'ExploreVideoManager', category: LogCategory.system);
    _syncAllCollections();
  }

  /// Sync all curation collections to VideoManager
  Future<void> _syncAllCollections() async {
    // IMPORTANT: Do NOT add videos to VideoManager here!
    // Riverpod providers handle video additions from Nostr subscriptions.
    // ExploreVideoManager only needs to check which curated videos are available.

    // Sync each collection by checking what's available in VideoManager
    for (final type in CurationSetType.values) {
      await _syncCollectionInternal(type);
    }


  }

  /// Internal sync method that doesn't notify listeners
  Future<void> _syncCollectionInternal(CurationSetType type) async {
    try {
      // Get videos from curation service
      final curatedVideos = _curationService.getVideosForSetType(type);

      // FIXED: Return curated videos directly instead of filtering through VideoManager
      // The CurationService already has access to all videos from VideoEventService
      _availableCollections[type] = curatedVideos;

      // Debug: Log what we're getting (reduce spam by only logging on changes)
      if (type == CurationSetType.editorsPicks) {
        final lastCount = _lastVideoCount[type] ?? -1;
        if (lastCount != curatedVideos.length) {
          Log.debug(
              "ExploreVideoManager: Editor's Picks has ${curatedVideos.length} videos",
              name: 'ExploreVideoManager',
              category: LogCategory.system);
          if (curatedVideos.isNotEmpty) {
            final firstVideo = curatedVideos.first;
            Log.debug(
                '  First video: ${firstVideo.title ?? firstVideo.id.substring(0, 8)} from pubkey ${firstVideo.pubkey.substring(0, 8)}',
                name: 'ExploreVideoManager',
                category: LogCategory.system);
          }
          _lastVideoCount[type] = curatedVideos.length;
        }
      }

      Log.verbose('Synced ${curatedVideos.length} videos for ${type.name}',
          name: 'ExploreVideoManager', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to sync collection ${type.name}: $e',
          name: 'ExploreVideoManager', category: LogCategory.system);
      _availableCollections[type] = [];
    }
  }

  /// Refresh collections from curation service
  Future<void> refreshCollections() async {
    await _curationService.refreshCurationSets();
    // _onCurationChanged will be called automatically
  }

  /// Start preloading videos for a specific collection
  void preloadCollection(CurationSetType type, {int startIndex = 0}) {
    final videos = _availableCollections[type];
    if (videos != null && videos.isNotEmpty && startIndex < videos.length) {
      // Use VideoManager's preloading for the collection
      final videoManager = _videoManager;

      // Preload around the starting position
      final preloadStart = (startIndex - 2).clamp(0, videos.length - 1);
      final preloadEnd = (startIndex + 3).clamp(0, videos.length);

      for (var i = preloadStart; i < preloadEnd; i++) {
        // Simply preload the video - VideoManager will handle if it already exists
        videoManager.preloadVideo(videos[i].id).catchError((error) {
          Log.warning(
              'Error preloading video ${videos[i].id.substring(0, 8)}... - $error',
              name: 'ExploreVideoManager',
              category: LogCategory.system);
        });
      }

      Log.debug('⚡ Preloading ${type.name} collection around index $startIndex',
          name: 'ExploreVideoManager', category: LogCategory.system);
    }
  }

  /// Pause all videos in collections (called when leaving explore)
  void pauseAllVideos() {
    try {
      _videoManager.pauseAllVideos();
      Log.debug('Paused all explore videos',
          name: 'ExploreVideoManager', category: LogCategory.system);
    } catch (e) {
      Log.error('Error pausing explore videos: $e',
          name: 'ExploreVideoManager', category: LogCategory.system);
    }
  }

  /// Get VideoManager for direct access
  VideoManager get videoManager => _videoManager;

  void dispose() {
      // REFACTORED: Service no longer needs manual listener cleanup
    
  }
}
