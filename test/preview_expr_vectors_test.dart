import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/logic/preview_expr.dart';
import 'package:gloss_editor/logic/preview_expr_functions.dart';
import 'package:test/test.dart';

/// The cross-repo contract: `Gloss/src/test/resources/expr_test_vectors.json`
/// copied verbatim. The Java suite (`ExprVectorsTest`) replays the same file, so
/// a vector that passes here and there pins both engines to one answer.
/// `cross_repo_fixture_pins_test.dart` asserts the copy still matches Gloss.
const String vectorsPath = 'test/fixtures/expr_test_vectors.json';

/// Matches `ExprVectorsTest.DELTA`.
const double delta = 1e-9;

/// A truncated or unresolved fixture must fail loudly rather than pass with
/// nothing to check. `ExprVectorsTest.MINIMUM_VECTOR_COUNT` is 40; this floor
/// is the shipped table's full size, so silently losing vectors in a refresh
/// fails here instead of quietly shrinking the contract.
const int minimumVectorCount = 106;

/// Scope over a literal variable map, falling back to the standard library —
/// the Dart twin of the Java harness's `MapScope`.
class MapScope extends PExprScope {
  MapScope(this.vars);

  final Map<String, Object?> vars;

  @override
  Object? variable(String dottedName) => vars[dottedName];

  @override
  Object? call(String name, List<Object?> args) =>
      previewStdFunction(name, args);
}

/// JSON numbers arrive as `int` or `double`; the engine only ever sees doubles.
Object? toRuntimeValue(Object? value) {
  if (value is List) {
    return value.map(toRuntimeValue).toList();
  }
  if (value is num) {
    return value.toDouble();
  }
  return value;
}

void main() {
  final File file = File(vectorsPath);
  if (!file.existsSync()) {
    throw StateError('missing vector fixture: $vectorsPath');
  }
  final Map<String, Object?> root =
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final List<Object?> vectors = root['vectors']! as List<Object?>;

  group('expression vectors', () {
    test('the fixture carries the full contract', () {
      expect(
        vectors.length,
        greaterThanOrEqualTo(minimumVectorCount),
        reason:
            'expected at least $minimumVectorCount vectors, found ${vectors.length}',
      );
    });

    for (int index = 0; index < vectors.length; index++) {
      final Map<String, Object?> vector =
          vectors[index]! as Map<String, Object?>;
      final String source = vector['expr']! as String;
      final bool expectError = vector['error'] == true;
      final Map<String, Object?> rawVars =
          (vector['vars'] as Map<String, Object?>?) ??
          const <String, Object?>{};
      final Map<String, Object?> vars = rawVars.map(
        (String key, Object? value) =>
            MapEntry<String, Object?>(key, toRuntimeValue(value)),
      );

      test('[$index] $source', () {
        final MapScope scope = MapScope(vars);
        if (expectError) {
          // Either stage may raise: a parse error and an evaluation error are
          // both "error": true.
          expect(
            () => evalPreviewExpr(parsePreviewExpr(source), scope),
            throwsA(isA<PExprException>()),
          );
          return;
        }
        final Object actual = evalPreviewExpr(parsePreviewExpr(source), scope);
        expectMatches(source, vector['expect'], actual);
      });
    }
  });
}

void expectMatches(String source, Object? expected, Object actual) {
  if (expected is bool) {
    expect(
      actual,
      isA<bool>(),
      reason: "vector '$source': expected boolean result",
    );
    expect(actual, expected, reason: "vector '$source'");
    return;
  }
  if (expected is num) {
    expect(
      actual,
      isA<double>(),
      reason: "vector '$source': expected numeric result",
    );
    expect(
      actual as double,
      closeTo(expected.toDouble(), delta),
      reason: "vector '$source'",
    );
    return;
  }
  final String text = expected! as String;
  if (text.startsWith('#')) {
    // Colour expectations are written as hex literals; reuse the parser's own
    // colour lexing rather than duplicating its hex-expansion rules here.
    expect(
      actual,
      isA<double>(),
      reason: "vector '$source': expected colour result",
    );
    final double expectColor = (parsePreviewExpr(text) as PNum).value;
    expect(
      actual as double,
      closeTo(expectColor, delta),
      reason: "vector '$source'",
    );
    return;
  }
  expect(
    actual,
    isA<String>(),
    reason: "vector '$source': expected string result",
  );
  expect(actual, text, reason: "vector '$source'");
}
