import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vocably/theme/theme.dart';

/// Loads the bundled typefaces, so layout tests measure real text instead of
/// the test font, whose square glyphs are far wider than Plus Jakarta Sans and
/// would report overflows that can't happen.
Future<void> loadAppFonts() async {
  Future<ByteData> read(String name) async {
    final bytes = await File('assets/fonts/$name.ttf').readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  final ui = FontLoader(AppFonts.ui)
    ..addFont(read('PlusJakartaSans-Regular'))
    ..addFont(read('PlusJakartaSans-SemiBold'))
    ..addFont(read('PlusJakartaSans-Bold'));
  final reading = FontLoader(AppFonts.reading)
    ..addFont(read('Literata-Regular'))
    ..addFont(read('Literata-Bold'))
    ..addFont(read('Literata-Italic'));
  await Future.wait([ui.load(), reading.load()]);
}
