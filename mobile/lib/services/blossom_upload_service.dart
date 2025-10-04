// ABOUTME: Service for uploading videos to user-configured Blossom media servers
// ABOUTME: Supports Blossom BUD-01 authentication and returns media URLs from any Blossom server

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/hash_util.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result type for Blossom upload operations
class BlossomUploadResult {
  final bool success;
  final String? videoId;
  final String? cdnUrl;
  final String? gifUrl;
  final String? thumbnailUrl;
  final String? blurhash;
  final String? errorMessage;

  const BlossomUploadResult({
    required this.success,
    this.videoId,
    this.cdnUrl,
    this.gifUrl,
    this.thumbnailUrl,
    this.blurhash,
    this.errorMessage,
  });
}

class BlossomUploadService {
  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';
  static const String defaultBlossomServer = 'https://cf-stream-service-prod.protestnet.workers.dev';
  
  final AuthService authService;
  final INostrService nostrService;
  final Dio dio;
  
  BlossomUploadService({
    required this.authService, 
    required this.nostrService,
    Dio? dio,
  }) : dio = dio ?? Dio();
  
  /// Get the configured Blossom server URL
  Future<String?> getBlossomServer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_blossomServerKey);
    // If nothing is stored, return default. If empty string is stored, return it.
    return stored ?? defaultBlossomServer;
  }
  
  /// Set the Blossom server URL
  Future<void> setBlossomServer(String? serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      await prefs.setString(_blossomServerKey, serverUrl);
    } else {
      // Store empty string to indicate "no server configured"
      await prefs.setString(_blossomServerKey, '');
    }
  }
  
  /// Check if Blossom upload is enabled
  Future<bool> isBlossomEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBlossomKey) ?? true; // Default to true
  }
  
  /// Enable or disable Blossom upload
  Future<void> setBlossomEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBlossomKey, enabled);
  }
  

  /// Create a Blossom authentication event for upload
  Future<Event?> _createBlossomAuthEvent({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
  }) async {
    try {
      // Blossom requires these tags (BUD-01):
      // - t: "upload" to indicate upload request
      // - expiration: Unix timestamp when auth expires
      // - x: SHA-256 hash of the file (optional but recommended)

      final now = DateTime.now();
      final expiration = now.add(const Duration(minutes: 5)); // 5 minute expiration
      final expirationTimestamp = expiration.millisecondsSinceEpoch ~/ 1000;

      // Build tags for Blossom auth event (kind 24242)
      final tags = [
        ['t', 'upload'],
        ['expiration', expirationTimestamp.toString()],
        ['x', fileHash], // SHA-256 hash of the file
      ];

      // Create human-readable content explaining the action
      const content = 'Upload video to Blossom server';

      // Use AuthService to create and sign the event (established pattern)
      final signedEvent = await authService.createAndSignEvent(
        kind: 24242, // Blossom auth event kind
        content: content,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error('Failed to create/sign Blossom auth event via AuthService',
            name: 'BlossomUploadService', category: LogCategory.video);
        return null;
      }

      Log.info('Created Blossom auth event: ${signedEvent.id}',
          name: 'BlossomUploadService', category: LogCategory.video);

      return signedEvent;
    } catch (e) {
      Log.error('Error creating Blossom auth event: $e',
          name: 'BlossomUploadService', category: LogCategory.video);
      return null;
    }
  }

  /// Upload a video file to the configured Blossom server
  /// 
  /// This method currently returns a placeholder implementation.
  /// The actual Blossom upload will be implemented using the SDK's
  /// BolssomUploader when the Nostr service integration is ready.
  Future<BlossomUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    required String title,
    String? description,
    List<String>? hashtags,
    void Function(double)? onProgress,
  }) async {
    try {
      // Check if Blossom is enabled and configured
      final isEnabled = await isBlossomEnabled();
      if (!isEnabled) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Blossom upload is not enabled',
        );
      }
      
      final serverUrl = await getBlossomServer();
      if (serverUrl == null || serverUrl.isEmpty) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'No Blossom server configured',
        );
      }
      
      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL',
        );
      }
      
      // Check authentication after URL validation
      if (!authService.isAuthenticated) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }
      
      Log.info('Uploading to Blossom server: $serverUrl',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('Checking if user is authenticated...',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Check if user is authenticated (has keys available)
      if (!authService.isAuthenticated) {
        Log.error('❌ User not authenticated - cannot sign Blossom requests',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'User not authenticated - please sign in to upload',
        );
      }

      Log.info('✅ User is authenticated, can create signed events',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      // For now, we'll use a simplified approach since the embedded relay doesn't expose Nostr SDK
      // We'll need to create the upload using direct HTTP calls with Blossom BUD-01 auth
      Log.warning('Blossom upload using SDK integration is pending - needs NostrService refactoring',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      // Report initial progress
      onProgress?.call(0.1);

      Log.info('Reading file bytes for hash calculation...',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Calculate file hash for Blossom
      final fileBytes = await videoFile.readAsBytes();
      Log.info('File bytes read: ${fileBytes.length} bytes',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('Calculating SHA-256 hash...',
          name: 'BlossomUploadService', category: LogCategory.video);
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;
      
      Log.info('File hash: $fileHash, size: $fileSize bytes',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      // Create Blossom auth event
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }
      
      // Prepare authorization header
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      Log.info('🔐 Auth event JSON: $authEventJson',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('🔐 Base64 auth payload: ${base64.encode(utf8.encode(authEventJson))}',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('Blossom BUD-01 Upload: Sending raw file bytes with PUT request',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('🔍 Upload request details:',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  📍 URL: $serverUrl/upload',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  📝 Method: PUT with raw bytes',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  📊 File size: $fileSize bytes',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  🔐 Auth header length: ${authHeader.length} chars',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  🔐 Auth header preview: ${authHeader.substring(0, 50)}...',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Blossom BUD-01: PUT raw file bytes directly to /upload
      final response = await dio.put(
        '$serverUrl/upload',
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'video/mp4',
            'Content-Length': fileSize.toString(),
          },
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Progress from 10% to 90% during upload
            final progress = 0.1 + (sent / total) * 0.8;
            onProgress?.call(progress);
          }
        },
      );

      Log.info('Blossom server response: ${response.statusCode}',
            name: 'BlossomUploadService', category: LogCategory.video);
        Log.info('Response headers: ${response.headers}',
            name: 'BlossomUploadService', category: LogCategory.video);
        Log.info('Response data type: ${response.data.runtimeType}',
            name: 'BlossomUploadService', category: LogCategory.video);
        Log.info('Response data: ${response.data}',
            name: 'BlossomUploadService', category: LogCategory.video);

        // Handle HTTP 409 Conflict - file already exists on server
        if (response.statusCode == 409) {
          Log.info('✅ File already exists on Blossom server (hash: $fileHash)',
              name: 'BlossomUploadService', category: LogCategory.video);

          // Try to extract URL from response, fall back to cdn.divine.video
          String existingUrl;
          if (response.data is Map) {
            final urlRaw = response.data['url'];
            existingUrl = urlRaw?.toString() ?? 'https://cdn.divine.video/$fileHash';
          } else {
            existingUrl = 'https://cdn.divine.video/$fileHash';
          }

          onProgress?.call(1.0);

          Log.info('  Using existing URL: $existingUrl',
              name: 'BlossomUploadService', category: LogCategory.video);

          return BlossomUploadResult(
            success: true,
            videoId: fileHash,
            cdnUrl: existingUrl,
          );
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          Log.info('✅ Upload completed successfully',
              name: 'BlossomUploadService', category: LogCategory.video);
          onProgress?.call(0.95);

          // Parse Blossom BUD-01 response: {sha256, url, size, type, uploaded}
          // Apply Postel's Law: be liberal in what we accept
          final blobData = response.data;

          if (blobData is Map) {
            // Robustly extract fields - handle different types and missing fields
            final sha256Raw = blobData['sha256'];
            final sha256 = sha256Raw?.toString();

            final urlRaw = blobData['url'];
            final mediaUrl = urlRaw?.toString();

            final uploadedRaw = blobData['uploaded'];
            final uploadedTimestamp = uploadedRaw?.toString();

            // URL is the only required field
            if (mediaUrl != null && mediaUrl.isNotEmpty) {
              // Extract video ID from hash, fallback to our calculated hash
              final videoId = (sha256 != null && sha256.isNotEmpty) ? sha256 : fileHash;

              onProgress?.call(1.0);

              Log.info('✅ Blossom upload successful',
                  name: 'BlossomUploadService', category: LogCategory.video);
              Log.info('  URL: $mediaUrl',
                  name: 'BlossomUploadService', category: LogCategory.video);
              Log.info('  SHA256: ${sha256 ?? fileHash} ${sha256 == null ? "(calculated)" : ""}',
                  name: 'BlossomUploadService', category: LogCategory.video);
              Log.info('  Uploaded: ${uploadedTimestamp ?? "unknown"}',
                  name: 'BlossomUploadService', category: LogCategory.video);

              return BlossomUploadResult(
                success: true,
                cdnUrl: mediaUrl,
                videoId: videoId,
              );
            } else {
              // Log full response for debugging
              Log.error('Missing or empty URL field in response. Full response: $blobData',
                  name: 'BlossomUploadService', category: LogCategory.video);
              return BlossomUploadResult(
                success: false,
                errorMessage: 'Invalid Blossom response: missing or empty URL field',
              );
            }
          } else {
            // Log unexpected response type
            Log.error('Expected JSON object, got: ${blobData.runtimeType}. Response: $blobData',
                name: 'BlossomUploadService', category: LogCategory.video);
            return BlossomUploadResult(
              success: false,
              errorMessage: 'Invalid Blossom response format: expected JSON object, got ${blobData.runtimeType}',
            );
          }
        } else if (response.statusCode == 401) {
          Log.error('❌ Blossom authentication failed: ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Authentication failed - check your Nostr keys. Server response: ${response.data}',
          );
        } else if (response.statusCode == 413) {
          Log.error('❌ Blossom file too large: ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'File too large for this Blossom server. Server response: ${response.data}',
          );
        } else {
          Log.error('❌ Upload failed: ${response.statusCode} - ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Upload failed: ${response.statusCode} - ${response.data}',
          );
        }
    } on DioException catch (e) {
      Log.error('Blossom upload network error: ${e.message}',
          name: 'BlossomUploadService', category: LogCategory.video);

      if (e.type == DioExceptionType.connectionTimeout) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Connection timeout - check server URL',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Cannot connect to Blossom server',
        );
      } else {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Network error: ${e.message}',
        );
      }
    } catch (e) {
      Log.error('Blossom upload error: $e',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Blossom upload failed: $e',
      );
    }
  }

  /// Upload an image file (e.g. thumbnail) to the configured Blossom server
  ///
  /// This uses the same Blossom BUD-01 protocol as video uploads but with image MIME type
  Future<BlossomUploadResult> uploadImage({
    required File imageFile,
    required String nostrPubkey,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check if Blossom is enabled and configured
      final isEnabled = await isBlossomEnabled();
      if (!isEnabled) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Blossom upload is not enabled',
        );
      }

      final serverUrl = await getBlossomServer();
      if (serverUrl == null || serverUrl.isEmpty) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'No Blossom server configured',
        );
      }

      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL',
        );
      }

      // Check authentication
      if (!authService.isAuthenticated) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      Log.info('Uploading image to Blossom server: $serverUrl',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Report initial progress
      onProgress?.call(0.1);

      // Calculate file hash for Blossom
      final fileBytes = await imageFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info('Image file hash: $fileHash, size: $fileSize bytes',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Create Blossom auth event
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }

      // Prepare authorization header
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      Log.info('📤 Blossom BUD-01 Image Upload: PUT raw bytes to $serverUrl/upload',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Blossom BUD-01: PUT raw file bytes directly to /upload
      final response = await dio.put(
        '$serverUrl/upload',
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {
            'Authorization': authHeader,
            'Content-Type': mimeType,
            'Content-Length': fileSize.toString(),
          },
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = 0.1 + (sent / total) * 0.8;
            onProgress?.call(progress);
          }
        },
      );

      Log.info('Response status: ${response.statusCode}',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Handle HTTP 409 Conflict - file already exists
      if (response.statusCode == 409) {
        Log.info('✅ Image already exists on server (hash: $fileHash)',
            name: 'BlossomUploadService', category: LogCategory.video);

        final existingUrl = 'https://cdn.divine.video/$fileHash';
        onProgress?.call(1.0);

        return BlossomUploadResult(
          success: true,
          videoId: fileHash,
          cdnUrl: existingUrl,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        Log.info('✅ Image upload successful',
            name: 'BlossomUploadService', category: LogCategory.video);
        onProgress?.call(0.95);

        // Parse Blossom BUD-01 response: {sha256, url, size, type}
        final blobData = response.data;

        if (blobData is Map) {
          final sha256 = blobData['sha256'] as String?;
          final mediaUrl = blobData['url'] as String?;

          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            final imageId = sha256 ?? fileHash;

            onProgress?.call(1.0);

            Log.info('  URL: $mediaUrl',
                name: 'BlossomUploadService', category: LogCategory.video);
            Log.info('  SHA256: $sha256',
                name: 'BlossomUploadService', category: LogCategory.video);

            return BlossomUploadResult(
              success: true,
              cdnUrl: mediaUrl,
              videoId: imageId,
            );
          } else {
            return BlossomUploadResult(
              success: false,
              errorMessage: 'Invalid Blossom response: missing URL field',
            );
          }
        } else {
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Invalid Blossom response format',
          );
        }
      } else if (response.statusCode == 401) {
        Log.error('❌ Authentication failed: ${response.data}',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Authentication failed',
        );
      } else {
        Log.error('❌ Image upload failed: ${response.statusCode}',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Image upload failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      Log.error('Image upload exception: $e',
          name: 'BlossomUploadService', category: LogCategory.video);
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Image upload failed: $e',
      );
    }
  }
}