# Profile Update Bug: Analysis & Solution

## Problem Statement

When a user updates their profile and publishes to Nostr, the ProfileScreen does not display the updated data immediately after navigating back. The data IS cached locally, but the UI doesn't rebuild to show it.

## Root Cause Analysis

### Current Architecture

```
ProfileSetupScreen (edit profile)
    ↓
1. User edits name, picture, bio
    ↓
2. NostrService.broadcastEvent(kind 0 event)
    ↓
3. UserProfileService.updateCachedProfile(newProfile) [✅ Data IS cached]
    ↓
4. AuthService.refreshCurrentProfile(userProfileService) [✅ AuthService.currentProfile IS updated]
    ↓
5. Navigator.pop() back to ProfileScreen
    ↓
6. ❌ ProfileScreen does NOT rebuild - shows old data
```

### Why ProfileScreen Doesn't Rebuild

**ProfileScreen reads profile data:**
```dart
final authService = ref.watch(authServiceProvider);  // Line 352
final authProfile = _isOwnProfile ? authService.currentProfile : null;  // Line 367
```

**The Issue:**
1. `authServiceProvider` is a `@Riverpod(keepAlive: true)` provider
2. It returns a static `AuthService` instance
3. When `AuthService._currentProfile` changes internally, the provider instance doesn't change
4. **Riverpod doesn't know the internal state changed**
5. Widgets watching `authServiceProvider` don't rebuild

### Evidence from Logs

```
[01:03:51.464] 📨 Received profile event for 78a5c21b...
[01:03:51.465] ✅ Cached profile for 78a5c21b: rabble dev machine  ← Profile IS cached!
[01:04:02.482] 📱 Navigation didPop to route: unnamed              ← Navigated back
                                                                    ← But UI shows old data
```

## Current Profile Screen Implementation

**Two profile sources:**
- `authService.currentProfile` - For own profile (AuthService.UserProfile type)
- `userProfileService.getCachedProfile()` - For other profiles (model.UserProfile type)

**Split caching leads to sync issues:**
- AuthService has its own UserProfile class (different from model)
- ProfileSetupScreen calls `refreshCurrentProfile()` to sync them
- But Riverpod doesn't detect the AuthService internal state change

## Proposed Solutions

### Solution 1: Unified Cache (Recommended)

**Eliminate the dual-cache problem entirely:**

```dart
// ProfileScreen reads ONLY from UserProfileService for everyone
final profile = userProfileService.getCachedProfile(targetPubkey);
final displayName = profile?.displayName ?? 'Loading...';
```

**Benefits:**
- Single source of truth
- UserProfileService already notifies changes properly
- Simpler architecture
- No sync issues

**Implementation:**
1. Make ProfileScreen read from UserProfileService for own profile too
2. Keep AuthService.currentProfile for internal use (signing, etc.)
3. Remove the profile sync complexity

### Solution 2: Reactive Auth Profile Provider

**Create a Stream-based provider that rebuilds when profile changes:**

```dart
@riverpod
Stream<AuthUserProfile?> authProfileStream(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.profileStream;  // AuthService already has this!
}

// In ProfileScreen:
final authProfileAsync = ref.watch(authProfileStreamProvider);
final authProfile = authProfileAsync.value;
```

**Benefits:**
- Proper reactive updates
- Leverages existing profileStream
- Minimal code changes

**Drawbacks:**
- Still maintaining two profile types
- Adds complexity with AsyncValue handling

### Solution 3: Make AuthService ChangeNotifier

**Convert AuthService to extend ChangeNotifier:**

```dart
class AuthService extends ChangeNotifier {
  UserProfile? _currentProfile;

  Future<void> refreshCurrentProfile(...) async {
    _currentProfile = updatedProfile;
    notifyListeners();  // ← Triggers rebuild
  }
}
```

**Drawbacks:**
- Large refactoring required
- AuthService wasn't designed as ChangeNotifier
- May conflict with existing Stream-based architecture

## Recommended Implementation: Solution 1 (Unified Cache)

### Step 1: Update ProfileScreen to use unified cache

```dart
// Replace split logic:
final authProfile = _isOwnProfile ? authService.currentProfile : null;
final cachedProfile = !_isOwnProfile ? userProfileService.getCachedProfile(_targetPubkey!) : null;

// With unified:
final profile = userProfileService.getCachedProfile(targetPubkey);
```

### Step 2: Ensure UserProfileService caches own profile

```dart
// In ProfileSetupScreen after publishing:
await userProfileService.updateCachedProfile(newProfile);
// No need to call authService.refreshCurrentProfile anymore
```

### Step 3: Keep AuthService.currentProfile for internal use

AuthService.currentProfile still needed for:
- Event signing (needs access to npub, etc.)
- Internal auth state
- Not for UI display

### Step 4: Test

Run `test/integration/profile_cache_sync_test.dart` to verify cache works correctly.

## Testing Strategy

**Integration tests verify:**
1. UserProfileService cache stores/retrieves profiles
2. Cache updates work correctly
3. Profile flow documents expected behavior

**See:** `test/integration/profile_cache_sync_test.dart`

## Files to Modify

1. `lib/screens/profile_screen_scrollable.dart` - Use unified cache
2. `lib/screens/profile_setup_screen.dart` - Remove redundant refresh call
3. `lib/services/auth_service.dart` - Document that currentProfile is internal-only

## Migration Notes

**Breaking Changes:** None - this is an internal refactoring

**Backward Compatibility:** Maintained - UserProfileService already exists

**Performance Impact:** Positive - eliminates duplicate caching and sync overhead
