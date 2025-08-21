// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeFeedLoadingHash() => r'81bbd67b4dd84f30061d4e63cb7e502c6370bb94';

/// Provider to check if home feed is loading
///
/// Copied from [homeFeedLoading].
@ProviderFor(homeFeedLoading)
final homeFeedLoadingProvider = AutoDisposeProvider<bool>.internal(
  homeFeedLoading,
  name: r'homeFeedLoadingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeFeedLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeFeedLoadingRef = AutoDisposeProviderRef<bool>;
String _$homeFeedCountHash() => r'b739e0a32bf057f20ec30d7ab945528757f833e9';

/// Provider to get current home feed video count
///
/// Copied from [homeFeedCount].
@ProviderFor(homeFeedCount)
final homeFeedCountProvider = AutoDisposeProvider<int>.internal(
  homeFeedCount,
  name: r'homeFeedCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeFeedCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeFeedCountRef = AutoDisposeProviderRef<int>;
String _$hasHomeFeedVideosHash() => r'7785c6a7ebf4bc3bcd84129c6b1fda16e7f72edf';

/// Provider to check if we have home feed videos
///
/// Copied from [hasHomeFeedVideos].
@ProviderFor(hasHomeFeedVideos)
final hasHomeFeedVideosProvider = AutoDisposeProvider<bool>.internal(
  hasHomeFeedVideos,
  name: r'hasHomeFeedVideosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasHomeFeedVideosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasHomeFeedVideosRef = AutoDisposeProviderRef<bool>;
String _$homeFeedHash() => r'c49d074c64a4a09ffa922bc7eb73a3b8c79b330e';

/// Home feed provider - shows videos only from people you follow
///
/// Copied from [HomeFeed].
@ProviderFor(HomeFeed)
final homeFeedProvider =
    AutoDisposeAsyncNotifierProvider<HomeFeed, VideoFeedState>.internal(
  HomeFeed.new,
  name: r'homeFeedProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$homeFeedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$HomeFeed = AutoDisposeAsyncNotifier<VideoFeedState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
