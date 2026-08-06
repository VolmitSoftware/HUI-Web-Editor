/// Small color preview for a field whose value folds to a constant unsigned
/// ARGB number: every `color`/`wellColor`/`background`/`accent` field, and a
/// `vars` entry written as a `#RRGGBB`-style literal.
///
/// Returns null (draw nothing) for anything that is not currently a constant
/// color — a live expression like `mod(...) == 0 ? vars.a : vars.b` has no one
/// swatch to show, and that is fine: the field's own text is the source of
/// truth, this is only ever a bonus.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/preview_doc_validation.dart';

Widget? previewColorSwatch(Object? raw) {
  final double? folded = previewFoldConstantNumber(raw);
  if (folded == null || !folded.isFinite) return null;
  final int bits = folded.toInt() & 0xFFFFFFFF;
  final int a = (bits >> 24) & 0xFF;
  final int r = (bits >> 16) & 0xFF;
  final int g = (bits >> 8) & 0xFF;
  final int b = bits & 0xFF;
  return dom.span(
    styles: dom.Styles(
      raw: <String, String>{
        'display': 'inline-block',
        'width': '18px',
        'height': '18px',
        'flex': '0 0 auto',
        'border-radius': '4px',
        'border': '1px solid var(--hui-border)',
        'background': 'rgba($r, $g, $b, ${(a / 255).toStringAsFixed(3)})',
        // A checkerboard shows through low alpha instead of reading as a flat
        // colour that happens to look washed out.
        'background-image': a == 255
            ? 'none'
            : 'linear-gradient(45deg, var(--hui-border-soft) 25%, transparent '
                '25%), linear-gradient(-45deg, var(--hui-border-soft) 25%, '
                'transparent 25%), linear-gradient(45deg, transparent 75%, '
                'var(--hui-border-soft) 75%), linear-gradient(-45deg, '
                'transparent 75%, var(--hui-border-soft) 75%)',
        'background-size': '6px 6px',
        'background-position': '0 0, 0 3px, 3px -3px, -3px 0px',
      },
    ),
    attributes: const <String, String>{'aria-hidden': 'true'},
    const <Widget>[],
  );
}
