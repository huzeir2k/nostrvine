// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for analytics API service

@ProviderFor(analyticsApiService)
const analyticsApiServiceProvider = AnalyticsApiServiceProvider._();

/// Provider for analytics API service

final class AnalyticsApiServiceProvider
    extends
        $FunctionalProvider<
          AnalyticsApiService,
          AnalyticsApiService,
          AnalyticsApiService
        >
    with $Provider<AnalyticsApiService> {
  /// Provider for analytics API service
  const AnalyticsApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsApiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsApiServiceHash();

  @$internal
  @override
  $ProviderElement<AnalyticsApiService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AnalyticsApiService create(Ref ref) {
    return analyticsApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsApiService>(value),
    );
  }
}

String _$analyticsApiServiceHash() =>
    r'bffbe1efb4b6d2a6172d4397e70d82b0312410e7';

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation

@ProviderFor(Curation)
const curationProvider = CurationProvider._();

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation
final class CurationProvider
    extends $NotifierProvider<Curation, CurationState> {
  /// Main curation provider that manages curated content sets
  /// keepAlive ensures provider persists across tab navigation
  const CurationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationHash();

  @$internal
  @override
  Curation create() => Curation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurationState>(value),
    );
  }
}

String _$curationHash() => r'ac57ca4fa72232ccf104c8b4739ec94c91aaa3d8';

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation

abstract class _$Curation extends $Notifier<CurationState> {
  CurationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CurationState, CurationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurationState, CurationState>,
              CurationState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider to check if curation is loading

@ProviderFor(curationLoading)
const curationLoadingProvider = CurationLoadingProvider._();

/// Provider to check if curation is loading

final class CurationLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if curation is loading
  const CurationLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return curationLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$curationLoadingHash() => r'e1a04d9f8d90870d340665613c0938b356085039';

/// Provider to get editor's picks

@ProviderFor(editorsPicks)
const editorsPicksProvider = EditorsPicksProvider._();

/// Provider to get editor's picks

final class EditorsPicksProvider
    extends
        $FunctionalProvider<
          List<VideoEvent>,
          List<VideoEvent>,
          List<VideoEvent>
        >
    with $Provider<List<VideoEvent>> {
  /// Provider to get editor's picks
  const EditorsPicksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorsPicksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorsPicksHash();

  @$internal
  @override
  $ProviderElement<List<VideoEvent>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<VideoEvent> create(Ref ref) {
    return editorsPicks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$editorsPicksHash() => r'47f6f4c73a8e2f6f8aafa718986c063feb530d08';

/// Provider for analytics-based trending videos

@ProviderFor(AnalyticsTrending)
const analyticsTrendingProvider = AnalyticsTrendingProvider._();

/// Provider for analytics-based trending videos
final class AnalyticsTrendingProvider
    extends $NotifierProvider<AnalyticsTrending, List<VideoEvent>> {
  /// Provider for analytics-based trending videos
  const AnalyticsTrendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsTrendingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsTrendingHash();

  @$internal
  @override
  AnalyticsTrending create() => AnalyticsTrending();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$analyticsTrendingHash() => r'ed584f47ce26a44ff368d0f7d32e27faa80697a7';

/// Provider for analytics-based trending videos

abstract class _$AnalyticsTrending extends $Notifier<List<VideoEvent>> {
  List<VideoEvent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<VideoEvent>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<VideoEvent>, List<VideoEvent>>,
              List<VideoEvent>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for analytics-based popular videos

@ProviderFor(AnalyticsPopular)
const analyticsPopularProvider = AnalyticsPopularProvider._();

/// Provider for analytics-based popular videos
final class AnalyticsPopularProvider
    extends $NotifierProvider<AnalyticsPopular, List<VideoEvent>> {
  /// Provider for analytics-based popular videos
  const AnalyticsPopularProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsPopularProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsPopularHash();

  @$internal
  @override
  AnalyticsPopular create() => AnalyticsPopular();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$analyticsPopularHash() => r'fe3a80d2e416f3d7b0bf7be35d30cbcfe5512543';

/// Provider for analytics-based popular videos

abstract class _$AnalyticsPopular extends $Notifier<List<VideoEvent>> {
  List<VideoEvent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<VideoEvent>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<VideoEvent>, List<VideoEvent>>,
              List<VideoEvent>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for trending hashtags

@ProviderFor(TrendingHashtags)
const trendingHashtagsProvider = TrendingHashtagsProvider._();

/// Provider for trending hashtags
final class TrendingHashtagsProvider
    extends $AsyncNotifierProvider<TrendingHashtags, List<TrendingHashtag>> {
  /// Provider for trending hashtags
  const TrendingHashtagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingHashtagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingHashtagsHash();

  @$internal
  @override
  TrendingHashtags create() => TrendingHashtags();
}

String _$trendingHashtagsHash() => r'6798c272e87bb8733a4f1729132ba7e5a54c656a';

/// Provider for trending hashtags

abstract class _$TrendingHashtags
    extends $AsyncNotifier<List<TrendingHashtag>> {
  FutureOr<List<TrendingHashtag>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<TrendingHashtag>>, List<TrendingHashtag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<TrendingHashtag>>,
                List<TrendingHashtag>
              >,
              AsyncValue<List<TrendingHashtag>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for top creators

@ProviderFor(TopCreators)
const topCreatorsProvider = TopCreatorsProvider._();

/// Provider for top creators
final class TopCreatorsProvider
    extends $AsyncNotifierProvider<TopCreators, List<TopCreator>> {
  /// Provider for top creators
  const TopCreatorsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topCreatorsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topCreatorsHash();

  @$internal
  @override
  TopCreators create() => TopCreators();
}

String _$topCreatorsHash() => r'5e191a9d9edb8c77a2c36ccc5046e801c64e56e8';

/// Provider for top creators

abstract class _$TopCreators extends $AsyncNotifier<List<TopCreator>> {
  FutureOr<List<TopCreator>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<TopCreator>>, List<TopCreator>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TopCreator>>, List<TopCreator>>,
              AsyncValue<List<TopCreator>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
