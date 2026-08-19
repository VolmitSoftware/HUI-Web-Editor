/// Mirror of Gloss `TextPipeline.java` for the editor's Gloss document
/// surfaces (holograms, scoreboards, animation frames).
///
/// The plugin renders every content line through four ordered stages
/// (`TextPipeline.render`):
///
///  1. `|function|` substitution — registered names only; this editor build
///     registers the `animation.<id>` family for the workspace's animation
///     documents (`AnimationService.java:16,88`) and knows the `metric.<key>`
///     family the integration bridge registers
///     (`IntegrationBridgeService.java:16,102-104`). An unregistered name stays
///     literal, and the scan then treats its closing pipe as the next
///     candidate opener (`TextPipeline.applyFunctions`: `open = close`).
///     A metric reference has no editor-side value — the samples come from
///     other Volmit plugins at runtime — so it keeps its token, is scanned
///     like the registered function it is, and renders as a chip.
///  2. `%placeholder%` PAPI expansion — the editor cannot run PAPI, so tokens
///     become chips instead of values.
///  3. Emoji substitution (`EmojiReplacer.apply` via the pipeline's emoji
///     filter, `EmojiService.enable`): `:id:` tokens and triggers become the
///     resolved glyphs. The editor's [GlossEmojiResolver] merges the shipped
///     catalog with the workspace's emoji documents. One honest divergence:
///     the plugin substitutes AFTER placeholders expand, but the editor
///     keeps placeholder tokens literal, so a trigger inside an expanded
///     placeholder value cannot be seen here.
///  4. Colours: `[RRGGBB]` bracket hex (exactly six hex digits then `]`,
///     `TextPipeline.translateBracketHex`), then legacy `&` codes via
///     `ChatColor.translateAlternateColorCodes` and the client's `§` state
///     machine — a colour code resets the decorations, `&r` resets
///     everything, and Bungee's `§x§R§R§G§G§B§B` hex form is honoured.
///
/// Menu text icons are the one Gloss surface that does NOT run stages 1 and 2
/// here: `TextMenuIcon.render` expands PlaceholderAPI itself and then calls
/// `TextPipeline.menuText`, which is emoji plus colours only
/// (`TextPipeline.renderMenuText`). [glossRenderMenuText] is that shorter path;
/// a literal `|` in a menu label stays literal.
///
/// Everything here is DOM-free and clock-free: the caller passes `nowMs` and
/// an animation resolver, so the whole pipeline is testable on the VM and
/// deterministic under an injected clock.
library;

import '../model/gloss_animation.dart';
import 'gloss_animation_playback.dart';
import 'mc_text.dart' show McSpan, mcDefaultTextColor;
import 'preview_expr.dart';
import 'preview_expr_functions.dart';

/// The function-name family `AnimationService` registers per document:
/// `animation.` + the document id (its file path).
const String glossAnimationFunctionPrefix = 'animation.';

/// The function-name family `IntegrationBridgeService` registers per metric
/// key published by another Volmit plugin: `metric.` + the key
/// (`IntegrationBridgeService.java:16,102-104`). Gloss content kinds
/// (hologram, scoreboard, tablist, motd, chat bubbles) run the full pipeline
/// and therefore resolve these; menus do not.
const String glossMetricFunctionPrefix = 'metric.';

/// Resolves the workspace's animation documents for text rendering. The
/// editor's stand-in for `TextPipeline`'s registered-function map.
abstract interface class GlossAnimationResolver {
  /// Ids (file paths) of every animation document, sorted.
  List<String> get ids;

  /// The animation document behind [id], or null when the workspace has none.
  GlossAnimationDoc? byId(String id);
}

/// The empty resolver: no animation functions are registered.
final class GlossNoAnimations implements GlossAnimationResolver {
  const GlossNoAnimations();

  @override
  List<String> get ids => const <String>[];

  @override
  GlossAnimationDoc? byId(String id) => null;
}

/// One replacement the emoji stage can make — `EmojiEntry.java`, with the
/// glyph already resolved through `UnicodeText.parse` the way
/// `EmojiService.rebuild` resolves it at load.
final class GlossEmojiEntry {
  const GlossEmojiEntry({
    required this.id,
    required this.trigger,
    required this.glyph,
    required this.enabled,
    this.fromWorkspace = false,
  });

  /// The document id (its file path), which names the chat token.
  final String id;

  /// Optional second spelling; `""` means token-only (`EmojiEntry.hasTrigger`).
  final String trigger;

  /// The resolved replacement text.
  final String glyph;

  /// Disabled entries stay listed but never substitute
  /// (`EmojiReplacer` constructor).
  final bool enabled;

  /// True when a workspace emoji document backs this entry rather than the
  /// shipped catalog. Editor bookkeeping only — the plugin has one folder.
  final bool fromWorkspace;

  /// `EmojiEntry.token`.
  String get token => ':$id:';

  bool get hasTrigger => trigger.isNotEmpty;
}

/// Resolves the emoji available to text rendering: the shipped-catalog
/// entries with any workspace emoji documents layered over them. The
/// editor's stand-in for the `EmojiReplacer` the pipeline's emoji filter
/// holds.
abstract interface class GlossEmojiResolver {
  /// Every entry sorted by id — `EmojiService.rebuild` sorts the same way.
  /// Includes disabled entries; [glossApplyEmoji] skips them exactly like
  /// the `EmojiReplacer` constructor does.
  List<GlossEmojiEntry> get entries;
}

/// The empty resolver: no emoji substitute.
final class GlossNoEmoji implements GlossEmojiResolver {
  const GlossNoEmoji();

  @override
  List<GlossEmojiEntry> get entries => const <GlossEmojiEntry>[];
}

/// `EmojiReplacer.apply`: for each enabled entry in id order, replace every
/// occurrence of the trigger, then every occurrence of the `:id:` token.
/// Both presence checks read the string BEFORE either replacement for that
/// entry, exactly like the Java scan.
String glossApplyEmoji(String message, GlossEmojiResolver emoji) {
  final List<GlossEmojiEntry> entries = emoji.entries;
  if (message.isEmpty || entries.isEmpty) return message;
  String out = message;
  for (final GlossEmojiEntry entry in entries) {
    if (!entry.enabled) continue;
    final bool hasToken = out.contains(entry.token);
    final bool hasTrigger = entry.hasTrigger && out.contains(entry.trigger);
    if (!hasToken && !hasTrigger) continue;
    if (hasTrigger) out = out.replaceAll(entry.trigger, entry.glyph);
    if (hasToken) out = out.replaceAll(entry.token, entry.glyph);
  }
  return out;
}

/// One styled run or placeholder chip of a rendered line.
sealed class GlossTextPiece {
  const GlossTextPiece();
}

final class GlossTextRun extends GlossTextPiece {
  const GlossTextRun(this.span);

  final McSpan span;
}

/// A `%placeholder%` the editor cannot expand, styled like the text around it
/// so the chip sits in the line's colour run.
final class GlossPlaceholderChip extends GlossTextPiece {
  const GlossPlaceholderChip({required this.token, required this.style});

  /// The raw token including both `%` signs.
  final String token;

  /// The colour/decoration state in scope where the token sat.
  final McSpan style;

  /// The token without its `%` fences, for compact chip labels.
  String get name => token.substring(1, token.length - 1);
}

/// A `|metric.<key>|` reference. The plugin substitutes the last sample the
/// integration bridge took from whichever Volmit plugin publishes [key]
/// (`IntegrationBridge.render` → `MetricFormat.compact`); the editor has no
/// sample to show, so the token stays visible as a chip.
final class GlossMetricChip extends GlossTextPiece {
  const GlossMetricChip({
    required this.key,
    required this.token,
    required this.style,
  });

  /// The metric key without the `metric.` prefix, e.g. `react.tps`.
  final String key;

  /// The raw token including both pipes, e.g. `|metric.react.tps|`.
  final String token;

  /// The colour/decoration state in scope where the token sat.
  final McSpan style;
}

/// One line rendered through the editor's pipeline mirror.
final class GlossLineRender {
  const GlossLineRender({
    required this.pieces,
    required this.usedAnimations,
    required this.missingAnimations,
    required this.placeholders,
    required this.metrics,
    required this.expressions,
    required this.expressionErrors,
  });

  final List<GlossTextPiece> pieces;

  /// Animation ids that were substituted — nonempty means the line changes
  /// over time and the surface's ticker has work to do.
  final List<String> usedAnimations;

  /// `animation.<id>` references whose id no workspace animation document
  /// carries. The plugin leaves them as literal text (the function is simply
  /// unregistered); the editor additionally reports them.
  final List<String> missingAnimations;

  /// `%placeholder%` tokens found after substitution, in order.
  final List<String> placeholders;

  /// `metric.<key>` references in the line, keys only, in order. The editor
  /// cannot sample them, so they render as chips rather than values.
  final List<String> metrics;

  final List<String> expressions;

  final List<String> expressionErrors;

  bool get isAnimated => usedAnimations.isNotEmpty || expressions.isNotEmpty;

  /// The line as plain characters: colour codes consumed, placeholder and
  /// metric tokens verbatim.
  String get plainText => <String>[
    for (final GlossTextPiece piece in pieces)
      switch (piece) {
        GlossTextRun(:final McSpan span) => span.text,
        GlossPlaceholderChip(:final String token) => token,
        GlossMetricChip(:final String token) => token,
      },
  ].join();
}

/// Renders [raw] at [nowMs] against the workspace's animations and emoji.
GlossLineRender renderGlossLine(
  String raw, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
  GlossTextExpressionSamples expressionSamples =
      const GlossTextExpressionSamples(),
}) {
  final List<String> used = <String>[];
  final List<String> missing = <String>[];
  final List<String> metrics = <String>[];
  final List<String> expressions = <String>[];
  final List<String> expressionErrors = <String>[];
  final String functions = _applyFunctions(
    raw,
    animations,
    nowMs,
    used,
    missing,
    metrics: metrics,
  );
  final String substituted = glossApplyEmoji(
    _applyTextExpressions(
      functions,
      nowMs,
      expressionSamples,
      expressions,
      expressionErrors,
    ),
    emoji,
  );
  final List<String> placeholders = <String>[];
  final List<GlossTextPiece> pieces = _renderColors(substituted, placeholders);
  return GlossLineRender(
    pieces: List<GlossTextPiece>.unmodifiable(pieces),
    usedAnimations: List<String>.unmodifiable(used),
    missingAnimations: List<String>.unmodifiable(missing),
    placeholders: List<String>.unmodifiable(placeholders),
    metrics: List<String>.unmodifiable(metrics),
    expressions: List<String>.unmodifiable(expressions),
    expressionErrors: List<String>.unmodifiable(expressionErrors),
  );
}

/// The `metric.<key>` keys [raw] references, in order — the editor's stand-in
/// for the samples `IntegrationBridge` would substitute.
List<String> glossLineMetricRefs(String raw) {
  final List<String> metrics = <String>[];
  _applyFunctions(
    raw,
    const GlossNoAnimations(),
    0,
    <String>[],
    <String>[],
    metrics: metrics,
  );
  return metrics;
}

/// `TextPipeline.renderMenuText` — the string a menu text icon hands to
/// `TextUtils.parse`.
///
/// `TextMenuIcon.render` expands PlaceholderAPI itself and then calls
/// `TextPipeline.menuText`, which is `applyColors(applyEmoji(...))`: emoji
/// substitution, then the `[RRGGBB]` bracket-hex translation, and no
/// `|function|` stage at all — a literal `|` in a menu label stays literal.
///
/// The plugin's colour step also rewrites `&` codes to `§`, which is a no-op
/// here: `parseMcText` mirrors `TextUtils.translateLegacy`, which reads both
/// markers identically.
String glossRenderMenuText(
  String raw, {
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  if (raw.isEmpty) return '';
  return _translateBracketHex(glossApplyEmoji(raw, emoji));
}

/// The animation ids [raw] actually plays — [GlossLineRender.usedAnimations]
/// without paying for the colour stages.
List<String> glossLineAnimationRefs(
  String raw,
  GlossAnimationResolver animations,
) {
  final List<String> used = <String>[];
  _applyFunctions(raw, animations, 0, used, <String>[]);
  return used;
}

/// The `animation.<id>` references in [raw] whose animation document does not
/// exist — [GlossLineRender.missingAnimations] without the colour stages.
List<String> glossLineMissingAnimationRefs(
  String raw,
  GlossAnimationResolver animations,
) {
  final List<String> missing = <String>[];
  _applyFunctions(raw, animations, 0, <String>[], missing);
  return missing;
}

/// Longest plain-character form the line can take: every known animation
/// reference replaced by its longest frame, emoji substituted, colour codes
/// consumed. What the scoreboard's visible-length validation measures.
int glossLineMaxVisibleLength(
  String raw,
  GlossAnimationResolver animations, {
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final String substituted = _applyFunctions(
    raw,
    animations,
    0,
    <String>[],
    <String>[],
    frameOf: (GlossAnimationDoc doc) {
      String longest = '';
      for (final String frame in doc.frames) {
        final String plain = _plainLength(frame);
        if (plain.length > longest.length) longest = plain;
      }
      return longest;
    },
  );
  final String expressed = _applyTextExpressions(
    substituted,
    0,
    const GlossTextExpressionSamples(),
    <String>[],
    <String>[],
  );
  return _plainLength(glossApplyEmoji(expressed, emoji)).length;
}

/// Length of [raw] AFTER the pipeline's colour translation but BEFORE the
/// client consumes the codes — the string `BoardService` truncates the title
/// on (`rendered.length() > MAX_TITLE_LENGTH`, `BoardService.java:363-367`),
/// where every `&` code still counts 2 characters and every `[RRGGBB]`
/// becomes Bungee's 14-character `§x§R§R§G§G§B§B` form. Known animation
/// references substitute their longest frame; emoji substitute before the
/// colour translation exactly as the pipeline orders its stages; placeholder
/// tokens stay verbatim since their runtime width is unknowable here.
int glossTranslatedLength(
  String raw,
  GlossAnimationResolver animations, {
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final String functions = _applyFunctions(
    raw,
    animations,
    0,
    <String>[],
    <String>[],
    frameOf: (GlossAnimationDoc doc) {
      String longest = '';
      for (final String frame in doc.frames) {
        if (frame.length > longest.length) longest = frame;
      }
      return longest;
    },
  );
  final String substituted = glossApplyEmoji(
    _applyTextExpressions(
      functions,
      0,
      const GlossTextExpressionSamples(),
      <String>[],
      <String>[],
    ),
    emoji,
  );
  int length = substituted.length;
  // Each valid bracket-hex token (8 chars) translates to 14 chars.
  int open = substituted.indexOf('[');
  while (open >= 0) {
    if (open + 7 < substituted.length &&
        substituted[open + 7] == ']' &&
        _isBracketHex(substituted, open + 1)) {
      length += 6;
      open = substituted.indexOf('[', open + 8);
    } else {
      open = substituted.indexOf('[', open + 1);
    }
  }
  return length;
}

final class GlossTextExpressionSamples {
  const GlossTextExpressionSamples({
    this.placeholders = _defaultExpressionPlaceholders,
    this.metrics = _defaultExpressionMetrics,
    this.serverTps = 19.8,
  });

  final Map<String, Object> placeholders;
  final Map<String, double> metrics;
  final double serverTps;
}

const Map<String, Object> _defaultExpressionPlaceholders = <String, Object>{
  'player_name': 'Builder',
  'player_ping': 42.0,
  'player_health': 18.0,
  'player_level': 27.0,
  'server_online': 86.0,
  'server_max_players': 250.0,
  'server_tps_1': 19.8,
};

const Map<String, double> _defaultExpressionMetrics = <String, double>{
  'react.tps': 19.8,
  'react.tick-ms': 12.4,
  'gloss.boards-active': 7.0,
};

String _applyTextExpressions(
  String input,
  int nowMs,
  GlossTextExpressionSamples samples,
  List<String> used,
  List<String> errors,
) {
  if (!input.contains('{{')) return input;
  final StringBuffer output = StringBuffer();
  int cursor = 0;
  int open = input.indexOf('{{');
  bool replaced = false;
  final _GlossTextExpressionScope scope = _GlossTextExpressionScope(
    nowMs,
    samples,
  );
  while (open >= 0) {
    final int close = input.indexOf('}}', open + 2);
    if (close < 0) break;
    final String source = input.substring(open + 2, close).trim();
    if (source.isEmpty || source.length > 1024) {
      open = input.indexOf('{{', close + 2);
      continue;
    }
    try {
      final String value = evalString(parsePreviewExpr(source), scope);
      output
        ..write(input.substring(cursor, open))
        ..write(value);
      used.add(source);
      replaced = true;
      cursor = close + 2;
    } on PExprException catch (failure) {
      errors.add('${failure.message} at ${failure.position}');
    }
    open = input.indexOf('{{', close + 2);
  }
  if (!replaced) return input;
  output.write(input.substring(cursor));
  return output.toString();
}

final class _GlossTextExpressionScope extends PExprScope {
  _GlossTextExpressionScope(this.nowMs, this.samples);

  final int nowMs;
  final GlossTextExpressionSamples samples;

  @override
  Object? variable(String dottedName) {
    switch (dottedName) {
      case 'time.ms':
        return nowMs.toDouble();
      case 'time.seconds':
        return nowMs / 1000.0;
      case 'time.ticks':
        return nowMs / 50.0;
      case 'player.name':
        return samples.placeholders['player_name'];
      case 'player.ping':
        return _sampleNumber('player_ping');
      case 'player.health':
        return _sampleNumber('player_health');
      case 'player.level':
        return _sampleNumber('player_level');
      case 'server.online':
        return _sampleNumber('server_online');
      case 'server.maxPlayers':
        return _sampleNumber('server_max_players');
      case 'server.tps':
        return samples.serverTps;
      default:
        return samples.metrics[dottedName];
    }
  }

  @override
  Object? call(String name, List<Object?> args) {
    switch (name) {
      case 'papi':
        return _papi(args, false);
      case 'papiNumber':
        return _papi(args, true);
      case 'metric':
        if ((args.length != 1 && args.length != 2) || args.first is! String) {
          throw const PExprException(
            'metric expects a key and optional numeric fallback',
            previewNoPosition,
          );
        }
        final Object? fallback = args.length == 2 ? args[1] : null;
        if (fallback != null && fallback is! double) {
          throw const PExprException(
            'metric fallback must be a number',
            previewNoPosition,
          );
        }
        final double? value = samples.metrics[args.first as String];
        if (value != null) return value;
        if (fallback != null) return fallback;
        throw PExprException(
          'unknown metric: ${args.first as String}',
          previewNoPosition,
        );
      default:
        return previewStdFunction(name, args);
    }
  }

  Object _papi(List<Object?> args, bool numeric) {
    if ((args.length != 1 && args.length != 2) || args.first is! String) {
      throw PExprException(
        '${numeric ? 'papiNumber' : 'papi'} expects a key and optional fallback',
        previewNoPosition,
      );
    }
    final Object? fallback = args.length == 2 ? args[1] : null;
    if (numeric && fallback != null && fallback is! double) {
      throw const PExprException(
        'papiNumber fallback must be a number',
        previewNoPosition,
      );
    }
    if (!numeric && fallback != null && fallback is! String) {
      throw const PExprException(
        'papi fallback must be a string',
        previewNoPosition,
      );
    }
    final String raw = args.first as String;
    final String key = raw.startsWith('%') && raw.endsWith('%')
        ? raw.substring(1, raw.length - 1)
        : raw;
    final Object? value = samples.placeholders[key];
    if (value == null) return fallback ?? '%$key%';
    if (!numeric) return previewStringify(value);
    try {
      return previewStdFunction('number', <Object?>[value])!;
    } on PExprException {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  double? _sampleNumber(String key) {
    final Object? value = samples.placeholders[key];
    return value is double ? value : null;
  }
}

/// Plain visible characters of [text]: bracket hex, `&`/`§` codes and
/// Bungee hex sequences consumed, everything else verbatim.
String _plainLength(String text) {
  final StringBuffer out = StringBuffer();
  for (final GlossTextPiece piece in _renderColors(text, <String>[])) {
    switch (piece) {
      case GlossTextRun(:final McSpan span):
        out.write(span.text);
      case GlossPlaceholderChip(:final String token):
        out.write(token);
      case GlossMetricChip(:final String token):
        out.write(token);
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Stage 1 - |function| substitution (TextPipeline.applyFunctions)
// ---------------------------------------------------------------------------

String _applyFunctions(
  String input,
  GlossAnimationResolver animations,
  int nowMs,
  List<String> used,
  List<String> missing, {
  String Function(GlossAnimationDoc doc)? frameOf,
  List<String>? metrics,
}) {
  if (!input.contains('|')) return input;
  final StringBuffer out = StringBuffer();
  int cursor = 0;
  int open = input.indexOf('|');
  bool replaced = false;
  while (open >= 0) {
    final int close = input.indexOf('|', open + 1);
    if (close < 0) break;
    final String name = input.substring(open + 1, close);
    if (name.startsWith(glossMetricFunctionPrefix) &&
        name.length > glossMetricFunctionPrefix.length) {
      // A registered name plugin-side, so the scan consumes both pipes exactly
      // as the Java one does — but the value is a live sample the editor has
      // no way to read, so the token is written back verbatim and chipped by
      // the colour stage.
      final String key = name.substring(glossMetricFunctionPrefix.length);
      if (metrics != null && !metrics.contains(key)) metrics.add(key);
      out.write(input.substring(cursor, open));
      out.write(input.substring(open, close + 1));
      replaced = true;
      cursor = close + 1;
      open = input.indexOf('|', cursor);
      continue;
    }
    if (!name.startsWith(glossAnimationFunctionPrefix)) {
      // Not a name this build registers: literal, and the closing pipe is the
      // next candidate opener — exactly the Java scan's `open = close`.
      open = close;
      continue;
    }
    final String id = name.substring(glossAnimationFunctionPrefix.length);
    final GlossAnimationDoc? doc = animations.byId(id);
    if (doc == null) {
      // The plugin would have no function registered under this name either;
      // the text stays literal, but the dangling reference is worth a
      // warning, which is the one thing the editor adds on top of the scan.
      if (!missing.contains(name)) missing.add(name);
      open = close;
      continue;
    }
    if (!used.contains(id)) used.add(id);
    out.write(input.substring(cursor, open));
    out.write(
      frameOf != null ? frameOf(doc) : glossAnimationFrameAt(doc, id, nowMs),
    );
    replaced = true;
    cursor = close + 1;
    open = input.indexOf('|', cursor);
  }
  if (!replaced) return input;
  out.write(input.substring(cursor));
  return out.toString();
}

// ---------------------------------------------------------------------------
// Stages 2 + 4 - placeholder chips and colours
// ---------------------------------------------------------------------------

/// PAPI's own token shape: `%` + one or more non-`%` characters + `%`
/// (`PlaceholderAPI.PLACEHOLDER_PATTERN`).
final RegExp _placeholderPattern = RegExp('%([^%]+)%');

/// A surviving `|metric.<key>|` token — one the function stage kept because
/// the editor has no sample for it.
///
/// The scan is positional, so a token that arrived INSIDE an animation frame
/// is chipped here too even though the plugin would leave it as text (its
/// single pass never rescans what a function substituted). Both render the
/// same characters; only the chip styling differs, and
/// [GlossLineRender.metrics] still lists only the references the line itself
/// wrote.
final RegExp _metricPattern = RegExp(r'\|metric\.([^|]+)\|');

const Map<String, int> _legacyColors = <String, int>{
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

const Set<String> _legacyDecorations = <String>{'k', 'l', 'm', 'n', 'o'};

class _ColorState {
  int color = mcDefaultTextColor;
  bool bold = false;
  bool italic = false;
  bool underlined = false;
  bool strikethrough = false;
  bool obfuscated = false;

  /// A colour code resets every decoration — vanilla legacy semantics, which
  /// is what a `TextDisplay` gives the translated string.
  void setColor(int rgb) {
    color = rgb;
    bold = false;
    italic = false;
    underlined = false;
    strikethrough = false;
    obfuscated = false;
  }

  void reset() => setColor(mcDefaultTextColor);

  McSpan span(String text) => McSpan(
    text: text,
    rgb: color,
    bold: bold,
    italic: italic,
    underlined: underlined,
    strikethrough: strikethrough,
    obfuscated: obfuscated,
  );
}

bool _isHexDigit(String char) {
  final int code = char.codeUnitAt(0);
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x61 && code <= 0x66) ||
      (code >= 0x41 && code <= 0x46);
}

/// True when `input[offset..offset+6)` is six hex digits —
/// `TextPipeline.isHex`.
bool _isBracketHex(String input, int offset) {
  if (offset + 6 > input.length) return false;
  for (int i = offset; i < offset + 6; i++) {
    if (!_isHexDigit(input[i])) return false;
  }
  return true;
}

List<GlossTextPiece> _renderColors(String input, List<String> placeholders) {
  final List<GlossTextPiece> pieces = <GlossTextPiece>[];
  final _ColorState state = _ColorState();
  final StringBuffer run = StringBuffer();

  void flushRun() {
    if (run.isEmpty) return;
    pieces.add(GlossTextRun(state.span(run.toString())));
    run.clear();
  }

  int i = 0;
  while (i < input.length) {
    final String char = input[i];

    // `[RRGGBB]` — the guard set is exactly TextPipeline.translateBracketHex:
    // a `]` at open+7 and six hex digits between.
    if (char == '[' &&
        i + 7 < input.length &&
        input[i + 7] == ']' &&
        _isBracketHex(input, i + 1)) {
      flushRun();
      state.setColor(int.parse(input.substring(i + 1, i + 7), radix: 16));
      i += 8;
      continue;
    }

    // Legacy codes. `&` is translated by the pipeline
    // (`ChatColor.translateAlternateColorCodes`), `§` is honoured by the
    // client directly; both land in the same state machine here.
    if ((char == '&' || char == '§') && i + 1 < input.length) {
      final String code = input[i + 1].toLowerCase();
      final int? rgb = _legacyColors[code];
      if (rgb != null) {
        flushRun();
        state.setColor(rgb);
        i += 2;
        continue;
      }
      if (_legacyDecorations.contains(code)) {
        flushRun();
        switch (code) {
          case 'k':
            state.obfuscated = true;
          case 'l':
            state.bold = true;
          case 'm':
            state.strikethrough = true;
          case 'n':
            state.underlined = true;
          case 'o':
            state.italic = true;
        }
        i += 2;
        continue;
      }
      if (code == 'r') {
        flushRun();
        state.reset();
        i += 2;
        continue;
      }
      if (code == 'x') {
        // Bungee hex: `§x` followed by six `§<hex digit>` pairs.
        final String? hex = _readBungeeHex(input, i + 2);
        if (hex != null) {
          flushRun();
          state.setColor(int.parse(hex, radix: 16));
          i += 2 + 12;
          continue;
        }
      }
      // An unknown code stays literal, exactly like the plugin's translate
      // step leaving `&z` alone.
    }

    // `|metric.<key>|` — the token the function stage wrote back.
    if (char == '|') {
      final Match? match = _metricPattern.matchAsPrefix(input, i);
      if (match != null) {
        flushRun();
        pieces.add(
          GlossMetricChip(
            key: match.group(1)!,
            token: match.group(0)!,
            style: state.span(''),
          ),
        );
        i = match.end;
        continue;
      }
    }

    // `%placeholder%`.
    if (char == '%') {
      final Match? match = _placeholderPattern.matchAsPrefix(input, i);
      if (match != null) {
        flushRun();
        final String token = match.group(0)!;
        placeholders.add(token);
        pieces.add(GlossPlaceholderChip(token: token, style: state.span('')));
        i = match.end;
        continue;
      }
    }

    run.write(char);
    i++;
  }
  flushRun();
  return pieces;
}

/// `TextPipeline.translateBracketHex`: every `[rrggbb]` (exactly six hex digits
/// then `]`) becomes Bungee's `§x§r§r§g§g§b§b`, which `parseMcText` then folds
/// into a `<#rrggbb>` tag the same way `TextUtils.legacyHex` does. A token that
/// fails the guard stays literal and the scan resumes at the next `[`.
String _translateBracketHex(String input) {
  if (!input.contains('[')) return input;
  StringBuffer? out;
  int cursor = 0;
  int open = input.indexOf('[');
  while (open >= 0) {
    if (open + 7 >= input.length ||
        input[open + 7] != ']' ||
        !_isBracketHex(input, open + 1)) {
      open = input.indexOf('[', open + 1);
      continue;
    }
    out ??= StringBuffer();
    out.write(input.substring(cursor, open));
    out.write(_bungeeHex(input.substring(open + 1, open + 7).toLowerCase()));
    cursor = open + 8;
    open = input.indexOf('[', cursor);
  }
  if (out == null) return input;
  out.write(input.substring(cursor));
  return out.toString();
}

/// `ChatColor.of("#rrggbb").toString()` — `§x` then one `§` per hex digit.
String _bungeeHex(String hex) {
  final StringBuffer out = StringBuffer('§x');
  for (int i = 0; i < hex.length; i++) {
    out
      ..write('§')
      ..write(hex[i]);
  }
  return out.toString();
}

String? _readBungeeHex(String input, int start) {
  final StringBuffer hex = StringBuffer();
  int i = start;
  for (int pair = 0; pair < 6; pair++) {
    if (i + 1 >= input.length) return null;
    if (input[i] != '&' && input[i] != '§') return null;
    if (!_isHexDigit(input[i + 1])) return null;
    hex.write(input[i + 1]);
    i += 2;
  }
  return hex.toString();
}
