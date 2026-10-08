import '../model/hui_actions.dart';
import 'gloss_condition_validation.dart';
import 'preview_expr.dart';
import 'validation.dart';

List<HuiIssue> behaviorActionIssues(Object? raw, String path) {
  final List<HuiIssue> issues = <HuiIssue>[];
  void error(
    String path,
    String message, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) => issues.add(
    HuiIssue(
      severity: HuiSeverity.error,
      path: path,
      message: message,
      messageArguments: arguments,
    ),
  );
  void number(
    Map<String, Object?> action,
    String key,
    String path,
    num minimum,
    num maximum, {
    bool required = false,
    bool integer = true,
  }) {
    final Object? value = action[key];
    if (value == null && !required) return;
    if (value is! num ||
        !value.isFinite ||
        integer && value % 1 != 0 ||
        value < minimum ||
        value > maximum) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.$key',
          message: 'Use a number from {minimum} through {maximum}.',
          messageArguments: <String, Object?>{
            'minimum': minimum,
            'maximum': maximum,
          },
        ),
      );
    }
  }

  void expression(
    Map<String, Object?> action,
    String key,
    String path, {
    bool required = false,
    bool condition = true,
  }) {
    final Object? value = action[key];
    if (value == null && !required) return;
    if (value is! String) {
      error('$path.$key', 'Expected a string');
    } else {
      if (!required && value.trim().isEmpty) return;
      if (condition) {
        issues.addAll(glossConditionIssues(value, '$path.$key'));
      } else {
        try {
          parsePreviewExpr(value);
        } on PExprException catch (failure) {
          issues.add(
            HuiIssue(
              severity: HuiSeverity.error,
              path: '$path.$key',
              message: 'Invalid action expression: {error}',
              messageArguments: <String, Object?>{'error': failure.message},
            ),
          );
        }
      }
    }
  }

  late void Function(Object?, String, int) visit;
  void list(Object? raw, String path, int depth, {bool nonempty = false}) {
    if (raw == null && !nonempty) return;
    if (raw is! List) {
      error(path, 'Expected an array');
      return;
    }
    if (nonempty && raw.isEmpty) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: path,
          message: 'Add at least one action.',
        ),
      );
    }
    for (final (int index, Object? item) in raw.indexed) {
      visit(item, '$path[$index]', depth + 1);
    }
  }

  visit = (Object? raw, String path, int depth) {
    if (depth > 64) return;
    if (raw is! Map<String, Object?>) {
      error(path, 'Expected an object');
      return;
    }
    final Object? type = raw['type'];
    if (!huiActionTypes.contains(type)) {
      error('$path.type', 'Choose one of: {values}', <String, Object?>{
        'values': huiActionTypes.join(', '),
      });
      return;
    }
    if (type == 'call') {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '$path.type',
          message: 'Named action calls are not supported in behaviors.',
        ),
      );
    }
    expression(raw, 'when', path, required: type == 'if');
    if (type == 'delay') number(raw, 'ticks', path, 1, 1728000, required: true);
    if (type == 'cooldown') {
      number(raw, 'ticks', path, 1, 2147483647, required: true);
    }
    if (type == 'sequence') {
      list(raw['steps'], '$path.steps', depth, nonempty: true);
      list(raw['onSkip'], '$path.onSkip', depth);
      final Object? steps = raw['steps'];
      if (steps is List) {
        for (final (int index, Object? step) in steps.indexed) {
          if (step is Map<String, Object?>) {
            number(step, 'atTicks', '$path.steps[$index]', 0, 1728000);
          }
        }
      }
    }
    if (type == 'repeat') {
      number(
        raw,
        'times',
        path,
        1,
        raw['everyTicks'] == null || raw['everyTicks'] == 0 ? 1024 : 100000,
        required: true,
      );
      number(raw, 'everyTicks', path, 0, 1728000);
      expression(raw, 'while', path);
      list(raw['steps'], '$path.steps', depth);
    }
    if (<String>{'if', 'chance', 'cooldown'}.contains(type)) {
      list(raw['then'], '$path.then', depth);
      list(raw['else'], '$path.else', depth);
    }
    if (type == 'prompt') {
      list(raw['then'], '$path.then', depth);
    }
    if (type == 'dialog') {
      list(raw['unsupported'], '$path.unsupported', depth);
      list(raw['onTimeout'], '$path.onTimeout', depth);
      final Object? buttons = raw['buttons'];
      if (buttons is List) {
        for (final (int index, Object? button) in buttons.indexed) {
          if (button is Map<String, Object?>) {
            list(button['actions'], '$path.buttons[$index].actions', depth);
          }
        }
      }
      final Object? exitButton = raw['exitButton'];
      if (exitButton is Map<String, Object?>) {
        list(exitButton['actions'], '$path.exitButton.actions', depth);
      }
    }
    if (type == 'chance') {
      number(raw, 'percent', path, 0, 100, integer: false, required: true);
    }
    if (type == 'parallel') {
      final Object? branches = raw['branches'];
      if (branches is! List || branches.isEmpty) {
        error('$path.branches', 'Add at least one action.');
      }
      if (branches is List) {
        for (final (int index, Object? branch) in branches.indexed) {
          list(branch, '$path.branches[$index]', depth);
        }
      }
    }
    if (type == 'switch') {
      expression(raw, 'on', path, required: true, condition: false);
      final Object? cases = raw['cases'];
      if (cases is! Map<String, Object?> || cases.isEmpty) {
        error('$path.cases', 'Add at least one action.');
      }
      if (cases is Map<String, Object?>) {
        for (final MapEntry<String, Object?> entry in cases.entries) {
          list(entry.value, '$path.cases.${entry.key}', depth);
        }
      }
      list(raw['default'], '$path.default', depth);
    }
    if (<String>{'setState', 'addState', 'clearState'}.contains(type)) {
      final Object? key = raw['key'];
      if (key is! String ||
          !RegExp(r'^[a-z][a-z0-9_.]*$').hasMatch(key.trim())) {
        issues.add(
          HuiIssue(
            severity: HuiSeverity.error,
            path: '$path.key',
            message: 'Invalid state key.',
          ),
        );
      }
      if (type != 'clearState') {
        expression(raw, 'value', path, required: true, condition: false);
      }
      final Object? target = raw['target'];
      if (target != null &&
          !const <String>{'viewer', 'subject', 'source'}.contains(target)) {
        error('$path.target', 'Choose one of: {values}', <String, Object?>{
          'values': 'viewer, subject, source',
        });
      }
    }
  };
  list(raw, path, 0);
  return issues;
}
