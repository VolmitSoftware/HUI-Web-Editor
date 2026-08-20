/// The pure halves of the two controls the inspector overhaul added: the
/// colour field's hex handling and the duration field's readout.
///
/// Both are the parts that can be wrong without looking wrong — a picker that
/// drops the alpha byte turns a transparent text background opaque, and a
/// readout that divides by the wrong unit teaches the tick/millisecond
/// confusion it exists to remove.
library;

import 'package:gloss_editor/components/common/hui_color_field.dart';
import 'package:gloss_editor/components/common/hui_duration_field.dart';
import 'package:test/test.dart';

void main() {
  group('huiParseHexColor', () {
    test('reads eight digits as alpha, red, green, blue', () {
      final HuiColorParts parts = huiParseHexColor('#80102030')!;
      expect(parts.a, 0x80);
      expect(parts.r, 0x10);
      expect(parts.g, 0x20);
      expect(parts.b, 0x30);
    });

    test('treats six digits as fully opaque', () {
      expect(huiParseHexColor('#102030')!.a, 255);
    });

    test('expands the three-digit shorthand', () {
      final HuiColorParts parts = huiParseHexColor('#abc')!;
      expect(parts.r, 0xAA);
      expect(parts.g, 0xBB);
      expect(parts.b, 0xCC);
    });

    test('accepts a value with no leading hash', () {
      expect(huiParseHexColor('FF0000')!.r, 255);
    });

    test('returns null for anything that is not a colour literal', () {
      for (final String? raw in <String?>[
        null,
        '',
        'vars.accent',
        '#12345',
        "i < bees ? vars.a : vars.b",
        '#GGGGGG',
      ]) {
        expect(huiParseHexColor(raw), isNull, reason: '$raw');
      }
    });

    test('renders the six digits a native colour input understands', () {
      expect(huiParseHexColor('#80102030')!.rgbHex, '#102030');
    });

    test('carries the alpha into the CSS it paints the swatch with', () {
      expect(huiParseHexColor('#00102030')!.css, 'rgba(16, 32, 48, 0.000)');
      expect(huiParseHexColor('#FF102030')!.css, 'rgba(16, 32, 48, 1.000)');
    });
  });

  group('huiApplyPickedColor', () {
    test('keeps the alpha the field already had', () {
      expect(
        huiApplyPickedColor('#112233', '#40FFFFFF', HuiColorFormat.argb),
        '#40112233',
      );
    });

    test('assumes opaque when the previous value carried no alpha', () {
      expect(
        huiApplyPickedColor('#112233', 'vars.accent', HuiColorFormat.argb),
        '#FF112233',
      );
    });

    test('emits six digits for a field that stores six', () {
      expect(
        huiApplyPickedColor('#112233', '#ffffff', HuiColorFormat.rgb),
        '#112233',
      );
    });

    test('leaves the value alone when the pick is unreadable', () {
      expect(
        huiApplyPickedColor('not a colour', '#40FFFFFF', HuiColorFormat.argb),
        '#40FFFFFF',
      );
    });
  });

  group('huiFormatDuration', () {
    test('reads ticks at 50 ms each', () {
      expect(huiFormatDuration(4, HuiDurationUnit.ticks), '200ms');
      expect(huiFormatDuration(20, HuiDurationUnit.ticks), '1s');
      expect(huiFormatDuration(1200, HuiDurationUnit.ticks), '60s');
    });

    test('reads milliseconds as themselves', () {
      expect(huiFormatDuration(250, HuiDurationUnit.milliseconds), '250ms');
      expect(huiFormatDuration(1500, HuiDurationUnit.milliseconds), '1.5s');
      expect(huiFormatDuration(60000, HuiDurationUnit.milliseconds), '60s');
    });

    test('says instant rather than 0s, because that is what 0 means', () {
      expect(huiFormatDuration(0, HuiDurationUnit.ticks), 'instant');
      expect(huiFormatDuration(0, HuiDurationUnit.milliseconds), 'instant');
    });

    test('never leaves a trailing zero on the seconds reading', () {
      expect(huiFormatDuration(2000, HuiDurationUnit.milliseconds), '2s');
      expect(huiFormatDuration(2500, HuiDurationUnit.milliseconds), '2.5s');
      expect(huiFormatDuration(12500, HuiDurationUnit.milliseconds), '12.5s');
    });

    test('the suffix names the unit the document stores', () {
      expect(HuiDurationUnit.ticks.suffix, 'ticks');
      expect(HuiDurationUnit.milliseconds.suffix, 'ms');
    });
  });
}
