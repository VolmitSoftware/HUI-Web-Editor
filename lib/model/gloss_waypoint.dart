import 'dart:convert';

import 'gloss_doc.dart';
import 'gloss_marker.dart';
import 'json_codec.dart';

bool looksLikeWaypointDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    raw['anchor'] is Map &&
    (raw.containsKey('range') || raw['style'] is String) &&
    !raw.containsKey('label') &&
    !raw.containsKey('beam');

GlossWaypointDoc decodeGlossWaypointDoc(String source) =>
    GlossWaypointDoc.fromJson(jsonDecode(source));
String encodeGlossWaypointDoc(GlossWaypointDoc doc) =>
    huiWriteJson(doc.toJson());

final class GlossWaypointDoc extends GlossDoc {
  GlossWaypointDoc({
    super.schemaVersion = 1,
    super.revision = glossInitialRevision,
    GlossMarkerAnchor? anchor,
    this.color = '#ffffff',
    this.style = 'default',
    this.range = 0,
    this.show = true,
    this.audience = true,
    Map<String, Object?>? extras,
    Map<String, Object?>? audienceExtras,
  }) : anchor = anchor ?? GlossMarkerAnchor(world: 'world', x: 0, y: 64, z: 0),
       extras = extras ?? <String, Object?>{},
       audienceExtras = audienceExtras ?? <String, Object?>{};

  GlossMarkerAnchor anchor;
  String color;
  String style;
  double range;
  Object? show;
  Object? audience;
  final Map<String, Object?> extras;
  final Map<String, Object?> audienceExtras;

  static GlossWaypointDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'waypoints');
    final Map<String, Object?> audience = map['audience'] == null
        ? <String, Object?>{}
        : huiReadObject(map['audience'], r'$.audience');
    return GlossWaypointDoc(
      revision: glossReadRevision(map),
      anchor: GlossMarkerAnchor.fromJson(
        map['anchor'] ?? <String, Object?>{},
        r'$.anchor',
      ),
      color: huiReadString(map, 'color', fallback: '#ffffff'),
      style: huiReadString(map, 'style', fallback: 'default'),
      range: huiReadDouble(map, 'range'),
      show: map['show'] ?? true,
      audience: audience['when'] ?? true,
      audienceExtras: huiCollectExtras(audience, const <String>{'when'}),
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'anchor',
        'color',
        'style',
        'range',
        'show',
        'audience',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'schemaVersion': schemaVersion,
    'revision': revision,
    'anchor': anchor.toJson(),
    'color': color,
    'style': style,
    'range': range,
    'show': show,
    'audience': <String, Object?>{
      ...huiDeepCopyMap(audienceExtras),
      'when': audience,
    },
  };
}
