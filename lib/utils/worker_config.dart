/// Base URL for the Cloudflare Worker AI proxy (`vocably-ai-worker`,
/// separate repo — `CLAUDE.md` §2/§7 Milestone 5, `DATA_MODEL.md` §10).
///
/// Configurable at build/run time via `--dart-define`, since the same
/// Flutter build must be able to point at either a local `wrangler dev`
/// server or the deployed Worker without a code change:
///
/// ```
/// flutter run -d chrome --web-port=5555 \
///   --dart-define=WORKER_BASE_URL=https://vocably-ai-worker.<subdomain>.workers.dev
/// ```
///
/// Defaults to the standard local `wrangler dev` address (`vocably-ai-
/// worker`'s `npm run dev`, per the project owner's decision to use
/// `wrangler dev` for local Worker development) so a plain `flutter run`
/// "just works" once that Worker is running locally — see
/// `vocably-ai-worker/README.md`.
const String kWorkerBaseUrl = String.fromEnvironment(
  'WORKER_BASE_URL',
  defaultValue: 'http://localhost:8787',
);
