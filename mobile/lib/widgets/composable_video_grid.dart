// ABOUTME: Composable video grid widget with automatic broken video filtering
// ABOUTME: Reusable component for Explore, Hashtag, and Search screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Composable video grid that automatically filters broken videos
/// and provides consistent styling across Explore, Hashtag, and Search screens
class ComposableVideoGrid extends ConsumerWidget {
  const ComposableVideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
    this.padding,
    this.emptyBuilder,
  });

  final List<VideoEvent> videos;
  final Function(List<VideoEvent> videos, int index) onVideoTap;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets? padding;
  final Widget Function()? emptyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch broken video tracker asynchronously
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) {
        // Fallback: show all videos if tracker fails
        return _buildGrid(context, ref, videos);
      },
      data: (tracker) {
        // Filter out broken videos
        final filteredVideos = videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();

        if (filteredVideos.isEmpty && emptyBuilder != null) {
          return emptyBuilder!();
        }

        return _buildGrid(context, ref, filteredVideos);
      },
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<VideoEvent> videosToShow) {
    if (videosToShow.isEmpty && emptyBuilder != null) {
      return emptyBuilder!();
    }

    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videosToShow.length,
      itemBuilder: (context, index) {
        final video = videosToShow[index];
        return _buildVideoTile(context, ref, video, index, videosToShow);
      },
    );
  }

  Widget _buildVideoTile(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
    int index,
    List<VideoEvent> displayedVideos,
  ) {
    return GestureDetector(
      onTap: () => onVideoTap(displayedVideos, index),
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Column(
            children: [
              // Video thumbnail with play overlay
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: VineTheme.cardBackground,
                      child: video.thumbnailUrl != null
                          ? VideoThumbnailWidget(
                              video: video,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: VineTheme.cardBackground,
                              child: Icon(
                                Icons.videocam,
                                size: 40,
                                color: VineTheme.secondaryText,
                              ),
                            ),
                    ),
                    // Play button overlay
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VineTheme.darkOverlay,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          size: 24,
                          color: VineTheme.whiteText,
                        ),
                      ),
                    ),
                    // Duration badge if available
                    if (video.duration != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: VineTheme.darkOverlay,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${video.duration}s',
                            style: TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Video info
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Creator name
                    _buildCreatorName(ref, video),
                    const SizedBox(height: 2),
                    // Title or content
                    Text(
                      video.title ?? video.content,
                      style: TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Stats row
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 11,
                          color: VineTheme.likeRed,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${video.originalLikes ?? 0}',
                          style: TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                        if (video.originalLoops != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.repeat,
                            size: 11,
                            color: VineTheme.secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${video.originalLoops}',
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorName(WidgetRef ref, VideoEvent video) {
    final profileService = ref.watch(userProfileServiceProvider);
    final profile = profileService.getCachedProfile(video.pubkey);
    final displayName = profile?.displayName ??
        profile?.name ??
        'Loading...';

    return Text(
      displayName,
      style: TextStyle(
        color: VineTheme.secondaryText,
        fontSize: 10,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
