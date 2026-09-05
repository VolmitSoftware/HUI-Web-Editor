/// Resolved, DOM-free description of one container-preview frame.
///
/// The editor's twin of `CompiledPreviewDocument.build` plus `CardFramer`: a
/// [HuiPreviewDoc] and one [PreviewSim] in, a flat list of positioned
/// [CardItem]s out. The painter and the inspector both consume this, which is
/// the only way the two stay in agreement about what is on screen — the same
/// contract [canvas_scene.dart](canvas_scene.dart) holds for the component
/// editor.
///
/// Coordinates are the document's own: pixels, origin at the card centre, `y`
/// growing UPWARDS, exactly as the plugin's `PreviewElement` carries them and
/// exactly as the golden snapshots record them. Flipping for a screen is the
/// painter's business, not this pass's.
///
/// ## Build semantics
///
/// Ported field for field from `CompiledPreviewDocument`:
///
///   * Elements expand in declaration order. A `repeat` emits one instance per
///     index with the loop variable bound to that index; the count is clamped
///     at [previewMaxRepeatCount] and the whole build shares a
///     [previewMaxTotalTemplates] budget that counts ATTEMPTS, so a document of
///     invisible elements still costs a bounded amount of work.
///   * `visible` is evaluated once per instance, before anything else.
///   * A failure never takes the frame down. An element whose structural
///     expressions fail is skipped and the rest of the document still renders;
///     a cell colour that fails renders transparent and a label text that fails
///     renders empty. Every failure is handed to the `onError` sink.
///
/// The plugin distinguishes build-once fields (positions, sizes, `visible`,
/// panel and well colours, the card's accent and title) from the two it keeps
/// live behind suppliers (`cell.color`, `label.text`). That distinction is a
/// render-loop optimisation there: the renderer polls the suppliers every four
/// ticks without rebuilding. The editor rebuilds the whole scene on every
/// simulation tick instead, so everything is evaluated on every build — which
/// produces the same values, because the plugin's suppliers capture the scope
/// they were built under and the editor re-derives that scope identically. What
/// still holds WITHIN one build is that every field is evaluated exactly once,
/// in element order: the plugin's golden serializer depends on that (its
/// suppliers can sample a time-flow tracker as a side effect) and so does the
/// editor's parity test.
///
/// ## Chrome
///
/// [_frame] is a line-for-line port of `CardFramer`. Its constants, its integer
/// division and its emission order are frozen — the plugin's golden snapshots
/// pin every one of those numbers and `preview_card_scene_test.dart` replays
/// three of them here. Nothing in it may be "cleaned up":
/// `(panelTop + panelBottom) ~/ 2` truncates towards zero and the snapshots
/// depend on it.
///
/// DOM-free: pure logic, runs on the VM under `dart test`.
library;

import '../l10n/hui_localizations.dart';
import '../model/preview_doc.dart';
import '../model/particle_layer.dart';
import 'gloss_text.dart' show GlossEmojiResolver, GlossNoEmoji, glossApplyEmoji;
import 'gloss_particle_text.dart';
import 'mc_text.dart';
import 'preview_expr.dart';
import 'preview_sim.dart';

/// The brief's name for the repo's existing styled run type: one stretch of
/// label text sharing a resolved colour and set of decorations, as
/// [parseMcText] produces it.
typedef StyledTextRun = McSpan;

/// `PreviewDocumentParser.MAX_REPEAT_COUNT`: instances one `repeat` may expand.
const int previewMaxRepeatCount = 1024;

/// `PreviewDocumentParser.MAX_TOTAL_TEMPLATES`: expansion attempts one build may
/// make across every element.
const int previewMaxTotalTemplates = 4096;

/// `CompiledPreviewDocument.TRANSPARENT`: what a cell renders when its colour
/// expression fails.
const int previewTransparent = 0x00000000;

/// `CompiledPreviewDocument.DEFAULT_ACCENT_COLOR`: the neutral grey a card with
/// no `accent` frames itself in.
const int previewDefaultAccentColor = 0xFFCBD0D9;

/// `PreviewDocumentParser.DEFAULT_WELL_COLOR`.
const int previewDefaultWellColor = 0xFF15151B;

/// `Long.MAX_VALUE` as TEXT, the value Java's `(long)` cast saturates an
/// out-of-range double at.
///
/// Carried as a string rather than an int on purpose: `dart compile js`
/// REJECTS any integer literal a JavaScript double cannot hold exactly, and
/// 9223372036854775807 is one (the nearest double is 2^63). Writing it as an
/// int would break the web build outright the moment anything web-reachable
/// imports this file. It is only ever printed — the count it stands for is
/// truncated to [previewMaxRepeatCount] on the same line — so text loses
/// nothing and keeps the message byte-identical to the plugin's.
const String _javaLongMaxText = '9223372036854775807';

const double _defaultZPanel = 1;
const double _defaultZWell = 4;
const double _defaultZLabel = 6;

const String _defaultRepeatVar = 'i';

const Set<String> _elementTypes = <String>{'panel', 'cell', 'slot', 'label'};

// ---------------------------------------------------------------------------
// Items
// ---------------------------------------------------------------------------

/// One positioned element of a built preview. Pixel coordinates, origin at the
/// card centre, `y` up; `z` is the paint layer the plugin assigns.
sealed class CardItem {
  const CardItem(this.x, this.y, this.z);

  final int x;
  final int y;
  final int z;
}

/// A filled rectangle: the card frame, the panel, the tray behind a grid, the
/// title bar, or a document's own `panel` element.
class CardPanel extends CardItem {
  const CardPanel(
    super.x,
    super.y,
    super.z,
    this.width,
    this.height,
    this.color,
  );

  final int width;
  final int height;

  /// Unsigned ARGB.
  final int color;
}

/// A square swatch. Its colour is the one field a document animates most, and
/// [previewTransparent] when the expression failed.
class CardCell extends CardItem {
  const CardCell(super.x, super.y, super.z, this.size, this.color);

  final int size;

  /// Unsigned ARGB.
  final int color;
}

/// An inventory slot: the well behind it plus whatever the simulation has in
/// that slot.
class CardSlot extends CardItem {
  const CardSlot(
    super.x,
    super.y,
    super.z,
    this.size,
    this.wellColor,
    this.index,
    this.item,
  );

  final int size;

  /// Unsigned ARGB.
  final int wellColor;

  /// The inventory index this slot draws, exactly as the document asked for it
  /// — out of range is not an error, it just holds no stack.
  final int index;

  /// The simulated stack, or null for an empty or out-of-range slot.
  final SimSlotItem? item;
}

/// A line of styled text. Empty [text] is a label that resolved to nothing,
/// which is also what a failed text expression renders.
class CardLabel extends CardItem {
  const CardLabel(
    super.x,
    super.y,
    super.z,
    this.text,
    this.background, {
    this.size,
    this.renderedText = '',
    this.particleSpans = const <GlossParticleTextSpan>[],
  });

  /// Always null. The preview format has no label size: `PreviewElement.Label`
  /// carries none and the parser never compiles one, so a painter has to
  /// measure the glyphs itself. Declared because every other item type exposes
  /// its drawn extent and callers switch over the union.
  final int? size;

  final List<StyledTextRun> text;

  /// Unsigned ARGB; 0 (fully transparent) unless the document asked for a
  /// backing plate.
  final int background;
  final String renderedText;
  final List<GlossParticleTextSpan> particleSpans;
}

/// One built frame: the items in paint order plus the extent they cover.
class PreviewCardScene {
  const PreviewCardScene(
    this.items,
    this.widthPx,
    this.heightPx, {
    this.sources = const <int>[],
    this.particleLayers = const <GlossParticleLayer>[],
  });

  static const PreviewCardScene empty = PreviewCardScene(<CardItem>[], 0, 0);

  /// Emission order, which is the plugin's render order: chrome first, then the
  /// document's own elements in declaration order.
  final List<CardItem> items;

  /// Index into `doc.elements` of the element that emitted each entry of
  /// [items], aligned one for one, or -1 for the card chrome nothing in the
  /// document authored. Every instance of a `repeat` reports its TEMPLATE, so
  /// an editor clicking one instance always lands on the element the author
  /// can actually edit.
  ///
  /// The plugin has no use for this — it renders the frame and forgets it —
  /// but the editor's canvas surface has nothing else to map a click back to
  /// the model with.
  final List<int> sources;

  /// Bounding box of the drawn content, measured the way `CardFramer` measures
  /// it: panels, cells and slots contribute their full box, and a label
  /// contributes [_line] of height and no width, because the format gives no
  /// way to know how wide a rendered string will be. Zero for an empty scene.
  final int widthPx;
  final int heightPx;
  final List<GlossParticleLayer> particleLayers;
}

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------

/// Resolves [doc] against [sim] into one frame.
///
/// Never throws — including for a document the JSON decoder could not have
/// produced, since editor UI code writes to the model directly. Every failure
/// is reported to [onError] and degrades to the plugin's own fallback (a
/// skipped element, a transparent cell, an empty label); see [_reason] for the
/// width of the net that guarantees it. [onError] must not throw.
PreviewCardScene buildCardScene(
  HuiPreviewDoc doc,
  PreviewSim sim, {
  void Function(String)? onError,
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final void Function(String) sink = onError ?? _noOpSink;
  try {
    if (!_bool(previewShowExpression(doc.show), true, sim, 'show')) {
      return PreviewCardScene.empty;
    }
    final List<CardItem> content = <CardItem>[];
    // Parallel to [content]: which element emitted each entry. Counted from the
    // list length rather than threaded through `_emit`, so a partially expanded
    // repeat that then threw still attributes the items it did emit.
    final List<int> sources = <int>[];
    // One budget per build call, exactly as the plugin scopes it.
    final _Budget budget = _Budget(previewMaxTotalTemplates);
    for (int index = 0; index < doc.elements.length; index++) {
      final HuiPreviewElement template = doc.elements[index];
      if (budget.exhausted) {
        sink(
          huiText(
            'element cap {limit} reached, remaining elements skipped',
            <String, Object?>{'limit': previewMaxTotalTemplates},
          ),
        );
        break;
      }
      final int before = content.length;
      try {
        _expand(template, sim, budget, content, sink, emoji);
      } catch (failure) {
        sink(
          huiText('{element}: {reason}', <String, Object?>{
            'element': _describe(template),
            'reason': _reason(failure),
          }),
        );
      }
      for (int emitted = content.length - before; emitted > 0; emitted--) {
        sources.add(index);
      }
    }
    final List<CardItem> items = _framed(doc, content, sim, sink);
    // The framer prepends its chrome and appends the content untouched, so the
    // count it added is all that has to be accounted for here.
    final List<int> owners = <int>[
      for (int chrome = items.length - content.length; chrome > 0; chrome--) -1,
      ...sources,
    ];
    return PreviewCardScene(
      List<CardItem>.unmodifiable(items),
      _width(items),
      _height(items),
      sources: List<int>.unmodifiable(owners),
      particleLayers: glossCopyParticleLayers(doc.particleLayers),
    );
  } catch (failure) {
    sink(
      huiText('build failed: {reason}', <String, Object?>{
        'reason': _reason(failure),
      }),
    );
    return PreviewCardScene.empty;
  }
}

void _noOpSink(String message) {}

/// Message for one caught failure.
///
/// Every recovery point in this file catches everything rather than just
/// [PExprException]. The Java original catches `RuntimeException`, which has no
/// Dart equivalent — a bad cast is an `Error` here, not an exception — and this
/// pass runs on the per-tick render path under a "never throws" contract, so a
/// net that only caught the expected type would let a mutable model take the
/// whole preview down. The typed guards in [_number], [_bool] and [_string]
/// mean the known wrong-primitive cases arrive as a proper [PExprException]
/// with a readable message; this net is what keeps an unforeseen one from
/// escaping. Anything that is not a [PExprException] reports its own
/// `toString`, so a swallowed bug is still visible in the sink rather than
/// silent.
String _reason(Object failure) =>
    failure is PExprException ? failure.message : '$failure';

String _describe(HuiPreviewElement template) => switch (template.type) {
  'panel' => huiText('panel'),
  'cell' => huiText('cell'),
  'slot' => huiText('slot'),
  'label' => huiText('label'),
  _ => template.type,
};

void _expand(
  HuiPreviewElement template,
  PreviewSim sim,
  _Budget budget,
  List<CardItem> out,
  void Function(String) sink,
  GlossEmojiResolver emoji,
) {
  final HuiPreviewRepeat? repeat = template.repeat;
  if (repeat == null) {
    budget.take();
    _emit(template, sim, sim, out, sink, emoji);
    return;
  }
  int count = _repeatCount(repeat, sim, sink);
  if (count > budget.remaining) {
    sink(
      huiText(
        'repeat of {count} truncated at the {limit} element cap',
        <String, Object?>{'count': count, 'limit': previewMaxTotalTemplates},
      ),
    );
    count = budget.remaining;
  }
  final String name = _repeatVar(repeat);
  for (int index = 0; index < count; index++) {
    budget.take();
    // One scope per instance, holding this instance's loop value. The plugin
    // hands the same scope to the live cell/label closures it builds here; the
    // editor evaluates them inline instead, off the same scope.
    _emit(
      template,
      sim,
      _RepeatScope(sim, name, index.toDouble()),
      out,
      sink,
      emoji,
    );
  }
}

String _repeatVar(HuiPreviewRepeat repeat) {
  final String? name = repeat.varName;
  return name == null || name.isEmpty ? _defaultRepeatVar : name;
}

int _repeatCount(
  HuiPreviewRepeat repeat,
  PExprScope scope,
  void Function(String) sink,
) {
  final double raw = _number(repeat.count, 0, scope, 'repeat.count');
  // NaN and negative infinity both fail this, exactly as Java's `!(raw >= 1.0)`
  // does, so only a positive infinity reaches the branch below.
  if (!(raw >= 1.0)) return 0;
  // Java's `(long) Math.floor(raw)` saturates at Long.MAX_VALUE for anything
  // too large to fit, infinity included. Dart's `floor()` saturates the same
  // way for a finite overflow (1e300 floors to Long.MAX_VALUE) but THROWS an
  // UnsupportedError on infinity, so infinity is handled before the call — and
  // handled as TEXT, because the saturated value cannot be written as a Dart
  // int at all on the web (see [_javaLongMaxText]). It never needs to be a
  // number: it is over the cap by construction, so the count is truncated to
  // the cap and only the message carries the value.
  if (!raw.isFinite) {
    sink(
      huiText(
        'repeat count {count} exceeds {limit}, truncated',
        <String, Object?>{
          'count': _javaLongMaxText,
          'limit': previewMaxRepeatCount,
        },
      ),
    );
    return previewMaxRepeatCount;
  }
  final int count = raw.floor();
  if (count > previewMaxRepeatCount) {
    sink(
      huiText(
        'repeat count {count} exceeds {limit}, truncated',
        <String, Object?>{'count': count, 'limit': previewMaxRepeatCount},
      ),
    );
    return previewMaxRepeatCount;
  }
  return count;
}

void _emit(
  HuiPreviewElement template,
  PreviewSim sim,
  PExprScope scope,
  List<CardItem> out,
  void Function(String) sink,
  GlossEmojiResolver emoji,
) {
  final String type = template.type;
  if (!_elementTypes.contains(type)) {
    throw PExprException(
      'type must be one of {types}',
      previewNoPosition,
      <String, Object?>{'types': _elementTypes.join(', ')},
    );
  }
  if (!_bool(previewShowExpression(template.show), true, scope, 'show') ||
      !_bool(template.visible, true, scope, 'visible')) {
    return;
  }
  final int x = _coordinate(template.x, 0, scope, 'x');
  final int y = _coordinate(template.y, 0, scope, 'y');
  final int z = _coordinate(template.z, _defaultZ(type), scope, 'z');
  switch (type) {
    case 'panel':
      out.add(
        CardPanel(
          x,
          y,
          z,
          _coordinate(_required(template.width, 'width'), 0, scope, 'width'),
          _coordinate(_required(template.height, 'height'), 0, scope, 'height'),
          _color(_required(template.color, 'color'), 0, scope, 'color'),
        ),
      );
    case 'cell':
      final int size = _coordinate(
        _required(template.size, 'size'),
        0,
        scope,
        'size',
      );
      out.add(CardCell(x, y, z, size, _cellColor(template.color, scope, sink)));
    case 'slot':
      if (sim.inventorySize <= 0) {
        sink(huiText('slot: target has no inventory'));
        return;
      }
      final int size = _coordinate(
        _required(template.size, 'size'),
        0,
        scope,
        'size',
      );
      final int index = _coordinate(
        _required(template.index, 'index'),
        0,
        scope,
        'index',
      );
      out.add(
        CardSlot(
          x,
          y,
          z,
          size,
          _color(
            template.wellColor,
            previewDefaultWellColor.toDouble(),
            scope,
            'wellColor',
          ),
          index,
          _slotItem(sim, index),
        ),
      );
    case 'label':
      final int background = _color(
        template.background,
        0,
        scope,
        'background',
      );
      final McTextResult parsed = _labelText(template.text, scope, sink, emoji);
      out.add(
        CardLabel(
          x,
          y,
          z,
          _flattenRuns(parsed),
          background,
          renderedText: parsed.renderedText,
          particleSpans: parsed.particleSpans,
        ),
      );
  }
}

double _defaultZ(String type) => switch (type) {
  'panel' => _defaultZPanel,
  'label' => _defaultZLabel,
  _ => _defaultZWell,
};

Object _required(Object? raw, String field) {
  if (raw == null) {
    throw PExprException(
      '{field} required',
      previewNoPosition,
      <String, Object?>{'field': field},
    );
  }
  return raw;
}

/// The stack the simulation holds in [index], or null for an empty or
/// out-of-range slot — the rule `PreviewStateAdapters` applies to a live
/// inventory.
SimSlotItem? _slotItem(PreviewSim sim, int index) {
  if (index < 0 || index >= sim.inventorySize) return null;
  for (final SimSlotItem item in sim.slotItems) {
    if (item.slot == index) return item.isEmpty ? null : item;
  }
  return null;
}

/// A cell's colour is one of the two fields the plugin keeps live; a failure
/// renders [previewTransparent] rather than dropping the cell.
int _cellColor(Object? raw, PExprScope scope, void Function(String) sink) {
  try {
    return _color(_required(raw, 'color'), 0, scope, 'color');
  } catch (failure) {
    sink(
      huiText('cell color: {reason}', <String, Object?>{
        'reason': _reason(failure),
      }),
    );
    return previewTransparent;
  }
}

/// A label's text is the other live field. It goes through [parseMcText], the
/// twin of the plugin's `TextUtils.parse`, so a document renders the same runs
/// the retired layouts built. A failure renders nothing.
McTextResult _labelText(
  String? raw,
  PExprScope scope,
  void Function(String) sink,
  GlossEmojiResolver emoji,
) {
  try {
    final Object sourceValue = _required(raw, 'text');
    if (sourceValue is! String) {
      _string(sourceValue, scope, 'text');
    }
    final String source = sourceValue as String;
    final GlossParticleTextRendered rendered = resolveGlossParticleText(
      glossApplyEmoji(
        _labelled(
          'text',
          () => evalString(_compileParticleText(source), scope),
        ),
        emoji,
      ),
    );
    return parseMcText(
      rendered.text,
    ).withParticleSpans(rendered.text, rendered.spans);
  } catch (failure) {
    sink(
      huiText('label text: {reason}', <String, Object?>{
        'reason': _reason(failure),
      }),
    );
    return const McTextResult(lines: <List<McSpan>>[], warnings: <String>[]);
  }
}

/// One label is one line: the plugin builds a single `Component` per label and
/// never splits on newlines, so every parsed line is concatenated back.
List<StyledTextRun> _parseRuns(String text) {
  final McTextResult parsed = parseMcText(text);
  return _flattenRuns(parsed);
}

List<StyledTextRun> _flattenRuns(McTextResult parsed) {
  if (parsed.lines.length == 1) return parsed.lines.first;
  return <StyledTextRun>[for (final List<McSpan> line in parsed.lines) ...line];
}

// ---------------------------------------------------------------------------
// Card chrome
// ---------------------------------------------------------------------------

List<CardItem> _framed(
  HuiPreviewDoc doc,
  List<CardItem> content,
  PreviewSim sim,
  void Function(String) sink,
) {
  final HuiPreviewCard? card = doc.card;
  if (card == null || !_cardFramed(card, sim, sink)) return content;
  // Both evaluated once per build, not per frame: a card's title and accent are
  // chrome, and the golden snapshots record them as fixed values.
  return _frame(
    content,
    _cardTitle(card, sim, sink),
    _cardAccent(card, sim, sink),
    card.minHalfWidth ?? _minPanelHalfWidth,
  );
}

bool _cardFramed(
  HuiPreviewCard card,
  PExprScope scope,
  void Function(String) sink,
) {
  try {
    return _bool(previewShowExpression(card.show), true, scope, 'card.show') &&
        _bool(card.framed, true, scope, 'card.framed');
  } catch (failure) {
    sink(
      huiText('card framed: {reason}', <String, Object?>{
        'reason': _reason(failure),
      }),
    );
    return false;
  }
}

List<StyledTextRun> _cardTitle(
  HuiPreviewCard card,
  PExprScope scope,
  void Function(String) sink,
) {
  final String? title = card.title;
  if (title == null) return const <StyledTextRun>[];
  try {
    return _parseRuns(_string(title, scope, 'card.title'));
  } catch (failure) {
    sink(
      huiText('card title: {reason}', <String, Object?>{
        'reason': _reason(failure),
      }),
    );
    return const <StyledTextRun>[];
  }
}

int _cardAccent(
  HuiPreviewCard card,
  PExprScope scope,
  void Function(String) sink,
) {
  final String? accent = card.accent;
  if (accent == null) return previewDefaultAccentColor;
  try {
    return _color(accent, 0, scope, 'card.accent');
  } catch (failure) {
    sink(
      huiText('card accent: {reason}', <String, Object?>{
        'reason': _reason(failure),
      }),
    );
    return previewDefaultAccentColor;
  }
}

// --- CardFramer port -------------------------------------------------------
//
// Every constant below was read off
// `HoloUi/src/main/java/art/arcane/holoui/menu/special/inventories/doc/CardFramer.java`
// except `_minPanelHalfWidth`, which lives in the parser as
// `PreviewDocumentParser.DEFAULT_MIN_HALF_WIDTH` and reaches the framer as its
// `minHalfWidth` argument.

const int _well = 18;
const int _line = 12;

const int _trayPad = 4;
const int _panelPad = 7;
const int _titleBarHeight = 17;
const int _frameBorder = 3;
const int _gap = 6;

const int _minPanelHalfWidth = 82;

const int _zFrame = 0;
const int _zPanel = 1;
const int _zTray = 2;
const int _zTitleBar = 3;
const int _zLabel = 6;

const int _panelColor = 0xF21B1B22;
const int _trayColor = 0xFF33333E;
const int _frameAlpha = 0xCC;
const int _titleBarAlpha = 0xE6;

/// Measures [content] and wraps it in the card chrome: outer frame, panel,
/// optional tray behind the cell grid, title bar, title label. A line-for-line
/// port of `CardFramer.frame`.
List<CardItem> _frame(
  List<CardItem> content,
  List<StyledTextRun> title,
  int accentColor,
  int minHalfWidth,
) {
  bool hasGrid = false;
  int gridLeft = 0;
  int gridRight = 0;
  int gridBottom = 0;
  int gridTop = 0;
  bool hasContent = false;
  int contentTop = 0;
  int contentBottom = 0;
  for (final CardItem element in content) {
    final int halfHeight = element is CardLabel ? _line ~/ 2 : _well ~/ 2;
    if (!hasContent) {
      contentTop = element.y + halfHeight;
      contentBottom = element.y - halfHeight;
      hasContent = true;
    } else {
      contentTop = _max(contentTop, element.y + halfHeight);
      contentBottom = _min(contentBottom, element.y - halfHeight);
    }
    final bool isCell = element is CardSlot || element is CardCell;
    if (isCell) {
      final int left = element.x - _well ~/ 2;
      final int right = element.x + _well ~/ 2;
      final int bottom = element.y - _well ~/ 2;
      final int top = element.y + _well ~/ 2;
      if (!hasGrid) {
        gridLeft = left;
        gridRight = right;
        gridBottom = bottom;
        gridTop = top;
        hasGrid = true;
      } else {
        gridLeft = _min(gridLeft, left);
        gridRight = _max(gridRight, right);
        gridBottom = _min(gridBottom, bottom);
        gridTop = _max(gridTop, top);
      }
    }
  }
  if (!hasContent) {
    contentTop = _well ~/ 2;
    contentBottom = -_well ~/ 2;
  }

  final int panelHalfWidth = _max(
    minHalfWidth,
    (hasGrid ? (gridRight - gridLeft) ~/ 2 : _well ~/ 2) + _panelPad,
  );
  final int titleBarBottom = contentTop + _gap;
  final int panelTop = titleBarBottom + _titleBarHeight;
  final int panelBottom = contentBottom - _panelPad;
  final int panelCenterY = (panelTop + panelBottom) ~/ 2;
  final int panelWidth = panelHalfWidth * 2;
  final int panelHeight = panelTop - panelBottom;

  final int accent = accentColor;
  final int frameColor = (_frameAlpha << 24) | (accent & 0xFFFFFF);
  final int titleBarColor = (_titleBarAlpha << 24) | (accent & 0xFFFFFF);

  final List<CardItem> styled = <CardItem>[];
  styled.add(
    CardPanel(
      0,
      panelCenterY,
      _zFrame,
      panelWidth + _frameBorder * 2,
      panelHeight + _frameBorder * 2,
      frameColor,
    ),
  );
  styled.add(
    CardPanel(0, panelCenterY, _zPanel, panelWidth, panelHeight, _panelColor),
  );
  if (hasGrid) {
    final int trayWidth = (gridRight - gridLeft) + _trayPad * 2;
    final int trayHeight = (gridTop - gridBottom) + _trayPad * 2;
    final int trayCenterX = (gridRight + gridLeft) ~/ 2;
    final int trayCenterY = (gridTop + gridBottom) ~/ 2;
    styled.add(
      CardPanel(
        trayCenterX,
        trayCenterY,
        _zTray,
        trayWidth,
        trayHeight,
        _trayColor,
      ),
    );
  }
  final int titleBarCenterY = (panelTop + titleBarBottom) ~/ 2;
  styled.add(
    CardPanel(
      0,
      titleBarCenterY,
      _zTitleBar,
      panelWidth,
      _titleBarHeight,
      titleBarColor,
    ),
  );
  styled.add(CardLabel(0, titleBarCenterY, _zLabel, title, 0));
  styled.addAll(content);
  return styled;
}

int _min(int a, int b) => a < b ? a : b;

int _max(int a, int b) => a > b ? a : b;

// ---------------------------------------------------------------------------
// Extent
// ---------------------------------------------------------------------------

int _width(List<CardItem> items) {
  int left = 0;
  int right = 0;
  bool any = false;
  for (final CardItem item in items) {
    final int half = _halfWidth(item);
    if (half < 0) continue;
    if (!any) {
      left = item.x - half;
      right = item.x + half;
      any = true;
    } else {
      left = _min(left, item.x - half);
      right = _max(right, item.x + half);
    }
  }
  return any ? right - left : 0;
}

int _height(List<CardItem> items) {
  int bottom = 0;
  int top = 0;
  bool any = false;
  for (final CardItem item in items) {
    final int half = _halfHeight(item);
    if (!any) {
      bottom = item.y - half;
      top = item.y + half;
      any = true;
    } else {
      bottom = _min(bottom, item.y - half);
      top = _max(top, item.y + half);
    }
  }
  return any ? top - bottom : 0;
}

/// Negative for a label: the format carries no rendered width, so a label is
/// left out of the horizontal extent entirely rather than guessed at.
int _halfWidth(CardItem item) => switch (item) {
  CardPanel() => item.width ~/ 2,
  CardCell() => item.size ~/ 2,
  CardSlot() => item.size ~/ 2,
  CardLabel() => -1,
};

int _halfHeight(CardItem item) => switch (item) {
  CardPanel() => item.height ~/ 2,
  CardCell() => item.size ~/ 2,
  CardSlot() => item.size ~/ 2,
  CardLabel() => _line ~/ 2,
};

// ---------------------------------------------------------------------------
// Field evaluation
// ---------------------------------------------------------------------------

/// Parsed expression sources, keyed by source text. Parsing is pure, the scene
/// rebuilds on every simulation tick, and a document's field sources are a
/// small fixed set, so re-lexing them twenty times a second is pure waste. The
/// cache is cleared wholesale once it outgrows [_exprCacheLimit], which bounds
/// it while an author is typing new sources into a field.
const int _exprCacheLimit = 512;

final Map<String, PExpr> _exprCache = <String, PExpr>{};
final Map<String, PExpr> _particleExprCache = <String, PExpr>{};

PExpr _compile(String source) {
  final PExpr? cached = _exprCache[source];
  if (cached != null) return cached;
  final PExpr parsed = parsePreviewExpr(source);
  if (_exprCache.length >= _exprCacheLimit) _exprCache.clear();
  _exprCache[source] = parsed;
  return parsed;
}

PExpr _compileParticleText(String source) {
  final PExpr? cached = _particleExprCache[source];
  if (cached != null) return cached;
  final PExpr parsed = _markParticleTextLiterals(_compile(source));
  if (_particleExprCache.length >= _exprCacheLimit) {
    _particleExprCache.clear();
  }
  _particleExprCache[source] = parsed;
  return parsed;
}

PExpr _markParticleTextLiterals(PExpr expression) {
  return switch (expression) {
    PNum() => expression,
    PStr(value: final String value) => PStr(
      parseGlossParticleText(value).marked,
    ),
    PBool() => expression,
    PList(items: final List<PExpr> items) => PList(<PExpr>[
      for (final PExpr item in items) _markParticleTextLiterals(item),
    ]),
    PVar() => expression,
    PUnary(op: final String op, operand: final PExpr operand) => PUnary(
      op,
      _markParticleTextLiterals(operand),
    ),
    PBinary(
      op: final String op,
      left: final PExpr left,
      right: final PExpr right,
    ) =>
      PBinary(
        op,
        _markParticleTextLiterals(left),
        _markParticleTextLiterals(right),
      ),
    PTernary(
      condition: final PExpr condition,
      ifTrue: final PExpr ifTrue,
      ifFalse: final PExpr ifFalse,
    ) =>
      PTernary(
        _markParticleTextLiterals(condition),
        _markParticleTextLiterals(ifTrue),
        _markParticleTextLiterals(ifFalse),
      ),
    PCall(name: final String name, args: final List<PExpr> args) => PCall(
      name,
      <PExpr>[
        for (final PExpr argument in args) _markParticleTextLiterals(argument),
      ],
    ),
  };
}

/// A number-or-expression field.
///
/// [HuiRawExpr] is `Object?` and the model is MUTABLE: the JSON decoder only
/// ever stores a `num`, a `String` or a `bool`, but editor UI code assigns to
/// these fields directly and can put anything in one. A wrong primitive is
/// therefore a first-class case here, reported with the parser's own wording
/// rather than left to become a `TypeError` out of a cast.
double _number(Object? raw, double fallback, PExprScope scope, String field) {
  if (raw == null) return fallback;
  if (raw is num) return raw.toDouble();
  if (raw is! String) {
    throw PExprException(
      '{field}: must be a number or a string expression',
      previewNoPosition,
      <String, Object?>{'field': field},
    );
  }
  return _labelled(field, () => evalNumber(_compile(raw), scope));
}

/// Positions and sizes round; `Math.round` is half-UP, not half-away-from-zero,
/// which is what [previewRound] reproduces.
int _coordinate(Object? raw, double fallback, PExprScope scope, String field) =>
    previewRound(_number(raw, fallback, scope, field)).toInt();

/// Reinterprets the unsigned ARGB double the expression language carries
/// colours as; see [previewNarrowArgb].
int _color(Object? raw, double fallback, PExprScope scope, String field) =>
    previewNarrowArgb(_number(raw, fallback, scope, field));

/// A boolean-or-expression field; see [_number] on why a wrong primitive is a
/// reported case rather than a cast failure.
bool _bool(Object? raw, bool fallback, PExprScope scope, String field) {
  if (raw == null) return fallback;
  if (raw is bool) return raw;
  if (raw is! String) {
    throw PExprException(
      '{field}: must be a boolean or a string expression',
      previewNoPosition,
      <String, Object?>{'field': field},
    );
  }
  return _labelled(field, () => evalBool(_compile(raw), scope));
}

String _string(Object? raw, PExprScope scope, String field) {
  if (raw is! String) {
    throw PExprException(
      '{field}: must be a string expression',
      previewNoPosition,
      <String, Object?>{'field': field},
    );
  }
  return _labelled(field, () => evalString(_compile(raw), scope));
}

/// Names the field a failure came from. The plugin reports the compiled path
/// (`elements[3].width`) because its failures happen at load; the editor
/// resolves fields on every build, so the field name is what a message can
/// carry without re-deriving the element's index.
T _labelled<T>(String field, T Function() body) {
  try {
    return body();
  } on PExprException catch (failure) {
    throw PExprException(
      '{field}: {message}',
      failure.position,
      <String, Object?>{
        'field': field,
        'message': failure.localizedMessageArgument,
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Expansion budget and scope
// ---------------------------------------------------------------------------

/// How many more elements one build may expand. Counts attempts rather than
/// emitted elements, so a document whose elements are all invisible still costs
/// a bounded amount of work.
class _Budget {
  _Budget(this.remaining);

  int remaining;

  bool get exhausted => remaining <= 0;

  void take() => remaining--;
}

/// Resolves one repeat variable, delegating everything else to the simulation.
class _RepeatScope implements PExprScope {
  const _RepeatScope(this.parent, this.name, this.value);

  final PExprScope parent;
  final String name;
  final Object value;

  @override
  Object? variable(String dottedName) =>
      name == dottedName ? value : parent.variable(dottedName);

  @override
  Object? call(String function, List<Object?> args) =>
      parent.call(function, args);
}
