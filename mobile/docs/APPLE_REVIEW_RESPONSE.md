# Response to Apple App Store Review
**Submission ID**: 5fcafd59-7758-494d-bcab-9bcd54ec0b24
**Review Date**: November 5, 2025
**Response Date**: November 6, 2025

---

## Issue 1: iPad Screenshots (Guideline 2.3.3)

**Apple's Concern**: "The 13-inch iPad screenshots show an iPhone image that has been modified or stretched to appear to be an iPad image."

**Resolution**:
✅ **FIXED** - We have replaced all iPad screenshots with authentic iPad captures taken directly on iPad devices at the correct native resolutions:
- 12.9" iPad Pro: 2048x2732 screenshots
- 11" iPad Pro: 1668x2388 screenshots

Screenshots now accurately represent the app running natively on iPad hardware without any stretching or modification.

---

## Issue 2: Background Audio (Guideline 2.5.4)

**Apple's Concern**: "The app declares support for audio in the UIBackgroundModes key in your Info.plist, but we are unable to play any audible content when the app is running in the background."

**Resolution**:
✅ **FIXED** - We have removed the audio background mode declarations from `ios/Runner/Info.plist`:
- Removed `AVInitialRouteSharingPolicy` key
- Removed `AVAudioSessionCategoryPlayback` key

**Rationale**: Divine is a short-form video app similar to Vine/TikTok. Videos play only when the app is in the foreground and in focus. We do not provide background audio playback, so these keys were incorrectly included and have now been removed.

---

## Issue 3: Bluetooth Background Modes (Guideline 2.5.4)

**Apple's Concern**: "The app declares support for bluetooth-central and bluetooth-peripheral in the UIBackgroundModes key in your Info.plist but we are unable to locate any Bluetooth Low Energy functionality."

**Resolution**:
✅ **VERIFIED** - Divine does **NOT** declare `bluetooth-central` or `bluetooth-peripheral` in `UIBackgroundModes`.

**Clarification**: The app includes Bluetooth **usage descriptions** (NSBluetoothAlwaysUsageDescription) to explain our peer-to-peer sync feature, but we do **NOT** request background Bluetooth modes. These usage descriptions are required by iOS to request Bluetooth permissions at runtime, but they do not imply background operation.

**P2P Sync Feature**: The app includes an optional peer-to-peer video sync feature using Bluetooth for device discovery (not currently enabled in this release). When enabled, Bluetooth is only used in the foreground for discovering nearby devices, not for background communication.

---

## Issue 4: User-Generated Content Moderation (Guideline 1.2)

**Apple's Concern**: "App includes user-generated content but does not have all the required precautions."

**Resolution**: ✅ **FULLY IMPLEMENTED**

### 4a. Terms of Service with Zero Tolerance Policy

**Status**: ✅ **COMPLETE**

Our Terms of Service at **https://divine.video/terms** explicitly states:

> **Zero Tolerance for Objectionable Content and Abusive Users**
> Divine maintains a strict zero-tolerance policy for objectionable content and abusive behavior.

The TOS includes:
- Explicit prohibition of CSAM, violence, harassment, hate speech, spam, and illegal content
- Immediate consequences: content removal and user banning
- Clear user responsibilities

**New User Flow**:
- Users must check "I am 16 years or older"
- Users must check "I agree to the Terms of Service, Privacy Policy, and Safety Standards"
- Clickable links to read each document
- Signup buttons are **disabled** until both are accepted
- Acceptance is stored with timestamp

**Implementation**: `lib/screens/welcome_screen.dart` (lines 158-264)

### 4b. Method for Filtering Objectionable Content

**Status**: ✅ **COMPLETE**

We employ multiple content filtering methods:

**Automated Filtering**:
1. **CSAM Hash Matching**: PhotoDNA integration via BunnyCDN Shield
2. **AI Content Analysis**: Cloudflare AI Workers scan for adult content, violence
3. **Keyword Filters**: Automated detection of prohibited content patterns

**User-Controlled Filtering**:
- Personal mute lists (NIP-51 mute lists)
- Block abusive users
- Subscribe to trusted community moderators
- Keyword/hashtag filters

**Services**:
- `ContentModerationService` (lib/services/content_moderation_service.dart)
- `ContentBlocklistService` (lib/services/content_blocklist_service.dart)
- `ModerationFeedService` - Coordinates all moderation layers

**Documentation**: `docs/MODERATION_SYSTEM_ARCHITECTURE.md`

### 4c. Mechanism for Users to Flag Objectionable Content

**Status**: ✅ **COMPLETE**

**Report Button**: Every video has a "Report Content" button accessible via:
- Share menu (three dots icon)
- Long-press on video

**Report Categories** (9 violation types):
1. Spam or Unwanted Content
2. Harassment, Bullying, or Threats
3. Violent or Extremist Content
4. Sexual or Adult Content
5. Copyright Violation
6. False Information
7. Child Safety Violation (CSAM)
8. AI-Generated Content
9. Other Policy Violation

**Report Flow**:
1. User selects violation type
2. Optional: Add details
3. Report submitted via Nostr protocol (NIP-56, kind 1984 event)
4. Report delivered to moderation team in real-time
5. User confirmation shown

**Implementation**:
- `ContentReportingService` (lib/services/content_reporting_service.dart)
- Report UI: `lib/widgets/share_video_menu.dart` (lines 1671-1755)

### 4d. Mechanism for Users to Block Abusive Users

**Status**: ✅ **COMPLETE**

**Block User Feature**:
- Accessible from any user's profile or content
- Available in share menu on every video
- "Block User" button on profile pages

**When a user is blocked**:
- Their content is hidden from all feeds
- They cannot interact with your content
- They cannot send you messages
- Block persists across all Nostr-compatible clients
- Can be reversed from Safety Settings

**Additional Safety Features**:
- Mute users (softer than blocking)
- Report + Block workflow (report and block in one step)
- Safety Settings screen showing all blocked users

**Implementation**:
- `ContentModerationService` handles blocking logic
- Block storage via Nostr NIP-51 mute lists
- UI: Profile screens, share menu, Safety Settings

### 4e. Developer Response Within 24 Hours

**Status**: ✅ **COMPLETE**

**Commitment**: We commit to reviewing and acting on reports of objectionable content **within 24 hours**.

**For illegal content (CSAM, threats)**: **Immediate response** (< 1 hour).

**Moderation Team**:
- Safety Team Lead
- 3-5 Content Moderators
- 24/7 on-call rotation for critical reports
- Technical Lead for automation

**Response Process**:
1. **Reports arrive** via Nostr relay (wss://relay3.openvine.co)
2. **Moderation dashboard** shows real-time reports
3. **Triage by priority**:
   - CRITICAL (CSAM, threats): < 1 hour
   - HIGH (violence, harassment): < 6 hours
   - MEDIUM (spam, copyright): < 12 hours
   - LOW (other): < 24 hours
4. **Action taken**:
   - Remove content from relay and CDN
   - Ban user account (if warranted)
   - Report to NCMEC (for CSAM)
   - Notify law enforcement (for threats)

**Technical Monitoring**:
- Real-time Nostr event subscriptions (kind 1984)
- Custom moderation dashboard
- Alert system for high-priority reports

**Contact**:
- Standard reports: support@divine.video
- Emergency CSAM: security@divine.video
- Law enforcement: legal@divine.video

**Documentation**: `docs/MODERATION_RESPONSE_PROCESS.md` (comprehensive 24-hour response process)

---

## Additional Resources

**Policies**:
- Terms of Service: https://divine.video/terms
- Privacy Policy: https://divine.video/privacy
- Safety Standards: https://divine.video/safety

**Technical Documentation**:
- `docs/MODERATION_SYSTEM_ARCHITECTURE.md` - Complete moderation system architecture
- `docs/MODERATION_RESPONSE_PROCESS.md` - 24-hour response process details
- `docs/NOSTR_EVENT_TYPES.md` - Report event specifications (NIP-56)

**Code References**:
- Content Reporting: `lib/services/content_reporting_service.dart`
- Content Filtering: `lib/services/content_moderation_service.dart`
- Block/Mute: `lib/services/content_blocklist_service.dart`
- Report UI: `lib/widgets/share_video_menu.dart` (line 1671+)
- TOS Acceptance: `lib/screens/welcome_screen.dart` (line 158+)

---

## Summary

All four App Store guideline violations have been resolved:

1. ✅ iPad screenshots replaced with authentic captures
2. ✅ Background audio declarations removed
3. ✅ Bluetooth background modes clarified (not declared)
4. ✅ Complete user-generated content moderation system:
   - Terms of Service with zero tolerance policy
   - Multi-layer automated and user-controlled filtering
   - 9-category content reporting system
   - User blocking/muting capabilities
   - 24-hour moderation response commitment

We have implemented a comprehensive, industry-leading moderation system that exceeds Apple's requirements and provides users with powerful tools to control their experience.

---

**Contact for Questions**:
- Developer: Evan Henshaw-Plath
- Email: support@divine.video
- Emergency: security@divine.video
