import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/research_instrument.dart';
import '../utils/research_constants.dart';

/// Loads the app-safe research instrument bank (`DATA_MODEL.md` §6c) from
/// the bundled asset. Unlike `VocabBundleService.loadLevel`, a missing or
/// broken asset is **not** an empty result: without a valid bank there is
/// no test to give, so every failure throws [ResearchInstrumentException].
///
/// [assetBundle] defaults to [rootBundle] and is injectable for tests, the
/// same pattern as `VocabBundleService`.
class ResearchInstrumentService {
  ResearchInstrumentService({AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  /// Loads and validates the bank for [instrumentVersion] (from the
  /// participant's trusted assignment).
  Future<ResearchInstrument> load(String instrumentVersion) async {
    final assetKey = kResearchInstrumentAssets[instrumentVersion];
    if (assetKey == null) {
      throw ResearchInstrumentException(
        'unsupported instrument version "$instrumentVersion"',
      );
    }

    String raw;
    try {
      raw = await _assetBundle.loadString(assetKey);
    } catch (_) {
      throw ResearchInstrumentException(
        'instrument asset "$assetKey" could not be loaded',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw ResearchInstrumentException(
        'instrument asset "$assetKey" is not valid JSON',
      );
    }

    return ResearchInstrument.fromJson(
      decoded,
      expectedVersion: instrumentVersion,
    );
  }
}
