import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Firebase Hosting security headers in `firebase.json` (OWASP ZAP
/// findings 10038 CSP, 10020 anti-clickjacking, 10021 nosniff) and the two
/// app-side changes the CSP depends on: no inline `<script>` in
/// `web/index.html`, and the Firebase JS SDK preloaded from Dart
/// (`lib/services/firebase_web_sdk_loader_web.dart`) instead of FlutterFire's
/// inline injection. Browser behaviour itself is checked manually
/// (`HANDOFF.md` §3); this keeps the configuration from drifting.
void main() {
  final hosting = (jsonDecode(File('firebase.json').readAsStringSync())
      as Map<String, dynamic>)['hosting'] as Map<String, dynamic>;
  final rules = (hosting['headers'] as List).cast<Map<String, dynamic>>();
  final catchAll = rules.singleWhere((r) => r['source'] == '**');
  final headers = {
    for (final h in (catchAll['headers'] as List).cast<Map<String, dynamic>>())
      (h['key'] as String).toLowerCase(): h['value'] as String,
  };

  Map<String, List<String>> parseCsp(String csp) => {
    for (final d in csp.split(';').map((d) => d.trim()).where((d) => d.isNotEmpty))
      d.split(RegExp(r'\s+')).first: d.split(RegExp(r'\s+')).skip(1).toList(),
  };
  final csp = parseCsp(headers['content-security-policy'] ?? '');

  test('every Hosting response gets the security headers', () {
    expect(headers['x-frame-options'], 'DENY');
    expect(headers['x-content-type-options'], 'nosniff');
    expect(headers['referrer-policy'], 'strict-origin-when-cross-origin');
    expect(headers, contains('permissions-policy'));
    expect(headers, contains('content-security-policy'));
  });

  test('Hosting never sends a permissive CORS header', () {
    final all = [
      for (final r in rules)
        for (final h in (r['headers'] as List).cast<Map<String, dynamic>>()) h,
    ];
    expect(
      all.where((h) => (h['key'] as String).toLowerCase().startsWith('access-control-')),
      isEmpty,
    );
  });

  test('CSP forbids framing, plugins, base/form hijacking', () {
    expect(csp['frame-ancestors'], ["'none'"]);
    expect(csp['object-src'], ["'none'"]);
    expect(csp['base-uri'], ["'self'"]);
    expect(csp['form-action'], ["'self'"]);
    expect(csp['default-src'], ["'self'"]);
  });

  test('script-src has no inline/eval escape hatch and no hashes to go stale', () {
    final scriptSrc = csp['script-src']!;
    expect(scriptSrc, containsAll(["'self'", "'wasm-unsafe-eval'", 'https://www.gstatic.com']));
    expect(scriptSrc, isNot(contains("'unsafe-inline'")));
    expect(scriptSrc, isNot(contains("'unsafe-eval'")));
    expect(scriptSrc.where((s) => s.startsWith("'sha") || s.startsWith("'nonce")), isEmpty);
  });

  test("style-src: 'unsafe-inline' only because the Flutter engine needs it", () {
    // The engine injects <style> elements (flt-text-editing-stylesheet,
    // flt-internals-stylesheet) whose text differs per browser and Flutter
    // version; static Hosting cannot send per-response nonces. Accepted
    // residual risk, recorded in README.md "Deployment".
    expect(csp['style-src'], unorderedEquals(["'self'", "'unsafe-inline'"]));
    expect(csp['media-src'], ["'self'"]); // TTS only, no audio files fetched
  });

  test('connect-src allows exactly the origins the app calls', () {
    expect(csp['connect-src'], unorderedEquals([
      "'self'",
      'https://www.gstatic.com', // CanvasKit wasm, Firebase SDK modules
      'https://fonts.gstatic.com', // Flutter fallback fonts
      'https://firestore.googleapis.com',
      'https://identitytoolkit.googleapis.com',
      'https://securetoken.googleapis.com',
      'https://vocably-ai-worker.refahilyaa.workers.dev', // README "Deployment"
      'https://api.dictionaryapi.dev', // SPEC.md §3.5
    ]));
  });

  test('web/index.html has no inline script (script-src is self only)', () {
    final html = File('web/index.html').readAsStringSync();
    final inline = RegExp(r'<script(?![^>]*\bsrc=)[^>]*>', caseSensitive: false);
    expect(inline.hasMatch(html), isFalse);
    expect(RegExp(r'\son[a-z]+\s*=', caseSensitive: false).hasMatch(html), isFalse);
    expect(File('web/splash.js').existsSync(), isTrue);
  });

  test('main() preloads the Firebase JS SDK before Firebase.initializeApp', () {
    final main = File('lib/main.dart').readAsStringSync();
    final preload = main.indexOf('await preloadFirebaseWebSdk();');
    expect(preload, greaterThan(-1));
    expect(preload, lessThan(main.indexOf('await Firebase.initializeApp(')));
  });
}
