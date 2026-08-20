/// Colour entry: a native picker drawn as the swatch, plus the hex text the
/// document actually stores.
///
/// Every colour in a Gloss document is a hex string, and until this widget the
/// editor made you type all eight digits by hand with no way to see what you
/// were choosing. The text field stays the source of truth — Gloss accepts
/// values the picker cannot express (an alpha byte, and in the preview
/// documents a whole expression), so the picker only ever writes the RGB half
/// and leaves the rest of the string alone.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import 'class_names.dart';

/// Whether the stored text carries an alpha byte.
enum HuiColorFormat {
  /// `#RRGGBB`, six digits. The bubble shimmer band.
  rgb,

  /// `#AARRGGBB`, eight digits. Every display-style colour.
  argb,
}

/// One parsed colour. Alpha is 255 for a source that carried none.
class HuiColorParts {
  const HuiColorParts(this.a, this.r, this.g, this.b);

  final int a;
  final int r;
  final int g;
  final int b;

  /// The six digits a native colour input understands.
  String get rgbHex => '#${_hex(r)}${_hex(g)}${_hex(b)}';

  /// CSS, with the alpha applied — the swatch has to show a transparent
  /// colour as transparent rather than as a washed-out solid.
  String get css => 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(3)})';

  static String _hex(int value) =>
      value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// Parses `#RGB`, `#RRGGBB` and `#AARRGGBB`, with or without the leading hash.
/// Anything else is null: an expression, a placeholder, a half-typed value.
HuiColorParts? huiParseHexColor(String? raw) {
  if (raw == null) return null;
  final String text = raw.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(text)) return null;
  switch (text.length) {
    case 3:
      final int r = int.parse(text[0], radix: 16);
      final int g = int.parse(text[1], radix: 16);
      final int b = int.parse(text[2], radix: 16);
      return HuiColorParts(255, r * 17, g * 17, b * 17);
    case 6:
      return HuiColorParts(
        255,
        int.parse(text.substring(0, 2), radix: 16),
        int.parse(text.substring(2, 4), radix: 16),
        int.parse(text.substring(4, 6), radix: 16),
      );
    case 8:
      return HuiColorParts(
        int.parse(text.substring(0, 2), radix: 16),
        int.parse(text.substring(2, 4), radix: 16),
        int.parse(text.substring(4, 6), radix: 16),
        int.parse(text.substring(6, 8), radix: 16),
      );
    default:
      return null;
  }
}

/// The picked RGB re-joined to the alpha the field already had, so choosing a
/// colour never quietly makes a transparent background opaque.
String huiApplyPickedColor(
  String picked,
  String? previous,
  HuiColorFormat format,
) {
  final HuiColorParts? next = huiParseHexColor(picked);
  if (next == null) return previous ?? picked;
  if (format == HuiColorFormat.rgb) return next.rgbHex;
  final HuiColorParts? current = huiParseHexColor(previous);
  final int alpha = current?.a ?? 255;
  return '#${HuiColorParts._hex(alpha)}'
      '${HuiColorParts._hex(next.r)}'
      '${HuiColorParts._hex(next.g)}'
      '${HuiColorParts._hex(next.b)}';
}

/// The swatch. With [onPicked] it is a native colour input wearing the swatch
/// as its whole surface; without one it is the read-only chip it always was.
class HuiColorSwatch extends StatelessWidget {
  const HuiColorSwatch({
    required this.value,
    this.onPicked,
    this.label = 'Pick a colour',
    this.size = 22,
    this.classes = '',
    super.key,
  });

  /// Any colour text. Unparseable values render the empty swatch rather than
  /// disappearing, so the row keeps its width while the user is typing.
  final String? value;

  /// Receives the six-digit hex the picker produced, already recombined with
  /// the existing alpha by [huiApplyPickedColor].
  final void Function(String hex)? onPicked;
  final String label;
  final num size;
  final String classes;

  @override
  Widget build(BuildContext context) {
    final HuiColorParts? parts = huiParseHexColor(value);
    final Map<String, String> box = <String, String>{
      'display': 'block',
      'width': '${size}px',
      'height': '${size}px',
      'flex': '0 0 auto',
      'padding': '0',
      'border': '1px solid var(--hui-border, var(--border))',
      'border-radius': '0',
      'background-color': parts?.css ?? 'transparent',
    };
    if (parts == null || parts.a != 255) {
      // The checkerboard reads as "transparent" where a flat fill would read
      // as "a colour that happens to look wrong".
      box['background-image'] =
          'linear-gradient(45deg, var(--hui-border-soft) 25%, transparent 25%),'
          ' linear-gradient(-45deg, var(--hui-border-soft) 25%, transparent'
          ' 25%), linear-gradient(45deg, transparent 75%,'
          ' var(--hui-border-soft) 75%), linear-gradient(-45deg, transparent'
          ' 75%, var(--hui-border-soft) 75%)';
      box['background-size'] = '6px 6px';
      box['background-position'] = '0 0, 0 3px, 3px -3px, -3px 0px';
    }

    final void Function(String hex)? picked = onPicked;
    if (picked == null) {
      return dom.span(
        classes: classNames(<String?>['hui-color-swatch', classes]),
        attributes: const <String, String>{'aria-hidden': 'true'},
        styles: dom.Styles(raw: box),
        const <Widget>[],
      );
    }
    return ArcaneTooltip(
      text: label,
      child: dom.input<dom.Color>(
        type: dom.InputType.color,
        classes: classNames(<String?>[
          'hui-color-swatch',
          'is-pickable',
          classes,
        ]),
        // The native control paints its own preview inside the box; the CSS
        // module strips that padding so the whole element is the colour.
        //
        // Lowercase deliberately: the browser's value sanitizer lowercases
        // whatever it is given, so an uppercase attribute would differ from
        // the property on every rebuild and be rewritten each time.
        value: (parts?.rgbHex ?? '#000000').toLowerCase(),
        // A `color` input is the one type whose event value jaspr decodes into
        // a `Color` rather than a string (`events.dart:79`), so the type
        // argument has to say so — `input<String>` throws on the first pick.
        onInput: (dom.Color next) => picked(next.value),
        styles: dom.Styles(raw: <String, String>{...box, 'cursor': 'pointer'}),
        attributes: <String, String>{'aria-label': label},
      ),
    );
  }
}

/// Swatch, picker and hex text on one row.
class HuiColorField extends StatelessWidget {
  const HuiColorField({
    required this.value,
    required this.onChanged,
    this.format = HuiColorFormat.argb,
    this.placeholder,
    this.label = 'colour',
    this.disabled = false,
    this.classes = '',
    super.key,
  });

  /// The document's own text, passed through untouched.
  final String value;
  final void Function(String value) onChanged;
  final HuiColorFormat format;
  final String? placeholder;

  /// Used in the picker's accessible name, e.g. `Pick a glow colour`.
  final String label;
  final bool disabled;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>['hui-color-field', classes]),
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '8px',
        'min-width': '0',
      },
    ),
    <Widget>[
      HuiColorSwatch(
        value: value,
        label: 'Pick a $label',
        onPicked: disabled
            ? null
            : (String picked) =>
                  onChanged(huiApplyPickedColor(picked, value, format)),
      ),
      dom.div(
        styles: const dom.Styles(
          raw: <String, String>{'flex': '1 1 auto', 'min-width': '0'},
        ),
        <Widget>[
          TextInput(
            value: value,
            size: ComponentSize.sm,
            fullWidth: true,
            disabled: disabled,
            placeholder:
                placeholder ??
                (format == HuiColorFormat.argb ? '#FFFFFFFF' : '#FFFFFF'),
            onInput: onChanged,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
        ],
      ),
    ],
  );
}
