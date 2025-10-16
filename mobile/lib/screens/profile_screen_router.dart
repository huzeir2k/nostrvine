// ABOUTME: Router-driven ProfileScreen implementation
// ABOUTME: Pure presentation with no lifecycle mutations - URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_page_view.dart';

/// Router-driven ProfileScreen - PageView syncs with URL bidirectionally
class ProfileScreenRouter extends ConsumerStatefulWidget {
  const ProfileScreenRouter({super.key});

  @override
  ConsumerState<ProfileScreenRouter> createState() =>
      _ProfileScreenRouterState();
}

class _ProfileScreenRouterState extends ConsumerState<ProfileScreenRouter> {
  PageController? _controller;
  int? _lastUrlIndex;
  int? _lastPrefetchIndex;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.info('🧭 ProfileScreenRouter.build', name: 'Profile');
    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return pageContext.when(
      data: (ctx) {
        // Only handle profile routes
        if (ctx.type != RouteType.profile) {
          return const Center(child: Text('Not a profile route'));
        }

        final urlIndex = ctx.videoIndex ?? 0;

        // Get video data from profile feed
        final videosAsync = ref.watch(videosForProfileRouteProvider);

        return videosAsync.when(
          data: (state) {
            final videos = state.videos;
            Log.info('UI PROFILE: loading=${state.isLoadingMore} items=${videos.length} err=null',
                name: 'Video', category: LogCategory.video);

            if (videos.isEmpty) {
              return const ProfileEmptyState();
            }

            final itemCount = videos.length;

            // Initialize controller once with URL index
            if (_controller == null) {
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              _controller = PageController(initialPage: safeIndex);
              _lastUrlIndex = safeIndex;
            }

            // Sync controller when URL changes externally (back/forward/deeplink)
            // Use post-frame to avoid calling jumpToPage during build
            if (urlIndex != _lastUrlIndex && _controller!.hasClients) {
              _lastUrlIndex = urlIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_controller!.hasClients) return;
                final safeIndex = urlIndex.clamp(0, itemCount - 1);
                final currentPage = _controller!.page?.round() ?? 0;
                if (currentPage != safeIndex) {
                  _controller!.jumpToPage(safeIndex);
                }
              });
            }

            // Prefetch profiles for adjacent videos (±1 index) only when URL index changes
            if (urlIndex != _lastPrefetchIndex) {
              _lastPrefetchIndex = urlIndex;
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              final pubkeysToPrefetech = <String>[];

              // Prefetch previous video's profile
              if (safeIndex > 0) {
                pubkeysToPrefetech.add(videos[safeIndex - 1].pubkey);
              }

              // Prefetch next video's profile
              if (safeIndex < itemCount - 1) {
                pubkeysToPrefetech.add(videos[safeIndex + 1].pubkey);
              }

              // Schedule prefetch for next frame to avoid doing work during build
              if (pubkeysToPrefetech.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ref
                      .read(userProfileProvider.notifier)
                      .prefetchProfilesImmediately(pubkeysToPrefetech);
                });
              }
            }

            return VideoPageView(
              videos: videos,
              controller: _controller,
              initialIndex: urlIndex,
              hasBottomNavigation: false, // Profile screen has no bottom nav
              enablePrewarming: true,
              enableLifecycleManagement: true,
              screenId: 'profile:${ctx.npub}',
              onPageChanged: (newIndex, video) {
                // Guard: only navigate if URL doesn't match
                if (newIndex != urlIndex) {
                  context.go(buildRoute(
                    RouteContext(
                      type: RouteType.profile,
                      npub: ctx.npub,
                      videoIndex: newIndex,
                    ),
                  ));
                }
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

/// Empty state widget shown when profile has no videos
class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
