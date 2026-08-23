library;

import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Listenable, ListenableBuilder;

import '../../logic/workspace_flow_graph.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../../state/workspace_panel.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class PanelView extends StatefulWidget {
  const PanelView({required this.store, super.key});

  final EditorStore store;

  @override
  State<PanelView> createState() => _PanelViewState();
}

class _PanelViewState extends State<PanelView> {
  Listenable? _sources;

  Listenable get _listenable => _sources ??= Listenable.merge(<Listenable?>[
    component.store,
    component.store.workspace,
  ]);

  @override
  void didUpdateComponent(PanelView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) _sources = null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _listenable,
    builder: (BuildContext context) => _body(),
  );

  Widget _body() {
    final WorkspacePanelDecodeResult? decoded = component.store.activePanel;
    if (decoded == null) {
      return dom.div(classes: 'hui-board-empty', <Widget>[
        Text(huiText('Open a menu flow map to inspect menu navigation.')),
      ]);
    }
    final WorkspacePanelData panel = decoded.data;
    final WorkspaceFlowGraph graph = buildWorkspaceFlowGraph(
      component.store.workspace,
      panel,
    );
    return dom.div(classes: 'hui-board', <Widget>[
      _toolbar(panel, graph),
      if (decoded.warning != null)
        _notice(decoded.warning!, 'is-warning')
      else if (graph.scopeMissing)
        _notice(
          huiText(
            'This panel\'s saved folder no longer exists. All menus are shown.',
          ),
          'is-warning',
        ),
      _summary(graph),
      dom.div(classes: 'hui-board-body', <Widget>[
        if (panel.view == WorkspacePanelView.canvas)
          _canvas(panel, graph)
        else
          _list(graph),
      ]),
    ]);
  }

  Widget _toolbar(WorkspacePanelData panel, WorkspaceFlowGraph graph) =>
      dom.div(classes: 'hui-board-toolbar', <Widget>[
        dom.div(classes: 'hui-board-heading', <Widget>[
          ArcaneIcon.workflow(size: IconSize.md),
          dom.div(<Widget>[
            dom.h1(<Widget>[
              Text(
                component.store.workspace.active?.title ??
                    huiText('Menu flow map'),
              ),
            ]),
            dom.p(<Widget>[
              Text(
                huiPlural(
                  'panel.flow.menu_count',
                  graph.documents.length,
                  oneEnglish: '{count} menu in flow',
                  otherEnglish: '{count} menus in flow',
                ),
              ),
            ]),
          ]),
        ]),
        dom.div(classes: 'hui-board-controls', <Widget>[
          dom.div(classes: 'hui-board-scope', <Widget>[
            dom.span(<Widget>[Text(huiText('Scope'))]),
            ArcaneSelect(
              value: panel.scopeFolderId ?? _allFoldersValue,
              size: ComponentSize.sm,
              onChange: (String value) => _setScope(panel, value),
              options: <ArcaneSelectOption>[
                ArcaneSelectOption(
                  label: huiText('All workspace folders'),
                  value: _allFoldersValue,
                ),
                for (final WorkspaceFolder folder in _sortedFolders(
                  component.store.workspace,
                ))
                  ArcaneSelectOption(
                    label: _folderPath(component.store.workspace, folder),
                    value: folder.id,
                  ),
              ],
            ),
          ]),
          Button.outline(
            size: ButtonSize.sm,
            icon: ArcaneIcon.wandSparkles(size: IconSize.sm),
            label: huiText('Arrange'),
            onPressed: () => _arrange(panel, graph),
          ),
          ArcaneToggleGroup(
            value: panel.view.name,
            variant: ToggleGroupVariant.outline,
            size: ToggleGroupSize.sm,
            onChanged: (String? value) => _setView(panel, value),
            items: <ToggleGroupItem>[
              ToggleGroupItem(
                value: WorkspacePanelView.canvas.name,
                child: ArcaneIcon.share2(size: IconSize.sm),
              ),
              ToggleGroupItem(
                value: WorkspacePanelView.list.name,
                child: ArcaneIcon.listTree(size: IconSize.sm),
              ),
            ],
          ),
        ]),
      ]);

  Widget _summary(WorkspaceFlowGraph graph) {
    final int dangling = graph.edges
        .where(
          (WorkspaceFlowEdge edge) =>
              edge.targetKind == WorkspaceFlowTargetKind.dangling ||
              edge.targetKind == WorkspaceFlowTargetKind.ambiguous ||
              edge.targetKind == WorkspaceFlowTargetKind.invalid,
        )
        .length;
    final int external = graph.edges
        .where(
          (WorkspaceFlowEdge edge) =>
              edge.targetKind == WorkspaceFlowTargetKind.external,
        )
        .length;
    final int sinks = graph.edges
        .where((WorkspaceFlowEdge edge) => _isSink(edge.targetKind))
        .length;
    return dom.div(classes: 'hui-board-summary', <Widget>[
      _metric('${graph.documents.length}', huiText('Menus')),
      _metric('${graph.edges.length}', huiText('Routes')),
      _metric('$sinks', huiText('Back / Home / Close')),
      _metric('$external', huiText('External')),
      _metric('$dangling', huiText('Needs attention'), danger: dangling > 0),
      _metric('${graph.cycleDocumentIds.length}', huiText('In cycles')),
      _metric('${graph.orphanDocumentIds.length}', huiText('No inbound links')),
    ]);
  }

  Widget _metric(String value, String label, {bool danger = false}) => dom.div(
    classes: 'hui-board-metric${danger ? ' is-danger' : ''}',
    <Widget>[
      dom.strong(<Widget>[Text(value)]),
      dom.span(<Widget>[Text(label)]),
    ],
  );

  Widget _canvas(WorkspacePanelData panel, WorkspaceFlowGraph graph) {
    if (graph.documents.isEmpty) return _emptyGraph();
    final Map<String, WorkspacePanelPoint> automatic =
        arrangeWorkspaceFlowGraph(graph);
    final Map<String, WorkspacePanelPoint> positions =
        <String, WorkspacePanelPoint>{
          for (final WorkspaceDoc doc in graph.documents)
            doc.id: panel.positions[doc.id] ?? automatic[doc.id]!,
        };
    double maxX = 0;
    double maxY = 0;
    for (final WorkspacePanelPoint point in positions.values) {
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }
    final Map<WorkspaceFlowTargetKind, WorkspacePanelPoint> sinks =
        _sinkPositions(graph, maxX + 340);
    for (final WorkspacePanelPoint point in sinks.values) {
      maxY = math.max(maxY, point.y);
    }
    final double width = math.max(760, maxX + 620);
    final double height = math.max(480, maxY + 220);
    return dom.div(classes: 'hui-board-scroll', <Widget>[
      dom.div(
        classes: 'hui-board-stage',
        styles: dom.Styles(
          raw: <String, String>{
            'width': '${width.round()}px',
            'height': '${height.round()}px',
          },
        ),
        <Widget>[
          for (final WorkspaceFlowEdge edge in graph.edges)
            if (edge.targetKind == WorkspaceFlowTargetKind.menu ||
                _isSink(edge.targetKind))
              _edge(
                edge,
                positions[edge.sourceDocumentId]!,
                edge.targetKind == WorkspaceFlowTargetKind.menu
                    ? positions[edge.targetDocumentId]!
                    : sinks[edge.targetKind]!,
              ),
          for (final MapEntry<WorkspaceFlowTargetKind, WorkspacePanelPoint> sink
              in sinks.entries)
            _sink(sink.key, sink.value),
          for (final WorkspaceDoc doc in graph.documents)
            _node(doc, graph, positions[doc.id]!),
        ],
      ),
    ]);
  }

  Widget _list(WorkspaceFlowGraph graph) {
    if (graph.documents.isEmpty) return _emptyGraph();
    return dom.div(classes: 'hui-board-list', <Widget>[
      for (final WorkspaceDoc doc in graph.documents)
        dom.article(classes: 'hui-board-list-card', <Widget>[
          _nodeHeader(doc, graph),
          _routeList(graph.outgoing(doc.id)),
          Button.outline(
            size: ButtonSize.sm,
            icon: ArcaneIcon.pencil(size: IconSize.sm),
            label: huiText('Edit menu'),
            onPressed: () => component.store.openDocument(doc.id),
          ),
        ]),
    ]);
  }

  Widget _node(
    WorkspaceDoc doc,
    WorkspaceFlowGraph graph,
    WorkspacePanelPoint point,
  ) => dom.article(
    classes: _nodeClasses(doc, graph),
    styles: dom.Styles(
      raw: <String, String>{
        'left': '${point.x.round()}px',
        'top': '${point.y.round()}px',
      },
    ),
    <Widget>[
      _nodeHeader(doc, graph),
      _routeList(graph.outgoing(doc.id), compact: true),
      Button.ghost(
        size: ButtonSize.sm,
        icon: ArcaneIcon.pencil(size: IconSize.sm),
        label: huiText('Edit menu'),
        onPressed: () => component.store.openDocument(doc.id),
      ),
    ],
  );

  Widget _nodeHeader(WorkspaceDoc doc, WorkspaceFlowGraph graph) =>
      dom.div(classes: 'hui-board-node-header', <Widget>[
        dom.div(<Widget>[
          dom.strong(<Widget>[Text(doc.title)]),
          dom.code(<Widget>[Text(doc.runtimeId!)]),
        ]),
        dom.div(classes: 'hui-board-badges', <Widget>[
          if (graph.cycleDocumentIds.contains(doc.id))
            _badge(huiText('Cycle'), 'is-cycle'),
          if (graph.orphanDocumentIds.contains(doc.id))
            _badge(huiText('Orphan'), 'is-orphan'),
          if (graph.invalidDocumentIds.contains(doc.id))
            _badge(huiText('Invalid JSON'), 'is-danger'),
          if (graph.duplicateRuntimeIds.contains(doc.runtimeId))
            _badge(huiText('Duplicate id'), 'is-danger'),
        ]),
      ]);

  Widget _routeList(List<WorkspaceFlowEdge> edges, {bool compact = false}) {
    if (edges.isEmpty) {
      return dom.p(classes: 'hui-board-no-routes', <Widget>[
        Text(huiText('No navigation actions')),
      ]);
    }
    final List<WorkspaceFlowEdge> shown = compact && edges.length > 3
        ? edges.take(3).toList(growable: false)
        : edges;
    return dom.div(classes: 'hui-board-routes', <Widget>[
      for (final WorkspaceFlowEdge edge in shown)
        dom.div(classes: 'hui-board-route is-${edge.targetKind.name}', <Widget>[
          dom.code(<Widget>[Text(edge.componentId)]),
          dom.span(<Widget>[Text(_edgeLabel(edge))]),
        ]),
      if (shown.length < edges.length)
        dom.span(classes: 'hui-board-more-routes', <Widget>[
          Text(
            huiText("+{value} more", <String, Object?>{
              'value': edges.length - shown.length,
            }),
          ),
        ]),
    ]);
  }

  Widget _edge(
    WorkspaceFlowEdge edge,
    WorkspacePanelPoint source,
    WorkspacePanelPoint target,
  ) {
    final double x1 = source.x + _nodeWidth;
    final double y1 = source.y + 48;
    final double x2 = target.x;
    final double y2 = target.y + 32;
    final double dx = x2 - x1;
    final double dy = y2 - y1;
    final double length = math.sqrt(dx * dx + dy * dy);
    final double degrees = math.atan2(dy, dx) * 180 / math.pi;
    return dom.div(
      classes: 'hui-board-edge is-${edge.targetKind.name}',
      styles: dom.Styles(
        raw: <String, String>{
          'left': '${x1.round()}px',
          'top': '${y1.round()}px',
          'width': '${length.round()}px',
          'transform': 'rotate(${degrees.toStringAsFixed(3)}deg)',
        },
      ),
      const <Widget>[],
    );
  }

  Widget _sink(WorkspaceFlowTargetKind kind, WorkspacePanelPoint point) =>
      dom.div(
        classes: 'hui-board-sink is-${kind.name}',
        styles: dom.Styles(
          raw: <String, String>{
            'left': '${point.x.round()}px',
            'top': '${point.y.round()}px',
          },
        ),
        <Widget>[_sinkIcon(kind), Text(_targetLabel(kind))],
      );

  Map<WorkspaceFlowTargetKind, WorkspacePanelPoint> _sinkPositions(
    WorkspaceFlowGraph graph,
    double x,
  ) {
    final Map<WorkspaceFlowTargetKind, WorkspacePanelPoint> out =
        <WorkspaceFlowTargetKind, WorkspacePanelPoint>{};
    int row = 0;
    for (final WorkspaceFlowTargetKind kind in const <WorkspaceFlowTargetKind>[
      WorkspaceFlowTargetKind.back,
      WorkspaceFlowTargetKind.home,
      WorkspaceFlowTargetKind.close,
    ]) {
      if (!graph.edges.any(
        (WorkspaceFlowEdge edge) => edge.targetKind == kind,
      )) {
        continue;
      }
      out[kind] = WorkspacePanelPoint(x, 72 + row * 94);
      row++;
    }
    return out;
  }

  Widget _emptyGraph() => dom.div(classes: 'hui-board-empty', <Widget>[
    Text(huiText('No menu documents are inside this panel scope.')),
  ]);

  Widget _notice(String message, String tone) => dom.div(
    classes: 'hui-board-notice $tone',
    attributes: const <String, String>{'role': 'status'},
    <Widget>[Text(message)],
  );

  Widget _badge(String label, String tone) =>
      dom.span(classes: 'hui-board-badge $tone', <Widget>[Text(label)]);

  String _nodeClasses(WorkspaceDoc doc, WorkspaceFlowGraph graph) {
    final List<String> classes = <String>['hui-board-node'];
    if (graph.cycleDocumentIds.contains(doc.id)) classes.add('has-cycle');
    if (graph.orphanDocumentIds.contains(doc.id)) classes.add('is-orphan');
    if (graph.invalidDocumentIds.contains(doc.id) ||
        graph.duplicateRuntimeIds.contains(doc.runtimeId)) {
      classes.add('has-danger');
    }
    return classes.join(' ');
  }

  String _edgeLabel(WorkspaceFlowEdge edge) {
    final String branch = edge.branch == 'click' ? '' : '${edge.branch}: ';
    final String trigger = edge.triggers.length == 4
        ? ''
        : '${edge.triggers.join(' / ')}: ';
    final String prefix = '$branch$trigger';
    return switch (edge.targetKind) {
      WorkspaceFlowTargetKind.menu => '$prefix${edge.mode} → ${edge.target}',
      WorkspaceFlowTargetKind.back => '$prefix${huiText('Back sink')}',
      WorkspaceFlowTargetKind.home => '$prefix${huiText('Home sink')}',
      WorkspaceFlowTargetKind.close => '$prefix${huiText('Close sink')}',
      WorkspaceFlowTargetKind.external => huiText(
        '{route} · outside scope',
        <String, Object?>{'route': '$prefix${edge.target}'},
      ),
      WorkspaceFlowTargetKind.dangling => huiText('{route} · dangling', <
        String,
        Object?
      >{
        'route':
            '$prefix${edge.target.isEmpty ? huiText('(missing target)') : edge.target}',
      }),
      WorkspaceFlowTargetKind.ambiguous => huiText(
        '{route} · duplicate runtime id',
        <String, Object?>{'route': '$prefix${edge.target}'},
      ),
      WorkspaceFlowTargetKind.invalid => huiText(
        '{route} · unknown mode',
        <String, Object?>{'route': '$prefix${edge.mode}'},
      ),
    };
  }

  String _targetLabel(WorkspaceFlowTargetKind kind) => switch (kind) {
    WorkspaceFlowTargetKind.back => huiText('Back'),
    WorkspaceFlowTargetKind.home => huiText('Home'),
    WorkspaceFlowTargetKind.close => huiText('Close'),
    _ => kind.name,
  };

  Widget _sinkIcon(WorkspaceFlowTargetKind kind) => switch (kind) {
    WorkspaceFlowTargetKind.back => ArcaneIcon.undo(size: IconSize.sm),
    WorkspaceFlowTargetKind.home => ArcaneIcon.house(size: IconSize.sm),
    WorkspaceFlowTargetKind.close => ArcaneIcon.x(size: IconSize.sm),
    _ => ArcaneIcon.circle(size: IconSize.sm),
  };

  void _setView(WorkspacePanelData panel, String? raw) {
    for (final WorkspacePanelView view in WorkspacePanelView.values) {
      if (view.name == raw) {
        component.store.updatePanel(panel.copyWith(view: view));
        return;
      }
    }
  }

  void _setScope(WorkspacePanelData panel, String raw) {
    component.store.updatePanel(
      panel.copyWith(
        scopeFolderId: raw == _allFoldersValue ? null : raw,
        clearScope: raw == _allFoldersValue,
        positions: const <String, WorkspacePanelPoint>{},
      ),
    );
  }

  void _arrange(WorkspacePanelData panel, WorkspaceFlowGraph graph) {
    component.store.updatePanel(
      panel.copyWith(positions: arrangeWorkspaceFlowGraph(graph)),
    );
  }
}

const String _allFoldersValue = '__all__';
const double _nodeWidth = 228;

bool _isSink(WorkspaceFlowTargetKind kind) =>
    kind == WorkspaceFlowTargetKind.back ||
    kind == WorkspaceFlowTargetKind.home ||
    kind == WorkspaceFlowTargetKind.close;

List<WorkspaceFolder> _sortedFolders(Workspace workspace) {
  final List<WorkspaceFolder> folders = List<WorkspaceFolder>.of(
    workspace.folders,
  );
  folders.sort(
    (WorkspaceFolder a, WorkspaceFolder b) =>
        _folderPath(workspace, a).compareTo(_folderPath(workspace, b)),
  );
  return folders;
}

String _folderPath(Workspace workspace, WorkspaceFolder folder) {
  final List<String> parts = <String>[folder.title];
  final Set<String> seen = <String>{folder.id};
  String? parentId = folder.parentId;
  while (parentId != null && seen.add(parentId)) {
    final WorkspaceFolder? parent = workspace.folderById(parentId);
    if (parent == null) break;
    parts.insert(0, parent.title);
    parentId = parent.parentId;
  }
  return parts.join(' / ');
}
