import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/ai_worker_service.dart';

part 'ai_worker_providers.g.dart';

/// Shared access point for the Cloudflare Worker AI proxy client — used
/// by both guru's Tambah Kosakata (`vocab_management_providers.dart`)
/// and siswa's lazy Word Detail translation display
/// (`lazy_translation_providers.dart`). Kept in its own file since it
/// isn't specific to either flow (`DATA_MODEL.md` §2 point 4: `/translate`
/// is called from both places, and the Worker itself doesn't
/// distinguish the caller's role — see `AiWorkerService`'s doc comment).
@riverpod
AiWorkerService aiWorkerService(Ref ref) => AiWorkerService();
