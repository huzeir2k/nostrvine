// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$videoFeedLoadingHash() => r'd202ed92cf906a603f676488ea4115de75d6242a';

/// Provider to check if video feed is loading
///
/// Copied from [videoFeedLoading].
@ProviderFor(videoFeedLoading)
final videoFeedLoadingProvider = AutoDisposeProvider<bool>.internal(
  videoFeedLoading,
  name: r'videoFeedLoadingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoFeedLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoFeedLoadingRef = AutoDisposeProviderRef<bool>;
String _$videoFeedCountHash() => r'c9fc7b68a402d8e63cff499a4a44842466718db8';

/// Provider to get current video count
///
/// Copied from [videoFeedCount].
@ProviderFor(videoFeedCount)
final videoFeedCountProvider = AutoDisposeProvider<int>.internal(
  videoFeedCount,
  name: r'videoFeedCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoFeedCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoFeedCountRef = AutoDisposeProviderRef<int>;
String _$hasVideosHash() => r'2780fade78b3238a1979632f42151a3400b482b7';

/// Provider to check if we have videos
///
/// Copied from [hasVideos].
@ProviderFor(hasVideos)
final hasVideosProvider = AutoDisposeProvider<bool>.internal(
  hasVideos,
  name: r'hasVideosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$hasVideosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasVideosRef = AutoDisposeProviderRef<bool>;
String _$videoFeedHash() => r'6f558a2dbaa3ccd4a70ade2c689b05a3cd47792b';

/// Simple discovery video feed provider
///
/// Copied from [VideoFeed].
@ProviderFor(VideoFeed)
final videoFeedProvider =
    AutoDisposeAsyncNotifierProvider<VideoFeed, VideoFeedState>.internal(
  VideoFeed.new,
  name: r'videoFeedProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$videoFeedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VideoFeed = AutoDisposeAsyncNotifier<VideoFeedState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
