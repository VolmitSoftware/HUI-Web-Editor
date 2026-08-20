library;

import 'dart:math' as math;

import '../model/gloss_bubble_style.dart';
import 'preview_expr.dart';
import 'preview_expr_functions.dart';

const int glossBubbleMotionMaxExpressionLength = 512;
const double glossBubbleMotionMinTranslation = -64;
const double glossBubbleMotionMaxTranslation = 64;
const double glossBubbleMotionMinScale = 0;
const double glossBubbleMotionMaxScale = 16;
const double glossBubbleMotionMinOpacity = 0;
const double glossBubbleMotionMaxOpacity = 1;

const Set<String> glossBubbleMotionVariables = <String>{
  't',
  'remaining',
  'ageMs',
  'lifetimeMs',
  'stackIndex',
  'stackCount',
  'lineCount',
  'stackY',
  'seed',
  'pi',
};

double evaluateGlossBubbleMotionSource(
  String source,
  GlossBubbleMotionContext context,
) {
  if (source.length > glossBubbleMotionMaxExpressionLength) {
    throw const PExprException(
      'bubble motion expression exceeds 512 characters',
      previewNoPosition,
    );
  }
  final double value = evalNumber(
    parsePreviewExpr(source),
    _BubbleMotionScope(context),
  );
  if (!value.isFinite) {
    throw const PExprException(
      'bubble motion expression must evaluate to a finite number',
      previewNoPosition,
    );
  }
  return value;
}

final class GlossBubbleMotionContext {
  const GlossBubbleMotionContext({
    required double t,
    required double ageMs,
    required double lifetimeMs,
    required this.stackIndex,
    required this.stackCount,
    required this.lineCount,
    required this.stackY,
    required this.seed,
  }) : _t = t,
       _ageMs = ageMs,
       _lifetimeMs = lifetimeMs;

  final double _t;
  final double _ageMs;
  final double _lifetimeMs;
  final double stackIndex;
  final double stackCount;
  final double lineCount;
  final double stackY;
  final double seed;

  double get t => math.min(1.0, math.max(0.0, _t));
  double get ageMs => math.max(0.0, _ageMs);
  double get lifetimeMs => math.max(1.0, _lifetimeMs);
  double get remaining => 1.0 - t;
}

final class GlossBubbleMotionFrame {
  const GlossBubbleMotionFrame({
    required this.translationX,
    required this.translationY,
    required this.translationZ,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.opacity,
  });

  const GlossBubbleMotionFrame.identity()
    : translationX = 0,
      translationY = 0,
      translationZ = 0,
      scaleX = 1,
      scaleY = 1,
      scaleZ = 1,
      rotationX = 0,
      rotationY = 0,
      rotationZ = 0,
      opacity = 1;

  final double translationX;
  final double translationY;
  final double translationZ;
  final double scaleX;
  final double scaleY;
  final double scaleZ;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double opacity;
}

final class GlossBubbleMotionProgram {
  GlossBubbleMotionProgram._({
    required PExpr translationX,
    required PExpr translationY,
    required PExpr translationZ,
    required PExpr scaleX,
    required PExpr scaleY,
    required PExpr scaleZ,
    required PExpr rotationX,
    required PExpr rotationY,
    required PExpr rotationZ,
    required PExpr opacity,
  }) : _translationX = translationX,
       _translationY = translationY,
       _translationZ = translationZ,
       _scaleX = scaleX,
       _scaleY = scaleY,
       _scaleZ = scaleZ,
       _rotationX = rotationX,
       _rotationY = rotationY,
       _rotationZ = rotationZ,
       _opacity = opacity;

  final PExpr _translationX;
  final PExpr _translationY;
  final PExpr _translationZ;
  final PExpr _scaleX;
  final PExpr _scaleY;
  final PExpr _scaleZ;
  final PExpr _rotationX;
  final PExpr _rotationY;
  final PExpr _rotationZ;
  final PExpr _opacity;

  factory GlossBubbleMotionProgram.compile(GlossBubbleMotion motion) =>
      GlossBubbleMotionProgram._(
        translationX: _parse(motion.translation.x),
        translationY: _parse(motion.translation.y),
        translationZ: _parse(motion.translation.z),
        scaleX: _parse(motion.scale.x),
        scaleY: _parse(motion.scale.y),
        scaleZ: _parse(motion.scale.z),
        rotationX: _parse(motion.rotation.x),
        rotationY: _parse(motion.rotation.y),
        rotationZ: _parse(motion.rotation.z),
        opacity: _parse(motion.opacity),
      );

  GlossBubbleMotionFrame evaluate(GlossBubbleMotionContext context) {
    return _evaluateFrame(context, effective: true);
  }

  GlossBubbleMotionFrame evaluateWritten(GlossBubbleMotionContext context) {
    return _evaluateFrame(context, effective: false);
  }

  GlossBubbleMotionFrame _evaluateFrame(
    GlossBubbleMotionContext context, {
    required bool effective,
  }) {
    final _BubbleMotionScope scope = _BubbleMotionScope(context);
    final double translationX = _evaluate(
      _translationX,
      scope,
      effective ? 0 : null,
    );
    final double translationY = _evaluate(
      _translationY,
      scope,
      effective ? 0 : null,
    );
    final double translationZ = _evaluate(
      _translationZ,
      scope,
      effective ? 0 : null,
    );
    final double scaleX = _evaluate(_scaleX, scope, effective ? 1 : null);
    final double scaleY = _evaluate(_scaleY, scope, effective ? 1 : null);
    final double scaleZ = _evaluate(_scaleZ, scope, effective ? 1 : null);
    final double rotationX = _evaluate(_rotationX, scope, effective ? 0 : null);
    final double rotationY = _evaluate(_rotationY, scope, effective ? 0 : null);
    final double rotationZ = _evaluate(_rotationZ, scope, effective ? 0 : null);
    final double opacity = _evaluate(_opacity, scope, effective ? 1 : null);
    return GlossBubbleMotionFrame(
      translationX: effective
          ? _bounded(
              translationX,
              glossBubbleMotionMinTranslation,
              glossBubbleMotionMaxTranslation,
            )
          : translationX,
      translationY: effective
          ? _bounded(
              translationY,
              glossBubbleMotionMinTranslation,
              glossBubbleMotionMaxTranslation,
            )
          : translationY,
      translationZ: effective
          ? _bounded(
              translationZ,
              glossBubbleMotionMinTranslation,
              glossBubbleMotionMaxTranslation,
            )
          : translationZ,
      scaleX: effective
          ? _bounded(
              scaleX,
              glossBubbleMotionMinScale,
              glossBubbleMotionMaxScale,
            )
          : scaleX,
      scaleY: effective
          ? _bounded(
              scaleY,
              glossBubbleMotionMinScale,
              glossBubbleMotionMaxScale,
            )
          : scaleY,
      scaleZ: effective
          ? _bounded(
              scaleZ,
              glossBubbleMotionMinScale,
              glossBubbleMotionMaxScale,
            )
          : scaleZ,
      rotationX: effective ? _normalizeRotation(rotationX) : rotationX,
      rotationY: effective ? _normalizeRotation(rotationY) : rotationY,
      rotationZ: effective ? _normalizeRotation(rotationZ) : rotationZ,
      opacity: effective
          ? _bounded(
              opacity,
              glossBubbleMotionMinOpacity,
              glossBubbleMotionMaxOpacity,
            )
          : opacity,
    );
  }

  static PExpr _parse(String source) {
    if (source.length > glossBubbleMotionMaxExpressionLength) {
      throw const PExprException(
        'bubble motion expression exceeds 512 characters',
        previewNoPosition,
      );
    }
    return parsePreviewExpr(source);
  }

  static double _evaluate(
    PExpr expression,
    PExprScope scope,
    double? fallback,
  ) {
    try {
      final double value = evalNumber(expression, scope);
      if (value.isFinite) return value;
    } on PExprException {
      if (fallback == null) rethrow;
    }
    if (fallback != null) return fallback;
    throw const PExprException(
      'bubble motion expression must evaluate to a finite number',
      previewNoPosition,
    );
  }

  static double _bounded(double value, double minimum, double maximum) =>
      math.min(maximum, math.max(minimum, value));

  static double _normalizeRotation(double value) {
    final double normalized = value % 360.0;
    if (normalized == 0.0) return 0.0;
    return normalized < 0.0 ? normalized + 360.0 : normalized;
  }
}

final class _BubbleMotionScope extends PExprScope {
  _BubbleMotionScope(this.context);

  final GlossBubbleMotionContext context;

  @override
  Object? variable(String dottedName) => switch (dottedName) {
    't' => context.t,
    'remaining' => context.remaining,
    'ageMs' => context.ageMs,
    'lifetimeMs' => context.lifetimeMs,
    'stackIndex' => context.stackIndex,
    'stackCount' => context.stackCount,
    'lineCount' => context.lineCount,
    'stackY' => context.stackY,
    'seed' => context.seed,
    'pi' => math.pi,
    _ => null,
  };

  @override
  Object? call(String name, List<Object?> args) =>
      previewStdFunction(name, args);
}
