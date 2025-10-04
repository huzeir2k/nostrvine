// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Async provider for loading profile statistics

@ProviderFor(fetchProfileStats)
const fetchProfileStatsProvider = FetchProfileStatsFamily._();

/// Async provider for loading profile statistics

final class FetchProfileStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileStats>,
          ProfileStats,
          FutureOr<ProfileStats>
        >
    with $FutureModifier<ProfileStats>, $FutureProvider<ProfileStats> {
  /// Async provider for loading profile statistics
  const FetchProfileStatsProvider._({
    required FetchProfileStatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fetchProfileStatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fetchProfileStatsHash();

  @override
  String toString() {
    return r'fetchProfileStatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ProfileStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileStats> create(Ref ref) {
    final argument = this.argument as String;
    return fetchProfileStats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FetchProfileStatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fetchProfileStatsHash() => r'16acf0baae8388bd0c9fdd3745666089f679687f';

/// Async provider for loading profile statistics

final class FetchProfileStatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ProfileStats>, String> {
  const FetchProfileStatsFamily._()
    : super(
        retry: null,
        name: r'fetchProfileStatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Async provider for loading profile statistics

  FetchProfileStatsProvider call(String pubkey) =>
      FetchProfileStatsProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'fetchProfileStatsProvider';
}

/// Notifier for managing profile stats state

@ProviderFor(ProfileStatsNotifier)
const profileStatsProvider = ProfileStatsNotifierProvider._();

/// Notifier for managing profile stats state
final class ProfileStatsNotifierProvider
    extends $NotifierProvider<ProfileStatsNotifier, ProfileStatsState> {
  /// Notifier for managing profile stats state
  const ProfileStatsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileStatsNotifierHash();

  @$internal
  @override
  ProfileStatsNotifier create() => ProfileStatsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileStatsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileStatsState>(value),
    );
  }
}

String _$profileStatsNotifierHash() =>
    r'772f1581765afd42d2c258f827130f761a580ac0';

/// Notifier for managing profile stats state

abstract class _$ProfileStatsNotifier extends $Notifier<ProfileStatsState> {
  ProfileStatsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ProfileStatsState, ProfileStatsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProfileStatsState, ProfileStatsState>,
              ProfileStatsState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
