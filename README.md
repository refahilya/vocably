# Vocably

A responsive, mobile-first Flutter web application for learning English vocabulary from Indonesian, built around the **Storyfier** (UIST '23) learning flow:
1. **Story Reading:** Read an AI-generated contextual story embedding target vocabulary.
2. **Cloze Test:** Fill in blanks for the target words within the generated story.
3. **Co-Write:** Collaborative turn-based story writing with an AI partner.

This project also serves as a research instrument for a bachelor's thesis, incorporating student mastery tracking, teacher target-word assignments, vocabulary editing, and research assessment scaffolds.

---

## Current Status (Updated: 2026-10-16)

- **Milestones 1–8:** Complete and committed. `main` is at `2e175f1`, which includes the Co-Write work below.
- **Difficult Words selection (working tree, not committed):** in Riwayat → Per Kata → Difficult, students tick the difficult words to relearn. Nothing is selected initially; there are Pilih Semua / Batalkan Pilihan and "Pelajari Kembali (N kata)", with no size cap. Riwayat reloads after the session. See `PROJECT_STATE.md` §5u.
- **Co-Write remediation Phase 1 + Phase 2:** Implemented, automated-test verified, and **committed** in this repo (`2e175f1`) and `vocably-ai-worker` (`5bcb5e4`). The **Worker side is deployed** (version `0bec79ee`, 2026-10-16, from the working tree just before that commit; see `PROJECT_STATE.md` §5t). The Flutter side isn't hosted. Covers the application-owned three-turn fallback, deterministic target-word validation, feedback tied to the current turn, and Indonesian writing suggestions. CW-05 (same working tree) credits meaningful target-word use even with grammar or tense errors, maps model-reported surface forms to base targets, and stops a retry from erasing a student's credit. Indonesian/mixed-language handling (same working tree) classifies each student turn deterministically: an Indonesian or mixed turn gets a short "write in English" reminder and earns session coverage only, never independent mastery; the bot always continues in English and stays in the story. CW-02 (same working tree):
  - Feedback puts the current turn's target-word use ahead of minor grammar.
  - Praise for a word that validation rejected is replaced with a neutral message.
  - Feedback shows a ✓, 💡 or 💬 indicator derived from validated results. It's display-only, not persisted, and doesn't affect mastery.
  - The Worker returns 502 rather than an unacceptable bot sentence.

  See `SPEC.md` §5.3 and `PROJECT_STATE.md` §5p–§5s. Browser and real-LLM end-to-end testing is still pending.
- **Test Suite:** **484 / 484 tests passing** (`flutter test --concurrency=1`).
- **Static Analysis:** Clean (**0 issues**, `flutter analyze`).
- **Production Build:** `flutter build web --release` succeeds (JavaScript/CanvasKit output).
- **Sibling Worker:** Separate repository [`vocably-ai-worker`](https://github.com/refahilya/vocably-ai-worker.git) running the Cloudflare Workers proxy for LLM endpoints (**148 / 148 tests passing** locally). Deployed 2026-10-16 as version `0bec79ee-2958-475e-97fe-64ababf31c9c` from its working tree just before commit `5bcb5e4`, including all Co-Write Worker work; production CORS, auth and routing smoke tests passed.
- **Firebase Hosting:** Web hosting configuration in `firebase.json` is pending implementation before deployment.

---

## Core Documentation

Read these documents for authoritative project guidelines:

1. [`HANDOFF.md`](HANDOFF.md) — Current state orientation layer, verification snapshot, and open items.
2. [`CLAUDE.md`](CLAUDE.md) — Developer context, strict constraints, tech stack rules, and conventions.
3. [`PROJECT_STATE.md`](PROJECT_STATE.md) — Detailed chronological project log, milestone details, and production roadmap.
4. [`SPEC.md`](SPEC.md) — Product and functional behavior specifications.
5. [`DATA_MODEL.md`](DATA_MODEL.md) — Firestore data schemas, security rules logic, and Worker API contracts.
6. [`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md) — Design system tokens, color palettes, and responsive layouts.
7. [`tools/vocab_import/README.md`](tools/vocab_import/README.md) — Oxford 3000/5000 vocabulary processing & Firestore seeding pipeline.

---

## Development Setup

### 1. Prerequisites
- Flutter SDK (stable channel, targeting Web)
- Chrome browser
- Node.js (for tools & Cloudflare Worker)
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Sibling Repository
The AI backend lives in a separate repository:
```bash
# Clone alongside this repository
git clone https://github.com/refahilya/vocably-ai-worker.git
```

### 3. Running Locally
Run the Flutter web app on a fixed port to match Cloudflare Worker CORS allowlists:
```bash
flutter run -d chrome --web-port=5555
```

### 4. Running Automated Tests
> **IMPORTANT:** Always run Flutter tests with `--concurrency=1`. The default concurrency in this environment non-deterministically drops test files while falsely reporting success.
```bash
flutter test --concurrency=1
```

### 5. Production Web Build
```bash
flutter build web --release --dart-define=WORKER_BASE_URL=https://vocably-ai-worker.refahilyaa.workers.dev
```
*(Note: Do not pass `--wasm` as `flutter_tts: ^4.2.2` utilizes legacy JS interop incompatible with `dart2wasm`).*
