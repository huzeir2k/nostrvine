// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileVideosHash() => r'a782bbe009434dcd9c5f9684fe168c38816c9fe3';

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

/// Async provider for loading profile videos
///
/// Copied from [profileVideos].
@ProviderFor(profileVideos)
const profileVideosProvider = ProfileVideosFamily();

/// Async provider for loading profile videos
///
/// Copied from [profileVideos].
class ProfileVideosFamily extends Family<AsyncValue<List<VideoEvent>>> {
  /// Async provider for loading profile videos
  ///
  /// Copied from [profileVideos].
  const ProfileVideosFamily();

  /// Async provider for loading profile videos
  ///
  /// Copied from [profileVideos].
  ProfileVideosProvider call(
    String pubkey,
  ) {
    return ProfileVideosProvider(
      pubkey,
    );
  }

  @override
  ProfileVideosProvider getProviderOverride(
    covariant ProfileVideosProvider provider,
  ) {
    return call(
      provider.pubkey,
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
  String? get name => r'profileVideosProvider';
}

/// Async provider for loading profile videos
///
/// Copied from [profileVideos].
class ProfileVideosProvider
    extends AutoDisposeFutureProvider<List<VideoEvent>> {
  /// Async provider for loading profile videos
  ///
  /// Copied from [profileVideos].
  ProfileVideosProvider(
    String pubkey,
  ) : this._internal(
          (ref) => profileVideos(
            ref as ProfileVideosRef,
            pubkey,
          ),
          from: profileVideosProvider,
          name: r'profileVideosProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$profileVideosHash,
          dependencies: ProfileVideosFamily._dependencies,
          allTransitiveDependencies:
              ProfileVideosFamily._allTransitiveDependencies,
          pubkey: pubkey,
        );

  ProfileVideosProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.pubkey,
  }) : super.internal();

  final String pubkey;

  @override
  Override overrideWith(
    FutureOr<List<VideoEvent>> Function(ProfileVideosRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProfileVideosProvider._internal(
        (ref) => create(ref as ProfileVideosRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        pubkey: pubkey,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<VideoEvent>> createElement() {
    return _ProfileVideosProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileVideosProvider && other.pubkey == pubkey;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, pubkey.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProfileVideosRef on AutoDisposeFutureProviderRef<List<VideoEvent>> {
  /// The parameter `pubkey` of this provider.
  String get pubkey;
}

class _ProfileVideosProviderElement
    extends AutoDisposeFutureProviderElement<List<VideoEvent>>
    with ProfileVideosRef {
  _ProfileVideosProviderElement(super.provider);

  @override
  String get pubkey => (origin as ProfileVideosProvider).pubkey;
}

String _$profileVideosNotifierHash() =>
    r'00f2c2333faa5c73a3517636643ffcfae328632c';

/// Notifier for managing profile videos state
///
/// Copied from [ProfileVideosNotifier].
@ProviderFor(ProfileVideosNotifier)
final profileVideosNotifierProvider = AutoDisposeNotifierProvider<
    ProfileVideosNotifier, ProfileVideosState>.internal(
  ProfileVideosNotifier.new,
  name: r'profileVideosNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$profileVideosNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProfileVideosNotifier = AutoDisposeNotifier<ProfileVideosState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
