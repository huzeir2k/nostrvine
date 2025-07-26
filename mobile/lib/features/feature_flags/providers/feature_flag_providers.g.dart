// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sharedPreferencesHash() => r'c086d2a68e1f0a688c061970ea89a5573fdd2265';

/// SharedPreferences provider for dependency injection
///
/// Copied from [sharedPreferences].
@ProviderFor(sharedPreferences)
final sharedPreferencesProvider =
    AutoDisposeProvider<SharedPreferences>.internal(
  sharedPreferences,
  name: r'sharedPreferencesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sharedPreferencesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SharedPreferencesRef = AutoDisposeProviderRef<SharedPreferences>;
String _$buildConfigurationHash() =>
    r'a62d4699f2242a50e8b591df8d9c62496bbb0123';

/// Build configuration provider
///
/// Copied from [buildConfiguration].
@ProviderFor(buildConfiguration)
final buildConfigurationProvider =
    AutoDisposeProvider<BuildConfiguration>.internal(
  buildConfiguration,
  name: r'buildConfigurationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$buildConfigurationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BuildConfigurationRef = AutoDisposeProviderRef<BuildConfiguration>;
String _$featureFlagServiceHash() =>
    r'f46cff92b5b08bd9517ffa18792018ed99b9350c';

/// Feature flag service provider
///
/// Copied from [featureFlagService].
@ProviderFor(featureFlagService)
final featureFlagServiceProvider =
    AutoDisposeProvider<FeatureFlagService>.internal(
  featureFlagService,
  name: r'featureFlagServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$featureFlagServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeatureFlagServiceRef = AutoDisposeProviderRef<FeatureFlagService>;
String _$featureFlagStateHash() => r'c873eb78ee0fea34033c61f2054af4e367b479a5';

/// Feature flag state provider (reactive to service changes)
///
/// Copied from [featureFlagState].
@ProviderFor(featureFlagState)
final featureFlagStateProvider =
    AutoDisposeProvider<Map<FeatureFlag, bool>>.internal(
  featureFlagState,
  name: r'featureFlagStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$featureFlagStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FeatureFlagStateRef = AutoDisposeProviderRef<Map<FeatureFlag, bool>>;
String _$isFeatureEnabledHash() => r'706cae00a5cf7bf715bcb31deb6840a98727e80e';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Individual feature flag check provider family
///
/// Copied from [isFeatureEnabled].
@ProviderFor(isFeatureEnabled)
const isFeatureEnabledProvider = IsFeatureEnabledFamily();

/// Individual feature flag check provider family
///
/// Copied from [isFeatureEnabled].
class IsFeatureEnabledFamily extends Family<bool> {
  /// Individual feature flag check provider family
  ///
  /// Copied from [isFeatureEnabled].
  const IsFeatureEnabledFamily();

  /// Individual feature flag check provider family
  ///
  /// Copied from [isFeatureEnabled].
  IsFeatureEnabledProvider call(
    FeatureFlag flag,
  ) {
    return IsFeatureEnabledProvider(
      flag,
    );
  }

  @override
  IsFeatureEnabledProvider getProviderOverride(
    covariant IsFeatureEnabledProvider provider,
  ) {
    return call(
      provider.flag,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isFeatureEnabledProvider';
}

/// Individual feature flag check provider family
///
/// Copied from [isFeatureEnabled].
class IsFeatureEnabledProvider extends AutoDisposeProvider<bool> {
  /// Individual feature flag check provider family
  ///
  /// Copied from [isFeatureEnabled].
  IsFeatureEnabledProvider(
    FeatureFlag flag,
  ) : this._internal(
          (ref) => isFeatureEnabled(
            ref as IsFeatureEnabledRef,
            flag,
          ),
          from: isFeatureEnabledProvider,
          name: r'isFeatureEnabledProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isFeatureEnabledHash,
          dependencies: IsFeatureEnabledFamily._dependencies,
          allTransitiveDependencies:
              IsFeatureEnabledFamily._allTransitiveDependencies,
          flag: flag,
        );

  IsFeatureEnabledProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.flag,
  }) : super.internal();

  final FeatureFlag flag;

  @override
  Override overrideWith(
    bool Function(IsFeatureEnabledRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsFeatureEnabledProvider._internal(
        (ref) => create(ref as IsFeatureEnabledRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        flag: flag,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _IsFeatureEnabledProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFeatureEnabledProvider && other.flag == flag;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, flag.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsFeatureEnabledRef on AutoDisposeProviderRef<bool> {
  /// The parameter `flag` of this provider.
  FeatureFlag get flag;
}

class _IsFeatureEnabledProviderElement extends AutoDisposeProviderElement<bool>
    with IsFeatureEnabledRef {
  _IsFeatureEnabledProviderElement(super.provider);

  @override
  FeatureFlag get flag => (origin as IsFeatureEnabledProvider).flag;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
