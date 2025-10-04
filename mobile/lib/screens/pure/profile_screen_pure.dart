// ABOUTME: Pure profile screen using revolutionary Riverpod architecture
// ABOUTME: Shows user profile with video grid display using composition architecture

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_videos_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/pure/video_grid_widget.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure profile screen using revolutionary single-controller Riverpod architecture
class ProfileScreenPure extends ConsumerStatefulWidget {
  const ProfileScreenPure({super.key, this.profilePubkey});

  final String? profilePubkey; // If null, shows current user's profile

  @override
  ConsumerState<ProfileScreenPure> createState() => _ProfileScreenPureState();
}

class _ProfileScreenPureState extends ConsumerState<ProfileScreenPure>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOwnProfile = true;
  String? _targetPubkey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize profile after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfile();
    });

    Log.info('👤 ProfileScreenPure: Initialized',
        category: LogCategory.video);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();

    Log.info('👤 ProfileScreenPure: Disposed',
        category: LogCategory.video);
  }

  void _initializeProfile() {
    final authService = ref.read(authServiceProvider);

    if (widget.profilePubkey != null) {
      // Viewing another user's profile
      _targetPubkey = widget.profilePubkey!;
      _isOwnProfile = false;
    } else {
      // Viewing own profile
      _targetPubkey = authService.currentPublicKeyHex;
      _isOwnProfile = true;
    }

    setState(() {});

    final pubkeyPreview = _targetPubkey != null && _targetPubkey!.length > 8
        ? '${_targetPubkey!.substring(0, 8)}...'
        : _targetPubkey ?? 'unknown';
    Log.info('👤 ProfileScreenPure: Initialized for ${_isOwnProfile ? "own" : "other"} profile: $pubkeyPreview',
        category: LogCategory.video);

    // Load videos for this profile
    if (_targetPubkey != null) {
      ref.read(profileVideosProvider.notifier).loadVideosForUser(_targetPubkey!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetPubkey == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          _isOwnProfile ? 'My Profile' : 'Profile',
          style: const TextStyle(color: Colors.white),
        ),
        leading: _isOwnProfile
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Videos'),
            Tab(text: 'Likes'),
            Tab(text: 'Followers'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideosTab(),
          _buildLikesTab(),
          _buildFollowersTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    // Watch user's videos from profile notifier
    final videosState = ref.watch(profileVideosProvider);

    // Convert to AsyncValue for compatibility
    final videosAsync = videosState.isLoading && videosState.videos.isEmpty
        ? const AsyncValue<List<VideoEvent>>.loading()
        : videosState.hasError
            ? AsyncValue<List<VideoEvent>>.error(videosState.error!, StackTrace.current)
            : AsyncValue.data(videosState.videos);

    return videosAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load videos',
              style: TextStyle(color: Colors.red),
            ),
            Text(
              '$error',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      data: (videos) => VideoGridWidget(
        key: const Key('profile-videos-grid'),
        videos: videos,
        crossAxisCount: 3, // Tighter grid for profile
        emptyMessage: _isOwnProfile
          ? 'No videos yet\nTap + to create your first vine!'
          : 'No videos from this user',
      ),
    );
  }

  Widget _buildLikesTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Liked Videos',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          Text(
            'Coming soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowersTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Social Network',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          Text(
            'Followers & Following coming soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    if (!_isOwnProfile) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'User Profile',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            Text(
              'Profile details coming soon',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Settings',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          Text(
            'Profile settings coming soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}