/// The real-drops `script` block, compiled and evaluated the way the plugin
/// does it.
///
/// Dart twin of `art.arcane.gloss.drop.RealDropScriptPlan`. It reuses the
/// expression engine already ported in `preview_expr.dart` — the same parser,
/// the same evaluator, the same standard library, pinned to the Java side by
/// `test/fixtures/expr_test_vectors.json` — and adds only what is specific to a
/// dropped item: the variable scope of section 4 of `DROP_SCRIPT_FORMAT.md`,
/// the `materialIs` / `materialMatches` tests, the per-field result clamps and
/// the load-time type check.
///
/// Two deliberate differences from the Java, both in the editor's favour:
///
///  * The plugin throws on the first bad expression and refuses the document
///    (`RealDropScriptPlan.compile`). This collects every problem instead, so
///    an author sees all four broken fields at once rather than one per save.
///    The wording of each message is the server's, field and character position
///    included, so what the inspector shows is what the console would print.
///  * A plan that failed to compile still evaluates the fields that did. The
///    server never gets that far, because the document is refused before it
///    reaches the runtime; the stage would otherwise go blank while somebody is
///    halfway through typing.
///
/// Runtime failure behaviour matches exactly: each field is evaluated inside
/// its own guard and falls back to the neutral value from section 1 of the
/// format doc, so one bad expression cannot take the drop with it.
library;

import 'dart:math' as math;

import '../l10n/hui_localizations.dart';
import '../model/gloss_real_drops.dart';
import 'preview_expr.dart';
import 'preview_expr_functions.dart';
import 'real_drop_model.dart';

/// `RealDropScriptPlan.MAX_OFFSET_BLOCKS`.
const double realDropScriptMaxOffset = 16;

/// The rotation clamp, in degrees.
const double realDropScriptMaxRotation = 3600;

/// `RealDropScriptPlan.MAX_SCALE_FACTOR`.
const double realDropScriptMaxScale = 16;

/// Every built-in name the scope publishes. A `vars` entry may not shadow one.
const Set<String> realDropScriptVariables = <String>{
  't',
  'age',
  'index',
  'count',
  'amount',
  'onGround',
  'settled',
  'phase',
  'stateTime',
  'impactSpeed',
  'inWater',
  'inLava',
  'bounces',
  'velocityX',
  'velocityY',
  'velocityZ',
  'speed',
  'height',
  'blockLight',
  'skyLight',
  'random',
  'material',
  'isBlock',
  'isFlat',
  'isThin',
  'pi',
};

/// The three names whose value costs the server a block lookup, so it only
/// probes for them when a document actually mentions one.
const Set<String> realDropScriptEnvironmentVariables = <String>{
  'height',
  'blockLight',
  'skyLight',
};

/// The two calls that exist only on this surface.
const Set<String> realDropScriptFunctions = <String>{
  'materialIs',
  'materialMatches',
};

final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// One reason the server would refuse the document at load.
final class RealDropScriptIssue {
  const RealDropScriptIssue({
    required this.path,
    required String message,
    this.messageArguments = const <String, Object?>{},
  }) : _message = message,
       pluralKey = null,
       pluralCount = null,
       oneEnglish = null;

  const RealDropScriptIssue.plural({
    required this.path,
    required this.pluralKey,
    required this.pluralCount,
    required this.oneEnglish,
    required String otherEnglish,
    this.messageArguments = const <String, Object?>{},
  }) : _message = otherEnglish;

  /// JSON path of the offending field, for inline placement in the inspector
  /// (`$.script.offset.y`).
  final String path;

  /// The server's own wording, minus the leading file name it prefixes every
  /// message with — `script.offset.y: unclosed paren at position 5`.
  final String _message;
  final Map<String, Object?> messageArguments;
  final String? pluralKey;
  final int? pluralCount;
  final String? oneEnglish;

  String get message {
    final String? key = pluralKey;
    final int? count = pluralCount;
    final String? one = oneEnglish;
    if (key == null || count == null || one == null) {
      return huiText(_message, messageArguments);
    }
    return huiPlural(
      key,
      count,
      oneEnglish: one,
      otherEnglish: _message,
      arguments: messageArguments,
    );
  }

  String get englishMessage => _message;
}

final class _DeferredText {
  const _DeferredText(this.resolve);

  final String Function() resolve;

  @override
  String toString() => resolve();
}

/// One evaluation of the whole script, for one display.
final class RealDropScriptSample {
  const RealDropScriptSample({
    required this.offsetX,
    required this.offsetY,
    required this.offsetZ,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.glowArgb,
    required this.visible,
    required this.failed,
  });

  /// The neutral sample: what a document with no script block, or one with the
  /// switch off, composes onto the presentation.
  static const RealDropScriptSample neutral = RealDropScriptSample(
    offsetX: 0,
    offsetY: 0,
    offsetZ: 0,
    rotationX: 0,
    rotationY: 0,
    rotationZ: 0,
    scaleX: 1,
    scaleY: 1,
    scaleZ: 1,
    glowArgb: 0,
    visible: true,
    failed: <String>{},
  );

  /// Blocks, already clamped to -16..16.
  final double offsetX;
  final double offsetY;
  final double offsetZ;

  /// Degrees, already clamped to -3600..3600.
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  /// Per-axis multipliers, already clamped to 0..16.
  final double scaleX;
  final double scaleY;
  final double scaleZ;

  /// Unsigned 32-bit ARGB. Exactly 0 means no glow.
  final int glowArgb;

  final bool visible;

  /// Field names that threw this evaluation and took their neutral fallback.
  /// The plugin logs one warning per document; the editor can name them.
  final Set<String> failed;

  bool get isNeutral =>
      offsetX == 0 &&
      offsetY == 0 &&
      offsetZ == 0 &&
      rotationX == 0 &&
      rotationY == 0 &&
      rotationZ == 0 &&
      scaleX == 1 &&
      scaleY == 1 &&
      scaleZ == 1 &&
      glowArgb == 0 &&
      visible;
}

/// Everything one evaluation reads. The plugin's `RealDropScriptContext`, with
/// the same units: `t` in seconds, `age` in ticks, velocities in blocks per
/// tick, `height` in blocks, light levels 0-15, `random` in `[0, 1)`.
final class RealDropScriptContext {
  const RealDropScriptContext({
    required this.t,
    required this.age,
    required this.index,
    required this.count,
    required this.amount,
    required this.onGround,
    required this.settled,
    this.phase = 'AIRBORNE',
    this.stateTime = 0,
    this.impactSpeed = 0,
    required this.inWater,
    required this.inLava,
    required this.bounces,
    required this.velocityX,
    required this.velocityY,
    required this.velocityZ,
    required this.height,
    required this.blockLight,
    required this.skyLight,
    required this.random,
    required this.material,
    required this.kind,
  });

  final double t;
  final int age;
  final int index;
  final int count;
  final int amount;
  final bool onGround;
  final bool settled;
  final String phase;
  final double stateTime;
  final double impactSpeed;
  final bool inWater;
  final bool inLava;
  final int bounces;
  final double velocityX;
  final double velocityY;
  final double velocityZ;
  final double height;
  final int blockLight;
  final int skyLight;
  final double random;

  /// Upper case, no namespace, as `Material.name()` spells it.
  final String material;

  final DropModelKind kind;

  double get speed => math.sqrt(
    velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ,
  );
}

/// The four synthetic contexts the server type-checks every expression
/// against, verbatim from `RealDropScriptPlan.validateSamples`.
///
/// They span airborne, grounded, settled-in-water and airborne-in-lava with a
/// mix of materials and shape families, which is what catches a division by
/// zero that only happens when `speed` is 0 before the document is accepted
/// rather than a tick later.
const List<RealDropScriptContext> realDropScriptSampleContexts =
    <RealDropScriptContext>[
      RealDropScriptContext(
        t: 0,
        age: 0,
        index: 0,
        count: 1,
        amount: 1,
        onGround: false,
        settled: false,
        inWater: false,
        inLava: false,
        bounces: 0,
        velocityX: 0,
        velocityY: -0.4,
        velocityZ: 0,
        height: 4,
        blockLight: 15,
        skyLight: 15,
        random: 0.25,
        material: 'STONE',
        kind: DropModelKind.block,
      ),
      RealDropScriptContext(
        t: 1.5,
        age: 30,
        index: 1,
        count: 3,
        amount: 32,
        onGround: true,
        settled: false,
        inWater: false,
        inLava: false,
        bounces: 2,
        velocityX: 0.12,
        velocityY: 0,
        velocityZ: -0.08,
        height: 0,
        blockLight: 7,
        skyLight: 0,
        random: 0.75,
        material: 'TORCH',
        kind: DropModelKind.flat,
      ),
      RealDropScriptContext(
        t: 9,
        age: 180,
        index: 2,
        count: 3,
        amount: 64,
        onGround: true,
        settled: true,
        inWater: true,
        inLava: false,
        bounces: 3,
        velocityX: 0,
        velocityY: 0,
        velocityZ: 0,
        height: 0.5,
        blockLight: 0,
        skyLight: 4,
        random: 0.5,
        material: 'OAK_SLAB',
        kind: DropModelKind.thin,
      ),
      RealDropScriptContext(
        t: 45,
        age: 900,
        index: 0,
        count: 2,
        amount: 8,
        onGround: false,
        settled: false,
        inWater: false,
        inLava: true,
        bounces: 11,
        velocityX: -0.3,
        velocityY: 0.6,
        velocityZ: 0.3,
        height: 12,
        blockLight: 15,
        skyLight: 15,
        random: 0.99,
        material: 'DIAMOND',
        kind: DropModelKind.flat,
      ),
    ];

/// One compiled `vars` entry, in declaration order.
final class _CompiledVar {
  const _CompiledVar(this.name, this.expression);

  final String name;

  /// Null when the source did not compile; the entry still reserves its name
  /// so a later expression reading it is not also reported as unknown.
  final PExpr? expression;
}

/// A compiled `script` block: what the inspector validates against and what the
/// drop stage evaluates.
final class RealDropScriptPlan {
  RealDropScriptPlan._({
    required this.issues,
    required this.environmentReferenced,
    required List<_CompiledVar> vars,
    required Map<String, PExpr?> fields,
  }) : _vars = vars,
       _fields = fields;

  /// A plan for a document with no script block at all: no issues, nothing to
  /// evaluate, [sample] always returns [RealDropScriptSample.neutral].
  static final RealDropScriptPlan empty = RealDropScriptPlan._(
    issues: const <RealDropScriptIssue>[],
    environmentReferenced: false,
    vars: const <_CompiledVar>[],
    fields: const <String, PExpr?>{},
  );

  /// Every reason the server would refuse this document, in field order.
  final List<RealDropScriptIssue> issues;

  /// True when at least one expression names `height`, `blockLight` or
  /// `skyLight`, which is the only thing that makes the server probe the world.
  final bool environmentReferenced;

  final List<_CompiledVar> _vars;
  final Map<String, PExpr?> _fields;

  bool get isValid => issues.isEmpty;

  /// Compiles [script] the way `RealDropSettingsDoc.Script`'s constructor does:
  /// `vars` first in declaration order, then the axes, then `glow` and
  /// `visible`, with every expression parsed and type-checked whether or not
  /// [GlossRealDropScript.enabled] is set.
  static RealDropScriptPlan compile(GlossRealDropScript script) {
    final List<RealDropScriptIssue> issues = <RealDropScriptIssue>[];
    final Set<String> referenced = <String>{};
    final Set<String> declared = <String>{};
    final List<_CompiledVar> vars = <_CompiledVar>[];

    if (script.vars.length > GlossRealDropScript.maxVars) {
      issues.add(
        RealDropScriptIssue.plural(
          path: r'$.script.vars',
          pluralKey: 'validation.real_drop_script.variable_count',
          pluralCount: script.vars.length,
          oneEnglish:
              'script.vars declares {count} variable; the limit is {limit}',
          otherEnglish:
              'script.vars declares {count} variables; the limit is {limit}',
          messageArguments: <String, Object?>{
            'count': script.vars.length,
            'limit': GlossRealDropScript.maxVars,
          },
        ),
      );
    }

    for (final GlossRealDropScriptVar variable in script.vars) {
      final String name = variable.name.trim();
      final String path = r'$.script.vars.' + name;
      if (name.isEmpty) {
        issues.add(
          const RealDropScriptIssue(
            path: r'$.script.vars',
            message: 'script.vars declares an entry with no name',
          ),
        );
        continue;
      }
      if (!_identifier.hasMatch(name)) {
        issues.add(
          RealDropScriptIssue(
            path: path,
            message:
                'script.vars.{name} is not a valid name; use letters, digits '
                'and underscores starting with a letter or underscore',
            messageArguments: <String, Object?>{'name': name},
          ),
        );
      } else if (realDropScriptVariables.contains(name)) {
        issues.add(
          RealDropScriptIssue(
            path: path,
            message: 'script.vars.{name} shadows the built-in variable {name}',
            messageArguments: <String, Object?>{'name': name},
          ),
        );
      } else if (declared.contains(name)) {
        issues.add(
          RealDropScriptIssue(
            path: path,
            message: 'script.vars.{name} is declared twice',
            messageArguments: <String, Object?>{'name': name},
          ),
        );
      }
      vars.add(
        _CompiledVar(
          name,
          _compile(
            'script.vars.$name',
            path,
            variable.expression,
            declared,
            referenced,
            issues,
          ),
        ),
      );
      declared.add(name);
    }

    final Map<String, PExpr?> fields = <String, PExpr?>{};
    for (final _AxisField axis in _axisFields) {
      final GlossRealDropScriptAxis source = axis.of(script);
      for (final MapEntry<String, String> entry in <String, String>{
        'x': source.x,
        'y': source.y,
        'z': source.z,
      }.entries) {
        final String field = '${axis.field}.${entry.key}';
        fields[field] = _compile(
          field,
          r'$.' + field,
          entry.value,
          declared,
          referenced,
          issues,
        );
      }
    }
    // Blank glow is not an empty expression, it is the feature turned off —
    // the one field the server leaves uncompiled rather than refusing.
    fields['script.glow'] = script.glow.trim().isEmpty
        ? null
        : _compile(
            'script.glow',
            r'$.script.glow',
            script.glow,
            declared,
            referenced,
            issues,
          );
    fields['script.visible'] = _compile(
      'script.visible',
      r'$.script.visible',
      script.visible,
      declared,
      referenced,
      issues,
    );

    final RealDropScriptPlan plan = RealDropScriptPlan._(
      issues: issues,
      environmentReferenced: referenced.any(
        realDropScriptEnvironmentVariables.contains,
      ),
      vars: vars,
      fields: fields,
    );
    plan._typeCheck(issues);
    return plan;
  }

  /// Evaluates the whole script once, for one display.
  ///
  /// `vars` run first in declaration order and each one is visible to
  /// everything after it; then the axes, `glow` and `visible`. Every field is
  /// guarded on its own, so a throw in `offset.y` costs that axis its value and
  /// nothing else.
  RealDropScriptSample sample(RealDropScriptContext context) {
    if (_fields.isEmpty) return RealDropScriptSample.neutral;
    final Set<String> failed = <String>{};
    final _Scope scope = _Scope(context);
    for (final _CompiledVar variable in _vars) {
      scope.locals[variable.name] = _varValue(variable, scope, failed);
    }
    return RealDropScriptSample(
      offsetX: _number('script.offset.x', scope, failed, 0, -16, 16),
      offsetY: _number('script.offset.y', scope, failed, 0, -16, 16),
      offsetZ: _number('script.offset.z', scope, failed, 0, -16, 16),
      rotationX: _number('script.rotation.x', scope, failed, 0, -3600, 3600),
      rotationY: _number('script.rotation.y', scope, failed, 0, -3600, 3600),
      rotationZ: _number('script.rotation.z', scope, failed, 0, -3600, 3600),
      scaleX: _number('script.scale.x', scope, failed, 1, 0, 16),
      scaleY: _number('script.scale.y', scope, failed, 1, 0, 16),
      scaleZ: _number('script.scale.z', scope, failed, 1, 0, 16),
      glowArgb: _glow(scope, failed),
      visible: _flag('script.visible', scope, failed),
      failed: failed,
    );
  }

  double _varValue(_CompiledVar variable, _Scope scope, Set<String> failed) {
    final PExpr? expression = variable.expression;
    if (expression == null) return 0;
    try {
      final double result = evalNumber(expression, scope);
      if (result.isFinite) return result;
      failed.add('script.vars.${variable.name}');
      return 0;
    } on PExprException {
      failed.add('script.vars.${variable.name}');
      return 0;
    }
  }

  double _number(
    String field,
    _Scope scope,
    Set<String> failed,
    double fallback,
    double minimum,
    double maximum,
  ) {
    final PExpr? expression = _fields[field];
    if (expression == null) return fallback;
    try {
      final double result = evalNumber(expression, scope);
      if (!result.isFinite) {
        failed.add(field);
        return fallback;
      }
      return math.max(minimum, math.min(maximum, result));
    } on PExprException {
      failed.add(field);
      return fallback;
    }
  }

  bool _flag(String field, _Scope scope, Set<String> failed) {
    final PExpr? expression = _fields[field];
    if (expression == null) return true;
    try {
      return evalBool(expression, scope);
    } on PExprException {
      failed.add(field);
      return true;
    }
  }

  int _glow(_Scope scope, Set<String> failed) {
    final PExpr? expression = _fields['script.glow'];
    if (expression == null) return 0;
    try {
      return _colorOf(evalPreviewExpr(expression, scope));
    } on PExprException {
      failed.add('script.glow');
      return 0;
    } on FormatException {
      failed.add('script.glow');
      return 0;
    }
  }

  /// The load-time type check: every expression is evaluated against the four
  /// synthetic contexts, and anything that throws for any of them — or returns
  /// the wrong type — refuses the document rather than degrading later.
  void _typeCheck(List<RealDropScriptIssue> issues) {
    for (final RealDropScriptContext context in realDropScriptSampleContexts) {
      final _Scope scope = _Scope(context);
      for (final _CompiledVar variable in _vars) {
        scope.locals[variable.name] = _checkNumber(
          'script.vars.${variable.name}',
          r'$.script.vars.' + variable.name,
          variable.expression,
          scope,
          issues,
        );
      }
      for (final String field in _numericFields) {
        _checkNumber(field, r'$.' + field, _fields[field], scope, issues);
      }
      _checkGlow(scope, issues);
      _checkBool(
        'script.visible',
        r'$.script.visible',
        _fields['script.visible'],
        scope,
        issues,
      );
    }
  }

  double _checkNumber(
    String field,
    String path,
    PExpr? expression,
    _Scope scope,
    List<RealDropScriptIssue> issues,
  ) {
    if (expression == null) return 0;
    final Object? result = _evaluate(field, path, expression, scope, issues);
    if (result == null) return 0;
    if (result is! double) {
      _add(
        issues,
        path,
        '{field} must evaluate to a number, got {type}',
        <String, Object?>{
          'field': field,
          'type': _DeferredText(() => previewTypeName(result)),
        },
      );
      return 0;
    }
    if (!result.isFinite) {
      _add(issues, path, '{field} result must be finite', <String, Object?>{
        'field': field,
      });
      return 0;
    }
    return result;
  }

  void _checkBool(
    String field,
    String path,
    PExpr? expression,
    _Scope scope,
    List<RealDropScriptIssue> issues,
  ) {
    if (expression == null) return;
    final Object? result = _evaluate(field, path, expression, scope, issues);
    if (result == null || result is bool) return;
    _add(
      issues,
      path,
      '{field} must evaluate to true or false, got {type}',
      <String, Object?>{
        'field': field,
        'type': _DeferredText(() => previewTypeName(result)),
      },
    );
  }

  void _checkGlow(_Scope scope, List<RealDropScriptIssue> issues) {
    final PExpr? expression = _fields['script.glow'];
    if (expression == null) return;
    final Object? result = _evaluate(
      'script.glow',
      r'$.script.glow',
      expression,
      scope,
      issues,
    );
    if (result == null) return;
    try {
      _colorOf(result);
    } on PExprException catch (e) {
      _add(issues, r'$.script.glow', e.englishMessage, e.arguments);
    }
  }

  /// Evaluates for validation, turning a throw into an issue and a null
  /// result so the caller stops rather than reporting a type error on top.
  Object? _evaluate(
    String field,
    String path,
    PExpr expression,
    _Scope scope,
    List<RealDropScriptIssue> issues,
  ) {
    try {
      return evalPreviewExpr(expression, scope);
    } on PExprException catch (e) {
      _add(issues, path, '{field}: {message}', <String, Object?>{
        'field': field,
        'message': _DeferredText(() => e.message),
      });
      return null;
    }
  }
}

/// Which axis object a field name belongs to, and its neutral source.
final class _AxisField {
  const _AxisField(this.field, this.of);

  final String field;
  final GlossRealDropScriptAxis Function(GlossRealDropScript script) of;
}

const List<_AxisField> _axisFields = <_AxisField>[
  _AxisField('script.offset', _offsetOf),
  _AxisField('script.rotation', _rotationOf),
  _AxisField('script.scale', _scaleOf),
];

GlossRealDropScriptAxis _offsetOf(GlossRealDropScript script) => script.offset;
GlossRealDropScriptAxis _rotationOf(GlossRealDropScript script) =>
    script.rotation;
GlossRealDropScriptAxis _scaleOf(GlossRealDropScript script) => script.scale;

const List<String> _numericFields = <String>[
  'script.offset.x',
  'script.offset.y',
  'script.offset.z',
  'script.rotation.x',
  'script.rotation.y',
  'script.rotation.z',
  'script.scale.x',
  'script.scale.y',
  'script.scale.z',
];

/// Parses, length-checks and name-checks one expression source.
///
/// Returns null when it did not compile, having already recorded why. The
/// unknown-variable and unknown-function walk is the server's `validateTree`:
/// a name is legal only if it is a built-in or a `vars` entry declared *before*
/// this one, which is what makes forward references an error rather than a
/// silent zero.
PExpr? _compile(
  String field,
  String path,
  String source,
  Set<String> declared,
  Set<String> referenced,
  List<RealDropScriptIssue> issues,
) {
  if (source.trim().isEmpty) {
    _add(
      issues,
      path,
      '{field} must be a non-blank expression',
      <String, Object?>{'field': field},
    );
    return null;
  }
  if (source.length > GlossRealDropScript.maxSourceLength) {
    _add(issues, path, '{field} exceeds {limit} characters', <String, Object?>{
      'field': field,
      'limit': GlossRealDropScript.maxSourceLength,
    });
    return null;
  }
  final PExpr expression;
  try {
    expression = parsePreviewExpr(source);
  } on PExprException catch (e) {
    _add(
      issues,
      path,
      e.position == previewNoPosition
          ? '{field}: {message}'
          : '{field}: {message} at position {position}',
      <String, Object?>{
        'field': field,
        'message': _DeferredText(() => e.message),
        if (e.position != previewNoPosition) 'position': e.position,
      },
    );
    return null;
  }
  final int before = issues.length;
  _walk(field, path, source, expression, declared, referenced, issues);
  return issues.length == before ? expression : null;
}

void _walk(
  String field,
  String path,
  String source,
  PExpr expression,
  Set<String> declared,
  Set<String> referenced,
  List<RealDropScriptIssue> issues,
) {
  switch (expression) {
    case PNum():
    case PStr():
    case PBool():
      return;
    case PVar(name: final String name):
      if (!realDropScriptVariables.contains(name) && !declared.contains(name)) {
        _add(
          issues,
          path,
          "{field}: unknown variable '{name}' at position {position}",
          <String, Object?>{
            'field': field,
            'name': name,
            'position': math.max(0, source.indexOf(name)),
          },
        );
        return;
      }
      referenced.add(name);
    case PList(items: final List<PExpr> items):
      for (final PExpr item in items) {
        _walk(field, path, source, item, declared, referenced, issues);
      }
    case PUnary():
      _walk(
        field,
        path,
        source,
        expression.operand,
        declared,
        referenced,
        issues,
      );
    case PBinary():
      _walk(field, path, source, expression.left, declared, referenced, issues);
      _walk(
        field,
        path,
        source,
        expression.right,
        declared,
        referenced,
        issues,
      );
    case PTernary():
      _walk(
        field,
        path,
        source,
        expression.condition,
        declared,
        referenced,
        issues,
      );
      _walk(
        field,
        path,
        source,
        expression.ifTrue,
        declared,
        referenced,
        issues,
      );
      _walk(
        field,
        path,
        source,
        expression.ifFalse,
        declared,
        referenced,
        issues,
      );
    case PCall(name: final String name, args: final List<PExpr> args):
      if (!realDropScriptFunctions.contains(name) &&
          !previewStandardFunctionNames.contains(name)) {
        _add(
          issues,
          path,
          "{field}: unknown function '{name}' at position {position}",
          <String, Object?>{
            'field': field,
            'name': name,
            'position': math.max(0, source.indexOf(name)),
          },
        );
        return;
      }
      for (final PExpr argument in args) {
        _walk(field, path, source, argument, declared, referenced, issues);
      }
  }
}

void _add(
  List<RealDropScriptIssue> issues,
  String path,
  String message, [
  Map<String, Object?> messageArguments = const <String, Object?>{},
]) {
  // One message per field is what the server prints, because it refuses the
  // document at the first one. Repeating the same complaint four times over
  // the four sample contexts would only pad the validation panel.
  if (issues.any(
    (RealDropScriptIssue issue) =>
        issue.path == path &&
        issue.englishMessage == message &&
        issue.message == huiText(message, messageArguments),
  )) {
    return;
  }
  issues.add(
    RealDropScriptIssue(
      path: path,
      message: message,
      messageArguments: messageArguments,
    ),
  );
}

/// `RealDropScriptPlan.color`: a number is an ARGB value narrowed the way
/// Java's `(int) (long)` cast narrows it; a string must be `#RRGGBB` or
/// `#AARRGGBB`, and an empty one means no glow.
int _colorOf(Object? result) {
  if (result is double) {
    return result.isFinite ? previewNarrowArgb(result) : 0;
  }
  if (result is String) {
    final String text = result.trim();
    if (text.isEmpty) return 0;
    final String digits = text.startsWith('#') ? text.substring(1) : text;
    final int? value = digits.length == 6 || digits.length == 8
        ? int.tryParse(digits, radix: 16)
        : null;
    if (value == null) {
      throw PExprException(
        "script.glow string must be #RRGGBB or #AARRGGBB, got '{text}'",
        previewNoPosition,
        <String, Object?>{'text': text},
      );
    }
    return digits.length == 6 ? value | 0xFF000000 : value;
  }
  throw PExprException(
    'script.glow must evaluate to a colour number or a #RRGGBB string, '
    'got {type}',
    previewNoPosition,
    <String, Object?>{'type': _DeferredText(() => previewTypeName(result))},
  );
}

/// The drop scope: built-ins first from the context, `vars` shadowing nothing
/// but resolved ahead of them because a name that shadows a built-in is
/// refused at compile time.
final class _Scope implements PExprScope {
  _Scope(this.context);

  final RealDropScriptContext context;
  final Map<String, Object> locals = <String, Object>{};

  @override
  Object? variable(String dottedName) {
    final Object? local = locals[dottedName];
    if (local != null) return local;
    return switch (dottedName) {
      't' => context.t,
      'age' => context.age.toDouble(),
      'index' => context.index.toDouble(),
      'count' => context.count.toDouble(),
      'amount' => context.amount.toDouble(),
      'onGround' => context.onGround,
      'settled' => context.settled,
      'phase' => context.phase,
      'stateTime' => context.stateTime,
      'impactSpeed' => context.impactSpeed,
      'inWater' => context.inWater,
      'inLava' => context.inLava,
      'bounces' => context.bounces.toDouble(),
      'velocityX' => context.velocityX,
      'velocityY' => context.velocityY,
      'velocityZ' => context.velocityZ,
      'speed' => context.speed,
      'height' => context.height,
      'blockLight' => context.blockLight.toDouble(),
      'skyLight' => context.skyLight.toDouble(),
      'random' => context.random,
      'material' => context.material,
      'isBlock' => context.kind == DropModelKind.block,
      'isFlat' => context.kind == DropModelKind.flat,
      'isThin' => context.kind == DropModelKind.thin,
      'pi' => math.pi,
      _ => null,
    };
  }

  @override
  Object? call(String name, List<Object?> args) {
    switch (name) {
      case 'materialIs':
        return realDropNormalizeMaterial(_stringArgument(name, args)) ==
            context.material;
      case 'materialMatches':
        return realDropGlobPattern(
          realDropNormalizeMaterial(_stringArgument(name, args)),
        ).hasMatch(context.material);
      default:
        return previewStdFunction(name, args);
    }
  }

  static String _stringArgument(String name, List<Object?> args) {
    if (args.length != 1) {
      throw PExprException(
        '{name} expects exactly one argument, got {count}',
        previewNoPosition,
        <String, Object?>{'name': name, 'count': args.length},
      );
    }
    final Object? value = args.first;
    if (value is String) return value;
    throw PExprException(
      '{name} argument 1 must be a string',
      previewNoPosition,
      <String, Object?>{'name': name},
    );
  }
}

/// `RealDropScriptPlan.normalizeMaterial`: strip a namespace, upper case, and
/// fold spaces and hyphens to underscores, so `materialIs('minecraft:soul
/// torch')` and `materialIs('SOUL_TORCH')` are the same test.
String realDropNormalizeMaterial(String value) {
  final String trimmed = value.trim();
  final int colon = trimmed.indexOf(':');
  final String bare = colon < 0 ? trimmed : trimmed.substring(colon + 1);
  return bare.toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
}

final Map<String, RegExp> _patterns = <String, RegExp>{};

/// `RealDropScriptPlan.globPattern`: `*` is any run, `?` is exactly one, and
/// everything else is literal. Anchored, because Java's `Matcher.matches`
/// requires the whole name to match.
RegExp realDropGlobPattern(String glob) => _patterns.putIfAbsent(glob, () {
  final StringBuffer regex = StringBuffer('^');
  for (int index = 0; index < glob.length; index++) {
    final String symbol = glob[index];
    if (symbol == '*') {
      regex.write('.*');
      continue;
    }
    if (symbol == '?') {
      regex.write('.');
      continue;
    }
    regex.write(RegExp.escape(symbol));
  }
  regex.write(r'$');
  return RegExp(regex.toString());
});
