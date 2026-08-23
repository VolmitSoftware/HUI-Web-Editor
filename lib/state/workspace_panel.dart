library;

import 'dart:convert';

import '../l10n/hui_localizations.dart';
import 'workspace.dart';

enum WorkspacePanelView { canvas, list }

class WorkspacePanelPoint {
  const WorkspacePanelPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};

  static WorkspacePanelPoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? x = raw['x'];
    final Object? y = raw['y'];
    if (x is! num || y is! num) return null;
    final double dx = x.toDouble();
    final double dy = y.toDouble();
    if (!dx.isFinite || !dy.isFinite) return null;
    return WorkspacePanelPoint(dx, dy);
  }
}

class WorkspacePanelData {
  const WorkspacePanelData({
    this.view = WorkspacePanelView.canvas,
    this.scopeFolderId,
    this.positions = const <String, WorkspacePanelPoint>{},
    this.runtimeBoardId,
    this.runtimeBoard,
    this.syncMenuIds = const <String>[],
    this.syncImagePaths = const <String>[],
  });

  static const int schemaVersion = 2;

  final WorkspacePanelView view;
  final String? scopeFolderId;
  final Map<String, WorkspacePanelPoint> positions;
  final String? runtimeBoardId;

  /// The strict server panel definition, stored without editor-only metadata.
  final Map<String, dynamic>? runtimeBoard;
  final List<String> syncMenuIds;
  final List<String> syncImagePaths;

  WorkspacePanelData copyWith({
    WorkspacePanelView? view,
    String? scopeFolderId,
    bool clearScope = false,
    Map<String, WorkspacePanelPoint>? positions,
    String? runtimeBoardId,
    bool clearRuntimeBoard = false,
    Map<String, dynamic>? runtimeBoard,
    List<String>? syncMenuIds,
    List<String>? syncImagePaths,
  }) => WorkspacePanelData(
    view: view ?? this.view,
    scopeFolderId: clearScope ? null : scopeFolderId ?? this.scopeFolderId,
    positions: positions ?? this.positions,
    runtimeBoardId: clearRuntimeBoard
        ? null
        : runtimeBoardId ?? this.runtimeBoardId,
    runtimeBoard: clearRuntimeBoard ? null : runtimeBoard ?? this.runtimeBoard,
    syncMenuIds: syncMenuIds ?? this.syncMenuIds,
    syncImagePaths: syncImagePaths ?? this.syncImagePaths,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'view': view.name,
    'scopeFolderId': scopeFolderId,
    'positions': <String, dynamic>{
      for (final MapEntry<String, WorkspacePanelPoint> entry
          in positions.entries)
        entry.key: entry.value.toJson(),
    },
    'runtimeBoardId': runtimeBoardId,
    'runtimeBoard': runtimeBoard,
    'syncMenuIds': syncMenuIds,
    'syncImagePaths': syncImagePaths,
  };
}

class WorkspacePanelDecodeResult {
  const WorkspacePanelDecodeResult(this.data, this._warning);

  final WorkspacePanelData data;
  final String? _warning;

  String? get warning => _warning == null ? null : huiText(_warning);
}

WorkspacePanelDecodeResult decodeWorkspacePanel(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return const WorkspacePanelDecodeResult(
      WorkspacePanelData(),
      'Panel metadata was unreadable and defaults are being shown.',
    );
  }
  if (decoded is! Map) {
    return const WorkspacePanelDecodeResult(
      WorkspacePanelData(),
      'Panel metadata was not an object and defaults are being shown.',
    );
  }
  final Object? rawVersion = decoded['schemaVersion'];
  if (rawVersion is! num ||
      (rawVersion.toInt() != 1 &&
          rawVersion.toInt() != WorkspacePanelData.schemaVersion)) {
    return const WorkspacePanelDecodeResult(
      WorkspacePanelData(),
      'Panel metadata uses an unsupported version and was left unchanged.',
    );
  }

  String? warning;
  WorkspacePanelView view = WorkspacePanelView.canvas;
  final Object? rawView = decoded['view'];
  for (final WorkspacePanelView candidate in WorkspacePanelView.values) {
    if (candidate.name == rawView) view = candidate;
  }
  if (rawView != null && rawView != view.name) {
    warning = 'The unknown flow-map view was replaced with Canvas.';
  }

  String? scopeFolderId;
  final Object? rawScope = decoded['scopeFolderId'];
  if (rawScope is String && isWorkspaceUuid(rawScope)) {
    scopeFolderId = rawScope;
  } else if (rawScope != null) {
    warning = 'The panel folder scope was invalid and all menus are shown.';
  }

  final Map<String, WorkspacePanelPoint> positions =
      <String, WorkspacePanelPoint>{};
  final Object? rawPositions = decoded['positions'];
  if (rawPositions is Map) {
    rawPositions.forEach((Object? key, Object? value) {
      if (key is! String || !isWorkspaceUuid(key)) return;
      final WorkspacePanelPoint? point = WorkspacePanelPoint.fromJson(value);
      if (point != null) positions[key] = point;
    });
  }

  String? runtimeBoardId;
  Map<String, dynamic>? runtimeBoard;
  final Object? rawRuntimeBoardId = decoded['runtimeBoardId'];
  final Object? rawRuntimeBoard = decoded['runtimeBoard'];
  if (rawRuntimeBoardId is String && rawRuntimeBoardId.trim().isNotEmpty) {
    runtimeBoardId = rawRuntimeBoardId;
  } else if (rawRuntimeBoardId != null) {
    warning = 'The linked runtime panel id was invalid and was ignored.';
  }
  if (rawRuntimeBoard is Map) {
    runtimeBoard = <String, dynamic>{
      for (final MapEntry<Object?, Object?> entry in rawRuntimeBoard.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
  } else if (rawRuntimeBoard != null) {
    warning =
        'The linked runtime panel definition was invalid and was ignored.';
  }
  final List<String> syncMenuIds = _stringList(decoded['syncMenuIds']);
  final List<String> syncImagePaths = _stringList(decoded['syncImagePaths']);
  return WorkspacePanelDecodeResult(
    WorkspacePanelData(
      view: view,
      scopeFolderId: scopeFolderId,
      positions: Map<String, WorkspacePanelPoint>.unmodifiable(positions),
      runtimeBoardId: runtimeBoardId,
      runtimeBoard: runtimeBoard == null
          ? null
          : Map<String, dynamic>.unmodifiable(runtimeBoard),
      syncMenuIds: List<String>.unmodifiable(syncMenuIds),
      syncImagePaths: List<String>.unmodifiable(syncImagePaths),
    ),
    warning,
  );
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  final List<String> values = <String>[];
  final Set<String> seen = <String>{};
  for (final Object? value in raw) {
    if (value is String && value.isNotEmpty && seen.add(value)) {
      values.add(value);
    }
  }
  return values;
}

String encodeWorkspacePanel(WorkspacePanelData panel) =>
    const JsonEncoder.withIndent('  ').convert(panel.toJson());
