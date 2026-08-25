// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_cart_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// "Keranjang Pelajari" (`SPEC.md` §3.4) — the student's in-progress
/// selection of words to learn next.
///
/// **Session-local, in-memory only — deliberately not persisted.**
/// `DATA_MODEL.md` has no Firestore collection for a cart at all; the
/// only documented destination for its contents is becoming a *new*
/// `learningSessions` document's `wordIds`
/// (`sourceType: "keranjangPelajari"`, §4) once the student presses the
/// CTA to start the 3-phase flow — Milestone 7 (Storyfier core),
/// explicitly out of scope for this stage. Inventing Firestore/local-
/// storage schema for a pre-session selection the docs don't describe
/// would be exactly the kind of unrequested architecture this stage was
/// told to avoid, so this stays plain Riverpod state.
///
/// Keyed by `normalizeWord(word)` (Stage 1's function) rather than the
/// raw word string, so duplicate prevention is normalization-sensitive
/// per this stage's instructions.
///
/// `keepAlive: true` — unlike `VocabBrowserFilter` (screen-local, fine to
/// reset when the browse screen is left), the cart needs to behave like
/// the shopping-cart metaphor `SPEC.md` §3.3/§3.4 explicitly uses: it
/// must survive navigating between levels/screens during a session, not
/// empty itself the moment the browse screen is popped.

@ProviderFor(LearningCart)
final learningCartProvider = LearningCartProvider._();

/// "Keranjang Pelajari" (`SPEC.md` §3.4) — the student's in-progress
/// selection of words to learn next.
///
/// **Session-local, in-memory only — deliberately not persisted.**
/// `DATA_MODEL.md` has no Firestore collection for a cart at all; the
/// only documented destination for its contents is becoming a *new*
/// `learningSessions` document's `wordIds`
/// (`sourceType: "keranjangPelajari"`, §4) once the student presses the
/// CTA to start the 3-phase flow — Milestone 7 (Storyfier core),
/// explicitly out of scope for this stage. Inventing Firestore/local-
/// storage schema for a pre-session selection the docs don't describe
/// would be exactly the kind of unrequested architecture this stage was
/// told to avoid, so this stays plain Riverpod state.
///
/// Keyed by `normalizeWord(word)` (Stage 1's function) rather than the
/// raw word string, so duplicate prevention is normalization-sensitive
/// per this stage's instructions.
///
/// `keepAlive: true` — unlike `VocabBrowserFilter` (screen-local, fine to
/// reset when the browse screen is left), the cart needs to behave like
/// the shopping-cart metaphor `SPEC.md` §3.3/§3.4 explicitly uses: it
/// must survive navigating between levels/screens during a session, not
/// empty itself the moment the browse screen is popped.
final class LearningCartProvider
    extends $NotifierProvider<LearningCart, Map<String, VocabBundleEntry>> {
  /// "Keranjang Pelajari" (`SPEC.md` §3.4) — the student's in-progress
  /// selection of words to learn next.
  ///
  /// **Session-local, in-memory only — deliberately not persisted.**
  /// `DATA_MODEL.md` has no Firestore collection for a cart at all; the
  /// only documented destination for its contents is becoming a *new*
  /// `learningSessions` document's `wordIds`
  /// (`sourceType: "keranjangPelajari"`, §4) once the student presses the
  /// CTA to start the 3-phase flow — Milestone 7 (Storyfier core),
  /// explicitly out of scope for this stage. Inventing Firestore/local-
  /// storage schema for a pre-session selection the docs don't describe
  /// would be exactly the kind of unrequested architecture this stage was
  /// told to avoid, so this stays plain Riverpod state.
  ///
  /// Keyed by `normalizeWord(word)` (Stage 1's function) rather than the
  /// raw word string, so duplicate prevention is normalization-sensitive
  /// per this stage's instructions.
  ///
  /// `keepAlive: true` — unlike `VocabBrowserFilter` (screen-local, fine to
  /// reset when the browse screen is left), the cart needs to behave like
  /// the shopping-cart metaphor `SPEC.md` §3.3/§3.4 explicitly uses: it
  /// must survive navigating between levels/screens during a session, not
  /// empty itself the moment the browse screen is popped.
  LearningCartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningCartProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningCartHash();

  @$internal
  @override
  LearningCart create() => LearningCart();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, VocabBundleEntry> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, VocabBundleEntry>>(
        value,
      ),
    );
  }
}

String _$learningCartHash() => r'23d5a0fd877c092cf7d65348982816dd62c45898';

/// "Keranjang Pelajari" (`SPEC.md` §3.4) — the student's in-progress
/// selection of words to learn next.
///
/// **Session-local, in-memory only — deliberately not persisted.**
/// `DATA_MODEL.md` has no Firestore collection for a cart at all; the
/// only documented destination for its contents is becoming a *new*
/// `learningSessions` document's `wordIds`
/// (`sourceType: "keranjangPelajari"`, §4) once the student presses the
/// CTA to start the 3-phase flow — Milestone 7 (Storyfier core),
/// explicitly out of scope for this stage. Inventing Firestore/local-
/// storage schema for a pre-session selection the docs don't describe
/// would be exactly the kind of unrequested architecture this stage was
/// told to avoid, so this stays plain Riverpod state.
///
/// Keyed by `normalizeWord(word)` (Stage 1's function) rather than the
/// raw word string, so duplicate prevention is normalization-sensitive
/// per this stage's instructions.
///
/// `keepAlive: true` — unlike `VocabBrowserFilter` (screen-local, fine to
/// reset when the browse screen is left), the cart needs to behave like
/// the shopping-cart metaphor `SPEC.md` §3.3/§3.4 explicitly uses: it
/// must survive navigating between levels/screens during a session, not
/// empty itself the moment the browse screen is popped.

abstract class _$LearningCart extends $Notifier<Map<String, VocabBundleEntry>> {
  Map<String, VocabBundleEntry> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, VocabBundleEntry>,
              Map<String, VocabBundleEntry>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, VocabBundleEntry>,
                Map<String, VocabBundleEntry>
              >,
              Map<String, VocabBundleEntry>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
