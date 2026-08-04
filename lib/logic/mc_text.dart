/// Minecraft text parsing for the HoloUI editor preview.
///
/// Mirrors the plugin pipeline in `util/common/TextUtils.java` exactly:
///
///   1. `ChatColor.translateAlternateColorCodes('&', text)` turns `&<code>`
///      into `§<lowercase code>`.
///   2. every `§<code>` is string-replaced with `<bungeeName>`.
///   3. the result is handed to MiniMessage.
///
/// Step 2 produces two tags MiniMessage does not know: `&n` becomes
/// `<underline>` (MiniMessage wants `underlined`/`u`) and `&k` becomes
/// `<magic>` (MiniMessage wants `obfuscated`/`obf`). Both survive as literal
/// text in game. That bug is reproduced here on purpose, with a warning.
///
/// Line splitting happens BEFORE parsing (`TextMenuIcon` splits on `\n` and
/// parses each line on its own), so tag state never carries across lines.
/// Splitting follows Java's `String.split` semantics, which drop trailing
/// empty parts: `"a\n"` is one line, `"\n"` is zero lines, `""` is one line.
library;

/// Colour applied to text with no colour tag in scope.
const int mcDefaultTextColor = 0xFFFFFF;

/// The 16 vanilla named colours, keyed by their MiniMessage tag name.
const Map<String, int> mcNamedColors = <String, int>{
  'black': 0x000000,
  'dark_blue': 0x0000AA,
  'dark_green': 0x00AA00,
  'dark_aqua': 0x00AAAA,
  'dark_red': 0xAA0000,
  'dark_purple': 0xAA00AA,
  'gold': 0xFFAA00,
  'gray': 0xAAAAAA,
  'dark_gray': 0x555555,
  'blue': 0x5555FF,
  'green': 0x55FF55,
  'aqua': 0x55FFFF,
  'red': 0xFF5555,
  'light_purple': 0xFF55FF,
  'yellow': 0xFFFF55,
  'white': 0xFFFFFF,
};

/// Resolves a MiniMessage colour name, honouring the `grey` spellings.
int? mcNamedColor(String name) {
  final String key = name.toLowerCase();
  final int? direct = mcNamedColors[key];
  if (direct != null) {
    return direct;
  }
  if (key == 'grey') {
    return mcNamedColors['gray'];
  }
  if (key == 'dark_grey') {
    return mcNamedColors['dark_gray'];
  }
  return null;
}

/// A run of characters that share one resolved style.
class McSpan {
  const McSpan({
    required this.text,
    this.rgb,
    this.bold = false,
    this.italic = false,
    this.underlined = false,
    this.strikethrough = false,
    this.obfuscated = false,
  });

  final String text;

  /// Always populated by [parseMcText]; unstyled text carries
  /// [mcDefaultTextColor]. Nullable so callers may build partial spans.
  final int? rgb;

  final bool bold;
  final bool italic;
  final bool underlined;
  final bool strikethrough;
  final bool obfuscated;

  /// Colour with the default already applied.
  int get color => rgb ?? mcDefaultTextColor;

  /// True when any decoration is set.
  bool get isStyled => bold || italic || underlined || strikethrough || obfuscated;

  McSpan withText(String value) => McSpan(
        text: value,
        rgb: rgb,
        bold: bold,
        italic: italic,
        underlined: underlined,
        strikethrough: strikethrough,
        obfuscated: obfuscated,
      );

  @override
  bool operator ==(Object other) =>
      other is McSpan &&
      other.text == text &&
      other.rgb == rgb &&
      other.bold == bold &&
      other.italic == italic &&
      other.underlined == underlined &&
      other.strikethrough == strikethrough &&
      other.obfuscated == obfuscated;

  @override
  int get hashCode => Object.hash(text, rgb, bold, italic, underlined, strikethrough, obfuscated);

  @override
  String toString() {
    final StringBuffer flags = StringBuffer();
    if (bold) flags.write(' bold');
    if (italic) flags.write(' italic');
    if (underlined) flags.write(' underlined');
    if (strikethrough) flags.write(' strikethrough');
    if (obfuscated) flags.write(' obfuscated');
    final String hex = color.toRadixString(16).padLeft(6, '0').toUpperCase();
    return 'McSpan("$text", #$hex$flags)';
  }
}

/// One parsed text icon: the styled lines plus authoring warnings.
class McTextResult {
  const McTextResult({required this.lines, required this.warnings});

  /// One entry per rendered `TextDisplay` line. May be empty (see the library
  /// doc for the Java split semantics).
  final List<List<McSpan>> lines;

  /// Deduplicated, human-readable authoring warnings.
  final List<String> warnings;

  int get lineCount => lines.length;

  bool get hasWarnings => warnings.isNotEmpty;

  List<String> get plainLines => lines
      .map((List<McSpan> line) => line.map((McSpan span) => span.text).join())
      .toList(growable: false);

  String get plainText => plainLines.join('\n');

  /// Widest line in plain characters. The plugin's hitbox width uses exactly
  /// this count (`TextUtils.content(component).length()`).
  int get maxLineLength {
    int widest = 0;
    for (final String line in plainLines) {
      if (line.length > widest) {
        widest = line.length;
      }
    }
    return widest;
  }
}

/// Parses a HoloUI text icon string into styled lines.
McTextResult parseMcText(String raw) {
  // A set literal is a LinkedHashSet, so warning order stays stable.
  final Set<String> warnings = <String>{};
  final List<List<McSpan>> lines = <List<McSpan>>[];
  for (final String line in _splitLines(raw)) {
    final String miniMessage = _legacyToMiniMessage(line);
    final List<_Node> nodes = _classify(_tokenize(miniMessage), warnings);
    lines.add(_render(nodes, warnings));
  }
  return McTextResult(
    lines: List<List<McSpan>>.unmodifiable(lines),
    warnings: List<String>.unmodifiable(warnings),
  );
}

// ---------------------------------------------------------------------------
// Stage 1 - line splitting and legacy code translation
// ---------------------------------------------------------------------------

/// Java `String.split("\n")`: no match returns the whole input, a match drops
/// trailing empty parts.
List<String> _splitLines(String raw) {
  if (!raw.contains('\n')) {
    return <String>[raw];
  }
  final List<String> parts = raw.split('\n');
  int end = parts.length;
  while (end > 0 && parts[end - 1].isEmpty) {
    end--;
  }
  return parts.sublist(0, end);
}

const int _ampersand = 0x26;
const int _sectionSign = 0xA7;

/// Bukkit's `ChatColor.ALL_CODES`, as code units.
final Set<int> _legacyCodeUnits =
    Set<int>.unmodifiable('0123456789AaBbCcDdEeFfKkLlMmNnOoRrXx'.codeUnits);

/// Bukkit `ChatColor` -> `color.asBungee().getName()`. `n` and `k` produce tags
/// MiniMessage does not know; that is the in-game bug.
const Map<String, String> _sectionCodeTags = <String, String>{
  '0': 'black',
  '1': 'dark_blue',
  '2': 'dark_green',
  '3': 'dark_aqua',
  '4': 'dark_red',
  '5': 'dark_purple',
  '6': 'gold',
  '7': 'gray',
  '8': 'dark_gray',
  '9': 'blue',
  'a': 'green',
  'b': 'aqua',
  'c': 'red',
  'd': 'light_purple',
  'e': 'yellow',
  'f': 'white',
  'k': 'magic',
  'l': 'bold',
  'm': 'strikethrough',
  'n': 'underline',
  'o': 'italic',
  'r': 'reset',
};

String _legacyToMiniMessage(String line) => _replaceSectionCodes(_translateAmpersands(line));

/// `ChatColor.translateAlternateColorCodes('&', text)` character for character,
/// including its inability to escape and its trailing-character blind spot.
String _translateAmpersands(String line) {
  if (line.length < 2) {
    return line;
  }
  final List<int> units = List<int>.of(line.codeUnits);
  for (int i = 0; i < units.length - 1; i++) {
    if (units[i] != _ampersand) {
      continue;
    }
    final int next = units[i + 1];
    if (!_legacyCodeUnits.contains(next)) {
      continue;
    }
    units[i] = _sectionSign;
    units[i + 1] = (next >= 0x41 && next <= 0x5A) ? next + 32 : next;
  }
  return String.fromCharCodes(units);
}

/// Unmapped codes (only `§x` in practice) stay literal, exactly as the
/// plugin's replacement map leaves them.
String _replaceSectionCodes(String line) {
  if (!line.contains('§')) {
    return line;
  }
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < line.length; i++) {
    if (line.codeUnitAt(i) == _sectionSign && i + 1 < line.length) {
      final String? tag = _sectionCodeTags[line[i + 1]];
      if (tag != null) {
        out.write('<$tag>');
        i++;
        continue;
      }
    }
    out.write(line[i]);
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Stage 2 - tokenizing
// ---------------------------------------------------------------------------

sealed class _Node {
  const _Node();
}

class _TextNode extends _Node {
  const _TextNode(this.text);

  final String text;
}

class _TagNode extends _Node {
  const _TagNode({
    required this.raw,
    required this.name,
    required this.args,
    required this.closing,
  });

  /// The tag exactly as written, used when it turns out to be unknown.
  final String raw;

  /// Lowercased tag name with the arguments stripped.
  final String name;

  final List<String> args;
  final bool closing;

  /// Lowercased `name:arg:arg`, the key MiniMessage matches closing tags on.
  String get key => args.isEmpty ? name : '$name:${args.join(':')}'.toLowerCase();
}

final RegExp _tagNamePattern = RegExp(r'^[a-z0-9_#!./-]+$');
final RegExp _whitespacePattern = RegExp(r'\s');

List<_Node> _tokenize(String input) {
  final List<_Node> out = <_Node>[];
  final StringBuffer text = StringBuffer();
  int i = 0;
  while (i < input.length) {
    if (input.codeUnitAt(i) == 0x3C) {
      final _TagNode? tag = _readTag(input, i);
      if (tag != null) {
        if (text.isNotEmpty) {
          out.add(_TextNode(text.toString()));
          text.clear();
        }
        out.add(tag);
        i += tag.raw.length;
        continue;
      }
    }
    text.write(input[i]);
    i++;
  }
  if (text.isNotEmpty) {
    out.add(_TextNode(text.toString()));
  }
  return out;
}

_TagNode? _readTag(String input, int start) {
  final int end = input.indexOf('>', start + 1);
  if (end < 0) {
    return null;
  }
  String inner = input.substring(start + 1, end);
  if (inner.isEmpty || inner.contains('<')) {
    return null;
  }
  final bool closing = inner.startsWith('/');
  if (closing) {
    inner = inner.substring(1);
  }
  if (inner.isEmpty) {
    return null;
  }
  final List<String> parts = inner.split(':');
  final String name = parts.first.toLowerCase();
  if (!_tagNamePattern.hasMatch(name)) {
    return null;
  }
  final List<String> args = parts.sublist(1);
  for (final String arg in args) {
    if (arg.isEmpty || arg.contains(_whitespacePattern)) {
      return null;
    }
  }
  return _TagNode(
    raw: input.substring(start, end + 1),
    name: name,
    args: args,
    closing: closing,
  );
}

// ---------------------------------------------------------------------------
// Stage 3 - tag classification
// ---------------------------------------------------------------------------

enum _Deco { bold, italic, underlined, strikethrough, obfuscated }

const Map<String, _Deco> _decorationTags = <String, _Deco>{
  'bold': _Deco.bold,
  'b': _Deco.bold,
  'italic': _Deco.italic,
  'em': _Deco.italic,
  'i': _Deco.italic,
  'underlined': _Deco.underlined,
  'u': _Deco.underlined,
  'strikethrough': _Deco.strikethrough,
  'st': _Deco.strikethrough,
  'obfuscated': _Deco.obfuscated,
  'obf': _Deco.obfuscated,
};

const Set<String> _colorTagNames = <String>{'color', 'colour', 'c'};
const String _gradientTag = 'gradient';
const String _resetTag = 'reset';

/// Replaces every unrecognised tag with the literal text MiniMessage would
/// leave behind, recording one warning per distinct problem.
List<_Node> _classify(List<_Node> nodes, Set<String> warnings) {
  final List<_Node> out = <_Node>[];
  for (final _Node node in nodes) {
    if (node is! _TagNode) {
      out.add(node);
      continue;
    }
    if (_isKnownTag(node)) {
      out.add(node);
      continue;
    }
    warnings.add(_unknownTagWarning(node));
    out.add(_TextNode(node.raw));
  }
  return out;
}

bool _isKnownTag(_TagNode tag) {
  if (tag.closing) {
    return tag.name == _gradientTag ||
        tag.name == _resetTag ||
        _colorTagNames.contains(tag.name) ||
        _decorationTags.containsKey(tag.name) ||
        mcNamedColor(tag.name) != null ||
        _parseHex(tag.name) != null;
  }
  if (tag.name == _resetTag && tag.args.isEmpty) {
    return true;
  }
  return _resolveOpen(tag) != null;
}

String _unknownTagWarning(_TagNode tag) {
  if (!tag.closing && tag.args.isEmpty && tag.name == 'underline') {
    return 'Legacy code &n becomes <underline>, which MiniMessage does not recognise - '
        'it renders as literal text in game. Use <underlined> or <u> instead.';
  }
  if (!tag.closing && tag.args.isEmpty && tag.name == 'magic') {
    return 'Legacy code &k becomes <magic>, which MiniMessage does not recognise - '
        'it renders as literal text in game. Use <obfuscated> or <obf> instead.';
  }
  return 'Unknown tag ${tag.raw} renders as literal text.';
}

// ---------------------------------------------------------------------------
// Stage 4 - colours and gradients
// ---------------------------------------------------------------------------

int? _parseHex(String value) {
  if (!value.startsWith('#')) {
    return null;
  }
  final String digits = value.substring(1);
  if (digits.length == 3) {
    final int? short = int.tryParse(digits, radix: 16);
    if (short == null) {
      return null;
    }
    final int r = (short >> 8) & 0xF;
    final int g = (short >> 4) & 0xF;
    final int b = short & 0xF;
    return (r * 0x11) << 16 | (g * 0x11) << 8 | (b * 0x11);
  }
  if (digits.length != 6) {
    return null;
  }
  return int.tryParse(digits, radix: 16);
}

int? _parseColorArg(String value) => value.startsWith('#') ? _parseHex(value) : mcNamedColor(value);

int _lerpRgb(int from, int to, double t) {
  final double clamped = t < 0 ? 0 : (t > 1 ? 1 : t);
  final int r = _lerpChannel((from >> 16) & 0xFF, (to >> 16) & 0xFF, clamped);
  final int g = _lerpChannel((from >> 8) & 0xFF, (to >> 8) & 0xFF, clamped);
  final int b = _lerpChannel(from & 0xFF, to & 0xFF, clamped);
  return r << 16 | g << 8 | b;
}

int _lerpChannel(int from, int to, double t) => (from + t * (to - from)).round();

class _GradientRun {
  _GradientRun(this.stops, this.phase);

  final List<int> stops;
  final double phase;

  /// Characters inside the gradient's scope, resolved when it is opened.
  int total = 0;

  /// Characters already emitted inside the gradient.
  int index = 0;

  int colorAt(int position) {
    double t = total <= 1 ? 0.0 : position / (total - 1);
    if (phase != 0) {
      t = (t + phase) % 1.0;
      if (t < 0) {
        t += 1.0;
      }
    }
    if (t <= 0) {
      return stops.first;
    }
    if (t >= 1) {
      return stops.last;
    }
    final double scaled = t * (stops.length - 1);
    int segment = scaled.floor();
    if (segment >= stops.length - 1) {
      segment = stops.length - 2;
    }
    return _lerpRgb(stops[segment], stops[segment + 1], scaled - segment);
  }
}

_GradientRun? _buildGradient(List<String> args) {
  List<String> colorArgs = args;
  double phase = 0;
  if (args.isNotEmpty && _parseColorArg(args.last) == null) {
    final double? parsed = double.tryParse(args.last);
    if (parsed == null) {
      return null;
    }
    phase = parsed.clamp(-1.0, 1.0);
    colorArgs = args.sublist(0, args.length - 1);
  }
  List<int> stops = <int>[];
  for (final String arg in colorArgs) {
    final int? color = _parseColorArg(arg);
    if (color == null) {
      return null;
    }
    stops.add(color);
  }
  if (stops.isEmpty) {
    stops = <int>[0xFFFFFF, 0x000000];
  }
  if (stops.length < 2) {
    return null;
  }
  if (phase < 0) {
    phase = 1 + phase;
    stops = stops.reversed.toList();
  }
  return _GradientRun(stops, phase);
}

// ---------------------------------------------------------------------------
// Stage 5 - rendering
// ---------------------------------------------------------------------------

class _Frame {
  _Frame({required this.key, this.color, this.gradient, this.deco});

  final String key;
  final int? color;
  final _GradientRun? gradient;
  final _Deco? deco;
}

class _Style {
  const _Style({
    required this.rgb,
    required this.bold,
    required this.italic,
    required this.underlined,
    required this.strikethrough,
    required this.obfuscated,
  });

  final int rgb;
  final bool bold;
  final bool italic;
  final bool underlined;
  final bool strikethrough;
  final bool obfuscated;

  @override
  bool operator ==(Object other) =>
      other is _Style &&
      other.rgb == rgb &&
      other.bold == bold &&
      other.italic == italic &&
      other.underlined == underlined &&
      other.strikethrough == strikethrough &&
      other.obfuscated == obfuscated;

  @override
  int get hashCode => Object.hash(rgb, bold, italic, underlined, strikethrough, obfuscated);
}

_Frame? _resolveOpen(_TagNode tag) {
  if (tag.args.isEmpty) {
    final int? named = mcNamedColor(tag.name);
    if (named != null) {
      return _Frame(key: tag.key, color: named);
    }
    final int? hex = _parseHex(tag.name);
    if (hex != null) {
      return _Frame(key: tag.key, color: hex);
    }
    final _Deco? deco = _decorationTags[tag.name];
    if (deco != null) {
      return _Frame(key: tag.key, deco: deco);
    }
    if (tag.name == _gradientTag) {
      final _GradientRun? gradient = _buildGradient(const <String>[]);
      return gradient == null ? null : _Frame(key: tag.key, gradient: gradient);
    }
    return null;
  }
  if (_colorTagNames.contains(tag.name) && tag.args.length == 1) {
    final int? color = _parseColorArg(tag.args.first);
    return color == null ? null : _Frame(key: tag.key, color: color);
  }
  if (tag.name == _gradientTag) {
    final _GradientRun? gradient = _buildGradient(tag.args);
    return gradient == null ? null : _Frame(key: tag.key, gradient: gradient);
  }
  return null;
}

/// MiniMessage's `TokenParser.tagCloses`: exact match, or a prefix that ends on
/// an argument separator (`</color>` closes `<color:red>`).
bool _tagCloses(String closeKey, String openKey) =>
    closeKey == openKey ||
    (closeKey.length < openKey.length &&
        openKey.codeUnitAt(closeKey.length) == 0x3A &&
        openKey.startsWith(closeKey));

_Style _resolveStyle(List<_Frame> stack) {
  int rgb = mcDefaultTextColor;
  bool bold = false;
  bool italic = false;
  bool underlined = false;
  bool strikethrough = false;
  bool obfuscated = false;
  for (final _Frame frame in stack) {
    if (frame.color != null) {
      rgb = frame.color!;
    }
    final _GradientRun? gradient = frame.gradient;
    if (gradient != null) {
      rgb = gradient.colorAt(gradient.index);
    }
    switch (frame.deco) {
      case _Deco.bold:
        bold = true;
      case _Deco.italic:
        italic = true;
      case _Deco.underlined:
        underlined = true;
      case _Deco.strikethrough:
        strikethrough = true;
      case _Deco.obfuscated:
        obfuscated = true;
      case null:
        break;
    }
  }
  return _Style(
    rgb: rgb,
    bold: bold,
    italic: italic,
    underlined: underlined,
    strikethrough: strikethrough,
    obfuscated: obfuscated,
  );
}

/// Characters a gradient will colour: everything up to its own closing tag, a
/// `<reset>`, the close of an enclosing tag, or the end of the line.
int _countGradientChars(List<_Node> nodes, int openIndex, List<String> ancestorKeys) {
  int depth = 0;
  int count = 0;
  for (int i = openIndex + 1; i < nodes.length; i++) {
    final _Node node = nodes[i];
    if (node is _TextNode) {
      count += node.text.runes.length;
      continue;
    }
    final _TagNode tag = node as _TagNode;
    if (!tag.closing && tag.name == _resetTag) {
      break;
    }
    if (tag.name == _gradientTag) {
      if (!tag.closing) {
        depth++;
        continue;
      }
      if (depth == 0) {
        break;
      }
      depth--;
      continue;
    }
    if (tag.closing &&
        depth == 0 &&
        ancestorKeys.any((String key) => _tagCloses(tag.key, key))) {
      break;
    }
  }
  return count;
}

List<McSpan> _render(List<_Node> nodes, Set<String> warnings) {
  final List<_Frame> stack = <_Frame>[];
  final List<McSpan> spans = <McSpan>[];
  final StringBuffer buffer = StringBuffer();
  _Style? current;

  void flush() {
    if (buffer.isEmpty) {
      return;
    }
    final _Style style = current!;
    spans.add(McSpan(
      text: buffer.toString(),
      rgb: style.rgb,
      bold: style.bold,
      italic: style.italic,
      underlined: style.underlined,
      strikethrough: style.strikethrough,
      obfuscated: style.obfuscated,
    ));
    buffer.clear();
  }

  void emit(String text, _Style style) {
    if (current == null || current != style) {
      flush();
      current = style;
    }
    buffer.write(text);
  }

  void writeText(String text) {
    if (text.isEmpty) {
      return;
    }
    if (!stack.any((_Frame frame) => frame.gradient != null)) {
      emit(text, _resolveStyle(stack));
      return;
    }
    for (final int rune in text.runes) {
      emit(String.fromCharCode(rune), _resolveStyle(stack));
      for (final _Frame frame in stack) {
        final _GradientRun? gradient = frame.gradient;
        if (gradient != null) {
          gradient.index++;
        }
      }
    }
  }

  for (int i = 0; i < nodes.length; i++) {
    final _Node node = nodes[i];
    if (node is _TextNode) {
      writeText(node.text);
      continue;
    }
    final _TagNode tag = node as _TagNode;
    if (!tag.closing && tag.name == _resetTag) {
      stack.clear();
      continue;
    }
    if (tag.closing) {
      final int index = stack.lastIndexWhere((_Frame frame) => _tagCloses(tag.key, frame.key));
      if (index < 0) {
        warnings.add('Closing tag ${tag.raw} has no matching opening tag.');
        continue;
      }
      stack.removeRange(index, stack.length);
      continue;
    }
    final _Frame? frame = _resolveOpen(tag);
    if (frame == null) {
      continue;
    }
    final _GradientRun? gradient = frame.gradient;
    if (gradient != null) {
      gradient.total = _countGradientChars(
        nodes,
        i,
        stack.map((_Frame f) => f.key).toList(growable: false),
      );
    }
    stack.add(frame);
  }

  flush();
  return List<McSpan>.unmodifiable(spans);
}
