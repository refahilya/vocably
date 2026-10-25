import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocably/models/research_instrument.dart';
import 'package:vocably/services/research_instrument_service.dart';

/// In-memory [AssetBundle], same shape as `vocab_bundle_service_test.dart`.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final content = _assets[key];
    if (content == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bankPath = 'assets/research/instrument_v1.json';

  Matcher throwsInstrumentError(String messagePart) => throwsA(
    isA<ResearchInstrumentException>().having(
      (e) => e.message,
      'message',
      contains(messagePart),
    ),
  );

  test('loads the bundled v1 bank through the real asset bundle', () async {
    final instrument = await ResearchInstrumentService().load('v1');
    expect(instrument.instrumentVersion, 'v1');
    expect(instrument.items, hasLength(80));
  });

  test('loads from an injected bundle', () async {
    final real = await rootBundle.loadString(bankPath);
    final service = ResearchInstrumentService(
      assetBundle: _FakeAssetBundle({bankPath: real}),
    );
    expect((await service.load('v1')).bands, ['A2', 'B1', 'B2', 'C1']);
  });

  test(
    'rejects an unsupported instrument version without reading any asset',
    () async {
      final service = ResearchInstrumentService(
        assetBundle: _FakeAssetBundle({}),
      );
      await expectLater(
        service.load('v2'),
        throwsInstrumentError('unsupported instrument version'),
      );
    },
  );

  test('fails clearly when the asset is missing', () async {
    final service = ResearchInstrumentService(
      assetBundle: _FakeAssetBundle({}),
    );
    await expectLater(
      service.load('v1'),
      throwsInstrumentError('could not be loaded'),
    );
  });

  test('fails clearly on invalid JSON', () async {
    final service = ResearchInstrumentService(
      assetBundle: _FakeAssetBundle({bankPath: '{"schemaVersion": 1,'}),
    );
    await expectLater(
      service.load('v1'),
      throwsInstrumentError('not valid JSON'),
    );
  });

  test('fails clearly on JSON that is not a valid bank', () async {
    final service = ResearchInstrumentService(
      assetBundle: _FakeAssetBundle({bankPath: '{"schemaVersion": 1}'}),
    );
    await expectLater(
      service.load('v1'),
      throwsA(isA<ResearchInstrumentException>()),
    );
  });
}
