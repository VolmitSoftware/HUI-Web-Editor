library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/preview_doc.dart';
import 'preview_expr.dart';
import 'validation.dart';

const List<String> glossShowVariables = <String>[
  'viewer.name',
  'viewer.world',
  'viewer.health',
  'viewer.maxHealth',
  'viewer.healthPercent',
  'viewer.level',
  'viewer.ping',
  'viewer.gameMode',
  'subject.name',
  'subject.world',
  'source.name',
  'source.world',
  'world.name',
  'world.time',
  'server.online',
  'server.max',
  'server.tps',
  'time.ms',
  'time.seconds',
  'time.ticks',
];

void setGlossShow(Map<String, Object?> fields, Object? value) {
  if (value == null || value == '') {
    fields.remove('show');
  } else {
    fields['show'] = value;
  }
}

List<HuiIssue> validateGlossShow(
  Object? raw, {
  String path = r'$.show',
  String? componentId,
}) {
  if (raw == null || raw is bool) return const <HuiIssue>[];
  if (raw is! String) {
    return <HuiIssue>[
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        componentId: componentId,
        message: 'Expected a boolean or expression string',
      ),
    ];
  }
  try {
    final Object? normalized = previewShowExpression(raw);
    if (normalized == null || normalized is bool) return const <HuiIssue>[];
    final PExpr expr = parsePreviewExpr(normalized as String);
    if (isConstantExpr(expr)) evalBool(expr, GlossShowScope());
    return const <HuiIssue>[];
  } on PExprException catch (error) {
    return <HuiIssue>[
      HuiIssue(
        severity: HuiSeverity.error,
        path: path,
        componentId: componentId,
        message: 'Invalid visibility expression: {error}',
        messageArguments: <String, Object?>{
          'error': error.localizedMessageArgument,
        },
      ),
    ];
  }
}

bool glossShowMatches(
  Object? raw, {
  PExprScope? scope,
  int nowMs = 0,
  bool viewerAware = true,
}) {
  if (raw == null) return true;
  if (raw is bool) return raw;
  if (raw is! String) return false;
  try {
    final Object? normalized = previewShowExpression(raw);
    if (normalized == null) return true;
    if (normalized is bool) return normalized;
    return evalBool(
      parsePreviewExpr(normalized as String),
      GlossShowScope(scope: scope, nowMs: nowMs, viewerAware: viewerAware),
    );
  } on PExprException {
    return false;
  }
}

final class GlossShowScope extends PExprScope {
  GlossShowScope({this.scope, this.nowMs = 0, this.viewerAware = true});
  final PExprScope? scope;
  final int nowMs;
  final bool viewerAware;
  final GlossConditionContext _defaults = GlossConditionContext(
    variables: <String, Object?>{
      'viewer.name': 'Builder',
      'viewer.world': 'world',
      'viewer.health': 18.0,
      'viewer.maxHealth': 20.0,
      'viewer.healthPercent': 90.0,
      'viewer.level': 27.0,
      'viewer.ping': 42.0,
      'viewer.gameMode': 'SURVIVAL',
      'subject.name': 'Builder',
      'subject.world': 'world',
      'source.name': 'Builder',
      'source.world': 'world',
      'world.name': 'world',
      'world.time': 6000.0,
      'server.online': 86.0,
      'server.max': 250.0,
      'server.tps': 19.8,
    },
    groups: <String>{'default'},
    placeholders: <String, String>{
      'player_name': 'Builder',
      'player_ping': '42',
    },
    metrics: <String, double>{'react.tps': 19.8, 'react.tick-ms': 12.4},
  );

  @override
  Object? variable(String name) {
    if (!viewerAware &&
        (name.startsWith('viewer.') ||
            name.startsWith('player.') ||
            name.startsWith('subject.') ||
            name.startsWith('source.') ||
            name.startsWith('world.'))) {
      return null;
    }
    final Object? supplied =
        scope?.variable(name) ??
        (name.startsWith('viewer.')
            ? scope?.variable('player.${name.substring(7)}')
            : null);
    if (supplied != null) return supplied;
    return switch (name) {
      'time.ms' => nowMs.toDouble(),
      'time.seconds' => nowMs / 1000,
      'time.ticks' => nowMs / 50,
      _ => _defaults.variable(
        name.startsWith('player.') ? 'viewer.${name.substring(7)}' : name,
      ),
    };
  }

  @override
  Object? call(String name, List<Object?> args) {
    if (!viewerAware &&
        const <String>{'hasPermission', 'inGroup', 'inRegion'}.contains(name)) {
      return false;
    }
    if (scope is GlossConditionContext) return scope!.call(name, args);
    if (const <String>{
          'hasPermission',
          'inGroup',
          'inRegion',
          'oneOf',
          'contains',
          'startsWith',
          'endsWith',
          'matchesGlob',
        }.contains(name) ||
        ((name == 'papi' || name == 'papiNumber') && args.length == 3)) {
      return _defaults.call(name, args);
    }
    if (scope != null) return scope!.call(name, args);
    return _defaults.call(name, args);
  }
}
