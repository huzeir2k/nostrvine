// ABOUTME: Reusable video grid widget using pure Riverpod architecture for any video list
// ABOUTME: Composable building block that can be used in profiles, search results, feeds, etc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Reusable video grid widget for any list of videos
class VideoGridWidget extends ConsumerStatefulWidget {
  const VideoGridWidget({
    super.key,
    required this.videos,
    this.crossAxisCount = 2,
    this.onVideoTap,
    this.emptyMessage = 'No videos available',
  });

  final List<VideoEvent> videos;
  final int crossAxisCount;
  final Function(List<VideoEvent> videos, int index)? onVideoTap;
  final String emptyMessage;

  @override
  ConsumerState<VideoGridWidget> createState() => _VideoGridWidgetState();
}

class _VideoGridWidgetState extends ConsumerState<VideoGridWidget> {
  bool _isInFeedMode = false;
  // ignore: unused_field
  int _feedStartIndex = 0;

  void _enterFeedMode(List<VideoEvent> videos, int startIndex) {
    if (!mounted) return;

    setState(() {
      _isInFeedMode = true;
      _feedStartIndex = startIndex;
    });

    Log.info('🎬 VideoGridWidget: Entered feed mode at index $startIndex',
        category: LogCategory.video);
  }

  void _exitFeedMode() {
    if (!mounted) return;

    setState(() {
      _isInFeedMode = false;
      _feedStartIndex = 0;
    });

    Log.info('🎬 VideoGridWidget: Exited feed mode',
        category: LogCategory.video);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInFeedMode) {
      return _buildFeedMode();
    }

    return _buildGrid();
  }

  Widget _buildFeedMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          key: const Key('back-button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _exitFeedMode,
        ),
        title: const Text('Videos', style: TextStyle(color: Colors.white)),
      ),
      body: ExploreVideoScreenPure(
        startingVideo: widget.videos[_feedStartIndex],
        videoList: widget.videos,
        contextTitle: '', // Don't show generic "Videos" label
        startingIndex: _feedStartIndex,
      ),
    );
  }

  Widget _buildGrid() {
    if (widget.videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final video = widget.videos[index];
        return _buildVideoTile(video, index);
      },
    );
  }

  Widget _buildVideoTile(VideoEvent video, int index) {
    return GestureDetector(
      onTap: () {
        if (widget.onVideoTap != null) {
          widget.onVideoTap!(widget.videos, index);
        } else {
          _enterFeedMode(widget.videos, index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          children: [
            // Video thumbnail
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Icon(
                  Icons.play_circle_filled,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
            ),
            // Video metadata
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title ?? video.content.substring(0, video.content.length > 30 ? 30 : video.content.length),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${video.originalLikes ?? 0} likes',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
