import 'json_codec.dart';

final class GlossPresentationVariant {
  GlossPresentationVariant({
    this.id = '',
    this.priority = 0,
    this.when = true,
    Map<String, Object?>? presentation,
    Map<String, Object?>? extras,
  }) : presentation = presentation ?? <String, Object?>{},
       extras = extras ?? <String, Object?>{};

  String id;
  int priority;
  Object? when;
  Map<String, Object?> presentation;
  Map<String, Object?> extras;

  static GlossPresentationVariant fromJson(Object? raw, String path) {
    final Map<String, Object?> map = huiReadObject(raw, path);
    return GlossPresentationVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiDeepCopy(map['when'] ?? true),
      presentation: huiDeepCopyMap(
        huiReadObject(
          map['presentation'] ?? <String, Object?>{},
          '$path.presentation',
        ),
      ),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'priority',
        'when',
        'presentation',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'id': id,
    'priority': priority,
    'when': huiDeepCopy(when),
    'presentation': huiDeepCopyMap(presentation),
  }, extras);

  GlossPresentationVariant copy() =>
      GlossPresentationVariant.fromJson(toJson(), 'variant');
}
