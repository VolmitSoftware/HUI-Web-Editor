import 'gloss_scoreboard.dart';
import 'json_codec.dart';

final class GlossScoreboardLayout {
  GlossScoreboardLayout({
    Map<String, List<GlossScoreboardLine>>? sections,
    List<GlossScoreboardPage>? pages,
    this.overflow,
    GlossScoreboardRefresh? refresh,
    Map<String, Object?>? extras,
  }) : sections = sections ?? <String, List<GlossScoreboardLine>>{},
       pages = pages ?? <GlossScoreboardPage>[],
       refresh = refresh ?? GlossScoreboardRefresh(),
       extras = extras ?? <String, Object?>{};

  final Map<String, List<GlossScoreboardLine>> sections;
  final List<GlossScoreboardPage> pages;
  String? overflow;
  final GlossScoreboardRefresh refresh;
  final Map<String, Object?> extras;

  static GlossScoreboardLayout fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(
      raw ?? <String, Object?>{},
      r'$.layout',
    );
    final Map<String, Object?> sections = huiReadObject(
      map['sections'] ?? <String, Object?>{},
      r'$.layout.sections',
    );
    return GlossScoreboardLayout(
      sections: <String, List<GlossScoreboardLine>>{
        for (final MapEntry<String, Object?> section in sections.entries)
          section.key: _rows(
            section.value,
            r'$.layout.sections.' + section.key,
          ),
      },
      pages: <GlossScoreboardPage>[
        for (final Object? page in _list(map['pages'], r'$.layout.pages'))
          GlossScoreboardPage.fromJson(page),
      ],
      overflow: _optionalString(map, 'overflow'),
      refresh: GlossScoreboardRefresh.fromJson(map['refresh']),
      extras: huiCollectExtras(map, const <String>{
        'sections',
        'pages',
        'overflow',
        'refresh',
      }),
    );
  }

  bool renameSection(
    String from,
    String to,
    List<GlossScoreboardLine> presentationRows,
  ) {
    if (from == to || !sections.containsKey(from) || sections.containsKey(to)) {
      return false;
    }
    final Map<String, List<GlossScoreboardLine>> renamed =
        <String, List<GlossScoreboardLine>>{
          for (final MapEntry<String, List<GlossScoreboardLine>> entry
              in sections.entries)
            entry.key == from ? to : entry.key: entry.value,
        };
    sections
      ..clear()
      ..addAll(renamed);
    for (final List<GlossScoreboardLine> rows in <List<GlossScoreboardLine>>[
      presentationRows,
      ...sections.values,
      for (final GlossScoreboardPage page in pages) page.lines,
    ]) {
      for (final GlossScoreboardLine row in rows) {
        if (row.section == from) row.section = to;
      }
    }
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    if (sections.isNotEmpty)
      'sections': <String, Object?>{
        for (final MapEntry<String, List<GlossScoreboardLine>> section
            in sections.entries)
          section.key: <Object>[
            for (final GlossScoreboardLine row in section.value) row.toJson(),
          ],
      },
    if (pages.isNotEmpty)
      'pages': <Object>[
        for (final GlossScoreboardPage page in pages) page.toJson(),
      ],
    if (overflow != null) 'overflow': overflow,
    if (refresh.toJson().isNotEmpty) 'refresh': refresh.toJson(),
  };
}

final class GlossScoreboardPage {
  GlossScoreboardPage({
    this.id = '',
    this.title,
    List<GlossScoreboardLine>? lines,
    this.show,
    this.durationTicks,
    Map<String, Object?>? extras,
  }) : lines = lines ?? <GlossScoreboardLine>[],
       extras = extras ?? <String, Object?>{};
  String id;
  String? title;
  final List<GlossScoreboardLine> lines;
  Object? show;
  int? durationTicks;
  final Map<String, Object?> extras;

  static GlossScoreboardPage fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.layout.pages[]');
    return GlossScoreboardPage(
      id: huiReadString(map, 'id'),
      title: _optionalString(map, 'title'),
      lines: _rows(map['lines'], r'$.layout.pages[].lines'),
      show: map['show'],
      durationTicks: _optionalInt(map, 'durationTicks'),
      extras: huiCollectExtras(map, const <String>{
        'id',
        'title',
        'lines',
        'show',
        'durationTicks',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    'id': id,
    if (title != null) 'title': title,
    'lines': <Object>[
      for (final GlossScoreboardLine row in lines) row.toJson(),
    ],
    if (show != null) 'show': show,
    if (durationTicks != null) 'durationTicks': durationTicks,
  };
}

final class GlossScoreboardRefresh {
  GlossScoreboardRefresh({
    this.titleTicks,
    this.textTicks,
    this.valueTicks,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  int? titleTicks;
  int? textTicks;
  int? valueTicks;
  final Map<String, Object?> extras;

  static GlossScoreboardRefresh fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(
      raw ?? <String, Object?>{},
      r'$.layout.refresh',
    );
    return GlossScoreboardRefresh(
      titleTicks: _optionalInt(map, 'titleTicks'),
      textTicks: _optionalInt(map, 'textTicks'),
      valueTicks: _optionalInt(map, 'valueTicks'),
      extras: huiCollectExtras(map, const <String>{
        'titleTicks',
        'textTicks',
        'valueTicks',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    if (titleTicks != null) 'titleTicks': titleTicks,
    if (textTicks != null) 'textTicks': textTicks,
    if (valueTicks != null) 'valueTicks': valueTicks,
  };
}

final class GlossScoreboardObjectives {
  GlossScoreboardObjectives({
    this.playerList,
    this.belowName,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  GlossScoreboardObjective? playerList;
  GlossScoreboardObjective? belowName;
  final Map<String, Object?> extras;

  static GlossScoreboardObjectives fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(
      raw ?? <String, Object?>{},
      r'$.objectives',
    );
    return GlossScoreboardObjectives(
      playerList: map['playerList'] == null
          ? null
          : GlossScoreboardObjective.fromJson(map['playerList']),
      belowName: map['belowName'] == null
          ? null
          : GlossScoreboardObjective.fromJson(map['belowName']),
      extras: huiCollectExtras(map, const <String>{'playerList', 'belowName'}),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    if (playerList != null) 'playerList': playerList!.toJson(),
    if (belowName != null) 'belowName': belowName!.toJson(),
  };
}

final class GlossScoreboardObjective {
  GlossScoreboardObjective({
    this.title,
    this.value,
    this.renderType,
    this.format,
    this.valueText,
    this.show,
    this.subjects,
    this.refreshTicks,
    this.conflict,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};
  String? title;
  String? value;
  String? renderType;
  String? format;
  String? valueText;
  Object? show;
  Object? subjects;
  int? refreshTicks;
  String? conflict;
  final Map<String, Object?> extras;

  static GlossScoreboardObjective fromJson(Object? raw) {
    final Map<String, Object?> map = huiReadObject(raw, r'$.objectives.slot');
    return GlossScoreboardObjective(
      title: _optionalString(map, 'title'),
      value: _optionalString(map, 'value'),
      renderType: _optionalString(map, 'renderType'),
      format: _optionalString(map, 'format'),
      valueText: _optionalString(map, 'valueText'),
      show: map['show'],
      subjects: map['subjects'],
      refreshTicks: _optionalInt(map, 'refreshTicks'),
      conflict: _optionalString(map, 'conflict'),
      extras: huiCollectExtras(map, const <String>{
        'title',
        'value',
        'renderType',
        'format',
        'valueText',
        'show',
        'subjects',
        'refreshTicks',
        'conflict',
      }),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ...huiDeepCopyMap(extras),
    if (title != null) 'title': title,
    if (value != null) 'value': value,
    if (renderType != null) 'renderType': renderType,
    if (format != null) 'format': format,
    if (valueText != null) 'valueText': valueText,
    if (show != null) 'show': show,
    if (subjects != null) 'subjects': subjects,
    if (refreshTicks != null) 'refreshTicks': refreshTicks,
    if (conflict != null) 'conflict': conflict,
  };
}

String? _optionalString(Map<String, Object?> map, String key) {
  final Object? value = map[key];
  if (value == null || value is String) return value as String?;
  throw HuiFormatException('Expected a string', key);
}

int? _optionalInt(Map<String, Object?> map, String key) {
  final Object? value = map[key];
  if (value == null || value is int) return value as int?;
  throw HuiFormatException('Expected an integer', key);
}

List<Object?> _list(Object? raw, String path) {
  if (raw == null) return <Object?>[];
  if (raw is List) return List<Object?>.from(raw);
  throw HuiFormatException('Expected an array', path);
}

List<GlossScoreboardLine> _rows(Object? raw, String path) =>
    <GlossScoreboardLine>[
      for (final (int index, Object? row) in _list(raw, path).indexed)
        GlossScoreboardLine.fromJson(row, '$path[$index]'),
    ];
