import 'json_codec.dart';

final class GlossTabPlayers {
  GlossTabPlayers({
    this.column = 0,
    this.columns = 1,
    this.rows = 20,
    this.filter = 'true',
    this.overflow = 'hide',
    this.overflowFormat = '+{count}',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  int column;
  int columns;
  int rows;
  String filter;
  String overflow;
  String overflowFormat;
  Map<String, Object?> extras;
  int get capacity => columns * rows;
  static GlossTabPlayers fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.layout.players');
    return GlossTabPlayers(
      column: huiReadInt(map, 'column'),
      columns: huiReadInt(map, 'columns', fallback: 1),
      rows: huiReadInt(map, 'rows', fallback: 1),
      filter: huiReadString(map, 'filter', fallback: 'true'),
      overflow: huiReadString(map, 'overflow', fallback: 'hide'),
      overflowFormat: huiReadString(
        map,
        'overflowFormat',
        fallback: '+{count}',
      ),
      extras: huiCollectExtras(map, <String>{
        'column',
        'columns',
        'rows',
        'filter',
        'overflow',
        'overflowFormat',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'column': column,
    'columns': columns,
    'rows': rows,
    'filter': filter,
    'overflow': overflow,
    'overflowFormat': overflowFormat,
  }, extras);
}

final class GlossTabLayout {
  GlossTabLayout({
    this.enabled = false,
    this.columns = 1,
    this.rows = 20,
    this.show = '!viewer.bedrock',
    this.players,
    List<Map<String, Object?>>? slots,
    Map<String, Object?>? extras,
  }) : slots = slots ?? <Map<String, Object?>>[],
       extras = extras ?? <String, Object?>{};
  bool enabled;
  int columns;
  int rows;
  Object? show;
  GlossTabPlayers? players;
  List<Map<String, Object?>> slots;
  Map<String, Object?> extras;
  static GlossTabLayout fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.layout');
    return GlossTabLayout(
      enabled: huiReadBool(map, 'enabled'),
      columns: huiReadInt(map, 'columns', fallback: 1),
      rows: huiReadInt(map, 'rows', fallback: 20),
      show: map['show'] ?? '!viewer.bedrock',
      players: map['players'] == null
          ? null
          : GlossTabPlayers.fromJson(map['players']),
      slots: <Map<String, Object?>>[
        for (final Object? slot in huiReadList(map['slots']))
          huiReadObject(slot, r'$.layout.slots'),
      ],
      extras: huiCollectExtras(map, <String>{
        'enabled',
        'columns',
        'rows',
        'show',
        'players',
        'slots',
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'enabled': enabled,
    'columns': columns,
    'rows': rows,
    'show': show,
    'slots': slots,
    if (players != null) 'players': players!.toJson(),
  }, extras);
  GlossTabLayout copy() => GlossTabLayout.fromJson(huiDeepCopy(toJson()));
}
