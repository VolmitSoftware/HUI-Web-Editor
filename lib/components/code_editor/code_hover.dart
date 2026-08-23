/// Hit-testing a pointer against the highlight layer, and what a key means.
///
/// The pointer never lands on the `<pre>`: a transparent textarea covers it
/// edge to edge, so the coloured spans underneath receive no pointer events at
/// all and `:hover` on them is dead. The hover is therefore hit-tested, not
/// listened for — the widget reads each key span's real
/// `getBoundingClientRect()` once per document, converts them to the pre's own
/// coordinate space so scrolling cannot invalidate them, and asks
/// [huiCodeHoverHit] which one a mousemove over the textarea falls inside.
///
/// Measured boxes rather than character arithmetic on purpose: the boxes come
/// from the browser's own layout of the very glyphs the user sees, so a wide
/// glyph, a ligature or a fallback font cannot slide the answer off the key.
///
/// [huiCodeKeyDoc] is the second half: given the source offset the hit resolves
/// to, it walks the kind's JSON-path model and hands back the same title, body
/// and citation the inspector's help popovers show, so the two surfaces can
/// never explain a field differently.
library;

import '../../config/field_docs.dart';
import '../../l10n/hui_localizations.dart';
import '../../logic/json_schema.dart';
import 'json_caret.dart';

/// One key token's box, in the highlight layer's own coordinates: relative to
/// the `<pre>` border box, so it survives every scroll of `.hui-code-body`.
final class HuiCodeKeyBox {
  const HuiCodeKeyBox({
    required this.offset,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Source offset of the key token's opening quote.
  final int offset;

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool contains(double x, double y) =>
      x >= left && x < right && y >= top && y < bottom;
}

/// The source offset of the key box under ([x], [y]), or null.
///
/// Boxes are tested in document order and the first containing one wins; they
/// never overlap, because two key tokens cannot share a glyph.
int? huiCodeHoverHit(List<HuiCodeKeyBox> boxes, double x, double y) {
  for (final HuiCodeKeyBox box in boxes) {
    if (box.contains(x, y)) return box.offset;
  }
  return null;
}

/// The box under ([x], [y]) itself, for positioning the card against the key.
HuiCodeKeyBox? huiCodeHoverBox(List<HuiCodeKeyBox> boxes, double x, double y) {
  for (final HuiCodeKeyBox box in boxes) {
    if (box.contains(x, y)) return box;
  }
  return null;
}

/// What one key explains, ready to render.
final class HuiCodeKeyDoc {
  const HuiCodeKeyDoc({
    required this.path,
    required this.title,
    required this.body,
    required this.detail,
    this.citation,
  });

  /// `$.components[0].data.icon.style.billboard` — the spelling `HuiIssue`
  /// uses, so a hover and a validation row name the same node the same way.
  final String path;

  final String title;
  final String body;

  /// Type, default and accepted values, on one line. Empty when the model has
  /// nothing to add beyond the body.
  final String detail;

  /// The Gloss source line or schema pointer the body is read from.
  final String? citation;
}

/// How many accepted values a hover card prints before it gives up and counts
/// the rest. The entity icon accepts ninety-odd keys; a tooltip is not a list.
const int huiCodeHoverValueLimit = 6;

/// The explanation for the key token covering [offset], or null when nothing
/// there is a key.
///
/// A key the model does not know is not an error and does not return null: the
/// models preserve unknown keys through `extras`, so the card says so instead
/// of pretending the key is a mistake.
HuiCodeKeyDoc? huiCodeKeyDoc({
  required GlossJsonObject root,
  required String source,
  required int offset,
}) {
  final JsonKeyHit? hit = jsonKeyAt(source, offset);
  if (hit == null) return null;
  final String path = glossJsonPathText(hit.path);
  final GlossJsonField? field = glossJsonFieldAt(root, hit.path);
  if (field == null) {
    final GlossJsonNode? container = glossJsonNodeAt(
      root,
      hit.path.sublist(0, hit.path.length - 1),
    );
    final String? openSummary = container is GlossJsonObject
        ? container.openKeySummary
        : null;
    final String body = openSummary == null
        ? huiText(
            'Gloss does not read a key by this name here. The editor keeps it '
            'through every round trip rather than dropping it, so a key a '
            'newer plugin build writes survives being edited.',
          )
        : huiText(openSummary);
    return HuiCodeKeyDoc(path: path, title: hit.key, body: body, detail: '');
  }
  final HuiFieldDoc? doc = field.docKey == null
      ? null
      : huiFieldDoc(field.docKey!);
  return HuiCodeKeyDoc(
    path: path,
    title: doc?.title ?? huiText(field.title),
    body: doc?.body ?? huiText(field.summary),
    detail: huiCodeFieldDetail(field),
    citation: doc?.citation,
  );
}

/// `boolean · default true` / `string · one of ascend, descend, …`.
String huiCodeFieldDetail(GlossJsonField field) {
  final List<String> parts = <String>[huiText(field.type.label)];
  if (field.defaultLiteral != null) {
    parts.add(
      huiText('default {value}', <String, Object?>{
        'value': field.defaultLiteral,
      }),
    );
  }
  if (field.values.isNotEmpty) {
    final List<String> shown = <String>[
      for (final GlossJsonValue value in field.values.take(
        huiCodeHoverValueLimit,
      ))
        value.literal,
    ];
    final int rest = field.values.length - shown.length;
    parts.add(
      rest > 0
          ? huiText('one of {values}, and {count} more', <String, Object?>{
              'values': shown.join(', '),
              'count': rest,
            })
          : huiText('one of {values}', <String, Object?>{
              'values': shown.join(', '),
            }),
    );
  }
  return parts.join(' · ');
}
