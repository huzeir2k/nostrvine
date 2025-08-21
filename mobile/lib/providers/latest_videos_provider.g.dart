// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'latest_videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$latestVideosHash() => r'4720f1bfae1af82216203b0e87bbc6a0fd14cd2a';

/// Provider for the latest videos from the network
///
/// Copied from [LatestVideos].
@ProviderFor(LatestVideos)
final latestVideosProvider =
    AutoDisposeAsyncNotifierProvider<LatestVideos, List<VideoEvent>>.internal(
  LatestVideos.new,
  name: r'latestVideosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$latestVideosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LatestVideos = AutoDisposeAsyncNotifier<List<VideoEvent>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
