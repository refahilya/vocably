// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_worker_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shared access point for the Cloudflare Worker AI proxy client — used
/// by both guru's Tambah Kosakata (`vocab_management_providers.dart`)
/// and siswa's lazy Word Detail translation display
/// (`lazy_translation_providers.dart`). Kept in its own file since it
/// isn't specific to either flow (`DATA_MODEL.md` §2 point 4: `/translate`
/// is called from both places, and the Worker itself doesn't
/// distinguish the caller's role — see `AiWorkerService`'s doc comment).

@ProviderFor(aiWorkerService)
final aiWorkerServiceProvider = AiWorkerServiceProvider._();

/// Shared access point for the Cloudflare Worker AI proxy client — used
/// by both guru's Tambah Kosakata (`vocab_management_providers.dart`)
/// and siswa's lazy Word Detail translation display
/// (`lazy_translation_providers.dart`). Kept in its own file since it
/// isn't specific to either flow (`DATA_MODEL.md` §2 point 4: `/translate`
/// is called from both places, and the Worker itself doesn't
/// distinguish the caller's role — see `AiWorkerService`'s doc comment).

final class AiWorkerServiceProvider
    extends
        $FunctionalProvider<AiWorkerService, AiWorkerService, AiWorkerService>
    with $Provider<AiWorkerService> {
  /// Shared access point for the Cloudflare Worker AI proxy client — used
  /// by both guru's Tambah Kosakata (`vocab_management_providers.dart`)
  /// and siswa's lazy Word Detail translation display
  /// (`lazy_translation_providers.dart`). Kept in its own file since it
  /// isn't specific to either flow (`DATA_MODEL.md` §2 point 4: `/translate`
  /// is called from both places, and the Worker itself doesn't
  /// distinguish the caller's role — see `AiWorkerService`'s doc comment).
  AiWorkerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiWorkerServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiWorkerServiceHash();

  @$internal
  @override
  $ProviderElement<AiWorkerService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiWorkerService create(Ref ref) {
    return aiWorkerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiWorkerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiWorkerService>(value),
    );
  }
}

String _$aiWorkerServiceHash() => r'fa8f2e9f6864bc0c261c30ed87223e47cbd1941c';
