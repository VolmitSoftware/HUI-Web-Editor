import 'validation.dart';

List<HuiIssue> validateDialogAction(Map<String, Object?> data, String path) {
  final List<HuiIssue> issues = <HuiIssue>[];
  void reject(String key, String message) => issues.add(
    HuiIssue(severity: HuiSeverity.error, path: '$path.$key', message: message),
  );
  void integer(
    Map<String, Object?> object,
    String key,
    int minimum,
    int maximum,
    String prefix,
  ) {
    final Object? value = object[key];
    if (value != null &&
        (value is! num ||
            !value.isFinite ||
            value % 1 != 0 ||
            value < minimum ||
            value > maximum)) {
      reject(
        '$prefix$key',
        '$key must be an integer from $minimum to $maximum.',
      );
    }
  }

  List<Object?> array(String key) {
    final Object? value = data[key];
    if (value == null) return <Object?>[];
    if (value is! List<Object?>) {
      reject(key, '$key must be an array.');
      return <Object?>[];
    }
    if (value.length > 64) reject(key, '$key supports at most 64 entries.');
    return value;
  }

  final Object kind = data['kind'] ?? 'notice';
  if (!const <String>['notice', 'confirmation', 'multi_action'].contains(kind)) {
    reject('kind', 'Use notice, confirmation or multi_action.');
  }
  integer(data, 'columns', 1, 64, '');
  integer(data, 'timeoutTicks', 1, 72000, '');
  final List<Object?> buttons = data['buttons'] == null
      ? <Object?>[<String, Object?>{}]
      : array('buttons');
  if (buttons.isEmpty ||
      kind == 'notice' && buttons.length != 1 ||
      kind == 'confirmation' && buttons.length != 2) {
    reject(
      'buttons',
      'Notice requires one button, confirmation two, and multi_action at least one.',
    );
  }
  if (data['exitButton'] != null && kind != 'multi_action') {
    reject('exitButton', 'Only multi_action supports an exit button.');
  }
  for (final String key in <String>['body', 'buttons']) {
    final List<Object?> entries = key == 'buttons' ? buttons : array(key);
    for (int index = 0; index < entries.length; index++) {
      final Object? entry = entries[index];
      if (entry is! Map<String, Object?>) {
        reject('$key[$index]', 'Each entry must be an object.');
        continue;
      }
      integer(entry, 'width', 1, 1024, '$key[$index].');
    }
  }
  final Set<String> keys = <String>{};
  final List<Object?> inputs = array('inputs');
  int lengthBudget = 0;
  for (int index = 0; index < inputs.length; index++) {
    final String prefix = 'inputs[$index].';
    final Object? input = inputs[index];
    if (input is! Map<String, Object?>) {
      reject('inputs[$index]', 'Input must be an object.');
      continue;
    }
    final Object? key = input['key'];
    if (key is! String ||
        !RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(key) ||
        !keys.add(key)) {
      reject(
        '${prefix}key',
        'Input keys must be unique, with 1..64 letters, digits or underscores.',
      );
    }
    final Object type = input['type'] ?? 'text';
    if (!const <String>[
      'text',
      'boolean',
      'single_option',
      'number_range',
    ].contains(type)) {
      reject(
        '${prefix}type',
        'Use a native text, boolean, single_option or number_range control.',
      );
    }
    integer(input, 'width', 1, 1024, prefix);
    integer(input, 'maxLength', 1, 4096, prefix);
    integer(input, 'maxLines', 1, 4096, prefix);
    integer(input, 'height', 1, 512, prefix);
    final Object? initial = input['initial'];
    final Object? maxLength = input['maxLength'];
    final int limit = maxLength is num && maxLength.isFinite
        ? maxLength.toInt()
        : 32;
    lengthBudget += type == 'text' ? limit : 256;
    if (type == 'text' &&
        initial != null &&
        (initial is! String || initial.length > limit)) {
      reject('${prefix}initial', 'Initial text must fit maxLength.');
    }
    if (type == 'boolean' && initial != null && initial is! bool) {
      reject('${prefix}initial', 'Checkbox initial must be a boolean.');
    }
    if (type == 'single_option') {
      final Object? options = input['options'];
      final Set<String> ids = <String>{};
      if (options is! List<Object?> || options.isEmpty || options.length > 64) {
        reject('${prefix}options', 'Provide 1..64 options.');
      } else {
        for (final Object? option in options) {
          final Object? id = option is Map<String, Object?>
              ? option['id']
              : null;
          if (id is! String || id.isEmpty || id.length > 256 || !ids.add(id)) {
            reject(
              '${prefix}options',
              'Option ids must be unique strings of 1..256 characters.',
            );
          }
        }
      }
      if (initial != null && !ids.contains(initial)) {
        reject('${prefix}initial', 'Initial must name one of the options.');
      }
    }
    if (type == 'number_range') {
      final Object? start = input['start'];
      final Object? end = input['end'];
      final Object? step = input['step'];
      if (start is! num ||
          end is! num ||
          !start.isFinite ||
          !end.isFinite ||
          start == end) {
        reject(
          '${prefix}start',
          'Range start and end must be distinct finite numbers.',
        );
      } else if (initial != null &&
          (initial is! num ||
              !initial.isFinite ||
              initial < (start < end ? start : end) ||
              initial > (start > end ? start : end))) {
        reject('${prefix}initial', 'Initial must be within the slider range.');
      }
      if (step != null && (step is! num || !step.isFinite || step <= 0)) {
        reject('${prefix}step', 'Step must be positive and finite.');
      }
    }
  }
  if (lengthBudget > 16000) {
    reject('inputs', 'Combined input length exceeds 16000 characters.');
  }
  return issues;
}
