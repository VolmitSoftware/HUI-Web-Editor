/// Conditional document and presentation selection used by Gloss previews.
library;

import '../../logic/preview_expr.dart';
import '../../logic/preview_expr_functions.dart';
import '../../model/gloss_scoreboard.dart';

final class GlossConditionContext extends PExprScope {
  GlossConditionContext({
    Map<String, Object?>? variables,
    Set<String>? permissions,
    Set<String>? groups,
    Set<String>? regions,
    Map<String, Set<String>>? permissionsByRole,
    Map<String, Set<String>>? groupsByRole,
    Map<String, Set<String>>? regionsByRole,
    Map<String, double>? metrics,
    Map<String, String>? placeholders,
    Map<String, Map<String, String>>? placeholdersByRole,
  }) : variables = variables ?? <String, Object?>{},
       permissions = permissions ?? <String>{},
       groups = groups ?? <String>{},
       regions = regions ?? <String>{},
       permissionsByRole = _roleSets(permissionsByRole, permissions),
       groupsByRole = _roleSets(groupsByRole, groups, lowerCase: true),
       regionsByRole = _roleSets(regionsByRole, regions),
       metrics = metrics ?? <String, double>{},
       placeholders = placeholders ?? <String, String>{},
       placeholdersByRole = _roleMaps(placeholdersByRole, placeholders);

  final Map<String, Object?> variables;
  final Set<String> permissions;
  final Set<String> groups;
  final Set<String> regions;
  final Map<String, Set<String>> permissionsByRole;
  final Map<String, Set<String>> groupsByRole;
  final Map<String, Set<String>> regionsByRole;
  final Map<String, double> metrics;
  final Map<String, String> placeholders;
  final Map<String, Map<String, String>> placeholdersByRole;

  @override
  Object? variable(String dottedName) => variables[dottedName];

  @override
  Object? call(String name, List<Object?> args) {
    switch (name) {
      case 'hasPermission':
        _requireCount(name, args, 2);
        return _roleValues(
          name,
          args,
          permissionsByRole,
        ).contains(_stringArgument(name, args, 1));
      case 'inGroup':
        _requireCount(name, args, 2);
        return _roleValues(
          name,
          args,
          groupsByRole,
        ).contains(_stringArgument(name, args, 1).toLowerCase());
      case 'inRegion':
        _requireCount(name, args, 2);
        return _roleValues(
          name,
          args,
          regionsByRole,
        ).contains(_stringArgument(name, args, 1));
      case 'papi':
        _requireCount(name, args, 3);
        final String role = _roleArgument(name, args);
        final String key = _stringArgument(name, args, 1);
        final String fallback = _stringArgument(name, args, 2);
        return _placeholderValue(role, key) ?? fallback;
      case 'papiNumber':
        _requireCount(name, args, 3);
        final String role = _roleArgument(name, args);
        final String key = _stringArgument(name, args, 1);
        final double fallback = _numberArgument(name, args, 2);
        return double.tryParse(_placeholderValue(role, key) ?? '') ?? fallback;
      case 'metric':
        _requireCount(name, args, 2);
        return metrics[_stringArgument(name, args, 0)] ??
            _numberArgument(name, args, 1);
      case 'oneOf':
        _requireCount(name, args, 2);
        final String expected = _stringArgument(name, args, 0);
        final Object? candidates = args[1];
        if (candidates is! List<Object?>) {
          throw PExprException(
            '{function} argument 2 must be a list',
            previewNoPosition,
            <String, Object?>{'function': name},
          );
        }
        for (final Object? candidate in candidates) {
          if (candidate is! String) {
            throw PExprException(
              '{function} argument 2 entries must be strings',
              previewNoPosition,
              <String, Object?>{'function': name},
            );
          }
          if (candidate == expected) return true;
        }
        return false;
      case 'contains':
        _requireCount(name, args, 2);
        return _stringArgument(
          name,
          args,
          0,
        ).contains(_stringArgument(name, args, 1));
      case 'startsWith':
        _requireCount(name, args, 2);
        return _stringArgument(
          name,
          args,
          0,
        ).startsWith(_stringArgument(name, args, 1));
      case 'endsWith':
        _requireCount(name, args, 2);
        return _stringArgument(
          name,
          args,
          0,
        ).endsWith(_stringArgument(name, args, 1));
      case 'matchesGlob':
        _requireCount(name, args, 2);
        return _matchesGlob(
          _stringArgument(name, args, 0),
          _stringArgument(name, args, 1),
        );
      default:
        return previewStdFunction(name, args);
    }
  }

  Set<String> _roleValues(
    String function,
    List<Object?> args,
    Map<String, Set<String>> values,
  ) => values[_roleArgument(function, args)] ?? const <String>{};

  String _roleArgument(String function, List<Object?> args) {
    final String role = _stringArgument(function, args, 0);
    if (role == 'viewer' || role == 'subject' || role == 'source') return role;
    throw PExprException(
      '{function} role must be viewer, subject, or source',
      previewNoPosition,
      <String, Object?>{'function': function},
    );
  }

  String _stringArgument(String function, List<Object?> args, int index) {
    if (args[index] is String) return args[index]! as String;
    throw PExprException(
      '{function} argument {argument} must be a string',
      previewNoPosition,
      <String, Object?>{'function': function, 'argument': index + 1},
    );
  }

  double _numberArgument(String function, List<Object?> args, int index) {
    if (args[index] is num) return (args[index]! as num).toDouble();
    throw PExprException(
      '{function} argument {argument} must be a number',
      previewNoPosition,
      <String, Object?>{'function': function, 'argument': index + 1},
    );
  }

  void _requireCount(String function, List<Object?> args, int count) {
    if (args.length == count) return;
    throw PExprException(
      '{function} expects {expected} argument(s), got {actual}',
      previewNoPosition,
      <String, Object?>{
        'function': function,
        'expected': count,
        'actual': args.length,
      },
    );
  }

  String? _placeholderValue(String role, String key) {
    final Map<String, String>? values = placeholdersByRole[role];
    final String wrapped = key.startsWith('%') && key.endsWith('%')
        ? key
        : '%$key%';
    return values?[key] ?? values?[wrapped];
  }

  bool _matchesGlob(String value, String pattern) {
    List<bool> previous = List<bool>.filled(value.length + 1, false);
    previous[0] = true;
    for (int patternIndex = 0; patternIndex < pattern.length; patternIndex++) {
      final String token = pattern[patternIndex];
      final List<bool> current = List<bool>.filled(value.length + 1, false);
      if (token == '*') {
        current[0] = previous[0];
        for (int valueIndex = 1; valueIndex <= value.length; valueIndex++) {
          current[valueIndex] = previous[valueIndex] || current[valueIndex - 1];
        }
      } else {
        for (int valueIndex = 1; valueIndex <= value.length; valueIndex++) {
          current[valueIndex] =
              previous[valueIndex - 1] &&
              (token == '?' || token == value[valueIndex - 1]);
        }
      }
      previous = current;
    }
    return previous[value.length];
  }
}

Map<String, Set<String>> _roleSets(
  Map<String, Set<String>>? values,
  Set<String>? viewerValues, {
  bool lowerCase = false,
}) {
  final Map<String, Set<String>> normalized = <String, Set<String>>{};
  for (final MapEntry<String, Set<String>> entry
      in (values ?? <String, Set<String>>{}).entries) {
    normalized[entry.key] = <String>{
      for (final String value in entry.value)
        lowerCase ? value.toLowerCase() : value,
    };
  }
  if (viewerValues != null && !normalized.containsKey('viewer')) {
    normalized['viewer'] = <String>{
      for (final String value in viewerValues)
        lowerCase ? value.toLowerCase() : value,
    };
  }
  return normalized;
}

Map<String, Map<String, String>> _roleMaps(
  Map<String, Map<String, String>>? values,
  Map<String, String>? viewerValues,
) {
  final Map<String, Map<String, String>> copied = <String, Map<String, String>>{
    for (final MapEntry<String, Map<String, String>> entry
        in (values ?? <String, Map<String, String>>{}).entries)
      entry.key: Map<String, String>.of(entry.value),
  };
  if (viewerValues != null && !copied.containsKey('viewer')) {
    copied['viewer'] = Map<String, String>.of(viewerValues);
  }
  return copied;
}

final class GlossBoardCandidate {
  const GlossBoardCandidate({
    required this.id,
    required this.priority,
    required this.when,
  });

  factory GlossBoardCandidate.fromDoc(String id, GlossScoreboardDoc doc) =>
      GlossBoardCandidate(
        id: id,
        priority: doc.select.priority,
        when: doc.select.when,
      );

  final String id;
  final int priority;
  final String when;
}

final class GlossBoardSelection {
  const GlossBoardSelection({required this.boardId, this.error});

  static const GlossBoardSelection empty = GlossBoardSelection(boardId: null);

  final String? boardId;
  final String? error;
}

GlossBoardSelection glossSelectBoard({
  required List<GlossBoardCandidate> boards,
  required GlossConditionContext context,
}) {
  final List<GlossBoardCandidate> matches = <GlossBoardCandidate>[];
  String? firstError;
  for (final GlossBoardCandidate board in boards) {
    final ({bool matches, String? error}) result = glossConditionMatches(
      board.when,
      context,
    );
    firstError ??= result.error;
    if (result.matches) matches.add(board);
  }
  matches.sort((GlossBoardCandidate first, GlossBoardCandidate second) {
    final int priority = second.priority.compareTo(first.priority);
    return priority != 0 ? priority : first.id.compareTo(second.id);
  });
  return GlossBoardSelection(
    boardId: matches.isEmpty ? null : matches.first.id,
    error: firstError,
  );
}

GlossScoreboardPresentation glossResolveScoreboardPresentation(
  GlossScoreboardDoc doc,
  GlossConditionContext context,
) {
  final List<GlossScoreboardVariant> matches =
      <GlossScoreboardVariant>[
        for (final GlossScoreboardVariant variant in doc.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort((GlossScoreboardVariant first, GlossScoreboardVariant second) {
        final int priority = second.priority.compareTo(first.priority);
        return priority != 0 ? priority : first.id.compareTo(second.id);
      });
  return matches.isEmpty ? doc.presentation : matches.first.presentation;
}

String? glossResolveScoreboardVariantId(
  GlossScoreboardDoc doc,
  GlossConditionContext context,
) {
  final List<GlossScoreboardVariant> matches =
      <GlossScoreboardVariant>[
        for (final GlossScoreboardVariant variant in doc.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort((GlossScoreboardVariant first, GlossScoreboardVariant second) {
        final int priority = second.priority.compareTo(first.priority);
        return priority != 0 ? priority : first.id.compareTo(second.id);
      });
  return matches.isEmpty ? null : matches.first.id;
}

({bool matches, String? error}) glossConditionMatches(
  String source,
  GlossConditionContext context,
) {
  try {
    return (matches: evalBool(parsePreviewExpr(source), context), error: null);
  } on PExprException catch (error) {
    return (matches: false, error: error.message);
  }
}
