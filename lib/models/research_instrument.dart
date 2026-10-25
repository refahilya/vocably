import '../utils/research_constants.dart';

/// Thrown when the research instrument bank, a participant assignment or an
/// attempt plan doesn't satisfy the instrument contract. Always fatal for
/// the attempt: the app must never fill in a default or guess.
class ResearchInstrumentException implements Exception {
  const ResearchInstrumentException(this.message);

  final String message;

  @override
  String toString() => 'ResearchInstrumentException: $message';
}

/// One answer choice as stored in the app-safe bank: an opaque ID plus the
/// Indonesian text shown to the student. Deliberately carries **no**
/// correctness information — the answer key never reaches the app
/// (`CLAUDE.md` §6).
class ResearchOption {
  const ResearchOption({required this.id, required this.text});

  final String id;
  final String text;

  static final _idPattern = RegExp(r'^opt_[0-9a-f]{12}$');

  factory ResearchOption.fromJson(Object? json, String context) {
    final map = _asMap(json, context);
    _onlyKeys(map, const {'id', 'text'}, context);
    final id = _requireString(map, 'id', context);
    if (!_idPattern.hasMatch(id)) {
      throw ResearchInstrumentException('$context: invalid option id "$id"');
    }
    return ResearchOption(id: id, text: _requireString(map, 'text', context));
  }
}

/// One test item: the English word plus its four substantive options in
/// the bank's source order (shuffled per attempt by the planner).
class ResearchItem {
  const ResearchItem({
    required this.id,
    required this.band,
    required this.number,
    required this.word,
    required this.pos,
    required this.posLabel,
    required this.options,
  });

  /// `{band}-{number:02}`, e.g. `A2-01`.
  final String id;
  final String band;
  final int number;
  final String word;

  /// English word class (`noun`), and its Indonesian label (`kata benda`).
  final String pos;
  final String posLabel;

  /// Exactly [kResearchOptionsPerItem] options, unique by ID and text.
  final List<ResearchOption> options;

  factory ResearchItem.fromJson(Object? json, String context) {
    final map = _asMap(json, context);
    _onlyKeys(map, const {
      'id',
      'band',
      'number',
      'word',
      'pos',
      'posLabel',
      'options',
    }, context);
    final id = _requireString(map, 'id', context);
    final itemContext = '$context ($id)';
    final band = _requireString(map, 'band', itemContext);
    final number = map['number'];
    if (number is! int || number < 1) {
      throw ResearchInstrumentException(
        '$itemContext: "number" must be a positive integer',
      );
    }
    if (id != '$band-${number.toString().padLeft(2, '0')}') {
      throw ResearchInstrumentException(
        '$itemContext: id does not match band and number',
      );
    }

    final rawOptions = map['options'];
    if (rawOptions is! List || rawOptions.length != kResearchOptionsPerItem) {
      throw ResearchInstrumentException(
        '$itemContext: "options" must list exactly $kResearchOptionsPerItem options',
      );
    }
    final options = [
      for (var i = 0; i < rawOptions.length; i++)
        ResearchOption.fromJson(rawOptions[i], '$itemContext option $i'),
    ];
    if (options.map((o) => o.id).toSet().length != options.length) {
      throw ResearchInstrumentException('$itemContext: duplicate option id');
    }
    if (options.map((o) => o.text).toSet().length != options.length) {
      throw ResearchInstrumentException('$itemContext: duplicate option text');
    }

    return ResearchItem(
      id: id,
      band: band,
      number: number,
      word: _requireString(map, 'word', itemContext),
      pos: _requireString(map, 'pos', itemContext),
      posLabel: _requireString(map, 'posLabel', itemContext),
      options: List.unmodifiable(options),
    );
  }
}

/// The parsed, validated app-safe bank (`assets/research/instrument_v1.json`,
/// `DATA_MODEL.md` §6c). Parsing is strict: unknown fields, missing fields,
/// duplicate IDs or a band without exactly [kResearchItemsPerBand] items all
/// throw [ResearchInstrumentException]. Unknown fields are rejected on
/// purpose, so a bank that somehow gained key-like data fails to load
/// instead of carrying it into the app.
class ResearchInstrument {
  const ResearchInstrument._({
    required this.instrumentVersion,
    required this.bands,
    required this.dontKnowOption,
    required this.items,
  });

  final String instrumentVersion;
  final List<String> bands;

  /// The separate "Saya tidak tahu kata ini" choice — never one of an
  /// item's [ResearchItem.options].
  final ResearchOption dontKnowOption;

  /// All items, in bank order.
  final List<ResearchItem> items;

  /// Descriptive top-level fields that are accepted but not modelled.
  static const _ignoredKeys = {'status', 'source', 'optionOrder'};

  /// Parses [json] and checks that it is the bank for [expectedVersion].
  factory ResearchInstrument.fromJson(
    Object? json, {
    required String expectedVersion,
  }) {
    const context = 'instrument';
    final map = _asMap(json, context);
    _onlyKeys(map, {
      'schemaVersion',
      'instrumentId',
      'instrumentVersion',
      'bands',
      'itemsPerBand',
      'dontKnowOption',
      'items',
      ..._ignoredKeys,
    }, context);

    if (map['schemaVersion'] != kResearchSchemaVersion) {
      throw ResearchInstrumentException(
        'unsupported schemaVersion ${map['schemaVersion']} (expected $kResearchSchemaVersion)',
      );
    }
    if (map['instrumentId'] != kResearchInstrumentId) {
      throw const ResearchInstrumentException('unexpected instrumentId');
    }
    final version = _requireString(map, 'instrumentVersion', context);
    if (version != expectedVersion) {
      throw ResearchInstrumentException(
        'instrumentVersion "$version" does not match the requested "$expectedVersion"',
      );
    }
    if (map['itemsPerBand'] != kResearchItemsPerBand) {
      throw const ResearchInstrumentException(
        '"itemsPerBand" must be $kResearchItemsPerBand',
      );
    }

    final rawBands = map['bands'];
    if (rawBands is! List ||
        rawBands.isEmpty ||
        rawBands.any((band) => band is! String || band.isEmpty) ||
        rawBands.toSet().length != rawBands.length) {
      throw const ResearchInstrumentException(
        '"bands" must be a non-empty list of unique band names',
      );
    }
    final bands = List<String>.unmodifiable(rawBands.cast<String>());

    final dontKnow = _asMap(map['dontKnowOption'], 'dontKnowOption');
    _onlyKeys(dontKnow, const {'id', 'text'}, 'dontKnowOption');
    if (dontKnow['id'] != kResearchDontKnowOptionId ||
        dontKnow['text'] != kResearchDontKnowOptionText) {
      throw const ResearchInstrumentException(
        '"dontKnowOption" does not match the instrument contract',
      );
    }

    final rawItems = map['items'];
    if (rawItems is! List) {
      throw const ResearchInstrumentException('"items" must be a list');
    }
    final items = [
      for (var i = 0; i < rawItems.length; i++)
        ResearchItem.fromJson(rawItems[i], 'item $i'),
    ];
    final seenIds = <String>{};
    for (final item in items) {
      if (!seenIds.add(item.id)) {
        throw ResearchInstrumentException('duplicate item id "${item.id}"');
      }
      if (!bands.contains(item.band)) {
        throw ResearchInstrumentException(
          'item ${item.id}: undeclared band "${item.band}"',
        );
      }
    }
    for (final band in bands) {
      final count = items.where((item) => item.band == band).length;
      if (count != kResearchItemsPerBand) {
        throw ResearchInstrumentException(
          'band $band has $count items (expected $kResearchItemsPerBand)',
        );
      }
    }

    return ResearchInstrument._(
      instrumentVersion: version,
      bands: bands,
      dontKnowOption: const ResearchOption(
        id: kResearchDontKnowOptionId,
        text: kResearchDontKnowOptionText,
      ),
      items: List.unmodifiable(items),
    );
  }

  /// The [kResearchItemsPerBand] items of [band], in bank order. Throws for
  /// a band the bank doesn't declare.
  List<ResearchItem> itemsForBand(String band) {
    if (!bands.contains(band)) {
      throw ResearchInstrumentException(
        'band "$band" is not in instrument $instrumentVersion',
      );
    }
    return [
      for (final item in items)
        if (item.band == band) item,
    ];
  }
}

Map<String, dynamic> _asMap(Object? json, String context) {
  if (json is! Map<String, dynamic>) {
    throw ResearchInstrumentException('$context: expected a JSON object');
  }
  return json;
}

void _onlyKeys(Map<String, dynamic> map, Set<String> allowed, String context) {
  final unknown = map.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw ResearchInstrumentException(
      '$context: unexpected field(s) ${unknown.join(', ')}',
    );
  }
}

String _requireString(Map<String, dynamic> map, String key, String context) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw ResearchInstrumentException(
      '$context: "$key" must be a non-empty string',
    );
  }
  return value;
}
