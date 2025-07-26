// ABOUTME: Universal camera screen that works on all platforms (mobile, macOS, web, Windows)
// ABOUTME: Uses VineRecordingController abstraction for consistent recording experience

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/main.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_manager_providers.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/video_metadata_screen.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/vine_recording_controls.dart';

class UniversalCameraScreen extends ConsumerStatefulWidget {
  const UniversalCameraScreen({super.key});

  @override
  ConsumerState<UniversalCameraScreen> createState() => _UniversalCameraScreenState();
}

class _UniversalCameraScreenState extends ConsumerState<UniversalCameraScreen> {
  late final NostrKeyManager _keyManager;
  UploadManager? _uploadManager;

  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    // Provider handles disposal automatically
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // Use post-frame callback to avoid provider modification during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // Stop all background videos after widget tree is built
          final videoManager = ref.read(videoManagerProvider.notifier);
          videoManager.stopAllVideos();
          Log.info('Stopped all background videos on camera screen init',
              name: 'UniversalCameraScreen', category: LogCategory.ui);

          // Get services from providers
          _uploadManager = ref.read(uploadManagerProvider);
          _keyManager = ref.read(nostrKeyManagerProvider);

          // Initialize recording controller via provider
          final recordingNotifier = ref.read(vineRecordingProvider.notifier);
          await recordingNotifier.initialize();

          if (mounted) {
            setState(() {
              _errorMessage = null;
            });
          }

          // For macOS, give the camera widget time to mount and initialize
          if (mounted && Theme.of(context).platform == TargetPlatform.macOS) {
            Log.debug('📱 Waiting for macOS camera widget to mount...',
                name: 'UniversalCameraScreen', category: LogCategory.ui);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Log.debug('📱 macOS camera widget should now be mounted',
                  name: 'UniversalCameraScreen', category: LogCategory.ui);
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to initialize camera: $e';
            });
          }
          Log.error('Camera initialization failed: $e',
              name: 'UniversalCameraScreen', category: LogCategory.ui);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
      Log.error('Camera initialization failed: $e',
          name: 'UniversalCameraScreen', category: LogCategory.ui);
    }
  }

  Future<void> _onRecordingComplete() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Finish recording and get the video file
      final recordingNotifier = ref.read(vineRecordingProvider.notifier);
      final videoFile = await recordingNotifier.finishRecording();

      if (videoFile != null && mounted) {
        // Navigate to metadata screen
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreen(
              videoFile: videoFile,
              duration: recordingNotifier.controller.totalRecordedDuration,
            ),
          ),
        );

        if (result != null && mounted) {
          // Get current user's pubkey
          final pubkey = _keyManager.publicKey ?? '';

          // Start upload through upload manager
          await _uploadManager!.startUpload(
            videoFile: videoFile,
            nostrPubkey: pubkey,
            title: result['caption'] ?? '',
            description: result['caption'] ?? '',
            hashtags: result['hashtags'] ?? [],
          );

          // Don't reset here - let files persist until next recording session

          // Navigate back to the main feed immediately after starting upload
          // The upload will continue in the background
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    const MainNavigationScreen(initialTabIndex: 0),
              ),
            );
          }
        }
      }
    } catch (e) {
      Log.error('Error processing recording: $e',
          name: 'UniversalCameraScreen', category: LogCategory.ui);

      // Don't reset here on error - let files persist until next recording session

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process recording: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onCancel() {
    // Just navigate back - keep recordings for potential retry
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Record Vine'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Stack(
          children: [
            // Camera preview (full screen)
            if (_errorMessage == null)
              Positioned.fill(
                child: Consumer(
                  builder: (context, ref, child) {
                    Log.debug('📱 Building camera preview widget',
                        name: 'UniversalCameraScreen',
                        category: LogCategory.ui);
                    final controller = ref.watch(vineRecordingProvider.notifier).controller;
                    return controller.cameraPreview;
                  },
                ),
              )
            else
              _buildErrorView(),

            // Recording UI overlay
            if (_errorMessage == null)
              Positioned.fill(
                child: Consumer(
                  builder: (context, ref, child) {
                    final recordingNotifier = ref.watch(vineRecordingProvider.notifier);
                    ref.watch(vineRecordingProvider); // Watch state to trigger rebuilds
                    return VineRecordingUI(
                      controller: recordingNotifier.controller,
                      onRecordingComplete: _onRecordingComplete,
                      onCancel: _onCancel,
                    );
                  },
                ),
              ),

            // Upload progress indicator removed - we navigate away immediately after upload starts

            // Processing overlay
            if (_isProcessing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              VineTheme.vineGreen),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing your vine...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildErrorView() => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Camera Error',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _initializeServices,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
