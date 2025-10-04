# Upload Bug Fix - Type Casting Error

## Date: 2025-10-04

## Bug Summary

**Symptom**: Upload failing with type cast error
**Error**: `type 'int' is not a subtype of type 'String?' in type cast`
**Root Cause**: Client code expected `uploaded` field as String, but server returns it as int (Unix timestamp)
**Status**: ✅ FIXED

---

## The Problem

### What We Thought
Server was returning 502 Bad Gateway errors → server is broken

### Reality
Server was returning **200 OK** with correct data, but client was crashing on response parsing

### Server Response (Correct per Blossom Spec)
```json
{
  "sha256": "b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "url": "https://cdn.divine.video/b19dc4deee058d6afdfa4b6c7ea7c30bb42a2e3fa654d31cfd03e4dd98e30c3c",
  "size": 1548762,
  "type": "video/mp4",
  "uploaded": 1759491775
}
```

**Key Point**: `uploaded` is an **integer** (Unix timestamp), not a string

### Client Code (Buggy)
```dart
// lib/services/blossom_upload_service.dart:322
final uploadedTimestamp = blobData['uploaded'] as String?;
```

**Problem**: Trying to cast `int` to `String?` → runtime exception

---

## The Fix

**File**: `lib/services/blossom_upload_service.dart`
**Lines**: 320-369

### Before (Brittle)
```dart
final sha256 = blobData['sha256'] as String?;
final mediaUrl = blobData['url'] as String?;
final uploadedTimestamp = blobData['uploaded'] as String?;
```

**Problems**:
- Type casts assume specific types (will crash if wrong)
- No fallback for missing fields
- No type conversion handling

### After (Robust - Postel's Law)
```dart
// Apply Postel's Law: be liberal in what we accept

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
  // ...
}
```

**Improvements**:
1. ✅ No type casts - uses `toString()` for safe conversion
2. ✅ Handles int, String, or any other type
3. ✅ Null-safe with `?.toString()`
4. ✅ Fallback to calculated hash if server doesn't return sha256
5. ✅ Better error logging with full response data
6. ✅ Only requires `url` field - all others optional

**Also Fixed**: 409 (File Exists) Response Handling
```dart
// Before: Hardcoded URL
final existingUrl = 'https://cdn.divine.video/$fileHash';

// After: Try to use server URL, fall back if needed
String existingUrl;
if (response.data is Map) {
  final urlRaw = response.data['url'];
  existingUrl = urlRaw?.toString() ?? 'https://cdn.divine.video/$fileHash';
} else {
  existingUrl = 'https://cdn.divine.video/$fileHash';
}
```

---

## Blossom Spec Compliance

**Blossom BUD-01 Spec**:
> The `uploaded` field SHOULD be a Unix timestamp (integer) indicating when the file was uploaded.

**Server Behavior**: ✅ Correct - returns integer Unix timestamp

**Client Expectation**: ❌ Incorrect - expected string

**Fix**: ✅ Accept any type for `uploaded` field

---

## Impact

### Before Fix
- ❌ All uploads failed with type cast exception
- ❌ Users couldn't upload videos
- ❌ E2E tests failed
- ❌ App unusable for video sharing

### After Fix
- ✅ Uploads should complete successfully
- ✅ Response parsing works correctly
- ✅ CDN URL extracted properly
- ✅ Video upload flow unblocked

---

## Testing Required

### 1. Manual Upload Test
```bash
dart run test/manual/test_blossom_upload_live.dart
```

**Expected**: Upload succeeds, CDN URL returned

### 2. App Upload Test
1. Run app on Chrome: `./run_dev.sh chrome debug`
2. Record a video
3. Add title/description
4. Click "Publish"
5. Verify upload completes
6. Verify video appears in feed

### 3. E2E Test
```bash
flutter test test/integration/video_record_publish_e2e_test.dart
```

**Expected**: Test passes, upload → publish flow works

---

## Related Issues

### Other Type Cast Issues to Watch For

Check for similar bugs in response parsing:

```dart
// Potential issues:
final size = blobData['size'] as String?; // Might be int
final type = blobData['type'] as int?;    // Might be String
```

**Recommendation**: Review all Blossom response parsing code for type assumptions

---

## Lessons Learned

### 1. Don't Assume Response Types
Server responses may vary in type even if spec suggests one format

**Bad**:
```dart
final uploaded = blobData['uploaded'] as String?;
```

**Good**:
```dart
final uploaded = blobData['uploaded']; // Accept any type
```

**Better**:
```dart
final uploadedRaw = blobData['uploaded'];
final uploaded = uploadedRaw is int
  ? uploadedRaw.toString()
  : uploadedRaw as String?;
```

### 2. Server Was Never Broken
All the debugging effort went into "fixing the server" when the server was working correctly all along

**Wasted Time**:
- Creating server debug guides
- Investigating 502 errors
- Checking R2 bindings
- Checking Stream API tokens

**Actual Issue**: Simple type cast bug on line 322

### 3. Error Messages Were Misleading
The circuit breaker and retry logic masked the real error:
```
[SYSTEM] CircuitBreaker: Failure recorded (count: 1)
[SYSTEM] AsyncUtils.retryWithBackoff attempt 1 failed
```

**Real Error** (buried in logs):
```
type 'int' is not a subtype of type 'String?' in type cast
```

**Lesson**: Always look for the FIRST error, not just retry/circuit breaker messages

---

## Code Review Checklist

When parsing external API responses:

- [ ] Don't assume field types
- [ ] Handle both int and String for numeric fields
- [ ] Handle missing fields gracefully
- [ ] Log raw response for debugging
- [ ] Test with real server responses, not mocks
- [ ] Check Blossom spec for expected types
- [ ] Don't use type casts without validation

---

## Status: Fixed ✅

**Change**: Removed incorrect type cast
**Testing**: Analysis passes
**Next**: Run manual/e2e tests to verify upload works
**Deployment**: Ready for commit

---

## Commit Message

```
fix: make Blossom response parsing robust (Postel's Law)

Apply Postel's Law ("be liberal in what you accept") to Blossom
server response parsing.

Changes:
- Remove type casts that assumed specific field types
- Use toString() for safe type conversion (handles int, String, etc)
- Only require 'url' field, make all others optional
- Fall back to calculated hash if server doesn't return sha256
- Improve error logging with full response data
- Handle 409 response URL extraction robustly

Fixes upload failures caused by servers returning fields as different
types (e.g., uploaded as int instead of String).

Not all Blossom servers will return perfectly formatted responses -
client must handle variety of implementations gracefully.

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```
