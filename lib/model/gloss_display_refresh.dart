import 'json_codec.dart';

final class GlossDisplayRefresh {
  GlossDisplayRefresh({this.contentTicks, this.visibilityTicks, this.motionTicks, Map<String, Object?>? extras})
      : extras = extras ?? <String, Object?>{};
  int? contentTicks;
  int? visibilityTicks;
  int? motionTicks;
  final Map<String, Object?> extras;

  static GlossDisplayRefresh fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw ?? <String, Object?>{}, r'$.refresh');
    return GlossDisplayRefresh(
      contentTicks: map['contentTicks'] == null ? null : huiReadInt(map, 'contentTicks'),
      visibilityTicks: map['visibilityTicks'] == null ? null : huiReadInt(map, 'visibilityTicks'),
      motionTicks: map['motionTicks'] == null ? null : huiReadInt(map, 'motionTicks'),
      extras: huiCollectExtras(map, const <String>{'contentTicks', 'visibilityTicks', 'motionTicks'}));
  }

  bool get isEmpty => contentTicks == null && visibilityTicks == null && motionTicks == null && extras.isEmpty;
  Map<String, Object?> toJson() => <String, Object?>{...huiDeepCopyMap(extras),
    if (contentTicks != null) 'contentTicks': contentTicks,
    if (visibilityTicks != null) 'visibilityTicks': visibilityTicks,
    if (motionTicks != null) 'motionTicks': motionTicks};
  GlossDisplayRefresh copy() => GlossDisplayRefresh.fromJson(toJson());
}
