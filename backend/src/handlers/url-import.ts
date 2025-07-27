// ABOUTME: URL-based video import handler that fetches videos from external URLs
// ABOUTME: Supports GCS and other HTTP sources with NIP-98 authentication

import { 
  NIP96UploadResponse, 
  NIP96ErrorResponse, 
  NIP96ErrorCode,
  FileMetadata
} from '../types/nip96';
import { 
  isSupportedContentType, 
  getMaxFileSize,
  isValidVideoContent,
  getFileExtension
} from './nip96-info';
import { 
  calculateSHA256
} from '../utils/nip94-generator';
import {
  validateNIP98Auth,
  extractUserPlan,
  createAuthErrorResponse
} from '../utils/nip98-auth';
import { MetadataStore } from '../services/metadata-store';
import { ThumbnailService } from '../services/ThumbnailService';

interface URLImportRequest {
  url: string;
  caption?: string;
  alt?: string;
  useCloudinary?: boolean; // Optional flag to use Cloudinary for processing
}

/**
 * Handle URL-based video import
 * Fetches video from URL and processes through existing pipeline
 */
export async function handleURLImport(
  request: Request, 
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  try {
    console.log('🌐 URL import handler started');
    
    // Validate NIP-98 authentication
    const authResult = await validateNIP98Auth(request);
    if (!authResult.valid) {
      console.error('NIP-98 authentication failed:', authResult.error);
      return createAuthErrorResponse(
        authResult.error || 'Valid NIP-98 authentication required',
        authResult.errorCode
      );
    }

    console.log(`✅ Authenticated user: ${authResult.pubkey}`);

    // Parse request body
    let importRequest: URLImportRequest;
    try {
      importRequest = await request.json();
    } catch (e) {
      return createErrorResponse(
        NIP96ErrorCode.SERVER_ERROR,
        'Invalid JSON in request body'
      );
    }

    if (!importRequest.url) {
      return createErrorResponse(
        NIP96ErrorCode.SERVER_ERROR,
        'URL parameter is required'
      );
    }

    // Validate URL
    let videoUrl: URL;
    try {
      videoUrl = new URL(importRequest.url);
      if (!['http:', 'https:'].includes(videoUrl.protocol)) {
        throw new Error('Only HTTP(S) URLs are supported');
      }
    } catch (e) {
      return createErrorResponse(
        NIP96ErrorCode.SERVER_ERROR,
        'Invalid URL provided'
      );
    }

    console.log(`📥 Fetching video from: ${videoUrl.href}`);

    // Fetch video from URL
    const fetchResponse = await fetch(videoUrl.href, {
      method: 'GET',
      headers: {
        'User-Agent': 'OpenVine/1.0 (Video Import Bot)'
      }
    });

    if (!fetchResponse.ok) {
      return createErrorResponse(
        NIP96ErrorCode.SERVER_ERROR,
        `Failed to fetch video: ${fetchResponse.status} ${fetchResponse.statusText}`
      );
    }

    // Get content type from response
    const contentType = fetchResponse.headers.get('content-type') || 'video/mp4';
    console.log(`📋 Content-Type header: ${contentType} for ${videoUrl.href}`);
    
    // Enhanced validation that handles GCS MIME type issues
    if (!isValidVideoContent(videoUrl.href, contentType)) {
      const extension = getFileExtension(videoUrl.href);
      console.log(`❌ Content validation failed: ${contentType} not supported for ${videoUrl.href} (extension: ${extension})`);
      return createErrorResponse(
        NIP96ErrorCode.INVALID_FILE_TYPE,
        `Content type ${contentType} not supported for URL ${videoUrl.href} (extension: ${extension})`
      );
    }
    
    console.log(`✅ Content validation passed for ${videoUrl.href}`);

    // Get content length
    const contentLength = fetchResponse.headers.get('content-length');
    const fileSize = contentLength ? parseInt(contentLength) : 0;

    // Extract user plan
    const userPlan = authResult.authEvent ? 
      extractUserPlan(authResult.authEvent) : 'free';

    // Validate file size if known
    if (fileSize > 0) {
      const maxSize = getMaxFileSize(userPlan);
      if (fileSize > maxSize) {
        return createErrorResponse(
          NIP96ErrorCode.FILE_TOO_LARGE,
          `File size ${fileSize} exceeds limit of ${maxSize} bytes`
        );
      }
    }

    // Download video data
    const fileData = await fetchResponse.arrayBuffer();
    
    // If content type was generic but we validated based on extension, 
    // use proper MIME type for processing
    let actualContentType = contentType;
    if (contentType === 'application/octet-stream' || contentType === 'application/binary') {
      const extension = getFileExtension(videoUrl.href);
      if (extension === '.mp4') {
        actualContentType = 'video/mp4';
      } else if (extension === '.webm') {
        actualContentType = 'video/webm';
      } else if (extension === '.mov') {
        actualContentType = 'video/quicktime';
      }
      console.log(`🔧 Content type corrected: ${contentType} -> ${actualContentType} for ${videoUrl.href}`);
    }
    
    // Validate actual size after download
    const actualSize = fileData.byteLength;
    const maxSize = getMaxFileSize(userPlan);
    if (actualSize > maxSize) {
      return createErrorResponse(
        NIP96ErrorCode.FILE_TOO_LARGE,
        `File size ${actualSize} exceeds limit of ${maxSize} bytes`
      );
    }

    // Calculate SHA256 hash
    const sha256Hash = await calculateSHA256(fileData);
    
    // Check for duplicates
    if (env.METADATA_CACHE) {
      const metadataStore = new MetadataStore(env.METADATA_CACHE);
      const duplicate = await metadataStore.checkDuplicateBySha256(sha256Hash);
      
      if (duplicate && duplicate.exists) {
        console.log(`🔁 Duplicate detected: ${duplicate.fileId}`);
        // Return existing file info
        const mediaUrl = `${new URL(request.url).origin}/media/${duplicate.fileId}`;
        
        return new Response(JSON.stringify({
          status: 'success',
          message: 'File already exists',
          processing_url: mediaUrl,
          download_url: mediaUrl,
          nip94_event: {
            kind: 1063,
            tags: [
              ['url', mediaUrl],
              ['x', sha256Hash],
              ['size', actualSize.toString()],
              ['m', actualContentType],
              ['dim', '640x640'], // Vines are square
              ['alt', importRequest.alt || `Video imported from ${videoUrl.hostname}`]
            ],
            content: importRequest.caption || ''
          }
        } as NIP96UploadResponse), {
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        });
      }
    }

    // Generate file ID
    const fileId = `${Date.now()}-${sha256Hash.substring(0, 8)}`;
    const filename = videoUrl.pathname.split('/').pop() || 'imported-video.mp4';

    console.log(`📁 Processing imported video: ${filename} (${actualSize} bytes)`);

    let mediaUrl: string;

    // Check if we should use Cloudinary for processing
    if (importRequest.useCloudinary && env.CLOUDINARY_API_KEY) {
      console.log('☁️ Using Cloudinary for video processing and moderation');
      
      // Upload to Cloudinary for processing, moderation, and thumbnail generation
      const cloudinaryResponse = await uploadToCloudinary(
        fileData,
        filename,
        actualContentType,
        authResult.pubkey,
        env
      );

      if (cloudinaryResponse.success && cloudinaryResponse.url) {
        // Store SHA256 mapping for deduplication
        if (env.METADATA_CACHE) {
          const metadataStore = new MetadataStore(env.METADATA_CACHE);
          await metadataStore.setFileIdBySha256(sha256Hash, fileId);
        }

        mediaUrl = cloudinaryResponse.url;
      } else {
        // Fallback to R2 if Cloudinary fails
        console.warn('Cloudinary upload failed, falling back to R2');
        mediaUrl = await storeInR2(fileData, fileId, filename, actualContentType, sha256Hash, videoUrl.href, authResult.pubkey, env, request);
      }
    } else {
      // Direct R2 storage
      mediaUrl = await storeInR2(fileData, fileId, filename, actualContentType, sha256Hash, videoUrl.href, authResult.pubkey, env, request);
    }

    // Trigger thumbnail generation in the background
    if (!importRequest.useCloudinary) {
      ctx.waitUntil(triggerThumbnailGeneration(fileId, new URL(request.url).origin));
    }
    
    const response: NIP96UploadResponse = {
      status: 'success',
      message: 'Video imported successfully',
      processing_url: mediaUrl,
      download_url: mediaUrl,
      nip94_event: {
        kind: 1063,
        tags: [
          ['url', mediaUrl],
          ['x', sha256Hash],
          ['size', actualSize.toString()],
          ['m', actualContentType],
          ['dim', '640x640'], // Vines are square
          ['alt', importRequest.alt || `Video imported from ${videoUrl.hostname}`]
        ],
        content: importRequest.caption || ''
      }
    };

    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('URL import error:', error);
    return createErrorResponse(
      NIP96ErrorCode.SERVER_ERROR,
      error instanceof Error ? error.message : 'Internal server error'
    );
  }
}

/**
 * Handle OPTIONS request for URL import endpoint
 */
export function handleURLImportOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Create NIP-96 error response
 */
function createErrorResponse(
  code: NIP96ErrorCode,
  message: string,
  status: number = 400
): Response {
  const response: NIP96ErrorResponse = {
    status: 'error',
    message,
    code
  };

  return new Response(JSON.stringify(response), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

/**
 * Store video directly in R2
 */
async function storeInR2(
  fileData: ArrayBuffer,
  fileId: string,
  filename: string,
  contentType: string,
  sha256Hash: string,
  originalUrl: string,
  uploaderPubkey: string,
  env: Env,
  request: Request
): Promise<string> {
  const r2Key = `uploads/${fileId}`;
  await env.MEDIA_BUCKET.put(r2Key, fileData, {
    httpMetadata: {
      contentType: contentType,
      contentDisposition: `inline; filename="${filename}"`
    },
    customMetadata: {
      sha256: sha256Hash,
      originalUrl: originalUrl,
      uploaderPubkey: uploaderPubkey,
      uploadedAt: Date.now().toString(),
      source: 'url-import'
    }
  });

  console.log(`✅ Video stored in R2: ${r2Key}`);

  // Store SHA256 mapping for deduplication
  if (env.METADATA_CACHE) {
    const metadataStore = new MetadataStore(env.METADATA_CACHE);
    await metadataStore.setFileIdBySha256(sha256Hash, fileId);
  }

  return `${new URL(request.url).origin}/media/${fileId}`;
}

/**
 * Upload video to Cloudinary for processing
 */
async function uploadToCloudinary(
  fileData: ArrayBuffer,
  filename: string,
  contentType: string,
  uploaderPubkey: string,
  env: Env
): Promise<{
  success: boolean;
  url?: string;
  public_id?: string;
  width?: number;
  height?: number;
  error?: string;
}> {
  try {
    const timestamp = Math.floor(Date.now() / 1000);
    const publicId = `nostrvine/${uploaderPubkey.substring(0, 16)}/${timestamp}_${filename.replace(/\.[^/.]+$/, '')}`;

    // Create upload parameters
    const params = {
      timestamp: timestamp,
      public_id: publicId,
      folder: 'nostrvine',
      resource_type: 'video',
      type: 'upload',
      // Enable moderation
      moderation: 'aws_rek_video',
      // Eager transformations for thumbnails (square for Vines)
      eager: [
        { width: 320, height: 320, crop: 'fill', quality: 'auto', format: 'jpg' },
        { width: 640, height: 640, crop: 'fill', quality: 'auto', format: 'jpg' },
        { width: 1280, height: 1280, crop: 'fill', quality: 'auto', format: 'jpg' }
      ],
      eager_async: true,
      context: `pubkey=${uploaderPubkey}|app=nostrvine|source=url-import`
    };

    // Generate signature
    const paramsToSign = Object.keys(params)
      .filter(k => k !== 'file' && k !== 'api_key' && k !== 'resource_type' && k !== 'eager')
      .sort()
      .map(k => `${k}=${params[k]}`)
      .join('&');

    const encoder = new TextEncoder();
    const data = encoder.encode(paramsToSign + (env as any).CLOUDINARY_API_SECRET);
    const hashBuffer = await crypto.subtle.digest('SHA-1', data);
    const signature = Array.from(new Uint8Array(hashBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    // Create form data
    const formData = new FormData();
    formData.append('file', new Blob([fileData], { type: contentType }), filename);
    formData.append('api_key', env.CLOUDINARY_API_KEY);
    formData.append('timestamp', timestamp.toString());
    formData.append('signature', signature);
    formData.append('public_id', publicId);
    formData.append('folder', 'nostrvine');
    formData.append('resource_type', 'video');
    formData.append('moderation', 'aws_rek_video');
    formData.append('eager', JSON.stringify(params.eager));
    formData.append('eager_async', 'true');
    formData.append('context', params.context);

    // Upload to Cloudinary
    const response = await fetch(
      `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/video/upload`,
      {
        method: 'POST',
        body: formData
      }
    );

    if (!response.ok) {
      const error = await response.text();
      console.error('Cloudinary upload failed:', error);
      return { success: false, error };
    }

    const result = await response.json();
    console.log(`✅ Video uploaded to Cloudinary: ${result.public_id}`);

    return {
      success: true,
      url: result.secure_url,
      public_id: result.public_id,
      width: result.width,
      height: result.height
    };

  } catch (error) {
    console.error('Cloudinary upload error:', error);
    return { success: false, error: error instanceof Error ? error.message : String(error) };
  }
}

/**
 * Trigger thumbnail generation by calling our own endpoint
 */
async function triggerThumbnailGeneration(videoId: string, baseUrl: string): Promise<void> {
  try {
    console.log(`🖼️ Triggering thumbnail generation for ${videoId}`);
    
    // Request medium size thumbnail which will generate it if not exists
    const thumbnailUrl = `${baseUrl}/thumbnail/${videoId}?size=medium&timestamp=1`;
    const response = await fetch(thumbnailUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'OpenVine-Internal/1.0'
      }
    });

    if (response.ok) {
      console.log(`✅ Thumbnail generation triggered for ${videoId}`);
    } else {
      console.warn(`⚠️ Thumbnail generation failed for ${videoId}: ${response.status}`);
    }
  } catch (error) {
    console.error(`❌ Failed to trigger thumbnail generation for ${videoId}:`, error);
  }
}