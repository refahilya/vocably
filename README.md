# Vocably

A responsive, mobile-first Flutter web application for learning English vocabulary from Indonesian, built around the **Storyfier** (UIST '23) learning flow:
1. **Story Reading:** Read an AI-generated contextual story embedding target vocabulary.
2. **Cloze Test:** Fill in blanks for the target words within the generated story.
3. **Co-Write:** Collaborative turn-based story writing with an AI partner.

This project also serves as a research instrument for a bachelor's thesis, incorporating student mastery tracking, teacher target-word assignments, vocabulary editing, and research assessment scaffolds.

---

## Current Status (Audit: 2026-10-12)

- **Milestones 1–8:** Complete, automated-test verified, and committed on `main` at commit `34a9c4b`.
- **Test Suite:** **348 / 348 tests passing** (`flutter test --concurrency=1`).
- **Static Analysis:** Clean (**0 issues**, `flutter analyze`).
- **Production Build:** Verified with JavaScript/CanvasKit output (`flutter build web`).
- **Sibling Worker:** Separate repository [`vocably-ai-worker`](https://github.com/refahilya/vocably-ai-worker.git) running Cloudflare Workers proxy for LLM endpoints.
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
