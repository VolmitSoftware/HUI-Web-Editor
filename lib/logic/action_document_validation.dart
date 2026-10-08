import 'dialog_action_validation.dart';
import 'validation.dart';

List<HuiIssue> validateActionDocument(Map<String, Object?> document) {
  final List<HuiIssue> issues = <HuiIssue>[];
  final Object? declared = document['actions'];
  final Map<String, Object?> library = declared is Map<String, Object?>
      ? declared
      : <String, Object?>{};
  void reject(String path, String message) => issues.add(
    HuiIssue(severity: HuiSeverity.error, path: path, message: message),
  );
  if (declared != null &&
      (declared is! Map<String, Object?> || library.length > 256)) {
    reject(
      'actions',
      'Named actions require an object with at most 256 action lists.',
    );
  }
  for (final MapEntry<String, Object?> entry in library.entries) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(entry.key) ||
        entry.value is! List<Object?>) {
      reject(
        'actions.${entry.key}',
        'Use a 1..64 character action name and an array of actions.',
      );
    }
  }
  final Map<String, int> depths = <String, int>{};
  final Set<String> active = <String>{};
  const Set<String> lists = <String>{
    'actions',
    'trueActions',
    'falseActions',
    'then',
    'else',
    'unsupported',
    'onTimeout',
  };
  int nodes = 0;
  late int Function(Object? value, String path, bool action, int depth) walk;
  int reference(String name, String path) {
    if (!library.containsKey(name)) {
      reject(path, 'Named action "$name" does not exist.');
      return 0;
    }
    if (active.contains(name)) {
      reject(path, 'Named action cycle includes "$name".');
      return 0;
    }
    if (depths.containsKey(name)) return depths[name]!;
    if (active.length >= 32) {
      reject(path, 'Named actions exceed 32 nested calls.');
      return 0;
    }
    active.add(name);
    final int depth = 1 + walk(library[name], 'actions.$name', true, 0);
    active.remove(name);
    depths[name] = depth;
    if (depth > 32) reject(path, 'Named actions exceed 32 nested calls.');
    return depth;
  }

  walk = (Object? value, String path, bool action, int depth) {
    if (++nodes > 100000 || depth > 256) {
      if (nodes == 100001 || depth == 257) {
        reject(path, 'Action document exceeds the complexity limit.');
      }
      return 0;
    }
    int maximum = 0;
    if (value is List<Object?>) {
      for (int index = 0; index < value.length; index++) {
        final int result = walk(
          value[index],
          '$path[$index]',
          action,
          depth + 1,
        );
        if (result > maximum) maximum = result;
      }
    } else if (value is Map<String, Object?>) {
      if (action && value['type'] == 'call') {
        final Object? name = value['action'];
        if (name is! String) {
          reject('$path.action', 'Call requires a named action.');
          return 0;
        }
        return reference(name, '$path.action');
      }
      if (action && value['type'] == 'dialog') {
        issues.addAll(validateDialogAction(value, path));
      }
      for (final MapEntry<String, Object?> entry in value.entries) {
        final int result = walk(
          entry.value,
          '$path.${entry.key}',
          action || lists.contains(entry.key),
          depth + 1,
        );
        if (result > maximum) maximum = result;
      }
    }
    return maximum;
  };
  for (final String name in library.keys) {
    reference(name, 'actions.$name');
  }
  final Map<String, Object?> body = Map<String, Object?>.from(document)
    ..remove('actions');
  walk(body, r'$', false, 0);
  return issues;
}
