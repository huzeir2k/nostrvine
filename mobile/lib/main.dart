import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social_providers;
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/screens/activity_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/profile_screen.dart';
import 'package:openvine/screens/search_screen.dart';
import 'package:openvine/screens/universal_camera_screen.dart';
import 'package:openvine/screens/video_feed_screen.dart';
import 'package:openvine/screens/web_auth_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/global_video_registry.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global navigation key for hashtag navigation
final GlobalKey<MainNavigationScreenState> mainNavigationKey =
    GlobalKey<MainNavigationScreenState>();

void main() async {
  // Ensure bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for macOS to control actual window size
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    try {
      await windowManager.ensureInitialized();
      
      // Set initial window size for desktop vine experience
      const initialWindowOptions = WindowOptions(
        size: Size(750, 950), // Wider, better proportioned for desktop
        minimumSize: Size(ResponsiveWrapper.baseWidth, ResponsiveWrapper.baseHeight),
        center: true,
        backgroundColor: Colors.black,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      
      await windowManager.waitUntilReadyToShow(initialWindowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      // If window_manager fails, continue without it - ResponsiveWrapper will still work
      Log.error('Window manager initialization failed: $e', name: 'main');
    }
  }

  // Initialize logging configuration first
  await LoggingConfigService.instance.initialize();

  // Set default log level based on build mode if not already configured
  if (const String.fromEnvironment('LOG_LEVEL').isEmpty) {
    if (kDebugMode) {
      // Debug builds: enable debug logging for development visibility
      // Note: LogCategory.relay excluded to prevent verbose WebSocket message logging
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories({
        LogCategory.system,
        LogCategory.auth,
        LogCategory.video
      });
    } else {
      // Release builds: minimal logging to reduce performance impact
      UnifiedLogger.setLogLevel(LogLevel.warning);
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
    }
  }

  // Store original debugPrint to avoid recursion
  final originalDebugPrint = debugPrint;

  // Override debugPrint to respect logging levels
  debugPrint = (message, {wrapWidth}) {
    if (message != null && UnifiedLogger.isLevelEnabled(LogLevel.debug)) {
      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };

  // Handle Flutter framework errors more gracefully
  FlutterError.onError = (details) {
    // Log the error but don't crash the app for known framework issues
    if (details.exception.toString().contains('KeyDownEvent') ||
        details.exception.toString().contains('HardwareKeyboard')) {
      Log.warning(
          'Known Flutter framework keyboard issue (ignoring): ${details.exception}',
          name: 'Main');
      return;
    }

    // For other errors, use default handling
    FlutterError.presentError(details);
  };

  // Initialize Hive for local data storage
  await Hive.initFlutter();

  Log.info('OpenVine starting...', name: 'Main');
  Log.info('Log level: ${UnifiedLogger.currentLevel.name}', name: 'Main');

  runApp(const OpenVineApp());
}

class OpenVineApp extends StatelessWidget {
  const OpenVineApp({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: AppLifecycleHandler(
          child: MaterialApp(
            title: 'OpenVine',
            debugShowCheckedModeBanner: false,
            theme: VineTheme.theme,
            home: const ResponsiveWrapper(child: AppInitializer()),
            navigatorObservers: [VideoStopNavigatorObserver()],
          ),
        ),
      );
}

/// AppInitializer handles the async initialization of services
class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  bool _isInitialized = false;
  String _initializationStatus = 'Initializing services...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing background activity manager...');
      
      // Initialize background activity manager early
      try {
        await BackgroundActivityManager().initialize();
      } catch (e) {
        Log.warning('Failed to initialize background activity manager: $e', name: 'AppInitializer');
      }

      if (!mounted) return;
      setState(() => _initializationStatus = 'Checking authentication...');
      await ref.read(authServiceProvider).initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Connecting to Nostr network...');
      try {
        await ref.read(nostrServiceProvider).initialize();
      } catch (e) {
        Log.error('Nostr service initialization failed: $e',
            name: 'Main', category: LogCategory.system);
        // This is critical - rethrow
        rethrow;
      }

      // NotificationServiceEnhanced is initialized automatically via provider

      if (!mounted) return;
      setState(
          () => _initializationStatus = 'Initializing seen videos tracker...');
      await ref.read(seenVideosServiceProvider).initialize();

      if (!mounted) return;
      setState(() => _initializationStatus = 'Initializing upload manager...');
      await ref.read(uploadManagerProvider).initialize();

      if (!mounted) return;
      setState(
          () => _initializationStatus = 'Starting background publisher...');
      try {
        await ref.read(videoEventPublisherProvider).initialize();
      } catch (e) {
        Log.error(
            'VideoEventPublisher initialization failed (backend endpoint missing): $e',
            name: 'Main',
            category: LogCategory.system);
        // Continue anyway - this is for background publishing optimization
      }

      if (!mounted) return;
      setState(() => _initializationStatus = 'Loading curated content...');
      await ref.read(curationServiceProvider).subscribeToCurationSets();


      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _initializationStatus = 'Ready!';
      });

      // Initialize social provider synchronously to ensure it's ready for feed
      if (!mounted) return;
      setState(() => _initializationStatus = 'Loading social connections...');
      try {
        await ref.read(social_providers.socialNotifierProvider.notifier).initialize();
        Log.info('Social provider initialized successfully',
            name: 'Main', category: LogCategory.system);
      } catch (e) {
        Log.warning('Social provider initialization failed: $e',
            name: 'Main', category: LogCategory.system);
        // Continue anyway - social features will work with empty following list
      }

      Log.info('All services initialized successfully',
          name: 'Main', category: LogCategory.system);
      
    } catch (e, stackTrace) {
      Log.error('Service initialization failed: $e',
          name: 'Main', category: LogCategory.system);
      Log.verbose('📱 Stack trace: $stackTrace',
          name: 'Main', category: LogCategory.system);

      if (mounted) {
        setState(() {
          _isInitialized = true; // Continue anyway with basic functionality
          _initializationStatus = 'Initialization completed with errors';
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: VineTheme.vineGreen),
              const SizedBox(height: 16),
              Text(
                _initializationStatus,
                style:
                    const TextStyle(color: VineTheme.primaryText, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Use Consumer to watch AuthService state
    return Consumer(
      builder: (context, ref, child) {
        final authService = ref.watch(authServiceProvider);
        
        switch (authService.authState) {
          case AuthState.unauthenticated:
            // On web platform, show the web authentication screen
            if (kIsWeb) {
              return const WebAuthScreen();
            }

            // Show error screen only if there's an actual error, not for TikTok-style auto-creation
            if (authService.lastError != null) {
              return Scaffold(
                backgroundColor: VineTheme.backgroundColor,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Authentication Error',
                        style: TextStyle(
                            color: VineTheme.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authService.lastError!,
                        style: const TextStyle(
                            color: VineTheme.secondaryText, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => authService.initialize(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                          foregroundColor: VineTheme.whiteText,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            // If no error, fall through to loading screen (auto-creation in progress)
            return const Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: VineTheme.vineGreen),
                    SizedBox(height: 16),
                    Text(
                      'Creating your identity...',
                      style:
                          TextStyle(color: VineTheme.primaryText, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case AuthState.checking:
          case AuthState.authenticating:
            return Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VineTheme.vineGreen),
                    const SizedBox(height: 16),
                    Text(
                      authService.authState == AuthState.checking
                          ? 'Getting things ready...'
                          : 'Setting up your identity...',
                      style: const TextStyle(
                          color: VineTheme.primaryText, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case AuthState.authenticated:
            return MainNavigationScreen(key: mainNavigationKey);
        }
      },
    );
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({
    super.key,
    this.initialTabIndex,
    this.startingVideo,
    this.initialHashtag,
  });
  final int? initialTabIndex;
  final VideoEvent? startingVideo;
  final String? initialHashtag;

  @override
  ConsumerState<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<State<VideoFeedScreen>> _feedScreenKey =
      GlobalKey<State<VideoFeedScreen>>();
  DateTime? _lastFeedTap;

  late List<Widget> _screens; // Created once to preserve state
  final GlobalKey<ExploreScreenState> _exploreScreenKey =
      GlobalKey<ExploreScreenState>();
  
  // Profile viewing state
  String? _viewingProfilePubkey; // null means viewing own profile

  @override
  void initState() {
    super.initState();
    
    // Set initial tab based on whether user is following anyone
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!;
    } else {
      // Default to feed tab - social data will load and update the feed
      _currentIndex = 0;
      Log.info(
        'MainNavigation: Defaulting to feed tab',
        name: 'MainNavigation',
        category: LogCategory.ui,
      );
      
      // After social data loads, check if we should switch to explore
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          final socialData = ref.read(social_providers.socialNotifierProvider);
          if (socialData.isInitialized && socialData.followingPubkeys.isEmpty && mounted) {
            // User isn't following anyone - switch to explore tab
            setState(() {
              _currentIndex = 2;
            });
            Log.info(
              'MainNavigation: User not following anyone, switching to explore tab',
              name: 'MainNavigation',
              category: LogCategory.ui,
            );
          }
        });
      });
    }

    // Initialize tab visibility provider with initial tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tabVisibilityProvider.notifier).setActiveTab(_currentIndex);
    });

    // Create screens once - IndexedStack will preserve their state
    // ProfileScreen is created lazily to avoid unnecessary profile stats loading during startup
    // UNLESS we're starting on the profile tab
    _screens = [
      VideoFeedScreen(
        key: _feedScreenKey,
        startingVideo: widget.startingVideo,
      ),
      const ActivityScreen(),
      ExploreScreen(key: _exploreScreenKey),
      // If starting on profile tab, create it immediately; otherwise use placeholder
      widget.initialTabIndex == 3 
          ? const ProfileScreen(profilePubkey: null) // null means current user
          : Container(), // Placeholder for ProfileScreen - will be replaced when needed
    ];
    
    Log.info('📱 MainNavigation: Created screens array with ${_screens.length} screens',
        name: 'MainNavigation', category: LogCategory.ui);
    Log.info('📱 MainNavigation: Screen at index 0 is ${_screens[0].runtimeType}',
        name: 'MainNavigation', category: LogCategory.ui);

    // If initial hashtag is provided, navigate to explore tab after build
    if (widget.initialHashtag != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateToHashtag(widget.initialHashtag!);
      });
    }
  }

  void _onTabTapped(int index) {
    // Update tab visibility provider FIRST to trigger reactive video pausing
    ref.read(tabVisibilityProvider.notifier).setActiveTab(index);
    
    // Let tab visibility provider handle video pausing reactively
    // No need for manual pause calls - VideoFeedItem handles this via _getTabActiveStatus()
    
    // Notify screens of visibility changes
    if (_currentIndex == 2 && index != 2) {
      // Leaving explore screen
      _exploreScreenKey.currentState?.onScreenHidden();
    } else if (_currentIndex != 2 && index == 2) {
      // Entering explore screen
      _exploreScreenKey.currentState?.onScreenVisible();
    }

    // When tapping the profile tab directly, always show current user's profile
    if (index == 3) {
      // Reset to current user's profile when tapping the tab
      _viewingProfilePubkey = null;
      
      // Lazy load ProfileScreen when profile tab is first accessed
      if (_screens[3] is Container) {
        setState(() {
          _screens[3] = ProfileScreen(profilePubkey: null); // null means current user
        });
      } else {
        // Update existing ProfileScreen to show current user
        setState(() {
          _screens[3] = ProfileScreen(profilePubkey: null); // null means current user
        });
      }
    }

    // Check for double-tap on feed icon
    if (index == 0 && _currentIndex == 0) {
      final now = DateTime.now();
      if (_lastFeedTap != null &&
          now.difference(_lastFeedTap!).inMilliseconds < 500) {
        // Double tap detected - scroll to top and refresh
        _scrollToTopAndRefresh();
        _lastFeedTap = null; // Reset to prevent triple tap
        return;
      }
      _lastFeedTap = now;
    }

    // Check for tap on explore tab while already on explore tab
    if (index == 2 && _currentIndex == 2) {
      Log.debug('🔄 Explore tab tapped while on explore (index: $index, current: $_currentIndex)',
          name: 'MainNavigation', category: LogCategory.ui);
      // Tell explore screen to exit feed mode and return to grid (only if in feed mode)
      final exploreState = _exploreScreenKey.currentState;
      if (exploreState != null) {
        Log.debug('✅ Found explore screen state, isInFeedMode: ${exploreState.isInFeedMode}',
            name: 'MainNavigation', category: LogCategory.ui);
        if (exploreState.isInFeedMode) {
          Log.debug('🔄 Calling exitFeedMode() to return to grid',
              name: 'MainNavigation', category: LogCategory.ui);
          exploreState.exitFeedMode();
        } else {
          Log.debug('📱 Already in grid mode, no action needed',
              name: 'MainNavigation', category: LogCategory.ui);
        }
      } else {
        Log.warning('❌ Explore screen state is null - key: $_exploreScreenKey',
            name: 'MainNavigation', category: LogCategory.ui);
      }
      return;
    }

    // Tab visibility provider will handle pausing via reactive VideoFeedItem updates
    // No manual pause calls needed

    // Tab visibility provider will handle resuming via reactive VideoFeedItem updates
    // No manual resume calls needed

    setState(() {
      _currentIndex = index;
    });
  }


  void _scrollToTopAndRefresh() {
    try {
      // Use the static method to scroll to top and refresh
      VideoFeedScreen.scrollToTopAndRefresh(_feedScreenKey);
      Log.info('🔄 Double-tap: Scrolling to top and refreshing feed',
          name: 'Main', category: LogCategory.ui);
    } catch (e) {
      Log.error('Error scrolling to top and refreshing: $e',
          name: 'Main', category: LogCategory.ui);
    }
  }

  void navigateToHashtag(String hashtag) {
    // Switch to explore tab
    setState(() {
      _currentIndex = 2;
    });

    // Pass hashtag to explore screen
    _exploreScreenKey.currentState?.showHashtagVideos(hashtag);
  }

  /// Public method to switch to a specific tab
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      _onTabTapped(index);
    }
  }

  /// Navigate to a user's profile
  /// Called from other screens to view a specific user's profile
  void navigateToProfile(String? profilePubkey) {
    // IMMEDIATELY pause ALL videos on profile navigation
    GlobalVideoRegistry().pauseAllControllers();
    Log.info('⏸️ Paused all videos when navigating to profile',
        name: 'Main', category: LogCategory.system);
    
    setState(() {
      _viewingProfilePubkey = profilePubkey;
      // Always create or update the profile screen
      _screens[3] = ProfileScreen(profilePubkey: _viewingProfilePubkey);
      // Switch to profile tab
      _currentIndex = 3;
    });
  }

  /// Navigate to search functionality within explore
  /// Called from other screens to open search functionality
  void navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  /// Play a specific video in the explore tab with context videos
  /// Called from search results to play a video within its result set
  void playSpecificVideo(List<VideoEvent> videos, int startIndex) {
    // IMMEDIATELY pause ALL videos before playing specific video
    GlobalVideoRegistry().pauseAllControllers();
    Log.info('⏸️ Paused all videos before playing specific video',
        name: 'Main', category: LogCategory.system);
    
    // Switch to explore tab first
    _onTabTapped(2);
    
    // After switching tabs, play the specific video with its context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exploreScreenKey.currentState?.playSpecificVideo(videos, startIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    Log.info('📱 MainNavigation: build() - currentIndex=$_currentIndex',
        name: 'MainNavigation', category: LogCategory.ui);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: VineTheme.vineGreen,
        selectedItemColor: VineTheme.whiteText,
        unselectedItemColor: VineTheme.whiteText.withValues(alpha: 0.7),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'FEED',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'ACTIVITY',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'EXPLORE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'PROFILE',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            // Capture context before async operations
            final scaffoldContext = context;
            
            // IMMEDIATELY pause ALL videos before opening camera
            GlobalVideoRegistry().pauseAllControllers();
            Log.info('⏸️ Paused all videos before camera', name: 'Main', category: LogCategory.system);

            // Check age verification before opening camera
            final ageVerificationService = ref.read(ageVerificationServiceProvider);
            final isVerified =
                await ageVerificationService.checkAgeVerification();

            if (!isVerified && mounted) {
              // Show age verification dialog
              if (!scaffoldContext.mounted) return;
              final result = await AgeVerificationDialog.show(scaffoldContext);
              if (result) {
                // User confirmed they are 16+
                await ageVerificationService.setAgeVerified(true);
                if (mounted) {
                  // Use universal camera screen that works on all platforms
                  if (scaffoldContext.mounted) {
                    await Navigator.push(
                      scaffoldContext,
                      MaterialPageRoute(
                          builder: (context) => const UniversalCameraScreen()),
                    );
                  }

                  // After returning from camera, refresh profile if on profile tab
                  if (mounted && _currentIndex == 3) {
                    Log.debug('Refreshing profile after camera return',
                        name: 'Main', category: LogCategory.system);
                    // Profile videos will auto-refresh when screen is rebuilt
                  }
                }
              } else {
                // User is under 16 or declined
                if (mounted) {
                  if (scaffoldContext.mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    const SnackBar(
                      content:
                          Text('You must be 16 or older to create content'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  }
                }
              }
            } else if (mounted) {
              // Already verified, go to camera
              if (scaffoldContext.mounted) {
                await Navigator.push(
                  scaffoldContext,
                  MaterialPageRoute(
                      builder: (context) => const UniversalCameraScreen()),
                );
              }

              // After returning from camera, refresh profile if on profile tab
              if (mounted && _currentIndex == 3) {
                Log.debug('Refreshing profile after camera return',
                    name: 'Main', category: LogCategory.system);
                // Profile videos will auto-refresh when screen is rebuilt
              }
            }
          },
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.whiteText,
          child: const Icon(Icons.videocam, size: 32),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      );
  }
}

/// ResponsiveWrapper adapts app size based on available screen space
class ResponsiveWrapper extends StatefulWidget {
  const ResponsiveWrapper({required this.child, super.key});
  final Widget child;

  // Base dimensions for desktop vine experience (1x scale)
  static const double baseWidth = 450; // Wider for better desktop experience
  static const double baseHeight = 700; // Taller but more proportionate for desktop
  
  // Calculate optimal dimensions based on screen size
  static Size getOptimalSize(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // For desktop vine experience, use more width while keeping vine feel
    // On web, be more generous with space since browsers can handle larger content
    final isWeb = kIsWeb;
    final targetWidth = screenSize.width * (isWeb ? 0.7 : 0.6); // More generous width for better desktop experience
    final targetHeight = screenSize.height * (isWeb ? 0.9 : 0.85); // Use most of screen height
    
    // Calculate scale factor to fit within target dimensions
    final widthScale = targetWidth / baseWidth;
    final heightScale = targetHeight / baseHeight;
    
    // Use the smaller scale to ensure both dimensions fit, but prioritize the classic vine aspect ratio
    final scaleFactor = (widthScale < heightScale ? widthScale : heightScale).clamp(1.2, 4.0);
    
    return Size(
      baseWidth * scaleFactor,
      baseHeight * scaleFactor,
    );
  }

  @override
  State<ResponsiveWrapper> createState() => _ResponsiveWrapperState();
}

class _ResponsiveWrapperState extends State<ResponsiveWrapper> {
  @override
  void initState() {
    super.initState();

    // Update window size after first frame when we have screen info
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateWindowSize();
      });
    }

    // Force rebuilds on window resize for web
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Listen to media query changes which includes window resizing
        MediaQuery.of(context);
      });
    }
  }

  Future<void> _updateWindowSize() async {
    if (!mounted) return;
    
    try {
      final optimalSize = ResponsiveWrapper.getOptimalSize(context);
      
      // Update window size to accommodate the scaled content
      await windowManager.setSize(Size(
        optimalSize.width + 20, // Minimal padding for window chrome
        optimalSize.height + 80, // Padding for title bar and chrome
      ));
      
      // Re-center the window
      await windowManager.center();
    } catch (e) {
      // Silently fail if window manager isn't available
      Log.error('Failed to update window size: $e', name: 'main');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web needs to fill the entire browser viewport with no gaps
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: widget.child,
      );
    } else if (defaultTargetPlatform == TargetPlatform.macOS || 
               defaultTargetPlatform == TargetPlatform.windows || 
               defaultTargetPlatform == TargetPlatform.linux) {
      // On desktop platforms, just return the child to fill the window
      // Window size is managed by windowManager, no need for containers or centering
      return widget.child;
    }

    // On mobile, return child as-is (no constraints)
    return widget.child;
  }
}