# Vocably — Project State

> This file is a snapshot, not a source of truth. `CLAUDE.md`, `SPEC.md`,
> `DATA_MODEL.md`, and `DESIGN_REFERENCE.md` remain the authoritative
> project documents. If anything here conflicts with the live repository
> or with those four documents, the live repository / those documents win
> — update this file, don't trust it blindly.

## 1. Current Status

**Milestone 2 (Auth: sign up, login, role-based routing) is complete,
committed locally, and manually verified end-to-end against the real
Firebase project.** It has not yet been pushed to `origin`.

Milestone 1 (skeleton + Firebase connection) is complete and pushed.

## 2. Milestone History

Per the build order in `CLAUDE.md` §7:

| # | Milestone | Status | Commit | What was delivered |
|---|---|---|---|---|
| 1 | Skeleton project + Firebase connection | **Complete, pushed** | `123eb38` | Flutter web scaffold (`com.uns.refa.vocably`, web-only), Firebase Auth/Firestore/Core wired via FlutterFire against the existing `vocably-idn-en` project, Riverpod codegen + `riverpod_lint` established, deny-all baseline Firestore rules deployed, `.gitignore` protecting `.env` |
| 2 | Auth: sign up, login, role-based routing | **Complete, committed locally, not yet pushed** | `ff705ea` | Email/password sign up + login, client-side `users/{uid}` creation (default `siswa`, `guru` via access code), full field-matrix Firestore rules, role-based root routing, orphaned-account recovery, siswa/guru placeholder screens, retirement of the Milestone 1 connection-check code |
| 3 | Design system / theme layer + responsive nav shell | **Not started** | — | Planned: `lib/theme/theme.dart`, rail/tab nav shell per `DESIGN_REFERENCE.md` §6 |
| 4 | Vocab module (no Worker): `vocabWords`, CSV import, CEFR bundles, browse, DictionaryAPI | **Not started** | — | — |
| 5 | Cloudflare Worker + guru "Tambah Kosakata" | **Not started** | — | — |
| 6 | Student dashboard + Riwayat + Placement/Pre-Post-Test scaffolds | **Not started** | — | — |
| 7 | Storyfier core (3-phase learning flow) | **Not started** | — | — |
| 8 | Guru: Set Target Kata + Edit Kata | **Not started** | — | — |

No milestones beyond these eight are documented anywhere; none are invented here.

## 3. Current Architecture

- **Framework:** Flutter (web-only target — no android/ios/desktop platform folders exist), Dart, `environment: sdk: ^3.11.4` in `pubspec.yaml`.
- **Firebase services in use:** `firebase_core`, `firebase_auth`, `cloud_firestore` — all wired against project **`vocably-idn-en`**, app **`vocably (web)`**. No Cloud Functions (project-wide decision, Spark plan).
- **State management:** Riverpod exclusively, with code generation (`@riverpod` / `riverpod_generator`) — no manual `Provider`/`StateNotifierProvider`. `riverpod_lint` active via `analysis_options.yaml`'s `plugins:` key (not `custom_lint` — that package was deliberately not added; see §8).
- **Routing:** no routing package. Root routing is a single `switch` in `lib/app.dart` (`_RootRouter`) driven by an `AppAuthStatus` sealed class from Riverpod state. Screen-to-screen navigation (login ↔ sign-up) uses plain `Navigator.push`/`MaterialPageRoute`.
- **Backend/API:** no Cloudflare Worker exists yet (Milestone 5). No AI calls, no DictionaryAPI integration yet. The only backend is Firebase itself.
- **Directory structure actually present today:**
  ```
  lib/
    app.dart                  # root widget + _RootRouter
    main.dart                 # Firebase bootstrap + runApp
    firebase_options.dart     # FlutterFire-generated, web only
    models/
      app_user.dart
    services/
      firebase_service.dart   # SDK instance accessor only
      auth_service.dart
      user_service.dart
    providers/
      auth_providers.dart(+.g.dart)
      sign_up_controller.dart(+.g.dart)
      login_controller.dart(+.g.dart)
      complete_registration_controller.dart(+.g.dart)
    screens/
      auth/
        login_screen.dart
        sign_up_screen.dart
        complete_registration_screen.dart
      placeholders/           # temporary, see §8 — not in CLAUDE.md's canonical tree
        student_placeholder.dart
        teacher_placeholder.dart
    utils/
      role.dart
  test/
    widget_test.dart
  ```
  `widgets/` and `theme/` (documented in `CLAUDE.md` §3) do not exist yet — they start in Milestone 3.

## 4. Authentication and Authorization

- **Method:** Firebase Auth email/password only (`createUserWithEmailAndPassword` / `signInWithEmailAndPassword` / `signOut`). No other provider (Google, phone, anonymous, etc.) is wired anywhere — verified by repo-wide search.
- **Roles:** `siswa` (default) and `guru`, as string constants in `lib/utils/role.dart` (`Role.siswa`, `Role.guru`).
- **Teacher access code:** sign-up form has a "Daftar sebagai Guru?" toggle revealing a code field. The client sends `role: "guru"` + `teacherCodeInput`; **Firestore Security Rules** (not client code) verify the code exists in `teacherAccessCodes` and is `active == true`. No fallback to `siswa` on failure — the create is rejected outright.
- **`users/{uid}` schema (implemented, matches `DATA_MODEL.md` §1):**
  - Always present: `uid`, `email`, `name`, `role`, `createdAt`.
  - `siswa` only: `cefrLevel` (`null` at creation), `placementTestCompleted` (`false`), `placementTestPrompted` (`false`).
  - `guru` only: `teacherCodeInput` (non-empty string).
  - Cross-role fields are structurally forbidden by the rules' `hasOnly()` whitelists — a `guru` doc can never contain `cefrLevel` etc., and a `siswa` doc can never contain `teacherCodeInput`.
- **Role immutability:** `role` cannot change after creation (enforced in rules: `request.resource.data.role == resource.data.role`, unconditionally).
- **`teacherCodeInput` behavior:** stored permanently as an audit trail (documented decision, not a bug); immutable after creation; never present on `siswa` docs.
- **Self-update permissions (final, implemented):**
  - `siswa` may update: `name`, `cefrLevel`, `placementTestCompleted`, `placementTestPrompted`.
  - `guru` may update: `name` only.
  - `uid`, `email`, `role`, `createdAt`, `teacherCodeInput` are immutable for both roles.
- **Logout:** `AuthService.signOut()`, exposed from both placeholder screens and the recovery screen.
- **Session restoration:** driven entirely by `authStateChanges()` (via `authStateProvider`), watched permanently by the root router — no separate/parallel session mechanism.
- **Orphaned-account recovery:** if Firebase Auth has a signed-in user but `users/{uid}` doesn't exist (interrupted/failed registration — *not* the confirmed-invalid-teacher-code case, which instead rolls back the Auth account), the app shows `CompleteRegistrationScreen`, which can **only ever create a `siswa` profile** (`CompleteRegistrationController` calls `createStudentProfile` exclusively — no code path to `createTeacherProfile` exists here). See `DATA_MODEL.md` §1 point 7.
- **Sign-up rollback:** a `permission-denied` confirmed to originate from a `role: "guru"` create attempt triggers `AuthService.deleteCurrentUser()` before surfacing "Kode akses tidak valid" to the user. Any other failure (network, transient Firestore errors) does *not* trigger rollback — the orphaned-account flow handles that case instead.
- **Out of scope for Milestone 2 (deliberately not built):** password reset, email verification, profile-editing UI beyond the rules-permitted self-update fields.

## 5. Firebase / Firestore State

- **Project:** `vocably-idn-en` (Firestore in **Native mode**, region `asia-southeast1`).
- **Services enabled/used:** Firebase Auth (email/password provider), Cloud Firestore. No Cloud Functions, no Hosting deploy yet, no Storage.
- **Firestore collections that currently exist in the schema/rules (not necessarily populated with data):**
  - `users/{uid}` — real rules in place, described in §4 above.
  - `teacherAccessCodes/{code}` — rules deny all client read/write (`allow read, write: if false`); only reachable via `exists()`/`get()` from the `users` create rule. **No document has been seeded into this collection yet** — teacher sign-up cannot succeed against real data until at least one `teacherAccessCodes` document is created manually via the Firebase Console (`docId` = the code itself, fields `active: true`, `createdAt`).
  - Everything else (`vocabWords`, `learningProgress`, `learningSessions`, `targetWordSets`, `topics`, `placementTestResults`, `researchAssessmentResults`) — **not yet modeled in rules or code**; still covered only by the deny-all fallback (`match /{document=**} { allow read, write: if false; }`).
- **Security Rules file:** `firestore.rules` at repo root, `rules_version = '2'`. Deployed to the live project as of Milestone 2 (confirmed via `firebase deploy --only firestore:rules` during Milestone 2 implementation; not re-deployed since).
- **Config files:** `.firebaserc` (default project = `vocably-idn-en`), `firebase.json` (maps `lib/firebase_options.dart` to the web app + points to `firestore.rules`/`firestore.indexes.json`), `firestore.indexes.json` (empty — no composite indexes needed yet).
- No secrets or credential values are recorded in this file or in any tracked file — `.env` (OpenAI-related dev config, unrelated to Firebase) remains untracked and git-ignored.

## 6. Implemented Features

- Flutter web scaffold, running via `flutter run -d chrome`.
- Firebase initialization (`main.dart`), with a graceful in-app error screen if `Firebase.initializeApp` itself throws.
- Student sign-up (email/password + name) → `users/{uid}` created with `role: "siswa"`.
- Teacher sign-up (same + "Daftar sebagai Guru?" toggle + access code) → `users/{uid}` created with `role: "guru"`, gated by a valid/active `teacherAccessCodes` document.
- Invalid teacher code → sign-up rejected, Auth account rolled back, friendly inline error shown.
- Login (email/password).
- Logout.
- Session restoration across page refresh.
- Role-based routing to one of two temporary placeholder screens.
- Orphaned-account recovery ("Lengkapi Pendaftaran" → default `siswa` profile only).
- All of the above were manually tested by the project owner against the real `vocably-idn-en` project and reported as passing (student sign-up, logout, re-login, session restoration after refresh, valid-code teacher sign-up, invalid-code teacher sign-up with rollback).

## 7. Not Yet Implemented

**Future milestone work (Milestones 3–8, per `CLAUDE.md` §7):** theme/design system, responsive nav shell, `vocabWords` + CSV import + CEFR bundles, vocab browsing (3 modes), DictionaryAPI integration, Cloudflare Worker (`vocably-ai-worker/`, separate repo — does not exist yet), guru "Tambah Kosakata", real student dashboard, Riwayat, the 3-phase Storyfier learning flow, guru "Set Target Kata" + "Edit Kata".

**Intentionally out of scope (not a gap, a decision):** password reset, email verification, any auth provider besides email/password — per explicit Milestone 2 scope decision, not revisited yet.

**Unresolved / TBD (per `CLAUDE.md` §10, not to be assumed or invented):** Placement Test scoring/level-determination algorithm; Pre-Test/Post-Test instrument and scoring; the ChatGPT-based DictionaryAPI fallback (`/word-details`) — pending a word-coverage measurement during CSV import; `flutter_tts` (or equivalent) as the audio fallback dependency — not yet confirmed/approved; the exact behavior for abandoned/incomplete `learningSessions` (explicitly flagged as an open question to revisit before Milestone 7, not decided).

## 8. Important Architectural Decisions

These must be preserved by future work unless explicitly revisited in discussion:

- **Riverpod with code generation is the only state-management approach** — no manual `Provider`/`StateNotifierProvider`, no other state library.
- **No routing package** (no `go_router`/`auto_route`) — plain `Navigator` + a status-driven `switch` in `app.dart` is the deliberate choice for as long as it stays adequate.
- **No `custom_lint`** — `riverpod_lint` (≥3.1.0) is implemented on `analysis_server_plugin`, not `custom_lint`; do not add `custom_lint` "for Riverpod" without a new, independent reason.
- **Role assignment happens through Firestore Security Rules, not client code or Cloud Functions** — the client cannot self-grant `guru`; the rules' `exists()`/`active==true` check against `teacherAccessCodes` is the only gate.
- **`role` and `teacherCodeInput` are permanently immutable** after `users/{uid}` creation, for both roles.
- **`teacherCodeInput` is a permanent, intentional audit trail** — not a temporary field, not something to later "clean up."
- **Self-update permissions are role-specific and enforced as closed whitelists** (`hasOnly()`) in rules: `siswa` gets 4 fields, `guru` gets `name` only. Extending this requires a rules change, reviewed the same way the original matrix was.
- **Orphaned-account recovery can only ever create a `siswa` profile** — this is a deliberate privilege-escalation guard, not an oversight to "complete" later by adding a guru path.
- **`lib/screens/placeholders/` is temporary**, not a permanent architectural layer — it exists only to prove role-based routing before Milestone 3 (nav shell) and Milestones 6/8 (real dashboards) exist, and should be deleted once those land. It is deliberately *not* part of `CLAUDE.md` §3's canonical folder structure (see the exception note added there).
- **Generated `.g.dart` files are committed to git** — not regenerated-on-clone-only; this was an explicit Milestone 1 decision.
- **The client-side data-integrity limitation is an accepted trade-off, not a bug**: `learningProgress`, `placementTestResults`, and `researchAssessmentResults` are written directly by the client with no server-side validator confirming the underlying activity actually happened — documented in `DATA_MODEL.md` §3 as a deliberate consequence of the no-Cloud-Functions architecture, not something Milestone work should try to "fix" without an explicit new discussion.

## 9. Current File Structure

```
vocably/
  CLAUDE.md, SPEC.md, DATA_MODEL.md, DESIGN_REFERENCE.md, PROJECT_STATE.md
  README.md
  pubspec.yaml, pubspec.lock, analysis_options.yaml
  firebase.json, .firebaserc, firestore.rules, firestore.indexes.json
  .gitignore, .env (untracked, git-ignored)
  lib/
    app.dart, main.dart, firebase_options.dart
    models/app_user.dart
    services/firebase_service.dart, auth_service.dart, user_service.dart
    providers/auth_providers.dart(+.g), sign_up_controller.dart(+.g),
              login_controller.dart(+.g), complete_registration_controller.dart(+.g)
    screens/auth/login_screen.dart, sign_up_screen.dart, complete_registration_screen.dart
    screens/placeholders/student_placeholder.dart, teacher_placeholder.dart
    utils/role.dart
  test/widget_test.dart
  web/                          # Flutter web scaffold assets (icons, manifest, index.html)
```
Not yet present: `lib/widgets/`, `lib/theme/`, `assets/vocab/`, `vocably-ai-worker/` (separate repo, per `CLAUDE.md` §3).

## 10. Verification Status

Latest results (Milestone 2, immediately pre-commit):

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 1/1 passed |
| `dart run build_runner build` | 0 new outputs (all generated files current) |
| `flutter build web` | Succeeded |
| Manual Milestone 2 test matrix (against real `vocably-idn-en` project) | All 6 scenarios passed: student sign-up, logout, re-login, session restoration after refresh, valid-code teacher sign-up, invalid-code teacher sign-up with Auth rollback |

## 11. Current Git State

- **Branch:** `main`
- **Latest commit:** `ff705ea` — "Milestone 2: Firebase Auth and role-based routing"
- **Working tree:** clean (before this file was added)
- **Remote relationship:** `main` is ahead of `origin/main` by 1 commit (Milestone 2 committed locally, **not yet pushed**)

## 12. Next Recommended Step

Per `CLAUDE.md` §7, **Milestone 3: design system / theme layer + responsive navigation shell** (`NavigationRail` for wide screens, top tabs for narrow/mobile screens — not bottom nav), based on `DESIGN_REFERENCE.md`. This has not been implemented, planned in detail, or started — this document only names it as the next milestone in sequence per the existing build order; it does not design or scaffold it.

Before that, two operational loose ends from Milestone 2 remain the project owner's decision, not a blocker to Milestone 3 itself: (a) whether/when to `git push` the Milestone 2 commit, and (b) seeding at least one real `teacherAccessCodes` document via the Firebase Console so teacher sign-up can be exercised against production data going forward.

## 13. Handoff Instructions for a New AI Session

1. Read this file (`PROJECT_STATE.md`) first for orientation.
2. Then read `CLAUDE.md` in full — it is the authoritative project-rules document and must be read every session per its own header.
3. Read `SPEC.md`, `DATA_MODEL.md`, and `DESIGN_REFERENCE.md` as needed for the specific task at hand.
4. **Inspect the live repository** (git log, git status, actual file contents) before changing anything — do not assume this file is still accurate; it is a snapshot from a specific point in time (Milestone 2 completion) and will drift as work continues.
5. If the live repository contradicts anything written here, **trust the live repository**, not this file — and consider updating this file to match.
6. Preserve the architectural decisions in §8 unless the project owner explicitly reopens discussion on one of them. Do not silently redesign role assignment, state management, routing, or the rules-enforced field matrix.
