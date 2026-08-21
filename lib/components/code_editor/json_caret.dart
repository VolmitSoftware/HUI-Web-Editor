/// Where a caret is, in JSON-path terms, in a buffer that may not parse.
///
/// The code view cannot use `jsonDecode` for this: the buffer is invalid for as
/// long as the user is mid-keystroke, and that is exactly when completion is
/// asked for. So this walks [tokenizeJson]'s output — which never throws and
/// never rejects — with a small brace/bracket state machine and reports what
/// container the caret sits in, whether the slot under it is a key or a value,
/// and what partial text is already typed.
///
/// Two deliberate approximations, both bounded:
///   1. The slot under the caret is a quoted token when the caret is inside
///      one, and a character scan otherwise — a number or a half-typed literal
///      is not a token yet. Either way the state machine is then run only over
///      the tokens that END AT OR BEFORE that slot, so the thing being edited
///      never feeds the machine and cannot desync it.
///   2. The `type` discriminator of an enclosing object is normally read on the
///      way in, since every model in this repo serializes `type` first. The
///      scan continues past the caret to EOF to pick up a `type` written after
///      it, which is best-effort: resuming the machine after skipping the
///      partial word can desync on badly broken text. A missed tag costs the
///      variant's extra keys in one completion, never a wrong answer — an
///      unknown tag resolves to the fields every variant shares.
///
/// Pure Dart; no DOM. `json_caret_test.dart` is the contract.
library;

import '../../logic/json_schema.dart';
import 'json_highlight.dart';

/// What the caret is sitting on.
enum JsonCaretSlot {
  /// A key, or the empty space where one belongs.
  key,

  /// A value, or the empty space after a `:` or inside a list.
  value,

  /// Nowhere either belongs — between a value and its comma, or outside the
  /// document root.
  none,
}

/// One token with its source span.
final class JsonSpan {
  const JsonSpan(this.token, this.start, this.end);

  final JsonToken token;
  final int start;
  final int end;
}

/// [tokenizeJson] with source offsets attached.
List<JsonSpan> jsonSpans(String source) {
  final List<JsonSpan> spans = <JsonSpan>[];
  int offset = 0;
  for (final JsonToken token in tokenizeJson(source)) {
    final int end = offset + token.text.length;
    spans.add(JsonSpan(token, offset, end));
    offset = end;
  }
  return spans;
}

/// Everything the completion needs to know about one caret position.
final class JsonCaretContext {
  const JsonCaretContext({
    required this.slot,
    required this.containerPath,
    required this.containerIsObject,
    required this.prefix,
    required this.replaceStart,
    required this.replaceEnd,
    required this.quoted,
    required this.needsColon,
    required this.siblingKeys,
    this.containerType,
    this.valueKey,
    this.commaInsertAt,
  });

  static const JsonCaretContext none = JsonCaretContext(
    slot: JsonCaretSlot.none,
    containerPath: <JsonPathStep>[],
    containerIsObject: false,
    prefix: '',
    replaceStart: 0,
    replaceEnd: 0,
    quoted: false,
    needsColon: false,
    siblingKeys: <String>{},
  );

  final JsonCaretSlot slot;

  /// Path from the document root to the container the caret sits inside.
  final List<JsonPathStep> containerPath;

  final bool containerIsObject;

  /// The container object's own `type` discriminator, when it has one.
  final String? containerType;

  /// For [JsonCaretSlot.value] inside an object: the key being given a value.
  final String? valueKey;

  /// Text already typed in the slot, unquoted.
  final String prefix;

  /// Source range a completion replaces. Equal when nothing is typed yet.
  final int replaceStart;
  final int replaceEnd;

  /// True when the replaced range already carries its quotes, so an inserted
  /// string literal must supply its own rather than land inside them.
  final bool quoted;

  /// Key slot with no `:` after it — the completion has to write one.
  final bool needsColon;

  /// Offset where a separating comma must be spliced in before the completion,
  /// or null when the container already has one. Always before [replaceStart].
  final int? commaInsertAt;

  /// Keys already written in the container object, so completion can stop
  /// offering them. Includes keys after the caret when the scan could reach
  /// them.
  final Set<String> siblingKeys;

  /// The full path to the slot: [containerPath] plus the key being typed.
  List<JsonPathStep> get path => switch (slot) {
    JsonCaretSlot.key when prefix.isNotEmpty => <JsonPathStep>[
      ...containerPath,
      JsonPathStep.key(prefix, ownerType: containerType),
    ],
    JsonCaretSlot.value when valueKey != null => <JsonPathStep>[
      ...containerPath,
      JsonPathStep.key(valueKey!, ownerType: containerType),
    ],
    _ => containerPath,
  };
}

/// A key token found under a hover, with the path that names it.
final class JsonKeyHit {
  const JsonKeyHit({
    required this.key,
    required this.path,
    required this.start,
    required this.end,
  });

  final String key;

  /// Root-to-key, with each step carrying its owner object's `type`.
  final List<JsonPathStep> path;

  /// Source span of the key token, quotes included.
  final int start;
  final int end;
}

// --- scanner ----------------------------------------------------------------

/// One open `{` or `[`.
final class _Frame {
  _Frame({required this.isObject, this.enteredByKey, this.enteredByIndex});

  final bool isObject;

  /// How the parent got here. Exactly one is set on every frame but the root.
  final String? enteredByKey;
  final int? enteredByIndex;

  /// Object: 0 expect key, 1 expect colon, 2 expect value, 3 after value.
  /// Array: 0 expect value, 1 after value.
  int state = 0;

  String? currentKey;
  int index = -1;
  String? typeTag;
  final Set<String> keys = <String>{};

  /// End offset of the last completed member, so a completion that needs a
  /// separating comma knows where to put it.
  int lastMemberEnd = -1;
}

/// Builds the path a frame chain describes. Read after the whole scan so the
/// `type` tags, which the frames fill in as they are walked, are final.
List<JsonPathStep> _pathOf(List<_Frame> chain) {
  final List<JsonPathStep> path = <JsonPathStep>[];
  for (int i = 1; i < chain.length; i++) {
    final _Frame frame = chain[i];
    if (frame.enteredByKey != null) {
      path.add(
        JsonPathStep.key(frame.enteredByKey!, ownerType: chain[i - 1].typeTag),
      );
    } else {
      path.add(JsonPathStep.index(frame.enteredByIndex ?? 0));
    }
  }
  return path;
}

String _unquote(String raw) {
  String text = raw;
  if (text.startsWith('"')) text = text.substring(1);
  if (text.endsWith('"') && text.isNotEmpty) {
    text = text.substring(0, text.length - 1);
  }
  return text.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
}

/// The state machine. [onKey] fires for every key token consumed, with the
/// live frame chain, so callers can capture a hover target mid-scan and read
/// its path once the scan is done.
final class _Scanner {
  _Scanner(this.spans);

  final List<JsonSpan> spans;
  final List<_Frame> stack = <_Frame>[];

  void run(
    int from,
    int to, {
    void Function(JsonSpan span, List<_Frame> chain)? onKey,
  }) {
    for (int i = from; i < to; i++) {
      _step(spans[i], onKey);
    }
  }

  void _step(JsonSpan span, void Function(JsonSpan, List<_Frame>)? onKey) {
    final JsonToken token = span.token;
    if (token.kind == JsonTokenKind.plain) return;
    final String text = token.text;

    if (stack.isEmpty) {
      if (text == '{') {
        stack.add(_Frame(isObject: true));
      } else if (text == '[') {
        stack.add(_Frame(isObject: false));
      }
      return;
    }

    final _Frame frame = stack.last;
    if (frame.isObject) {
      _stepObject(frame, span, text, onKey);
      return;
    }
    _stepArray(frame, span, text);
  }

  void _stepObject(
    _Frame frame,
    JsonSpan span,
    String text,
    void Function(JsonSpan, List<_Frame>)? onKey,
  ) {
    switch (frame.state) {
      case 0:
        if (text == '}') {
          _pop(span);
          return;
        }
        if (span.token.kind == JsonTokenKind.key ||
            span.token.kind == JsonTokenKind.string) {
          frame.currentKey = _unquote(text);
          frame.keys.add(frame.currentKey!);
          frame.state = 1;
          onKey?.call(span, List<_Frame>.of(stack));
        }
      case 1:
        if (text == ':') {
          frame.state = 2;
        } else if (text == '}') {
          _pop(span);
        }
      case 2:
        if (text == '{') {
          frame.state = 3;
          stack.add(_Frame(isObject: true, enteredByKey: frame.currentKey));
          return;
        }
        if (text == '[') {
          frame.state = 3;
          stack.add(_Frame(isObject: false, enteredByKey: frame.currentKey));
          return;
        }
        if (text == '}') {
          _pop(span);
          return;
        }
        if (text == ',') {
          frame.state = 0;
          return;
        }
        if (text == ':') return;
        if (frame.currentKey == 'type' &&
            span.token.kind == JsonTokenKind.string) {
          frame.typeTag = _unquote(text);
        }
        frame.state = 3;
        frame.lastMemberEnd = span.end;
      case 3:
        if (text == ',') {
          frame.state = 0;
        } else if (text == '}') {
          _pop(span);
        }
    }
  }

  void _stepArray(_Frame frame, JsonSpan span, String text) {
    switch (frame.state) {
      case 0:
        if (text == ']') {
          _pop(span);
          return;
        }
        if (text == ',') {
          frame.index++;
          return;
        }
        if (text == '{') {
          frame.index++;
          frame.state = 1;
          stack.add(_Frame(isObject: true, enteredByIndex: frame.index));
          return;
        }
        if (text == '[') {
          frame.index++;
          frame.state = 1;
          stack.add(_Frame(isObject: false, enteredByIndex: frame.index));
          return;
        }
        if (text == ':') return;
        frame.index++;
        frame.state = 1;
        frame.lastMemberEnd = span.end;
      case 1:
        if (text == ',') {
          frame.state = 0;
        } else if (text == ']') {
          _pop(span);
        }
    }
  }

  void _pop(JsonSpan span) {
    stack.removeLast();
    if (stack.isEmpty) return;
    stack.last.lastMemberEnd = span.end;
  }
}

// --- word under the caret ---------------------------------------------------

/// Characters a bare (unquoted) token is made of: what a number, `true` or a
/// half-typed literal can contain. Deliberately narrow — `:` and `/` belong to
/// namespaced ids, which only ever appear INSIDE a string, and a string is
/// handled by its token rather than by this scan.
bool _isWordChar(int code) =>
    (code >= 0x30 && code <= 0x39) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x61 && code <= 0x7A) ||
    code == 0x5F ||
    code == 0x2D ||
    code == 0x2E ||
    code == 0x2B;

/// True when [text] is a string token that reached its closing quote. A token
/// that did not is still being typed, so the caret sitting at its end is inside
/// it rather than after it.
bool _terminated(String text) => text.length >= 2 && text.endsWith('"');

/// The token being edited at [offset]: the span a completion replaces, whether
/// it carries quotes, and the text typed before the caret.
///
/// A quoted token is taken whole off the token stream, so `"minecraft:sto|ne"`
/// replaces the entire string and not the three letters a character scan would
/// have stopped at. Everything else — a number, a literal, an empty slot — is
/// read off the characters, because a half-typed one is not a token yet.
({int start, int end, bool quoted, String text}) jsonWordAt(
  String source,
  int offset, {
  List<JsonSpan>? spans,
}) {
  final int caret = offset.clamp(0, source.length);
  for (final JsonSpan span in spans ?? jsonSpans(source)) {
    final JsonTokenKind kind = span.token.kind;
    if (kind != JsonTokenKind.key && kind != JsonTokenKind.string) continue;
    if (caret <= span.start) continue;
    final bool inside = caret < span.end ||
        (caret == span.end && !_terminated(span.token.text));
    if (!inside) continue;
    return (
      start: span.start,
      end: span.end,
      quoted: true,
      text: source.substring(span.start + 1, caret),
    );
  }
  int start = caret;
  while (start > 0 && _isWordChar(source.codeUnitAt(start - 1))) {
    start--;
  }
  int end = caret;
  while (end < source.length && _isWordChar(source.codeUnitAt(end))) {
    end++;
  }
  return (
    start: start,
    end: end,
    quoted: false,
    text: source.substring(start, caret),
  );
}

/// True when the next non-space character at or after [from] is a `:`.
bool _colonAhead(String source, int from) {
  for (int i = from; i < source.length; i++) {
    final int code = source.codeUnitAt(i);
    if (code == 0x3A) return true;
    if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D) continue;
    return false;
  }
  return false;
}

// --- public entry points ----------------------------------------------------

/// What the caret at [offset] is sitting on.
JsonCaretContext jsonCaretContext(String source, int offset) {
  final List<JsonSpan> spans = jsonSpans(source);
  final ({int start, int end, bool quoted, String text}) word = jsonWordAt(
    source,
    offset,
    spans: spans,
  );

  int consumed = 0;
  while (consumed < spans.length && spans[consumed].end <= word.start) {
    consumed++;
  }

  final _Scanner scanner = _Scanner(spans);
  scanner.run(0, consumed);
  if (scanner.stack.isEmpty) return JsonCaretContext.none;

  final List<_Frame> chain = List<_Frame>.of(scanner.stack);
  final _Frame frame = chain.last;
  // Snapshot everything that describes the caret BEFORE the remainder scan
  // below walks the same frames forward. `keys` and `typeTag` are read after it
  // on purpose — those are what the second pass is for — but the state, the
  // key being given a value and the end of the last member all describe this
  // caret and would otherwise be overwritten by the text following it.
  final int state = frame.state;
  final int lastMemberEnd = frame.lastMemberEnd;
  final String? currentKey = frame.currentKey;
  final bool isObject = frame.isObject;

  // Best-effort: pick up a `type` written after the caret, and the keys that
  // follow it. Resumed from the first token past the edited word so the partial
  // token never enters the machine.
  int resume = consumed;
  while (resume < spans.length && spans[resume].start < word.end) {
    resume++;
  }
  scanner.run(resume, spans.length);

  final JsonCaretSlot slot;
  int? commaInsertAt;
  if (isObject) {
    if (state == 1 && word.text.isEmpty) {
      // A key was read and the caret is past it with nothing typed. Offering
      // one here would write a second key beside the first.
      return JsonCaretContext.none;
    }
    if (state == 0 || state == 1) {
      slot = JsonCaretSlot.key;
    } else if (state == 2) {
      slot = JsonCaretSlot.value;
    } else {
      slot = JsonCaretSlot.key;
      if (lastMemberEnd >= 0 && lastMemberEnd <= word.start) {
        commaInsertAt = lastMemberEnd;
      }
    }
  } else {
    slot = state == 0 ? JsonCaretSlot.value : JsonCaretSlot.none;
  }

  if (slot == JsonCaretSlot.none) return JsonCaretContext.none;
  // A `type` written after a state-3 caret is a sibling, not this key's owner.
  return JsonCaretContext(
    slot: slot,
    containerPath: _pathOf(chain),
    containerIsObject: isObject,
    containerType: frame.typeTag,
    valueKey: slot == JsonCaretSlot.value && isObject ? currentKey : null,
    prefix: word.text,
    replaceStart: word.start,
    replaceEnd: word.end,
    quoted: word.quoted,
    needsColon: slot == JsonCaretSlot.key && !_colonAhead(source, word.end),
    commaInsertAt: commaInsertAt,
    siblingKeys: Set<String>.of(frame.keys),
  );
}

/// The key token whose span covers [offset], or null.
///
/// Used by the hover: a pointer resting anywhere on `"seeThrough"` — the quotes
/// included — resolves to that key's path.
JsonKeyHit? jsonKeyAt(String source, int offset) {
  final List<JsonSpan> spans = jsonSpans(source);
  final _Scanner scanner = _Scanner(spans);
  JsonSpan? hitSpan;
  String? hitKey;
  List<_Frame>? hitChain;
  scanner.run(
    0,
    spans.length,
    onKey: (JsonSpan span, List<_Frame> chain) {
      if (offset < span.start || offset >= span.end) return;
      hitSpan = span;
      hitKey = _unquote(span.token.text);
      hitChain = chain;
    },
  );
  final JsonSpan? span = hitSpan;
  final List<_Frame>? chain = hitChain;
  if (span == null || chain == null) return null;
  return JsonKeyHit(
    key: hitKey!,
    path: <JsonPathStep>[
      ..._pathOf(chain),
      JsonPathStep.key(hitKey!, ownerType: chain.last.typeTag),
    ],
    start: span.start,
    end: span.end,
  );
}

/// Every key token in [source] with its span, in document order.
///
/// The hover hit-test needs the spans to line the highlight layer's key spans
/// up with pointer coordinates; it never re-tokenizes to get them.
List<({int start, int end})> jsonKeySpans(String source) {
  final List<({int start, int end})> out = <({int start, int end})>[];
  for (final JsonSpan span in jsonSpans(source)) {
    if (span.token.kind == JsonTokenKind.key) {
      out.add((start: span.start, end: span.end));
    }
  }
  return out;
}
