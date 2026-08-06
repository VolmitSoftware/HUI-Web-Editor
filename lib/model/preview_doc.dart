/// Raw DTO mirror of HoloUI's container-preview JSON documents (the format
/// `PreviewDocumentParser` compiles). Every field that the plugin can accept
/// as either a JSON constant or a live expression string is stored exactly as
/// decoded — `num`, `String`, or `bool` — and is never evaluated or defaulted
/// here. Defaulting (e.g. `z` depending on element type, `wellColor` on a
/// slot, `framed` on a card) is the compiler's business, ported in a later
/// task; this file only has to be a lossless, byte-stable mirror of the JSON.
library;

import 'dart:convert';

import 'json_codec.dart';

/// True when [json] has the shape of a preview document (an `elements` list
/// and no `components` key) rather than a `HuiMenu` component document. Not a
/// full validation — just enough to route an imported file to the right
/// decoder.
bool looksLikePreviewDoc(Object? json) {
  if (json is! Map) return false;
  return json['elements'] is List && !json.containsKey('components');
}

HuiPreviewDoc decodeHuiPreviewDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: ${e.message}', r'$');
  }
  return HuiPreviewDoc.fromJson(raw);
}

String encodeHuiPreviewDoc(HuiPreviewDoc doc) => huiWriteJson(doc.toJson());

HuiPreviewDoc cloneHuiPreviewDoc(HuiPreviewDoc doc) =>
    HuiPreviewDoc.fromJson(huiDeepCopy(doc.toJson()));

/// A value or an expression source string that a field accepts verbatim,
/// without evaluation: `num`, `String`, or (for `visible`/`framed`) `bool`.
/// `null` means the key was absent from the document.
typedef HuiRawExpr = Object?;

HuiRawExpr _rawNumberOrExpr(Object? value) =>
    value is num || value is String ? value : null;

HuiRawExpr _rawBoolOrExpr(Object? value) =>
    value is bool || value is String ? value : null;

// ---------------------------------------------------------------------
// Match / Variant (identical raw shape — `VariantDef extends MatchDef` in
// the Java DTO)
// ---------------------------------------------------------------------

const Set<String> _matchKnown = <String>{
  'blocks',
  'entities',
  'special',
  'priority',
  'vars',
};

class _MatchFields {
  final List<String> blocks;
  final List<String> entities;
  final String? special;
  final int? priority;
  final Map<String, dynamic> vars;
  final Map<String, dynamic> extras;
  final Set<String> absentKeys;

  const _MatchFields(
    this.blocks,
    this.entities,
    this.special,
    this.priority,
    this.vars,
    this.extras,
    this.absentKeys,
  );
}

_MatchFields _readMatchFields(Map<String, dynamic> map) {
  final Map<String, dynamic> vars = map['vars'] is Map
      ? huiReadObject(map['vars'], r'$.vars')
      : const <String, dynamic>{};
  return _MatchFields(
    huiReadStringList(map['blocks']),
    huiReadStringList(map['entities']),
    map['special'] is String ? map['special'] as String : null,
    map['priority'] is num ? (map['priority'] as num).toInt() : null,
    huiDeepCopyMap(vars),
    huiCollectExtras(map, _matchKnown),
    <String>{if (map['priority'] == null) 'priority'},
  );
}

Map<String, dynamic> _matchToJson(
  List<String> blocks,
  List<String> entities,
  String? special,
  int? priority,
  Map<String, dynamic> vars,
  Map<String, dynamic> extras,
) {
  final Map<String, dynamic> out = <String, dynamic>{};
  if (blocks.isNotEmpty) out['blocks'] = List<String>.of(blocks);
  if (entities.isNotEmpty) out['entities'] = List<String>.of(entities);
  if (special != null) out['special'] = special;
  if (priority != null) out['priority'] = priority;
  if (vars.isNotEmpty) out['vars'] = huiDeepCopyMap(vars);
  return huiMergeExtras(out, extras);
}

/// Match criteria: `HuiPreviewDoc.match` and each entry of `variants` share
/// this exact JSON shape (the Java DTO literally subclasses one into the
/// other). `special`/`priority` are only meaningful on the document's own
/// top-level match, but are still preserved verbatim if a variant carries
/// them, since the model never drops a key the parser would still bind.
class HuiPreviewMatch {
  List<String> blocks;
  List<String> entities;
  String? special;
  int? priority;
  Map<String, dynamic> vars;
  Map<String, dynamic> extras = <String, dynamic>{};

  /// Keys that had a compiler-side default applied downstream (never here)
  /// because the JSON omitted them. Never serialized.
  Set<String> absentKeys = <String>{};

  HuiPreviewMatch({
    List<String>? blocks,
    List<String>? entities,
    this.special,
    this.priority,
    Map<String, dynamic>? vars,
  }) : blocks = blocks ?? <String>[],
       entities = entities ?? <String>[],
       vars = vars ?? <String, dynamic>{};

  HuiPreviewMatch copy() =>
      HuiPreviewMatch(
          blocks: List<String>.of(blocks),
          entities: List<String>.of(entities),
          special: special,
          priority: priority,
          vars: huiDeepCopyMap(vars),
        )
        ..extras = huiDeepCopyMap(extras)
        ..absentKeys = Set<String>.of(absentKeys);

  Map<String, dynamic> toJson() =>
      _matchToJson(blocks, entities, special, priority, vars, extras);

  static HuiPreviewMatch fromJson(Object? raw) {
    if (raw == null) return HuiPreviewMatch();
    final Map<String, dynamic> map = huiReadObject(raw, r'$.match');
    final _MatchFields f = _readMatchFields(map);
    return HuiPreviewMatch(
        blocks: f.blocks,
        entities: f.entities,
        special: f.special,
        priority: f.priority,
        vars: f.vars,
      )
      ..extras = f.extras
      ..absentKeys = f.absentKeys;
  }
}

/// One entry of `HuiPreviewDoc.variants`: an alternate `vars` set (and
/// optionally more `blocks`/`entities`) for the same element templates.
class HuiPreviewVariant {
  List<String> blocks;
  List<String> entities;
  String? special;
  int? priority;
  Map<String, dynamic> vars;
  Map<String, dynamic> extras = <String, dynamic>{};
  Set<String> absentKeys = <String>{};

  HuiPreviewVariant({
    List<String>? blocks,
    List<String>? entities,
    this.special,
    this.priority,
    Map<String, dynamic>? vars,
  }) : blocks = blocks ?? <String>[],
       entities = entities ?? <String>[],
       vars = vars ?? <String, dynamic>{};

  HuiPreviewVariant copy() =>
      HuiPreviewVariant(
          blocks: List<String>.of(blocks),
          entities: List<String>.of(entities),
          special: special,
          priority: priority,
          vars: huiDeepCopyMap(vars),
        )
        ..extras = huiDeepCopyMap(extras)
        ..absentKeys = Set<String>.of(absentKeys);

  Map<String, dynamic> toJson() =>
      _matchToJson(blocks, entities, special, priority, vars, extras);

  static HuiPreviewVariant fromJson(Object? raw, {required String path}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final _MatchFields f = _readMatchFields(map);
    return HuiPreviewVariant(
        blocks: f.blocks,
        entities: f.entities,
        special: f.special,
        priority: f.priority,
        vars: f.vars,
      )
      ..extras = f.extras
      ..absentKeys = f.absentKeys;
  }
}

// ---------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------

const Set<String> _cardKnown = <String>{
  'framed',
  'title',
  'accent',
  'minHalfWidth',
};

/// The chrome drawn around the elements. `null` at the `HuiPreviewDoc` level
/// means the document declared no card object at all (bare content); this is
/// distinct from a card whose fields are all absent, which the parser still
/// draws with its defaults.
class HuiPreviewCard {
  /// Raw `bool` or expression `String`. `null` means absent (parser default
  /// `true`).
  HuiRawExpr framed;
  String? title;
  String? accent;
  int? minHalfWidth;
  Map<String, dynamic> extras = <String, dynamic>{};
  Set<String> absentKeys = <String>{};

  HuiPreviewCard({this.framed, this.title, this.accent, this.minHalfWidth});

  HuiPreviewCard copy() =>
      HuiPreviewCard(
          framed: huiDeepCopy(framed),
          title: title,
          accent: accent,
          minHalfWidth: minHalfWidth,
        )
        ..extras = huiDeepCopyMap(extras)
        ..absentKeys = Set<String>.of(absentKeys);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    if (framed != null) out['framed'] = framed;
    if (title != null) out['title'] = title;
    if (accent != null) out['accent'] = accent;
    if (minHalfWidth != null) out['minHalfWidth'] = minHalfWidth;
    return huiMergeExtras(out, extras);
  }

  static HuiPreviewCard? fromJson(Object? raw) {
    if (raw == null) return null;
    final Map<String, dynamic> map = huiReadObject(raw, r'$.card');
    return HuiPreviewCard(
        framed: _rawBoolOrExpr(map['framed']),
        title: map['title'] is String ? map['title'] as String : null,
        accent: map['accent'] is String ? map['accent'] as String : null,
        minHalfWidth: map['minHalfWidth'] is num
            ? (map['minHalfWidth'] as num).toInt()
            : null,
      )
      ..extras = huiCollectExtras(map, _cardKnown)
      ..absentKeys = <String>{
        if (map['framed'] == null) 'framed',
        if (map['minHalfWidth'] == null) 'minHalfWidth',
      };
  }
}

// ---------------------------------------------------------------------
// Repeat
// ---------------------------------------------------------------------

const Set<String> _repeatKnown = <String>{'count', 'var'};

/// Loop directive on an element: emit it `count` times with the index bound
/// to `varName` (JSON key `var`; renamed because `var` is a Dart keyword).
class HuiPreviewRepeat {
  /// Raw `num` or expression `String`. Required by the format; `null` only
  /// happens on a malformed document.
  HuiRawExpr count;

  /// `null` means absent (parser default `'i'`).
  String? varName;
  Map<String, dynamic> extras = <String, dynamic>{};
  Set<String> absentKeys = <String>{};

  HuiPreviewRepeat({this.count, this.varName});

  HuiPreviewRepeat copy() =>
      HuiPreviewRepeat(count: huiDeepCopy(count), varName: varName)
        ..extras = huiDeepCopyMap(extras)
        ..absentKeys = Set<String>.of(absentKeys);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    if (count != null) out['count'] = count;
    if (varName != null) out['var'] = varName;
    return huiMergeExtras(out, extras);
  }

  static HuiPreviewRepeat fromJson(Object? raw, {required String path}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return HuiPreviewRepeat(
        count: _rawNumberOrExpr(map['count']),
        varName: map['var'] is String ? map['var'] as String : null,
      )
      ..extras = huiCollectExtras(map, _repeatKnown)
      ..absentKeys = <String>{if (map['var'] == null) 'var'};
  }
}

// ---------------------------------------------------------------------
// Element
// ---------------------------------------------------------------------

/// The four element types, case-sensitive, in the order the inspector's "add"
/// menu lists them. Mirrors `PreviewDocumentParser.ELEMENT_TYPES`.
const List<String> previewElementTypes = <String>[
  'panel',
  'cell',
  'slot',
  'label',
];

const Set<String> _elementKnown = <String>{
  'type',
  'x',
  'y',
  'z',
  'width',
  'height',
  'size',
  'color',
  'wellColor',
  'index',
  'background',
  'text',
  'visible',
  'repeat',
};

/// One drawn element (`panel`, `cell`, `slot`, or `label`), in paint order. A
/// single flat DTO for every type — mirroring `ElementDef`, not a sealed
/// hierarchy like `HuiComponentData` — since the JSON shape itself is flat
/// regardless of `type`; which fields are actually meaningful for a given
/// type is the compiler's concern.
class HuiPreviewElement {
  String type;
  HuiRawExpr x;
  HuiRawExpr y;

  /// `null` means absent: the per-type default (1/4/6 for panel/cell&slot/
  /// label) is the compiler's business, not the model's.
  HuiRawExpr z;
  HuiRawExpr width;
  HuiRawExpr height;
  HuiRawExpr size;
  HuiRawExpr color;
  HuiRawExpr wellColor;
  HuiRawExpr index;
  HuiRawExpr background;

  /// Always a plain expression source string in the format (never a JSON
  /// number/bool), required for type `label`.
  String? text;
  HuiRawExpr visible;
  HuiPreviewRepeat? repeat;
  Map<String, dynamic> extras = <String, dynamic>{};
  Set<String> absentKeys = <String>{};

  HuiPreviewElement(
    this.type, {
    this.x,
    this.y,
    this.z,
    this.width,
    this.height,
    this.size,
    this.color,
    this.wellColor,
    this.index,
    this.background,
    this.text,
    this.visible,
    this.repeat,
  });

  HuiPreviewElement copy() =>
      HuiPreviewElement(
          type,
          x: huiDeepCopy(x),
          y: huiDeepCopy(y),
          z: huiDeepCopy(z),
          width: huiDeepCopy(width),
          height: huiDeepCopy(height),
          size: huiDeepCopy(size),
          color: huiDeepCopy(color),
          wellColor: huiDeepCopy(wellColor),
          index: huiDeepCopy(index),
          background: huiDeepCopy(background),
          text: text,
          visible: huiDeepCopy(visible),
          repeat: repeat?.copy(),
        )
        ..extras = huiDeepCopyMap(extras)
        ..absentKeys = Set<String>.of(absentKeys);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{'type': type};
    if (x != null) out['x'] = x;
    if (y != null) out['y'] = y;
    if (z != null) out['z'] = z;
    if (width != null) out['width'] = width;
    if (height != null) out['height'] = height;
    if (size != null) out['size'] = size;
    if (color != null) out['color'] = color;
    if (wellColor != null) out['wellColor'] = wellColor;
    if (index != null) out['index'] = index;
    if (background != null) out['background'] = background;
    if (text != null) out['text'] = text;
    if (visible != null) out['visible'] = visible;
    if (repeat != null) out['repeat'] = repeat!.toJson();
    return huiMergeExtras(out, extras);
  }

  static HuiPreviewElement fromJson(Object? raw, {required String path}) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final Object? repeatRaw = map['repeat'];
    return HuiPreviewElement(
        huiReadString(map, 'type'),
        x: _rawNumberOrExpr(map['x']),
        y: _rawNumberOrExpr(map['y']),
        z: _rawNumberOrExpr(map['z']),
        width: _rawNumberOrExpr(map['width']),
        height: _rawNumberOrExpr(map['height']),
        size: _rawNumberOrExpr(map['size']),
        color: _rawNumberOrExpr(map['color']),
        wellColor: _rawNumberOrExpr(map['wellColor']),
        index: _rawNumberOrExpr(map['index']),
        background: _rawNumberOrExpr(map['background']),
        text: map['text'] is String ? map['text'] as String : null,
        visible: _rawBoolOrExpr(map['visible']),
        repeat: repeatRaw == null
            ? null
            : HuiPreviewRepeat.fromJson(repeatRaw, path: '$path.repeat'),
      )
      ..extras = huiCollectExtras(map, _elementKnown)
      ..absentKeys = <String>{
        if (map['z'] == null) 'z',
        if (map['wellColor'] == null) 'wellColor',
        if (map['background'] == null) 'background',
        if (map['visible'] == null) 'visible',
      };
  }
}

// ---------------------------------------------------------------------
// Document
// ---------------------------------------------------------------------

const Set<String> _docKnown = <String>{'match', 'variants', 'card', 'elements'};

/// Root of one container-preview JSON document.
class HuiPreviewDoc {
  HuiPreviewMatch match;
  List<HuiPreviewVariant> variants;
  HuiPreviewCard? card;
  List<HuiPreviewElement> elements;
  Map<String, dynamic> extras = <String, dynamic>{};

  HuiPreviewDoc({
    HuiPreviewMatch? match,
    List<HuiPreviewVariant>? variants,
    this.card,
    List<HuiPreviewElement>? elements,
  }) : match = match ?? HuiPreviewMatch(),
       variants = variants ?? <HuiPreviewVariant>[],
       elements = elements ?? <HuiPreviewElement>[];

  HuiPreviewDoc copy() => HuiPreviewDoc(
    match: match.copy(),
    variants: variants.map((HuiPreviewVariant v) => v.copy()).toList(),
    card: card?.copy(),
    elements: elements.map((HuiPreviewElement e) => e.copy()).toList(),
  )..extras = huiDeepCopyMap(extras);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{};
    final Map<String, dynamic> matchJson = match.toJson();
    if (matchJson.isNotEmpty) out['match'] = matchJson;
    if (variants.isNotEmpty) {
      out['variants'] = variants
          .map((HuiPreviewVariant v) => v.toJson())
          .toList();
    }
    if (card != null) out['card'] = card!.toJson();
    // Always emitted (even empty), unlike the optional fields above: it is
    // the field `looksLikePreviewDoc` keys off of, so a round-tripped
    // document must keep detecting as one.
    out['elements'] = elements
        .map((HuiPreviewElement e) => e.toJson())
        .toList();
    return huiMergeExtras(out, extras);
  }

  static HuiPreviewDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    final List<Object?> rawVariants = huiReadList(map['variants']);
    final List<HuiPreviewVariant> variants = <HuiPreviewVariant>[];
    for (int i = 0; i < rawVariants.length; i++) {
      final Object? entry = rawVariants[i];
      if (entry == null) continue;
      variants.add(HuiPreviewVariant.fromJson(entry, path: 'variants[$i]'));
    }
    final List<Object?> rawElements = huiReadList(map['elements']);
    final List<HuiPreviewElement> elements = <HuiPreviewElement>[];
    for (int i = 0; i < rawElements.length; i++) {
      final Object? entry = rawElements[i];
      if (entry == null) continue;
      elements.add(HuiPreviewElement.fromJson(entry, path: 'elements[$i]'));
    }
    return HuiPreviewDoc(
      match: HuiPreviewMatch.fromJson(map['match']),
      variants: variants,
      card: HuiPreviewCard.fromJson(map['card']),
      elements: elements,
    )..extras = huiCollectExtras(map, _docKnown);
  }
}
