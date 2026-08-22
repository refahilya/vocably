# Vocably

A responsive, mobile-first Flutter web app for learning English vocabulary
from Indonesian, built around the Storyfier (UIST '23) learning method:
read an AI-generated story → cloze test → co-write with AI.

This repository is also a thesis research instrument (placement test and
pre-test/post-test modules), currently under active development.

## Start here

Read these in order before making changes:

- [`CLAUDE.md`](CLAUDE.md) — project context, tech stack, conventions, and
  milestone plan. Read this first, every session.
- [`SPEC.md`](SPEC.md) — functional specification.
- [`DATA_MODEL.md`](DATA_MODEL.md) — Firestore schema and architecture.
- [`DESIGN_REFERENCE.md`](DESIGN_REFERENCE.md) — visual design reference.

## Running the app

```
flutter run -d chrome --web-port=5555
```

The fixed port matters once the Cloudflare Worker (AI proxy) is in the
picture — see `DATA_MODEL.md` §10.1 for the CORS reasoning.
