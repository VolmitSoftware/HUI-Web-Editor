/// The colour picker for a preview field whose value folds to a constant
/// unsigned ARGB number: every `color`/`wellColor`/`background`/`accent` field,
/// and a `vars` entry written as a `#RRGGBB`-style literal.
///
/// It returns null (draw nothing) for anything that is not currently a
/// constant colour — a live expression like `mod(...) == 0 ? vars.a : vars.b`
/// has no one swatch to show and nothing a picker could safely overwrite
/// without destroying the expression. The field's own text stays the source of
/// truth; this is only ever a bonus.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../logic/preview_doc_validation.dart';
import '../common/hui_color_field.dart';

/// `#AARRGGBB` for a value that folds to a constant colour, else null.
String? _constantColorHex(Object? raw) {
  final double? folded = previewFoldConstantNumber(raw);
  if (folded == null || !folded.isFinite) return null;
  final int bits = folded.toInt() & 0xFFFFFFFF;
  return '#${bits.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// The swatch, opened as a native colour picker. [onPicked] receives a
/// complete `#AARRGGBB` literal with the field's existing alpha preserved, so
/// choosing a colour never quietly makes a transparent well opaque.
Widget? previewColorPicker(
  Object? raw, {
  required void Function(String hex) onPicked,
  String label = 'colour',
}) {
  final String? hex = _constantColorHex(raw);
  if (hex == null) return null;
  return HuiColorSwatch(
    value: hex,
    size: 18,
    label: 'Pick a $label',
    onPicked: (String picked) =>
        onPicked(huiApplyPickedColor(picked, hex, HuiColorFormat.argb)),
  );
}
