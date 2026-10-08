import 'dart:convert';

import 'hui_actions.dart';
import 'json_codec.dart';

final class BehaviorStateDeclaration {
  BehaviorStateDeclaration({
    required this.scope,
    required this.type,
    this.defaultValue,
    this.hasDefault = false,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String scope;
  String type;
  Object? defaultValue;
  bool hasDefault;
  final Map<String, Object?> extras;

  static BehaviorStateDeclaration? read(Object? raw) {
    if (raw is! Map || raw['scope'] is! String || raw['type'] is! String) {
      return null;
    }
    return BehaviorStateDeclaration(
      scope: raw['scope'] as String,
      type: raw['type'] as String,
      defaultValue: huiDeepCopy(raw['default']),
      hasDefault: raw.containsKey('default'),
      extras: <String, Object?>{
        for (final MapEntry<Object?, Object?> field in raw.entries)
          if (field.key is String &&
              !const <String>{'scope', 'type', 'default'}.contains(field.key))
            field.key! as String: huiDeepCopy(field.value),
      },
    );
  }

  Object? get resolvedDefault {
    final Object? value = defaultValue;
    if (value == null) {
      return switch (type) {
        'number' => 0,
        'boolean' => false,
        _ => '',
      };
    }
    return switch (type) {
      'number' =>
        value is num
            ? value
            : value is bool
            ? (value ? 1 : 0)
            : double.tryParse('$value'.trim()),
      'boolean' =>
        value is bool
            ? value
            : value is num
            ? value != 0
            : switch ('$value'.trim().toLowerCase()) {
                'true' || 'yes' || 'on' || '1' => true,
                'false' || 'no' || 'off' || '0' => false,
                _ => null,
              },
      'string' => '$value',
      _ => null,
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...extras,
    'scope': scope,
    'type': type,
    if (hasDefault) 'default': huiDeepCopy(defaultValue),
  };
}

final class HuiActionSourceList {
  HuiActionSourceList._(this.source, this.actions);
  final List<Map<String, Object?>> source;
  final List<HuiAction> actions;

  static HuiActionSourceList? read(Object? raw) {
    if (raw != null && raw is! List) return null;
    final List<Map<String, Object?>> source = <Map<String, Object?>>[];
    final List<HuiAction> actions = <HuiAction>[];
    try {
      for (final Object? item in raw as List? ?? const <Object?>[]) {
        if (item is! Map<String, Object?>) return null;
        source.add(huiDeepCopyMap(item));
        actions.add(HuiAction.fromJson(item));
      }
    } on HuiFormatException {
      return null;
    }
    return HuiActionSourceList._(source, actions);
  }

  List<Map<String, Object?>> edit(void Function(List<HuiAction>) update) {
    final List<HuiAction> before = List<HuiAction>.of(actions);
    final List<Map<String, Object?>> normalized = <Map<String, Object?>>[
      for (final HuiAction action in before) huiDeepCopyMap(action.toJson()),
    ];
    update(actions);
    final Map<HuiAction, int> origins = <HuiAction, int>{for (final (int index, HuiAction action) in before.indexed) action: index};
    final Set<int> retained = <int>{for (final HuiAction action in actions) if (origins.containsKey(action)) origins[action]!};
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];
    for (final (int index, HuiAction action) in actions.indexed) {
      int origin = origins[action] ?? -1;
      if (origin < 0 && index < before.length && !retained.contains(index)) {
        origin = index;
      }
      final Map<String, Object?> next = action.toJson();
      if (origin < 0 || next['type'] != source[origin]['type']) {
        result.add(huiDeepCopyMap(next));
        continue;
      }
      final Map<String, Object?> patched = huiDeepCopyMap(source[origin]);
      final Map<String, Object?> baseline = normalized[origin];
      for (final String key in <String>{...baseline.keys, ...next.keys}) {
        if (baseline.containsKey(key) == next.containsKey(key) &&
            jsonEncode(baseline[key]) == jsonEncode(next[key])) {
          continue;
        }
        if (next.containsKey(key)) {
          patched[key] = huiDeepCopy(next[key]);
        } else {
          patched.remove(key);
        }
      }
      result.add(patched);
    }
    return result;
  }
}
