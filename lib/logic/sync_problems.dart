/// The findings the plugin's workspace linter sends with a sync project.
///
/// They arrive in the project's `warnings` array as
/// `code|kind|id|pointer|message`. That shape is the contract: the plugin
/// writes it in `art.arcane.gloss.lint.Diagnostic.wire()`, and this is the only
/// place the editor takes it apart. A warning with no pipes is a plain sentence
/// the server wrote about the project as a whole, and stays whole.
library;

import '../l10n/hui_localizations.dart';

/// How much a finding matters. Derived from the code, because the plugin's own
/// severities travel with the code rather than with the sentence.
enum SyncProblemSeverity { error, warning, info }

const Set<String> _errorCodes = <String>{
  'dangling-navigate',
  'panel-root-missing',
  'image-missing',
  'animation-unknown',
  'motion-unknown',
  'dialog-unknown',
  'inventory-unknown',
};

/// One finding, about one document or about the workspace.
final class SyncProblem {
  const SyncProblem({
    required this.code,
    required this.kind,
    required this.id,
    required this.pointer,
    required this.message,
    required this.severity,
  });

  final String code;
  final String kind;
  final String id;

  /// JSON pointer into the document, or empty when the finding is about the
  /// document as a whole.
  final String pointer;

  final String message;
  final SyncProblemSeverity severity;

  bool get hasDocument => kind.isNotEmpty && id.isNotEmpty;

  /// The last pointer token, which is the field the finding blames, or null
  /// when the finding names no field.
  String? get fieldName {
    if (pointer.isEmpty) return null;
    final int separator = pointer.lastIndexOf('/');
    if (separator < 0 || separator == pointer.length - 1) return null;
    return pointer
        .substring(separator + 1)
        .replaceAll('~1', '/')
        .replaceAll('~0', '~');
  }
}

/// The findings for one document, or the workspace-wide group.
final class SyncProblemGroup {
  const SyncProblemGroup({
    required this.kind,
    required this.id,
    required this.problems,
  });

  final String kind;
  final String id;
  final List<SyncProblem> problems;

  bool get isWorkspace => kind.isEmpty;

  String get label => isWorkspace ? huiText('Workspace') : '$kind $id';
}

/// Every finding a project carried, parsed once.
final class SyncProblems {
  const SyncProblems._(this.all);

  static const SyncProblems empty = SyncProblems._(<SyncProblem>[]);

  final List<SyncProblem> all;

  static SyncProblems of(List<String> warnings) => SyncProblems._(
    List<SyncProblem>.unmodifiable(<SyncProblem>[
      for (final String warning in warnings) _parse(warning),
    ]),
  );

  int get errorCount => _count(SyncProblemSeverity.error);

  int get warningCount => _count(SyncProblemSeverity.warning);

  int get infoCount => _count(SyncProblemSeverity.info);

  bool get isEmpty => all.isEmpty;

  /// Findings grouped by document, documents in kind then id order, with the
  /// workspace-wide group last.
  List<SyncProblemGroup> get groups {
    final Map<String, List<SyncProblem>> byDocument =
        <String, List<SyncProblem>>{};
    for (final SyncProblem problem in all) {
      final String key = problem.hasDocument
          ? '${problem.kind} ${problem.id}'
          : '';
      byDocument.putIfAbsent(key, () => <SyncProblem>[]).add(problem);
    }
    final List<String> keys = byDocument.keys.toList()
      ..sort((String left, String right) {
        if (left.isEmpty) return 1;
        if (right.isEmpty) return -1;
        return left.compareTo(right);
      });
    return List<SyncProblemGroup>.unmodifiable(<SyncProblemGroup>[
      for (final String key in keys)
        SyncProblemGroup(
          kind: key.isEmpty ? '' : key.split(' ').first,
          id: key.isEmpty ? '' : key.split(' ').last,
          problems: List<SyncProblem>.unmodifiable(byDocument[key]!),
        ),
    ]);
  }

  int _count(SyncProblemSeverity severity) =>
      all.where((SyncProblem problem) => problem.severity == severity).length;

  static SyncProblem _parse(String warning) {
    final List<String> parts = warning.split('|');
    if (parts.length < 5 || parts.first.isEmpty) {
      return SyncProblem(
        code: '',
        kind: '',
        id: '',
        pointer: '',
        message: warning,
        severity: SyncProblemSeverity.warning,
      );
    }
    return SyncProblem(
      code: parts[0],
      kind: parts[1],
      id: parts[2],
      pointer: parts[3],
      message: parts.sublist(4).join('|'),
      severity: _errorCodes.contains(parts[0])
          ? SyncProblemSeverity.error
          : SyncProblemSeverity.warning,
    );
  }
}

/// One document the server kept its own copy of because it moved under the
/// editor. The publish acknowledgement carries these as `{kind, id}`.
final class SyncConflict {
  const SyncConflict({required this.kind, required this.id});

  final String kind;
  final String id;

  static List<SyncConflict> of(Object? raw) {
    if (raw is! List) return const <SyncConflict>[];
    final List<SyncConflict> conflicts = <SyncConflict>[];
    for (final Object? entry in raw) {
      if (entry is! Map) continue;
      final Object? kind = entry['kind'];
      final Object? id = entry['id'];
      if (kind is! String || id is! String || kind.isEmpty || id.isEmpty) {
        continue;
      }
      conflicts.add(SyncConflict(kind: kind, id: id));
    }
    return List<SyncConflict>.unmodifiable(conflicts);
  }
}
