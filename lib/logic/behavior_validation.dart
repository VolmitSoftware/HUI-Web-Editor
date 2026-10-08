import '../model/gloss_behavior.dart';
import '../model/behavior_authoring.dart';
import '../model/gloss_doc.dart';
import '../services/channel_filters_stub.dart'
    if (dart.library.js_interop) '../services/channel_filters_web.dart'
    as platform;
import 'gloss_show.dart';
import 'behavior_action_validation.dart';
import 'validation.dart';

const Map<String, Set<String>> behaviorTriggerOptions = <String, Set<String>>{
  'join': <String>{},
  'first_join': <String>{},
  'quit': <String>{},
  'respawn': <String>{},
  'death': <String>{},
  'kill': <String>{},
  'damage': <String>{},
  'chat': <String>{'pattern'},
  'command': <String>{'name'},
  'block_break': <String>{'material'},
  'block_place': <String>{'material'},
  'pickup': <String>{'material'},
  'drop': <String>{'material'},
  'world_change': <String>{},
  'region_enter': <String>{'region'},
  'region_leave': <String>{'region'},
  'menu_open': <String>{'menu'},
  'menu_close': <String>{'menu'},
  'menu_click': <String>{'menu', 'component'},
  'inventory_click': <String>{'menu', 'component'},
  'interval': <String>{'everyTicks', 'scope'},
  'server_start': <String>{},
  'emit': <String>{'name'},
};

List<HuiIssue> validateBehaviorDoc(GlossBehaviorDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[?glossRevisionIssue(doc.revision)];
  void error(String path, String message) => issues.add(
    HuiIssue(severity: HuiSeverity.error, path: path, message: message),
  );
  if (doc.matching.syntax != 're2') {
    error(r'$.matching.syntax', 'Use re2 syntax.');
  }
  final Map<String, List<int>> bounds = <String, List<int>>{
    'maxInputCharacters': <int>[1, 32768],
    'maxPatternCharacters': <int>[1, 4096],
    'maxProgramSize': <int>[16, 1000000],
    'maxNestingDepth': <int>[1, 128],
    'maxWorkUnits': <int>[1, 100000000],
  };
  final Map<String, Object?> matching = doc.matching.toJson();
  for (final MapEntry<String, List<int>> entry in bounds.entries) {
    final int value = matching[entry.key] as int;
    if (value < entry.value.first || value > entry.value.last) {
      error(
        '\$.matching.${entry.key}',
        'Use ${entry.value.first} through ${entry.value.last}.',
      );
    }
  }
  if (doc.on.length > 256) {
    error(r'$.on', 'A behavior supports at most 256 entries.');
  }
  for (int index = 0; index < doc.on.length; index++) {
    final GlossBehaviorEntry entry = doc.on[index];
    final String path = '\$.on[$index]';
    final Set<String>? accepted = behaviorTriggerOptions[entry.trigger];
    if (accepted == null) {
      error('$path.trigger', 'Choose a supported trigger.');
      continue;
    }
    for (final String key in entry.toJson().keys) {
      if (!const <String>{
            'trigger',
            'do',
            'when',
            'permission',
          }.contains(key) &&
          !accepted.contains(key)) {
        error('$path.$key', 'This trigger does not accept $key.');
      }
    }
    final String? required = switch (entry.trigger) {
      'command' || 'emit' => 'name',
      'region_enter' || 'region_leave' => 'region',
      'interval' => 'everyTicks',
      _ => null,
    };
    if (required != null && !entry.toJson().containsKey(required)) {
      error('$path.$required', '$required is required.');
    }
    if (entry.everyTicks != null &&
        (entry.everyTicks! < 1 || entry.everyTicks! > 1728000)) {
      error('$path.everyTicks', 'Use 1 through 1728000 ticks.');
    }
    if (entry.scope != null &&
        entry.scope != 'player' &&
        entry.scope != 'global') {
      error('$path.scope', 'Use player or global.');
    }
    for (final String key in <String>[
      'pattern',
      'name',
      'region',
      'material',
      'menu',
      'component',
    ]) {
      final Object? value = entry.toJson()[key];
      if (value is String && value.trim().isEmpty) {
        error('$path.$key', '$key must not be empty.');
      }
    }
    if (entry.pattern != null &&
        entry.pattern!.length > doc.matching.maxPatternCharacters) {
      error('$path.pattern', 'Pattern exceeds maxPatternCharacters.');
    }
    if (entry.when != null) {
      issues.addAll(validateGlossShow(entry.when, path: '$path.when'));
    }
    void checkActions(Object? value, String actionPath) {
      if (value is List<Object?>) {
        for (int actionIndex = 0; actionIndex < value.length; actionIndex++) {
          checkActions(value[actionIndex], '$actionPath[$actionIndex]');
        }
      } else if (value is Map<String, Object?>) {
        if (!doc.allowServerCommands &&
            value['type'] == 'command' &&
            const <String>{'server', 'GLOBAL'}.contains(value['source'])) {
          error(actionPath, 'Server commands require allowServerCommands.');
        }
        for (final MapEntry<String, Object?> child in value.entries) {
          checkActions(child.value, '$actionPath.${child.key}');
        }
      }
    }

    checkActions(entry.actions, '$path.do');
    issues.addAll(behaviorActionIssues(entry.actions, '$path.do'));
  }
  for (final MapEntry<String, Object?> entry in doc.state.entries) {
    final Object? declaration = entry.value;
    if (!RegExp(r'^[a-z][a-z0-9_.]*$').hasMatch(entry.key) ||
        declaration is! Map<String, Object?> ||
        !const <String>{
          'player',
          'world',
          'global',
        }.contains(declaration['scope']) ||
        !const <String>{
          'number',
          'string',
          'boolean',
        }.contains(declaration['type'])) {
      error(
        '\$.state.${entry.key}',
        'Use a lowercase key and a state object with scope and type.',
      );
    }
  }
  for (final MapEntry<String, Object?> entry in doc.state.entries) {
    final BehaviorStateDeclaration? state = BehaviorStateDeclaration.read(
      entry.value,
    );
    if (state != null &&
        const <String>{'number', 'boolean'}.contains(state.type) &&
        state.resolvedDefault == null) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '\$.state.${entry.key}.default',
          message: 'Invalid state default.',
        ),
      );
    }
  }
  final String? syntax = platform.validateBehavior(doc.toJson());
  if (syntax != null) error(r'$.on', syntax);
  return issues;
}
