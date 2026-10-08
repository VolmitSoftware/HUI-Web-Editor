import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

bool looksLikeGlyphDoc(Object? raw) =>
    raw is Map &&
    raw['schemaVersion'] is num &&
    (raw.containsKey('glyphs') ||
        raw.containsKey('waypointStyles') ||
        (raw.containsKey('namespace') && raw.containsKey('font')));

GlossGlyphDoc decodeGlossGlyphDoc(String source) =>
    GlossGlyphDoc.fromJson(jsonDecode(source));
String encodeGlossGlyphDoc(GlossGlyphDoc doc) => huiWriteJson(doc.toJson());

final class GlossGlyphDoc extends GlossDoc {
  GlossGlyphDoc({
    super.schemaVersion = 1,
    super.revision = glossInitialRevision,
    this.namespace = 'gloss',
    this.font = 'glyphs',
    List<GlossGlyph>? glyphs,
    List<GlossGlyphOverlay>? overlays,
    GlossGlyphSpace? space,
    List<GlossWaypointStyleAsset>? waypointStyles,
    Map<String, Object?>? extras,
  }) : glyphs = glyphs ?? <GlossGlyph>[],
       overlays = overlays ?? <GlossGlyphOverlay>[],
       space = space ?? GlossGlyphSpace(),
       waypointStyles = waypointStyles ?? <GlossWaypointStyleAsset>[],
       extras = extras ?? <String, Object?>{};

  String namespace;
  String font;
  List<GlossGlyph> glyphs;
  List<GlossGlyphOverlay> overlays;
  GlossGlyphSpace space;
  List<GlossWaypointStyleAsset> waypointStyles;
  final Map<String, Object?> extras;

  static GlossGlyphDoc fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'glyphs');
    return GlossGlyphDoc(
      revision: glossReadRevision(map),
      namespace: huiReadString(map, 'namespace', fallback: 'gloss'),
      font: huiReadString(map, 'font', fallback: 'glyphs'),
      glyphs: <GlossGlyph>[
        for (final Object? item in huiReadList(map['glyphs']))
          GlossGlyph.fromJson(item),
      ],
      overlays: <GlossGlyphOverlay>[
        for (final Object? item in huiReadList(map['overlays']))
          GlossGlyphOverlay.fromJson(item),
      ],
      space: GlossGlyphSpace.fromJson(map['space']),
      waypointStyles: <GlossWaypointStyleAsset>[
        for (final Object? item in huiReadList(map['waypointStyles']))
          GlossWaypointStyleAsset.fromJson(item),
      ],
      extras: huiCollectExtras(map, const <String>{
        'schemaVersion',
        'revision',
        'namespace',
        'font',
        'glyphs',
        'overlays',
        'space',
        'waypointStyles',
      }),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'schemaVersion': schemaVersion,
    'revision': revision,
    'namespace': namespace,
    'font': font,
    'glyphs': <Object?>[for (final GlossGlyph glyph in glyphs) glyph.toJson()],
    'overlays': <Object?>[
      for (final GlossGlyphOverlay overlay in overlays) overlay.toJson(),
    ],
    'space': space.toJson(),
    'waypointStyles': <Object?>[
      for (final GlossWaypointStyleAsset style in waypointStyles)
        style.toJson(),
    ],
  };
}

final class GlossGlyph {
  GlossGlyph({
    this.id = 'glyph',
    this.image = '',
    this.height = 8,
    this.ascent = 7,
    this.emoji = '',
    this.fallback = '',
    this.width,
    this.frames = 1,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String id;
  String image;
  int height;
  int ascent;
  String emoji;
  String fallback;
  int? width;
  int frames;
  final Map<String, Object?> extras;

  static GlossGlyph fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.glyphs[]');
    final int height = huiReadInt(map, 'height', fallback: 8);
    return GlossGlyph(
      id: huiReadString(map, 'id'),
      image: huiReadString(map, 'image'),
      height: height,
      ascent: huiReadInt(map, 'ascent', fallback: height - 1),
      emoji: huiReadString(map, 'emoji'),
      fallback: huiReadString(map, 'fallback'),
      width: map['width'] == null ? null : huiReadInt(map, 'width'),
      frames: huiReadInt(map, 'frames', fallback: 1),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'image',
        'height',
        'ascent',
        'emoji',
        'fallback',
        'width',
        'frames',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'id': id,
    'image': image,
    'height': height,
    'ascent': ascent,
    if (emoji.isNotEmpty) 'emoji': emoji,
    'fallback': fallback,
    if (width != null) 'width': width,
    'frames': frames,
  };
}

final class GlossGlyphOverlay {
  GlossGlyphOverlay({
    this.id = 'overlay',
    this.image = '',
    this.height = 8,
    this.ascent = 7,
    this.anchor = 'center',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String id;
  String image;
  int height;
  int ascent;
  String anchor;
  final Map<String, Object?> extras;
  static GlossGlyphOverlay fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.overlays[]');
    final int height = huiReadInt(map, 'height', fallback: 8);
    return GlossGlyphOverlay(
      id: huiReadString(map, 'id'),
      image: huiReadString(map, 'image'),
      height: height,
      ascent: huiReadInt(map, 'ascent', fallback: height - 1),
      anchor: huiReadString(map, 'anchor', fallback: 'center'),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'image',
        'height',
        'ascent',
        'anchor',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'id': id,
    'image': image,
    'height': height,
    'ascent': ascent,
    'anchor': anchor,
  };
}

final class GlossGlyphSpace {
  GlossGlyphSpace({
    this.enabled = true,
    List<int>? range,
    Map<String, Object?>? extras,
  }) : range = range ?? <int>[-256, 256],
       extras = extras ?? <String, Object?>{};
  bool enabled;
  List<int> range;
  final Map<String, Object?> extras;
  static GlossGlyphSpace fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(
      raw ?? <String, Object?>{},
      r'$.space',
    );
    final List<Object?> values = huiReadList(map['range']);
    return GlossGlyphSpace(
      enabled: map['enabled'] == null || huiReadBool(map, 'enabled'),
      range: values.isEmpty
          ? null
          : <int>[
              for (final Object? value in values)
                value is num ? value.toInt() : 0,
            ],
      extras: huiCollectExtras(map, const <String>{'enabled', 'range'}),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'enabled': enabled,
    'range': List<int>.of(range),
  };
}

final class GlossWaypointStyleAsset {
  GlossWaypointStyleAsset({
    this.id = 'style',
    this.nearDistance = 128,
    this.farDistance = 332,
    List<GlossWaypointSprite>? sprites,
    Map<String, Object?>? extras,
  }) : sprites = sprites ?? <GlossWaypointSprite>[],
       extras = extras ?? <String, Object?>{};
  String id;
  double nearDistance;
  double farDistance;
  List<GlossWaypointSprite> sprites;
  final Map<String, Object?> extras;
  static GlossWaypointStyleAsset fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.waypointStyles[]');
    return GlossWaypointStyleAsset(
      id: huiReadString(map, 'id'),
      nearDistance: huiReadDouble(map, 'nearDistance', fallback: 128),
      farDistance: huiReadDouble(map, 'farDistance', fallback: 332),
      sprites: <GlossWaypointSprite>[
        for (final Object? item in huiReadList(map['sprites']))
          GlossWaypointSprite.fromJson(item),
      ],
      extras: huiCollectExtras(map, const <String>{
        'id',
        'nearDistance',
        'farDistance',
        'sprites',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'id': id,
    'nearDistance': nearDistance,
    'farDistance': farDistance,
    'sprites': <Object?>[
      for (final GlossWaypointSprite sprite in sprites) sprite.toJson(),
    ],
  };
}

final class GlossWaypointSprite {
  GlossWaypointSprite({
    this.id = 'sprite',
    this.image = '',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String id;
  String image;
  final Map<String, Object?> extras;
  static GlossWaypointSprite fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(
      raw,
      r'$.waypointStyles[].sprites[]',
    );
    return GlossWaypointSprite(
      id: huiReadString(map, 'id'),
      image: huiReadString(map, 'image'),
      extras: huiCollectExtras(map, const <String>{'id', 'image'}),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'id': id,
    'image': image,
  };
}
