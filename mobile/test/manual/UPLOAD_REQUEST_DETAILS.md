# Upload Request Details - How We Send Data to Blossom Server

## Date: 2025-10-04

## Server Configuration

**Default Blossom Server**: `https://cf-stream-service-prod.protestnet.workers.dev`

**Endpoint**: `/upload`

**Full URL**: `https://cf-stream-service-prod.protestnet.workers.dev/upload`

**User Configurable**: Yes - users can set their own Blossom server via `SharedPreferences`:
- Key: `blossom_server_url`
- Default: `https://cf-stream-service-prod.protestnet.workers.dev`
- Can be changed to any Blossom BUD-01 compliant server

---

## Upload Protocol: Blossom BUD-01

**Specification**: Single PUT request with raw file bytes

**Reference**: Blossom BUD-01 (Blossom Upload/Download) specification

**Implementation**: `lib/services/blossom_upload_service.dart:266-284`

---

## HTTP Request Details

### Method
```
PUT
```

### URL
```
https://cf-stream-service-prod.protestnet.workers.dev/upload
```

### Headers

#### 1. Authorization (Nostr Signature)
```
Authorization: Nostr <base64-encoded-event>
```

**Format**:
1. Create Nostr event (kind 24242 - Blossom auth)
2. Sign event with user's private key
3. Encode event JSON as base64
4. Prefix with "Nostr "

**Example**:
```
Authorization: Nostr eyJraW5kIjoyNDI0MiwiY3JlYXRlZF9hdCI6MTcyNTkwNDE2M...
```

#### 2. Content-Type
```
Content-Type: video/mp4
```

**Hardcoded**: Yes, always `video/mp4` regardless of actual video format

**Location**: `blossom_upload_service.dart:272`

#### 3. Content-Length
```
Content-Length: <file-size-in-bytes>
```

**Calculated**: From `videoFile.lengthSync()`

**Example**: `Content-Length: 1548762`

---

## Request Body

**Format**: Raw binary bytes (streaming)

**Implementation**:
```dart
data: Stream.fromIterable([fileBytes])
```

**File Reading**:
```dart
final fileBytes = await videoFile.readAsBytes();
```

**No Encoding**: Video file bytes sent as-is, no base64, no JSON wrapping

---

## Authentication Event (Kind 24242)

### Event Structure

```json
{
  "kind": 24242,
  "created_at": <unix-timestamp>,
  "pubkey": "<user-public-key-hex>",
  "tags": [
    ["t", "upload"],
    ["expiration", "<unix-timestamp>"],
    ["x", "<file-sha256-hash>"]
  ],
  "content": "Upload video to Blossom server",
  "id": "<event-id>",
  "sig": "<event-signature>"
}
```

### Tag Breakdown

#### Tag: `t` (type)
```json
["t", "upload"]
```
**Purpose**: Indicates this is an upload authorization request

**Required**: Yes (BUD-01 spec)

#### Tag: `expiration`
```json
["expiration", "1759491465"]
```
**Purpose**: Unix timestamp when authorization expires

**Value**: Current time + 5 minutes

**Calculation**:
```dart
final expiration = now.add(const Duration(minutes: 5));
final expirationTimestamp = expiration.millisecondsSinceEpoch ~/ 1000;
```

**Example**: If now is `1759491165`, expiration is `1759491465`

#### Tag: `x` (hash)
```json
["x", "b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c"]
```
**Purpose**: SHA-256 hash of the file being uploaded

**Calculation**:
```dart
final fileHash = HashUtil.sha256Hash(fileBytes);
```

**Format**: Lowercase hexadecimal string (64 characters)

**Example**: `b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c`

---

## Event Signing Process

**Service**: `AuthService.createAndSignEvent()`

**Steps**:
1. Create event with kind 24242 and tags
2. Calculate event ID (SHA-256 of serialized event)
3. Sign event ID with user's private key (Schnorr signature)
4. Add signature to event

**Key Source**: User's Nostr private key from `AuthService`

**Authentication Check**:
```dart
if (!authService.isAuthenticated) {
  return BlossomUploadResult(
    success: false,
    errorMessage: 'User not authenticated - please sign in to upload',
  );
}
```

---

## Authorization Header Construction

### Step 1: Create Event JSON
```dart
final authEvent = await _createBlossomAuthEvent(
  url: '$serverUrl/upload',
  method: 'PUT',
  fileHash: fileHash,
  fileSize: fileSize,
);
```

### Step 2: Encode Event as JSON
```dart
final authEventJson = jsonEncode(authEvent.toJson());
```

**Example**:
```json
{"kind":24242,"created_at":1759491165,"pubkey":"abc123...","tags":[["t","upload"],["expiration","1759491465"],["x","b19dc4...]],"content":"Upload video to Blossom server","id":"def456...","sig":"789abc..."}
```

### Step 3: Base64 Encode JSON
```dart
final base64Payload = base64.encode(utf8.encode(authEventJson));
```

**Example**:
```
eyJraW5kIjoyNDI0MiwiY3JlYXRlZF9hdCI6MTc1OTQ5MTE2NSwicHVia2V5IjoiYWJjMTIzLi4uIiwidGFncyI6W1sidCIsInVwbG9hZCJdLFsiZXhwaXJhdGlvbiIsIjE3NTk0OTE0NjUiXSxbIngiLCJiMTlkYzQuLi4iXV0sImNvbnRlbnQiOiJVcGxvYWQgdmlkZW8gdG8gQmxvc3NvbSBzZXJ2ZXIiLCJpZCI6ImRlZjQ1Ni4uLiIsInNpZyI6Ijc4OWFiYy4uLiJ9
```

### Step 4: Add "Nostr " Prefix
```dart
final authHeader = 'Nostr ${base64Payload}';
```

**Final Header**:
```
Authorization: Nostr eyJraW5kIjoyNDI0MiwiY3JlYXRlZF9hdCI6MTc1OTQ5MTE2NSwicHVia2V5IjoiYWJjMTIzLi4uIiwidGFncyI6W1sidCIsInVwbG9hZCJdLFsiZXhwaXJhdGlvbiIsIjE3NTk0OTE0NjUiXSxbIngiLCJiMTlkYzQuLi4iXV0sImNvbnRlbnQiOiJVcGxvYWQgdmlkZW8gdG8gQmxvc3NvbSBzZXJ2ZXIiLCJpZCI6ImRlZjQ1Ni4uLiIsInNpZyI6Ijc4OWFiYy4uLiJ9
```

---

## Complete Request Example

### Request
```http
PUT /upload HTTP/1.1
Host: cf-stream-service-prod.protestnet.workers.dev
Authorization: Nostr eyJraW5kIjoyNDI0MiwiY3JlYXRlZF9hdCI6MTc1OTQ5MTE2NSwicHVia2V5IjoiYWJjMTIzLi4uIiwidGFncyI6W1sidCIsInVwbG9hZCJdLFsiZXhwaXJhdGlvbiIsIjE3NTk0OTE0NjUiXSxbIngiLCJiMTlkYzQuLi4iXV0sImNvbnRlbnQiOiJVcGxvYWQgdmlkZW8gdG8gQmxvc3NvbSBzZXJ2ZXIiLCJpZCI6ImRlZjQ1Ni4uLiIsInNpZyI6Ijc4OWFiYy4uLiJ9
Content-Type: video/mp4
Content-Length: 1548762

<binary video data>
```

### Expected Response (Success)
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "sha256": "b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "url": "https://cdn.divine.video/b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "cdn_url": "https://cdn.divine.video/b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c.mp4",
  "size": 1548762,
  "type": "video/mp4",
  "uploaded": "2025-10-04T12:34:56.789Z"
}
```

### Expected Response (File Exists)
```http
HTTP/1.1 409 Conflict
Content-Type: application/json

{
  "message": "File already exists",
  "sha256": "b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "url": "https://cdn.divine.video/b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c"
}
```

### Expected Response (Auth Failed)
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{
  "error": "Invalid signature",
  "message": "Authentication failed"
}
```

### Current Response (Server Error)
```http
HTTP/1.1 502 Bad Gateway
Content-Type: text/plain

Bad Gateway
```

---

## Response Handling

### Success (200/201)
```dart
if (response.statusCode == 200 || response.statusCode == 201) {
  final blobData = response.data;
  final sha256 = blobData['sha256'] as String?;
  final mediaUrl = blobData['url'] as String?;

  return BlossomUploadResult(
    success: true,
    cdnUrl: mediaUrl,
    videoId: sha256 ?? fileHash,
  );
}
```

**Expected Fields**:
- `sha256`: File hash (verification)
- `url`: CDN URL (e.g., `https://cdn.divine.video/<hash>`)
- `size`: File size in bytes
- `type`: MIME type (should be `video/mp4`)
- `uploaded`: Upload timestamp (optional)

### File Exists (409)
```dart
if (response.statusCode == 409) {
  final existingUrl = 'https://cdn.divine.video/$fileHash';
  return BlossomUploadResult(
    success: true,
    videoId: fileHash,
    cdnUrl: existingUrl,
  );
}
```

**Behavior**: Treat as success - file is already on CDN

### Auth Failed (401)
```dart
if (response.statusCode == 401) {
  return BlossomUploadResult(
    success: false,
    errorMessage: 'Authentication failed - check your Nostr keys',
  );
}
```

**Causes**:
- Invalid Nostr signature
- Expired auth event
- Missing/malformed Authorization header
- Unknown public key

### File Too Large (413)
```dart
if (response.statusCode == 413) {
  return BlossomUploadResult(
    success: false,
    errorMessage: 'File too large for this Blossom server',
  );
}
```

### Other Errors
```dart
return BlossomUploadResult(
  success: false,
  errorMessage: 'Upload failed: ${response.statusCode} - ${response.data}',
);
```

---

## Logging Output

When upload is attempted, you'll see these logs:

```
[BlossomUploadService] Uploading to Blossom server: https://cf-stream-service-prod.protestnet.workers.dev
[BlossomUploadService] Checking if user is authenticated...
[BlossomUploadService] ✅ User is authenticated, can create signed events
[BlossomUploadService] Reading file bytes for hash calculation...
[BlossomUploadService] File bytes read: 1548762 bytes
[BlossomUploadService] Calculating SHA-256 hash...
[BlossomUploadService] File hash: b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c, size: 1548762 bytes
[BlossomUploadService] Created Blossom auth event: def456...
[BlossomUploadService] 🔐 Auth event JSON: {"kind":24242,"created_at":...}
[BlossomUploadService] 🔐 Base64 auth payload: eyJraW5kIjoyNDI0MiwiY3JlYXRlZF9h...
[BlossomUploadService] Blossom BUD-01 Upload: Sending raw file bytes with PUT request
[BlossomUploadService] 🔍 Upload request details:
[BlossomUploadService]   📍 URL: https://cf-stream-service-prod.protestnet.workers.dev/upload
[BlossomUploadService]   📝 Method: PUT with raw bytes
[BlossomUploadService]   📊 File size: 1548762 bytes
[BlossomUploadService]   🔐 Auth header length: 523 chars
[BlossomUploadService]   🔐 Auth header preview: Nostr eyJraW5kIjoyNDI0MiwiY3JlYXRlZF9hdCI6MTc1...
[BlossomUploadService] Blossom server response: 502
[BlossomUploadService] Response headers: {content-type: text/plain, ...}
[BlossomUploadService] Response data: Bad Gateway
[BlossomUploadService] ❌ Upload failed: 502 - Bad Gateway
```

---

## Manual Test Script

**File**: `test/manual/test_blossom_upload_live.dart`

**Run**:
```bash
dart run test/manual/test_blossom_upload_live.dart
```

**What It Tests**:
- Creates minimal test video (1016 bytes)
- Calculates SHA-256 hash
- Creates Blossom auth event (with dummy signature)
- Sends PUT request to server
- Parses response
- Verifies CDN URL format
- Verifies SHA-256 match

**Last Successful Run** (from `UPLOAD_FLOW_VERIFIED.md`):
```
✅ Status: 200 OK
✅ Response: {
  "sha256": "b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "url": "https://cdn.divine.video/b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "cdn_url": "https://cdn.divine.video/b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c.mp4",
  "size": 1016,
  "type": "video/mp4"
}
✅ VERIFIED: URL is on cdn.divine.video domain
✅ VERIFIED: SHA256 matches client calculation
```

**Current Status**: Server returns 502 Bad Gateway

---

## Curl Test Command

Test upload with curl:

```bash
# Create test file
echo "test video data" > test.mp4

# Calculate SHA-256
FILE_HASH=$(shasum -a 256 test.mp4 | cut -d' ' -f1)
echo "File hash: $FILE_HASH"

# Create auth event (simplified)
AUTH_EVENT='{"kind":24242,"created_at":'$(date +%s)',"pubkey":"0000000000000000000000000000000000000000000000000000000000000000","tags":[["t","upload"],["expiration","'$(($(date +%s) + 300))'"],["x","'$FILE_HASH'"]],"content":"Test upload","id":"0000000000000000000000000000000000000000000000000000000000000000","sig":"'$(printf '0%.0s' {1..128})'"}'

# Base64 encode
AUTH_B64=$(echo -n "$AUTH_EVENT" | base64)

# Upload
curl -X PUT \
  https://cf-stream-service-prod.protestnet.workers.dev/upload \
  -H "Authorization: Nostr $AUTH_B64" \
  -H "Content-Type: video/mp4" \
  --data-binary @test.mp4 \
  -v
```

**Expected**: 200/201 with JSON response containing `url` field

**Actual**: 502 Bad Gateway

---

## Server-Side Debugging

To debug server issues:

1. **Check Cloudflare Workers Dashboard**
   - Go to Cloudflare dashboard
   - Navigate to Workers & Pages
   - Find `cf-stream-service-prod`
   - Check error logs

2. **Tail Worker Logs**
   ```bash
   wrangler tail cf-stream-service-prod
   ```

3. **Check R2 Binding**
   - Verify `wrangler.toml` has correct R2 bucket binding
   - Check bucket exists and is accessible

4. **Check Stream API**
   - Verify Stream API token is valid
   - Check if Stream API is accessible

5. **Common Issues**:
   - R2 bucket binding misconfigured
   - Stream API token expired
   - Worker throwing unhandled exceptions
   - CORS misconfiguration
   - Missing environment variables

---

## Summary

**What We Send**:
- ✅ PUT request to `/upload` endpoint
- ✅ Blossom BUD-01 compliant authentication (kind 24242 event)
- ✅ Raw video file bytes (not base64, not JSON-wrapped)
- ✅ Correct headers (Authorization, Content-Type, Content-Length)
- ✅ SHA-256 hash in auth event for verification

**What We Expect Back**:
- ✅ 200/201: Success with `{sha256, url, size, type}` JSON
- ✅ 409: File exists (treated as success)
- ⚠️ 401: Auth failed (invalid signature)
- ⚠️ 413: File too large

**What We Actually Get**:
- 🚨 502: Bad Gateway (server-side error)

**Root Cause**: Server cannot process request - likely R2/Stream API backend issue

**Next Step**: Debug server-side configuration and error logs
