import 'json_codec.dart';

const List<String> glossSurfaceSubscriptionTriggers = <String>[
  'join',
  'world_change',
  'server_change',
  'interval',
];

final class GlossSurfaceSubscription {
  GlossSurfaceSubscription({
    this.trigger,
    this.everyTicks,
    this.delayTicks,
    this.when,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  String? trigger;
  int? everyTicks;
  int? delayTicks;
  String? when;
  final Map<String, Object?> extras;

  static List<GlossSurfaceSubscription>? readList(Object? source) {
    if (source is! List) return null;
    final List<GlossSurfaceSubscription> entries = <GlossSurfaceSubscription>[];
    for (final Object? value in source) {
      if (value is! Map) return null;
      for (final String key in <String>['trigger', 'when']) {
        if (value[key] != null && value[key] is! String) return null;
      }
      for (final String key in <String>['everyTicks', 'delayTicks']) {
        if (value[key] != null && value[key] is! int) return null;
      }
      entries.add(
        GlossSurfaceSubscription(
          trigger: value['trigger'] as String?,
          everyTicks: value['everyTicks'] as int?,
          delayTicks: value['delayTicks'] as int?,
          when: value['when'] as String?,
          extras: <String, Object?>{
            for (final MapEntry<Object?, Object?> field in value.entries)
              if (field.key is String &&
                  !const <String>{
                    'trigger',
                    'everyTicks',
                    'delayTicks',
                    'when',
                  }.contains(field.key))
                field.key! as String: huiDeepCopy(field.value),
            for (final String key in <String>[
              'trigger',
              'everyTicks',
              'delayTicks',
              'when',
            ])
              if (value.containsKey(key) && value[key] == null) key: null,
          },
        ),
      );
    }
    return entries;
  }

  void setTrigger(String value) {
    trigger = value;
    extras.remove('trigger');
    if (value == 'interval') {
      everyTicks ??= 20;
    } else {
      everyTicks = null;
      extras.remove('everyTicks');
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...extras,
    if (trigger != null) 'trigger': trigger,
    if (everyTicks != null) 'everyTicks': everyTicks,
    if (delayTicks != null) 'delayTicks': delayTicks,
    if (when != null) 'when': when,
  };

  GlossSurfaceSubscription copy() => GlossSurfaceSubscription(
    trigger: trigger,
    everyTicks: everyTicks,
    delayTicks: delayTicks,
    when: when,
    extras: <String, Object?>{
      for (final MapEntry<String, Object?> entry in extras.entries)
        entry.key: huiDeepCopy(entry.value),
    },
  );
}
