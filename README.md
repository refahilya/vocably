# Vocably

A responsive, mobile-first Flutter web application for learning English vocabulary from Indonesian, built around the **Storyfier** (UIST '23) learning flow:
1. **Story Reading:** Read an AI-generated contextual story embedding target vocabulary.
2. **Cloze Test:** Fill in blanks for the target words within the generated story.
3. **Co-Write:** Collaborative turn-based story writing with an AI partner.

This project also serves as a research instrument for a bachelor's thesis, incorporating student mastery tracking, teacher target-word assignments, vocabulary editing, an in-app research pretest/posttest with offline scoring tooling, and a Researcher Panel for running test sessions from the app.

---

## Current Status

Milestones 1–8, the Co-Write remediation, Difficult-word relearning and the research pretest/posttest workflow are implemented. The Flutter app is not hosted yet, and the research workflow has not been used in production. For the verified current state — Git, deployment, latest test results, blockers, open research decisions and next steps — see **[`HANDOFF.md`](HANDOFF.md)**, the only maintained status snapshot.

---

## Documentation

Each kind of information has one owner; other documents link to it instead of copying it.

| Document | Owns |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Rules for AI coding agents: source-of-truth hierarchy, hard constraints, conventions, documentation maintenance, Git/deployment limits |
| [`HANDOFF.md`](HANDOFF.md) | **Current status**: Git and deployment state, latest verification, blockers, open decisions, known issues, next steps |
| [`PROJECT_STATE.md`](PROJECT_STATE.md) | Historical development record and decision rationale (append-only) |
| [`SPEC.md`](SPEC.md) | Product and functional behaviour |
| [`DATA_MODEL.md`](DATA_MODEL.md) | Firestore schemas, security-rules logic, Worker API contracts |
| [`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md) | Visual identity, UI patterns, responsive layout |
| [`tools/research/README.md`](tools/research/README.md) | Research tooling: instrument bank build, private answer key, emulator tests, researcher administration (incl. the one-time Researcher Panel operator grant), export and scoring |
| [`tools/vocab_import/README.md`](tools/vocab_import/README.md) | Oxford 3000/5000 vocabulary import and bundle generation |

**Reading order for a new session:** `CLAUDE.md`, then `HANDOFF.md`, then whichever of `SPEC.md`, `DATA_MODEL.md` or `DESIGN_REFERENCE.md` the task touches.

---

## Development Setup

### 1. Prerequisites
- Flutter SDK (stable channel, targeting Web)
- Chrome browser
- Node.js (for the tools and the Cloudflare Worker)
- Firebase CLI (`npm install -g firebase-tools`)
- Java 21+ only for the local Firebase Emulators (research tooling; see `tools/research/README.md`)

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
To run the app against local Firebase Emulators with dummy accounts (debug only; refused in release builds), see "Running the app against the emulators" in `tools/research/README.md`.

### 4. Running Automated Tests
> **IMPORTANT:** Always run Flutter tests with `--concurrency=1`. The default concurrency in this environment non-deterministically drops test files while falsely reporting success.
```bash
flutter analyze
flutter test --concurrency=1
cd tools/research && npm test             # research tooling unit tests
cd tools/research && npm run test:rules   # security rules + tooling + end-to-end, local emulators (Java 21+)
cd tools/vocab_import && npm test         # vocabulary pipeline unit tests
```

### 5. Production Web Build
```bash
flutter build web --release --dart-define=WORKER_BASE_URL=https://vocably-ai-worker.refahilyaa.workers.dev
```
*(Note: Do not pass `--wasm`: `flutter_tts: ^4.2.5` uses legacy JS interop that is incompatible with `dart2wasm`.)*

---

## Deployment

**Every deployment is a deliberate action by the project owner.** AI agents must not deploy or write to production without explicit authorization (`CLAUDE.md` §0). Check `HANDOFF.md` for what is currently deployed and for blockers before deploying anything.

### Architecture
- **Web frontend:** Firebase Hosting serving the Flutter web single-page app, at `https://vocably-idn-en.web.app` and `https://vocably-idn-en.firebaseapp.com`.
- **Database & Auth:** Firebase project `vocably-idn-en` (Spark plan, Firestore Native mode, `asia-southeast1`). Single environment, no staging project. Research rules are tested only against the local emulator under the demo project `demo-vocably-test`.
- **AI proxy:** Cloudflare Worker at `https://vocably-ai-worker.refahilyaa.workers.dev` (separate repository). Its allowed CORS origins are the two Hosting domains plus the local development origin `http://localhost:5555`.

### 1. Hosting configuration
`firebase.json` needs a `"hosting"` block before the first Hosting deploy:
```json
"hosting": {
  "public": "build/web",
  "ignore": [
    "firebase.json",
    "**/.*",
    "**/node_modules/**"
  ],
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"
    }
  ]
}
```

### 2. Build, then deploy rules, indexes and Hosting
```bash
flutter build web --release --dart-define=WORKER_BASE_URL=https://vocably-ai-worker.refahilyaa.workers.dev
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only hosting
```
- `firestore.rules` contains every collection's rules, including the research rules, so deploying it deploys all of them. The research rules fail closed until researcher tooling seeds `researchInstrument` (`tools/research/README.md`, "Researcher administration").
- **Deploy the rules before hosting a build that contains the research module.** Older deployed rules deny the research reads, and the Pre-Test/Post-Test banners would show "Gagal memuat".

### 3. Cloudflare Worker (only when Worker code changed)
Never run a plain `wrangler deploy` from a working copy whose `wrangler.jsonc` lists the local-only `http://localhost:5000` origin. Override the origins instead:
```bash
cd ../vocably-ai-worker
npx wrangler deploy --var "ALLOWED_ORIGINS:https://vocably-idn-en.web.app,https://vocably-idn-en.firebaseapp.com,http://localhost:5555"
```
Secrets (`OPENAI_API_KEY`) are managed with `wrangler secret`; never print or commit `.dev.vars`.

### 4. Research data collection
Production setup for the pretest/posttest and the Placement Test (seeding the bank and placement-key documents, the study and stage windows, enrolling participants, opening stages, export) uses the researcher tooling with the researcher's own service account and is never automatic. Once that setup and the one-time `operator --grant` are done, the classroom steps (opening/closing stages, authorizing, monitoring, technical retakes) can run from the app's Researcher Panel. See `tools/research/README.md` ("Researcher Panel"), and the blockers and open decisions in `HANDOFF.md`.
