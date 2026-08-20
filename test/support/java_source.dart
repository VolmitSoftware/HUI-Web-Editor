/// Minimal Java-source readers for the cross-repo contract tests.
///
/// The editor hand-ports a handful of Gloss constants (enum spellings, provider
/// order, clamp ranges, geometry and sync limits). Nothing here generates Dart:
/// these helpers only lift the numbers and strings back out of the Java source
/// so a test can assert the Dart mirror still matches. Parsing is deliberately
/// line/regex level — enough for constant declarations and enum bodies, and
/// loud when the shape it expects is gone.
library;

import 'dart:io';

import 'gloss_repository.dart';

/// Reads a Java file from the Gloss checkout with comments removed.
///
/// Throws [StateError] rather than returning empty text when the file is
/// missing, so a moved class fails as a contract break instead of silently
/// pinning nothing.
String readGlossJava(String relativePath) {
  final File file = File(glossRepositoryFilePath(relativePath));
  if (!file.existsSync()) {
    throw StateError(
      'missing Gloss source ${file.path}; set GLOSS_REPOSITORY to a Gloss '
      'checkout, or update this path if the class moved',
    );
  }
  return stripJavaComments(file.readAsStringSync());
}

/// Drops `/* ... */` and `// ...` so a commented-out declaration can never be
/// mistaken for the live one.
String stripJavaComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

final RegExp _serializedName = RegExp(r'@SerializedName\(\s*"([^"]*)"\s*\)');

/// Every `@SerializedName("x")` in declaration order — the wire spelling of a
/// Gson-serialized enum.
List<String> javaSerializedNames(String source) => <String>[
  for (final RegExpMatch match in _serializedName.allMatches(source))
    match.group(1)!,
];

final RegExp _enumConstant = RegExp(
  r'^\s*([A-Z][A-Z0-9_]*)\(\s*"([^"]*)"',
  multiLine: true,
);

/// Every `NAME("value", ...)` enum constant in declaration order, as
/// `NAME` to `value`. This is the spelling carried by an explicit
/// `getSerializedName()`-style field rather than a Gson annotation.
Map<String, String> javaEnumConstants(String source) => <String, String>{
  for (final RegExpMatch match in _enumConstant.allMatches(source))
    match.group(1)!: match.group(2)!,
};

/// The `"literal"` arguments of every `new <TypeName>(` call, in source order.
List<String> javaConstructorFirstStrings(String source, String typeName) =>
    <String>[
      for (final RegExpMatch match in RegExp(
        'new $typeName'
        r'\(\s*"([^"]+)"',
      ).allMatches(source))
        match.group(1)!,
    ];

final RegExp _numericValue = RegExp(r'^[-+*/() \t0-9._FfDdLl]+$');

/// The value of a numeric constant declaration, evaluated in double
/// arithmetic: `MAX_DOCUMENT_BYTES = 2 * 1024 * 1024` reads back as 2097152 and
/// `NAMETAG_SIZE = 1 / 16F * 3.5F` as 0.21875.
///
/// Only assignments whose right-hand side is a pure numeric expression count,
/// so a later `field = clamp(field, ...)` reassignment is skipped and the
/// declaration wins. Throws [StateError] when the member is gone or its value
/// stopped being a literal — a drifted name must fail loudly, not silently
/// compare against nothing.
double constantNumber(String source, String member) {
  for (final RegExpMatch match in RegExp(
    '\\b$member\\s*=\\s*([^;]+);',
  ).allMatches(source)) {
    final String raw = match.group(1)!.trim();
    if (!_numericValue.hasMatch(raw)) continue;
    return evaluateConstantNumber(raw);
  }
  throw StateError(
    'no numeric declaration of `$member` in the source; the constant was '
    'renamed, moved, or is no longer a literal',
  );
}

/// The string literal a constant is declared with, unescaped:
/// `PROJECT_FORMAT = "gloss-sync-project"` and
/// `PATTERN = Pattern.compile("^[a-z]...$")` both read back as their contents.
/// Works on Dart declarations too, including raw strings.
String stringLiteral(String source, String member) {
  final RegExpMatch? match = RegExp(
    '\\b$member\\s*=\\s*(?:Pattern\\.compile\\(\\s*|RegExp\\(\\s*)?'
    r'''r?["']((?:[^"'\\]|\\.)*)["']''',
  ).firstMatch(source);
  if (match == null) {
    throw StateError(
      'no string declaration of `$member` in the source; the constant was '
      'renamed, moved, or is no longer a literal',
    );
  }
  return match.group(1)!.replaceAll(r'\\', r'\').replaceAll(r'\"', '"');
}

/// Strips the anchors a Dart/Java pattern may or may not carry, so
/// `String.matches` (implicitly anchored) can be compared against an explicitly
/// anchored `RegExp`.
String unanchoredPattern(String pattern) {
  String value = pattern;
  if (value.startsWith('^')) value = value.substring(1);
  if (value.endsWith(r'$')) value = value.substring(0, value.length - 1);
  return value;
}

/// [constantNumber] for a member that must still be a whole number.
int constantInt(String source, String member) {
  final double value = constantNumber(source, member);
  if (value != value.roundToDouble()) {
    throw StateError('`$member` is not a whole number: $value');
  }
  return value.toInt();
}

final RegExp _numberToken = RegExp(r'\d[\d_]*\.?\d*|\.\d[\d_]*');

/// Evaluates the arithmetic Java writes in a constant initializer: numeric
/// literals with `_` separators and `F`/`D`/`L` suffixes, `+ - * /`, and
/// left-to-right evaluation within a precedence level. No parentheses — no
/// pinned constant uses them, and silently mis-grouping one would be worse
/// than failing here.
double evaluateConstantNumber(String expression) {
  if (expression.contains('(') || expression.contains(')')) {
    throw StateError('parenthesized constant expression: $expression');
  }
  final String cleaned = expression
      .replaceAll(RegExp(r'(?<=[\d.])[FfDdLl]'), '')
      .replaceAll('_', '')
      .replaceAll(RegExp(r'\s+'), '');
  final List<String> tokens = <String>[];
  int index = 0;
  while (index < cleaned.length) {
    final Match? number = _numberToken.matchAsPrefix(cleaned, index);
    if (number != null) {
      tokens.add(number.group(0)!);
      index = number.end;
      continue;
    }
    final String operator = cleaned[index];
    if (!'+-*/'.contains(operator)) {
      throw StateError('unsupported token "$operator" in: $expression');
    }
    if (tokens.isEmpty || '+-*/'.contains(tokens.last)) {
      // Unary sign: fold it into the number that follows.
      final Match? signed = _numberToken.matchAsPrefix(cleaned, index + 1);
      if (signed == null) {
        throw StateError('dangling sign in: $expression');
      }
      tokens.add('$operator${signed.group(0)!}');
      index = signed.end;
      continue;
    }
    tokens.add(operator);
    index++;
  }
  if (tokens.isEmpty) {
    throw StateError('empty constant expression');
  }

  final List<String> products = <String>[tokens.first];
  for (int at = 1; at < tokens.length; at += 2) {
    final String operator = tokens[at];
    final double right = double.parse(tokens[at + 1]);
    if (operator == '*' || operator == '/') {
      final double left = double.parse(products.removeLast());
      products.add((operator == '*' ? left * right : left / right).toString());
    } else {
      products
        ..add(operator)
        ..add(right.toString());
    }
  }

  double total = double.parse(products.first);
  for (int at = 1; at < products.length; at += 2) {
    final double right = double.parse(products[at + 1]);
    total += products[at] == '+' ? right : -right;
  }
  return total;
}
