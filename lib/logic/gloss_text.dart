/// Mirror of Gloss `TextPipeline.java` for the editor's authored text
/// surfaces.
///
/// The plugin renders every authored line through five ordered stages
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
///  2. `{{ expression }}` evaluation with native player/server/time values,
///     PAPI and integration-metric samples.
///  3. `%placeholder%` PAPI expansion — the editor cannot run PAPI, so tokens
///     become chips instead of values.
///  4. Emoji substitution (`EmojiReplacer.apply` via the pipeline's emoji
///     filter, `EmojiService.enable`): `:id:` tokens and triggers become the
///     resolved glyphs. The editor's [GlossEmojiResolver] merges the shipped
///     catalog with the workspace's emoji documents. One honest divergence:
///     the plugin substitutes AFTER placeholders expand, but the editor
///     keeps placeholder tokens literal, so a trigger inside an expanded
///     placeholder value cannot be seen here.
///  5. Colours: `[RRGGBB]` bracket hex (exactly six hex digits then `]`,
///     `TextPipeline.translateBracketHex`), then legacy `&` codes via
///     `ChatColor.translateAlternateColorCodes` and the client's `§` state
///     machine — a colour code resets the decorations, `&r` resets
///     everything, and Bungee's `§x§R§R§G§G§B§B` hex form is honoured.
///
/// Menu text icons use this same pipeline. [glossRenderMenuText] returns its
/// string form for `TextUtils.parse`; unresolved PAPI stays literal because
/// the browser has no live PlaceholderAPI server.
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
/// (hologram, scoreboard, tablist, motd, bubble prefixes and menus) run the
/// full pipeline and therefore resolve these.
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
}) => _renderGlossLine(
  raw,
  animations: animations,
  emoji: emoji,
  nowMs: nowMs,
  expressionSamples: expressionSamples,
);

GlossLineRender renderGlossAnimationFramePreview(
  String raw, {
  GlossEmojiResolver emoji = const GlossNoEmoji(),
}) {
  final GlossLineRender rendered = renderGlossLine(raw, emoji: emoji);
  final bool hasVisibleContent = rendered.pieces.any(
    (GlossTextPiece piece) => switch (piece) {
      GlossTextRun(:final McSpan span) => span.text.isNotEmpty,
      GlossPlaceholderChip() || GlossMetricChip() => true,
    },
  );
  return hasVisibleContent
      ? rendered
      : renderGlossLine('$raw&lRAINBOW', emoji: emoji);
}

GlossLineRender renderGlossScoreboardTitle(
  String raw, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
  GlossTextExpressionSamples expressionSamples =
      const GlossTextExpressionSamples(),
}) => _renderGlossLine(
  raw,
  animations: animations,
  emoji: emoji,
  nowMs: nowMs,
  expressionSamples: expressionSamples,
  runtimeTransform: _limitScoreboardTitle,
);

GlossLineRender renderGlossScoreboardLine(
  String raw, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
  GlossTextExpressionSamples expressionSamples =
      const GlossTextExpressionSamples(),
}) => _renderGlossLine(
  raw,
  animations: animations,
  emoji: emoji,
  nowMs: nowMs,
  expressionSamples: expressionSamples,
  runtimeTransform: _limitScoreboardLine,
);

GlossScoreboardLineMeasure measureGlossScoreboardLine(
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
    frameOf: (GlossAnimationDoc doc) => _longestRuntimeFrame(doc.frames),
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
  final String translated = _normalizeScoreboardCharacters(
    _translateRuntimeColors(substituted),
  );
  final _ScoreboardLineFit fit = _fitScoreboardLine(translated);
  return GlossScoreboardLineMeasure(
    encodedLength: translated.length,
    visibleLength: _plainLength(translated).length,
    deliveredVisibleLength: _plainLength(fit.text).length,
    truncated: fit.truncated,
  );
}

final class GlossScoreboardLineMeasure {
  const GlossScoreboardLineMeasure({
    required this.encodedLength,
    required this.visibleLength,
    required this.deliveredVisibleLength,
    required this.truncated,
  });

  final int encodedLength;
  final int visibleLength;
  final int deliveredVisibleLength;
  final bool truncated;
}

GlossLineRender _renderGlossLine(
  String raw, {
  required GlossAnimationResolver animations,
  required GlossEmojiResolver emoji,
  required int nowMs,
  required GlossTextExpressionSamples expressionSamples,
  String Function(String value)? runtimeTransform,
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
  String substituted = glossApplyEmoji(
    _applyTextExpressions(
      functions,
      nowMs,
      expressionSamples,
      expressions,
      expressionErrors,
    ),
    emoji,
  );
  if (runtimeTransform != null) {
    substituted = runtimeTransform(substituted);
  }
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

String _limitScoreboardTitle(String value) {
  final String translated = _normalizeScoreboardCharacters(
    _translateRuntimeColors(value),
  );
  return translated.substring(0, _safeLegacyBoundary(translated, 32));
}

String _limitScoreboardLine(String value) =>
    _fitScoreboardLine(_translateRuntimeColors(value)).text;

_ScoreboardLineFit _fitScoreboardLine(String input) {
  final String normalized = _normalizeScoreboardCharacters(input);
  final int lineEnd = _safeLegacyBoundary(normalized, 32);
  final String line = normalized.substring(0, lineEnd);
  bool truncated = lineEnd < normalized.length;
  if (line.length <= 16) {
    return _ScoreboardLineFit(text: line, truncated: truncated);
  }

  final int prefixEnd = _safeLegacyBoundary(line, 16);
  final String prefix = line.substring(0, prefixEnd);
  final String completeSuffix =
      _lastLegacyColors(prefix) + line.substring(prefixEnd);
  final int suffixEnd = _safeLegacyBoundary(completeSuffix, 16);
  truncated = truncated || suffixEnd < completeSuffix.length;
  return _ScoreboardLineFit(
    text: prefix + completeSuffix.substring(0, suffixEnd),
    truncated: truncated,
  );
}

String _normalizeScoreboardCharacters(String input) {
  final StringBuffer out = StringBuffer();
  int index = 0;
  while (index < input.length) {
    final int codeUnit = input.codeUnitAt(index);
    if (_isHighSurrogate(codeUnit)) {
      if (index + 1 < input.length &&
          _isLowSurrogate(input.codeUnitAt(index + 1))) {
        out.write(input.substring(index, index + 2));
        index += 2;
        continue;
      }
      index++;
      continue;
    }
    if (_isLowSurrogate(codeUnit)) {
      index++;
      continue;
    }
    if (codeUnit == 0x0D ||
        codeUnit == 0x0A ||
        codeUnit == 0x2028 ||
        codeUnit == 0x2029) {
      out.write(' ');
      if (codeUnit == 0x0D &&
          index + 1 < input.length &&
          input.codeUnitAt(index + 1) == 0x0A) {
        index++;
      }
      index++;
      continue;
    }
    out.writeCharCode(codeUnit);
    index++;
  }
  return out.toString();
}

int _safeLegacyBoundary(String input, int maximum) {
  int end = input.length < maximum ? input.length : maximum;
  if (end > 0 &&
      _isHighSurrogate(input.codeUnitAt(end - 1)) &&
      (end == input.length || _isLowSurrogate(input.codeUnitAt(end)))) {
    end--;
  }

  int index = 0;
  while (index < end) {
    if (input[index] != '§') {
      index++;
      continue;
    }
    final int tokenLength = _completeBungeeHexAt(input, index) ? 14 : 2;
    if (index + tokenLength > end) {
      return index;
    }
    index += tokenLength;
  }
  return end;
}

bool _completeBungeeHexAt(String input, int start) {
  if (start + 14 > input.length ||
      input[start] != '§' ||
      input[start + 1].toLowerCase() != 'x') {
    return false;
  }
  for (int index = start + 2; index < start + 14; index += 2) {
    if (input[index] != '§' || !_isHexDigit(input[index + 1])) {
      return false;
    }
  }
  return true;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

String _lastLegacyColors(String input) {
  final StringBuffer formats = StringBuffer();
  for (int index = input.length - 2; index >= 0; index--) {
    if (input[index] != '§') continue;
    final String code = input[index + 1].toLowerCase();
    if (_legacyDecorations.contains(code)) {
      formats.write('§$code');
      continue;
    }
    if (code == 'r') {
      return '§r${_reverseLegacyCodes(formats.toString())}';
    }
    if (_legacyColors.containsKey(code)) {
      final String? hex = _bungeeHexEndingAt(input, index + 1);
      final String color = hex ?? '§$code';
      return color + _reverseLegacyCodes(formats.toString());
    }
  }
  return _reverseLegacyCodes(formats.toString());
}

String? _bungeeHexEndingAt(String input, int digitIndex) {
  final int start = digitIndex - 13;
  if (start < 0 ||
      input[start] != '§' ||
      input[start + 1].toLowerCase() != 'x') {
    return null;
  }
  for (int index = start + 2; index <= digitIndex; index += 2) {
    if (input[index] != '§' || !_isHexDigit(input[index + 1])) {
      return null;
    }
  }
  return input.substring(start, digitIndex + 1);
}

String _reverseLegacyCodes(String reversed) {
  if (reversed.isEmpty) return '';
  final StringBuffer out = StringBuffer();
  for (int index = reversed.length - 2; index >= 0; index -= 2) {
    out.write(reversed.substring(index, index + 2));
  }
  return out.toString();
}

String _longestRuntimeFrame(List<String> frames) {
  String longest = '';
  int longestLength = 0;
  for (final String frame in frames) {
    final int length = _normalizeScoreboardCharacters(
      _translateRuntimeColors(frame),
    ).length;
    if (length > longestLength) {
      longest = frame;
      longestLength = length;
    }
  }
  return longest;
}

String _translateRuntimeColors(String input) {
  final String bracketHex = _translateBracketHex(input);
  if (!bracketHex.contains('&')) return bracketHex;
  final StringBuffer out = StringBuffer();
  int index = 0;
  while (index < bracketHex.length) {
    final String char = bracketHex[index];
    if (char == '&' && index + 1 < bracketHex.length) {
      final String code = bracketHex[index + 1].toLowerCase();
      if (_legacyColors.containsKey(code) ||
          _legacyDecorations.contains(code) ||
          code == 'r' ||
          code == 'x') {
        out.write('§$code');
        index += 2;
        continue;
      }
    }
    out.write(char);
    index++;
  }
  return out.toString();
}

final class _ScoreboardLineFit {
  const _ScoreboardLineFit({required this.text, required this.truncated});

  final String text;
  final bool truncated;
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
/// `TextUtils.parse`. It now delegates to the full viewer-aware pipeline:
/// functions, inline expressions, raw PAPI, emoji, then colours.
///
/// The plugin's colour step also rewrites `&` codes to `§`, which is a no-op
/// here: `parseMcText` mirrors `TextUtils.translateLegacy`, which reads both
/// markers identically.
String glossRenderMenuText(
  String raw, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
  GlossTextExpressionSamples expressionSamples =
      const GlossTextExpressionSamples(),
}) {
  if (raw.isEmpty) return '';
  final String functions = _applyFunctions(
    raw,
    animations,
    nowMs,
    <String>[],
    <String>[],
  );
  final String expressions = _applyTextExpressions(
    functions,
    nowMs,
    expressionSamples,
    <String>[],
    <String>[],
  );
  return _translateBracketHex(glossApplyEmoji(expressions, emoji));
}

bool glossMenuTextNeedsRefresh(String raw) {
  if (raw.isEmpty) return false;
  final int expression = raw.indexOf('{{');
  if (expression >= 0 && raw.indexOf('}}', expression + 2) >= 0) return true;
  return _hasDelimitedToken(raw, '%') || _hasDelimitedToken(raw, '|');
}

bool _hasDelimitedToken(String raw, String marker) {
  final int opening = raw.indexOf(marker);
  return opening >= 0 && raw.indexOf(marker, opening + 1) > opening + 1;
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
/// client consumes the codes — the string VolmLib safely caps for a board
/// title. Every `&` code still counts 2 characters and every `[RRGGBB]`
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
    frameOf: (GlossAnimationDoc doc) => _longestRuntimeFrame(doc.frames),
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
  return _normalizeScoreboardCharacters(
    _translateRuntimeColors(substituted),
  ).length;
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
  final GlossTextExpressionScope scope = GlossTextExpressionScope(
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

final class GlossTextExpressionScope extends PExprScope {
  GlossTextExpressionScope(this.nowMs, this.samples, {this.viewerAware = true});

  final int nowMs;
  final GlossTextExpressionSamples samples;
  final bool viewerAware;

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
        return viewerAware ? samples.placeholders['player_name'] : null;
      case 'player.ping':
        return viewerAware ? _sampleNumber('player_ping') : null;
      case 'player.health':
        return viewerAware ? _sampleNumber('player_health') : null;
      case 'player.level':
        return viewerAware ? _sampleNumber('player_level') : null;
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
    final Object? value = viewerAware
        ? samples.placeholders[key]
        : _viewerlessNativeValue(key);
    if (value == null) {
      if (fallback != null) return fallback;
      if (numeric) {
        if (viewerAware) {
          return previewStdFunction('number', <Object?>['%$key%'])!;
        }
        throw const PExprException(
          'papiNumber requires a player-backed surface',
          previewNoPosition,
        );
      }
      return '%$key%';
    }
    if (!numeric) return previewStringify(value);
    try {
      return previewStdFunction('number', <Object?>[value])!;
    } on PExprException {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Object? _viewerlessNativeValue(String key) => switch (key) {
    'server_online' => variable('server.online'),
    'server_max_players' => variable('server.maxPlayers'),
    'server_tps' => variable('server.tps'),
    _ => null,
  };

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
