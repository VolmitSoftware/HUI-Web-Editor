/// The 16 legacy colour codes, pinned.
///
/// `mcLegacyColors` is derived from the parser's own tag table rather than
/// written out a second time, so this file is the golden that proves the
/// derivation produces exactly the table it replaced — both as a map and
/// through the Gloss pipeline that reads it.
library;

import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/mc_text.dart';
import 'package:test/test.dart';

/// The table as it was written by hand in `gloss_text.dart` before the
/// derivation. Do not regenerate this from the source it verifies.
const Map<String, int> _pinned = <String, int>{
  '0': 0x000000,
  '1': 0x0000AA,
  '2': 0x00AA00,
  '3': 0x00AAAA,
  '4': 0xAA0000,
  '5': 0xAA00AA,
  '6': 0xFFAA00,
  '7': 0xAAAAAA,
  '8': 0x555555,
  '9': 0x5555FF,
  'a': 0x55FF55,
  'b': 0x55FFFF,
  'c': 0xFF5555,
  'd': 0xFF55FF,
  'e': 0xFFFF55,
  'f': 0xFFFFFF,
};

int _firstColor(GlossLineRender render) {
  for (final GlossTextPiece piece in render.pieces) {
    if (piece case GlossTextRun(:final span)) return span.color;
  }
  fail('rendered line had no styled run');
}

void main() {
  test('the derived legacy table is exactly the 16 pinned mappings', () {
    expect(mcLegacyColors, _pinned);
    expect(mcLegacyColors.length, 16);
  });

  test('decoration and reset codes name no colour', () {
    for (final String code in <String>['k', 'l', 'm', 'n', 'o', 'r']) {
      expect(mcLegacyColors.containsKey(code), isFalse, reason: code);
    }
  });

  test('every legacy code renders its pinned colour through the pipeline', () {
    _pinned.forEach((String code, int rgb) {
      expect(_firstColor(renderGlossLine('&${code}x')), rgb, reason: code);
    });
  });

  test('the section-sign spelling resolves the same colours', () {
    _pinned.forEach((String code, int rgb) {
      expect(_firstColor(renderGlossLine('§${code}x')), rgb, reason: code);
    });
  });

  test('an uppercase legacy code resolves the same colour', () {
    expect(_firstColor(renderGlossLine('&Ax')), _pinned['a']);
    expect(_firstColor(renderGlossLine('&Fx')), _pinned['f']);
  });

  test('the legacy table agrees with the named colour table', () {
    expect(mcLegacyColors['0'], mcNamedColors['black']);
    expect(mcLegacyColors['6'], mcNamedColors['gold']);
    expect(mcLegacyColors['7'], mcNamedColors['gray']);
    expect(mcLegacyColors['d'], mcNamedColors['light_purple']);
    expect(mcLegacyColors['f'], mcNamedColors['white']);
  });

  test('mcColorCss pads and masks a packed colour', () {
    expect(mcColorCss(0x000000), '#000000');
    expect(mcColorCss(0x55FF55), '#55ff55');
    expect(mcColorCss(0xFF123456), '#123456');
  });
}
