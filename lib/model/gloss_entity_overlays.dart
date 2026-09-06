library;

import 'gloss_hologram_box.dart';
import 'dart:convert';

import 'gloss_doc.dart';
import 'hui_icons.dart';
import 'json_codec.dart';
import 'particle_layer.dart';

const int glossEntityOverlaysCurrentSchemaVersion = 2;
const String glossEntityOverlaysDefaultId = 'default';
const List<String> glossEntityOverlayLineTypes = <String>[
  'text',
  'insight',
  'spacer',
];

bool looksLikeEntityOverlaysDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    raw.containsKey('healthSegments');

GlossEntityOverlaysDoc decodeGlossEntityOverlaysDoc(String json) {
  try {
    return GlossEntityOverlaysDoc.fromJson(jsonDecode(json));
  } on FormatException catch (error) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': error.message,
    });
  }
}

String encodeGlossEntityOverlaysDoc(GlossEntityOverlaysDoc doc) =>
    huiWriteJson(doc.toJson());

HuiIconStyle defaultEntityOverlayStyle() =>
    HuiIconStyle(billboard: 'center', scaleX: 0.75, scaleY: 0.75, scaleZ: 0.75);

Object? _show(Object? value, String path) {
  if (value == null || value is bool || value is String) return value ?? true;
  throw HuiFormatException('Expected a boolean or expression string', path);
}

final class GlossEntityOverlayLine {
  GlossEntityOverlayLine({
    required this.id,
    this.type = 'text',
    this.text = '',
    this.show = true,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  String id;
  String type;
  String text;
  Object? show;
  Map<String, Object?> extras;

  static GlossEntityOverlayLine fromJson(Object? raw, String path) {
    final Map<String, Object?> map = huiReadObject(raw, path);
    final String type = huiReadString(map, 'type', fallback: 'text');
    return GlossEntityOverlayLine(
      id: huiReadString(map, 'id'),
      type: type,
      text: huiReadString(
        map,
        'text',
        fallback: type == 'insight' ? '{insight}' : '',
      ),
      show: _show(map['show'], '$path.show'),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'type',
        'text',
        'show',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'id': id,
    'type': type,
    'text': text,
    'show': show ?? true,
  }, extras);

  GlossEntityOverlayLine copy() =>
      GlossEntityOverlayLine.fromJson(toJson(), r'$.lines');
}

List<GlossEntityOverlayLine>
defaultEntityOverlayLines() => <GlossEntityOverlayLine>[
  GlossEntityOverlayLine(id: 'name', text: '&f{name}', show: 'entity.named'),
  GlossEntityOverlayLine(id: 'health', text: '{bar} &f{health}&7/{max_health}'),
  GlossEntityOverlayLine(
    id: 'stack',
    text: '&7x{count}',
    show: 'entity.stackCount > 1',
  ),
  GlossEntityOverlayLine(
    id: 'damage',
    text: '&c-{damage}',
    show: 'entity.damaged',
  ),
  GlossEntityOverlayLine(id: 'insight', type: 'insight', text: '{insight}'),
  GlossEntityOverlayLine(
    id: 'stats',
    text: '&7ATK &f{attack} &8| &7ARM &f{armor}',
  ),
];

final class GlossEntityOverlaysDoc extends GlossDoc {
  GlossEntityOverlaysDoc({
    super.schemaVersion = glossEntityOverlaysCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.enabled = true,
    this.range = 16,
    this.updateIntervalTicks = 5,
    this.maxEntitiesPerViewer = 64,
    this.includePlayers = true,
    this.verticalOffset = 0.35,
    this.healthSegments = 10,
    this.hitHighlightMs = 750,
    List<String>? blacklistWorlds,
    List<String>? excludedEntityTypes,
    this.show = true,
    List<GlossEntityOverlayLine>? lines,
    HuiIconStyle? style,
    GlossHologramBox? box,
    List<GlossParticleLayer>? particleLayers,
    Map<String, Object?>? extras,
  }) : blacklistWorlds = blacklistWorlds ?? <String>[],
       excludedEntityTypes = excludedEntityTypes ?? <String>['ARMOR_STAND'],
       lines = lines ?? defaultEntityOverlayLines(),
       style = style ?? defaultEntityOverlayStyle(),
       box = box ?? GlossHologramBox(),
       particleLayers = particleLayers ?? <GlossParticleLayer>[],
       extras = extras ?? <String, Object?>{};

  bool enabled;
  double range;
  int updateIntervalTicks;
  int maxEntitiesPerViewer;
  bool includePlayers;
  double verticalOffset;
  int healthSegments;
  int hitHighlightMs;
  List<String> blacklistWorlds;
  List<String> excludedEntityTypes;
  Object? show;
  List<GlossEntityOverlayLine> lines;
  HuiIconStyle style;
  GlossHologramBox box;
  List<GlossParticleLayer> particleLayers;
  Map<String, Object?> extras;

  static GlossEntityOverlaysDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(
      map,
      'entity-overlays',
      expected: glossEntityOverlaysCurrentSchemaVersion,
    );
    final Object? rawLines = map['lines'];
    if (rawLines != null && rawLines is! List) {
      throw const HuiFormatException('Expected a JSON array', r'$.lines');
    }
    return GlossEntityOverlaysDoc(
      revision: glossReadRevision(map),
      enabled: map['enabled'] == null || huiReadBool(map, 'enabled'),
      range: huiReadDouble(map, 'range', fallback: 16),
      updateIntervalTicks: huiReadInt(map, 'updateIntervalTicks', fallback: 5),
      maxEntitiesPerViewer: huiReadInt(
        map,
        'maxEntitiesPerViewer',
        fallback: 64,
      ),
      includePlayers:
          map['includePlayers'] == null || huiReadBool(map, 'includePlayers'),
      verticalOffset: huiReadDouble(map, 'verticalOffset', fallback: 0.35),
      healthSegments: huiReadInt(map, 'healthSegments', fallback: 10),
      hitHighlightMs: huiReadInt(map, 'hitHighlightMs', fallback: 750),
      blacklistWorlds: _strings(
        map['blacklistWorlds'],
        const <String>[],
        r'$.blacklistWorlds',
      ),
      excludedEntityTypes: _strings(map['excludedEntityTypes'], const <String>[
        'ARMOR_STAND',
      ], r'$.excludedEntityTypes'),
      show: _show(map['show'], r'$.show'),
      lines: rawLines is List
          ? <GlossEntityOverlayLine>[
              for (int index = 0; index < rawLines.length; index++)
                GlossEntityOverlayLine.fromJson(
                  rawLines[index],
                  '\$.lines[$index]',
                ),
            ]
          : null,
      style: map['style'] == null
          ? null
          : HuiIconStyle.fromJsonOrNull(map['style'], path: r'$.style'),
      box: GlossHologramBox.fromJson(map['box']),
      particleLayers: glossReadParticleLayers(map['particleLayers']),
      extras: huiCollectExtras(map, <String>{
        ...GlossEntityOverlaysDoc().toJson().keys,
      }),
    );
  }

  static List<String> _strings(
    Object? raw,
    List<String> fallback,
    String path,
  ) {
    if (raw == null) return List<String>.of(fallback);
    if (raw is! List || raw.any((Object? value) => value is! String)) {
      throw HuiFormatException('Expected a JSON array of strings', path);
    }
    return raw.cast<String>().toList();
  }

  @override
  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'enabled': enabled,
    'range': range,
    'updateIntervalTicks': updateIntervalTicks,
    'maxEntitiesPerViewer': maxEntitiesPerViewer,
    'includePlayers': includePlayers,
    'verticalOffset': verticalOffset,
    'healthSegments': healthSegments,
    'hitHighlightMs': hitHighlightMs,
    'blacklistWorlds': blacklistWorlds,
    'excludedEntityTypes': excludedEntityTypes,
    'show': show ?? true,
    'lines': <Map<String, Object?>>[
      for (final GlossEntityOverlayLine line in lines) line.toJson(),
    ],
    'style': style.toJson(),
    'box': box.toJson(),
    'particleLayers': glossWriteParticleLayers(particleLayers),
  }, extras);

  GlossEntityOverlaysDoc copy() => GlossEntityOverlaysDoc.fromJson(toJson());
}
