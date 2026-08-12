library;

import '../model/model.dart';
import '../state/workspace.dart';
import '../state/workspace_board.dart';

enum WorkspaceFlowTargetKind {
  menu,
  back,
  home,
  close,
  external,
  dangling,
  ambiguous,
  invalid,
}

class WorkspaceFlowEdge {
  const WorkspaceFlowEdge({
    required this.sourceDocumentId,
    required this.sourceRuntimeId,
    required this.componentId,
    required this.branch,
    required this.mode,
    required this.target,
    required this.targetKind,
    required this.triggers,
    this.targetDocumentId,
  });

  final String sourceDocumentId;
  final String sourceRuntimeId;
  final String componentId;
  final String branch;
  final String mode;
  final String target;
  final WorkspaceFlowTargetKind targetKind;
  final Set<String> triggers;
  final String? targetDocumentId;
}

class WorkspaceFlowGraph {
  const WorkspaceFlowGraph({
    required this.documents,
    required this.edges,
    required this.cycleDocumentIds,
    required this.orphanDocumentIds,
    required this.invalidDocumentIds,
    required this.duplicateRuntimeIds,
    required this.scopeFolderIds,
    required this.scopeMissing,
  });

  final List<WorkspaceDoc> documents;
  final List<WorkspaceFlowEdge> edges;
  final Set<String> cycleDocumentIds;
  final Set<String> orphanDocumentIds;
  final Set<String> invalidDocumentIds;
  final Set<String> duplicateRuntimeIds;
  final Set<String> scopeFolderIds;
  final bool scopeMissing;

  List<WorkspaceFlowEdge> outgoing(String documentId) => edges
      .where((WorkspaceFlowEdge edge) => edge.sourceDocumentId == documentId)
      .toList(growable: false);
}

WorkspaceFlowGraph buildWorkspaceFlowGraph(
  Workspace workspace,
  WorkspaceBoardData board,
) {
  final List<WorkspaceDoc> allMenus = workspace.docs
      .where((WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.menu)
      .toList(growable: false);
  final _WorkspaceScope scope = _resolveScope(workspace, board.scopeFolderId);
  final List<WorkspaceDoc> documents = allMenus
      .where((WorkspaceDoc doc) => scope.folderIds.contains(doc.folderId))
      .toList();
  documents.sort(_compareDocuments);

  final Map<String, List<WorkspaceDoc>> allByRuntimeId =
      <String, List<WorkspaceDoc>>{};
  final Map<String, List<WorkspaceDoc>> portableByRuntimeId =
      <String, List<WorkspaceDoc>>{};
  final Map<String, List<WorkspaceDoc>> localByRuntimeId =
      <String, List<WorkspaceDoc>>{};
  for (final WorkspaceDoc doc in allMenus) {
    final String runtimeId = doc.runtimeId!;
    allByRuntimeId.putIfAbsent(runtimeId, () => <WorkspaceDoc>[]).add(doc);
    portableByRuntimeId
        .putIfAbsent(runtimeId.toLowerCase(), () => <WorkspaceDoc>[])
        .add(doc);
  }
  for (final WorkspaceDoc doc in documents) {
    final String runtimeId = doc.runtimeId!;
    localByRuntimeId.putIfAbsent(runtimeId, () => <WorkspaceDoc>[]).add(doc);
  }

  final List<WorkspaceFlowEdge> edges = <WorkspaceFlowEdge>[];
  final Set<String> invalidDocumentIds = <String>{};
  for (final WorkspaceDoc doc in documents) {
    final HuiMenu menu;
    try {
      menu = decodeHuiMenu(doc.json);
    } catch (_) {
      invalidDocumentIds.add(doc.id);
      continue;
    }
    for (final _NavigationReference reference in _navigationReferences(menu)) {
      edges.add(_resolveEdge(doc, reference, localByRuntimeId, allByRuntimeId));
    }
  }

  final Set<String> cycleDocumentIds = _cycleDocumentIds(documents, edges);
  final Set<String> incoming = <String>{
    for (final WorkspaceFlowEdge edge in edges)
      if (edge.targetKind == WorkspaceFlowTargetKind.menu)
        edge.targetDocumentId!,
  };
  final Set<String> orphanDocumentIds = <String>{
    for (final WorkspaceDoc doc in documents)
      if (!incoming.contains(doc.id)) doc.id,
  };
  final Set<String> duplicateRuntimeIds = <String>{};
  for (final List<WorkspaceDoc> matches in portableByRuntimeId.values) {
    if (matches.length < 2) continue;
    duplicateRuntimeIds.addAll(
      matches.map((WorkspaceDoc doc) => doc.runtimeId!),
    );
  }

  return WorkspaceFlowGraph(
    documents: List<WorkspaceDoc>.unmodifiable(documents),
    edges: List<WorkspaceFlowEdge>.unmodifiable(edges),
    cycleDocumentIds: Set<String>.unmodifiable(cycleDocumentIds),
    orphanDocumentIds: Set<String>.unmodifiable(orphanDocumentIds),
    invalidDocumentIds: Set<String>.unmodifiable(invalidDocumentIds),
    duplicateRuntimeIds: Set<String>.unmodifiable(duplicateRuntimeIds),
    scopeFolderIds: Set<String>.unmodifiable(scope.folderIds),
    scopeMissing: scope.missing,
  );
}

Map<String, WorkspaceBoardPoint> arrangeWorkspaceFlowGraph(
  WorkspaceFlowGraph graph,
) {
  final Map<String, Set<String>> outgoing = <String, Set<String>>{
    for (final WorkspaceDoc doc in graph.documents) doc.id: <String>{},
  };
  final Map<String, int> indegree = <String, int>{
    for (final WorkspaceDoc doc in graph.documents) doc.id: 0,
  };
  for (final WorkspaceFlowEdge edge in graph.edges) {
    if (edge.targetKind != WorkspaceFlowTargetKind.menu) continue;
    if (outgoing[edge.sourceDocumentId]!.add(edge.targetDocumentId!)) {
      indegree[edge.targetDocumentId!] = indegree[edge.targetDocumentId!]! + 1;
    }
  }

  final Map<String, int> depth = <String, int>{};
  final List<String> queue = <String>[
    for (final WorkspaceDoc doc in graph.documents)
      if (indegree[doc.id] == 0) doc.id,
  ];
  for (final String id in queue) {
    depth[id] = 0;
  }
  int cursor = 0;
  while (cursor < queue.length) {
    final String id = queue[cursor++];
    for (final String target in outgoing[id]!) {
      depth[target] = _maxInt(depth[target] ?? 0, depth[id]! + 1);
      indegree[target] = indegree[target]! - 1;
      if (indegree[target] == 0) queue.add(target);
    }
  }
  int cycleDepth = 0;
  for (final int value in depth.values) {
    cycleDepth = _maxInt(cycleDepth, value + 1);
  }
  for (final WorkspaceDoc doc in graph.documents) {
    depth.putIfAbsent(doc.id, () => cycleDepth);
  }

  final Map<int, int> rows = <int, int>{};
  final Map<String, WorkspaceBoardPoint> positions =
      <String, WorkspaceBoardPoint>{};
  for (final WorkspaceDoc doc in graph.documents) {
    final int column = depth[doc.id]!;
    final int row = rows[column] ?? 0;
    rows[column] = row + 1;
    positions[doc.id] = WorkspaceBoardPoint(64 + column * 292, 72 + row * 172);
  }
  return positions;
}

WorkspaceFlowEdge _resolveEdge(
  WorkspaceDoc source,
  _NavigationReference reference,
  Map<String, List<WorkspaceDoc>> localByRuntimeId,
  Map<String, List<WorkspaceDoc>> allByRuntimeId,
) {
  final HuiNavigateAction action = reference.action;
  final WorkspaceFlowTargetKind sink = switch (action.mode) {
    'back' => WorkspaceFlowTargetKind.back,
    'home' => WorkspaceFlowTargetKind.home,
    'close' => WorkspaceFlowTargetKind.close,
    _ => WorkspaceFlowTargetKind.invalid,
  };
  if (sink != WorkspaceFlowTargetKind.invalid) {
    return _edge(source, reference, sink);
  }
  if (action.mode != 'push' && action.mode != 'replace') {
    return _edge(source, reference, WorkspaceFlowTargetKind.invalid);
  }
  final String target = action.target;
  if (target.trim().isEmpty) {
    return _edge(source, reference, WorkspaceFlowTargetKind.dangling);
  }
  final List<WorkspaceDoc> local =
      localByRuntimeId[target] ?? const <WorkspaceDoc>[];
  final List<WorkspaceDoc> all =
      allByRuntimeId[target] ?? const <WorkspaceDoc>[];
  if (all.length > 1) {
    return _edge(source, reference, WorkspaceFlowTargetKind.ambiguous);
  }
  if (local.length == 1) {
    return _edge(
      source,
      reference,
      WorkspaceFlowTargetKind.menu,
      targetDocumentId: local.single.id,
    );
  }
  if (all.length == 1) {
    return _edge(source, reference, WorkspaceFlowTargetKind.external);
  }
  return _edge(source, reference, WorkspaceFlowTargetKind.dangling);
}

WorkspaceFlowEdge _edge(
  WorkspaceDoc source,
  _NavigationReference reference,
  WorkspaceFlowTargetKind targetKind, {
  String? targetDocumentId,
}) => WorkspaceFlowEdge(
  sourceDocumentId: source.id,
  sourceRuntimeId: source.runtimeId!,
  componentId: reference.componentId,
  branch: reference.branch,
  mode: reference.action.mode,
  target: reference.action.target,
  targetKind: targetKind,
  triggers: Set<String>.unmodifiable(reference.triggers),
  targetDocumentId: targetDocumentId,
);

Iterable<_NavigationReference> _navigationReferences(HuiMenu menu) sync* {
  for (final HuiComponent component in menu.components) {
    switch (component.data) {
      case final HuiButtonData button:
        yield* _branchNavigationReferences(
          component.id,
          'click',
          button.actions,
        );
      case final HuiToggleData toggle:
        yield* _branchNavigationReferences(
          component.id,
          'true',
          toggle.trueActions,
        );
        yield* _branchNavigationReferences(
          component.id,
          'false',
          toggle.falseActions,
        );
      case HuiDecorationData():
        break;
    }
  }
}

Iterable<_NavigationReference> _branchNavigationReferences(
  String componentId,
  String branch,
  List<HuiAction> actions,
) sync* {
  final Set<String> remaining = <String>{..._physicalTriggers};
  for (final HuiAction action in actions) {
    if (action is! HuiNavigateAction) continue;
    if (!huiActionTriggers.contains(action.trigger)) {
      yield _NavigationReference(componentId, branch, action, <String>{
        action.trigger,
      });
      continue;
    }
    final Set<String> matched = action.trigger == 'any'
        ? <String>{...remaining}
        : <String>{action.trigger}.intersection(remaining);
    if (matched.isEmpty) continue;
    yield _NavigationReference(componentId, branch, action, matched);
    remaining.removeAll(matched);
    if (remaining.isEmpty) return;
  }
}

const Set<String> _physicalTriggers = <String>{
  'left_click',
  'right_click',
  'shift_left_click',
  'shift_right_click',
};

Set<String> _cycleDocumentIds(
  List<WorkspaceDoc> documents,
  List<WorkspaceFlowEdge> edges,
) {
  final Map<String, Set<String>> adjacency = <String, Set<String>>{
    for (final WorkspaceDoc doc in documents) doc.id: <String>{},
  };
  for (final WorkspaceFlowEdge edge in edges) {
    if (edge.targetKind == WorkspaceFlowTargetKind.menu) {
      adjacency[edge.sourceDocumentId]!.add(edge.targetDocumentId!);
    }
  }

  int nextIndex = 0;
  final Map<String, int> index = <String, int>{};
  final Map<String, int> lowLink = <String, int>{};
  final List<String> stack = <String>[];
  final Set<String> onStack = <String>{};
  final Set<String> cycles = <String>{};

  void visit(String node) {
    index[node] = nextIndex;
    lowLink[node] = nextIndex;
    nextIndex++;
    stack.add(node);
    onStack.add(node);
    for (final String target in adjacency[node]!) {
      if (!index.containsKey(target)) {
        visit(target);
        lowLink[node] = _minInt(lowLink[node]!, lowLink[target]!);
      } else if (onStack.contains(target)) {
        lowLink[node] = _minInt(lowLink[node]!, index[target]!);
      }
    }
    if (lowLink[node] != index[node]) return;
    final List<String> component = <String>[];
    while (stack.isNotEmpty) {
      final String member = stack.removeLast();
      onStack.remove(member);
      component.add(member);
      if (member == node) break;
    }
    if (component.length > 1 || adjacency[node]!.contains(node)) {
      cycles.addAll(component);
    }
  }

  for (final WorkspaceDoc doc in documents) {
    if (!index.containsKey(doc.id)) visit(doc.id);
  }
  return cycles;
}

_WorkspaceScope _resolveScope(Workspace workspace, String? rootFolderId) {
  if (rootFolderId == null) {
    return _WorkspaceScope(<String>{
      for (final WorkspaceFolder folder in workspace.folders) folder.id,
    }, false);
  }
  if (workspace.folderById(rootFolderId) == null) {
    return _WorkspaceScope(<String>{
      for (final WorkspaceFolder folder in workspace.folders) folder.id,
    }, true);
  }
  final Set<String> ids = <String>{rootFolderId};
  bool changed = true;
  while (changed) {
    changed = false;
    for (final WorkspaceFolder folder in workspace.folders) {
      if (folder.parentId != null &&
          ids.contains(folder.parentId) &&
          ids.add(folder.id)) {
        changed = true;
      }
    }
  }
  return _WorkspaceScope(ids, false);
}

int _compareDocuments(WorkspaceDoc a, WorkspaceDoc b) {
  final int runtime = a.runtimeId!.compareTo(b.runtimeId!);
  return runtime != 0 ? runtime : a.id.compareTo(b.id);
}

int _minInt(int a, int b) => a < b ? a : b;

int _maxInt(int a, int b) => a > b ? a : b;

class _NavigationReference {
  const _NavigationReference(
    this.componentId,
    this.branch,
    this.action,
    this.triggers,
  );

  final String componentId;
  final String branch;
  final HuiNavigateAction action;
  final Set<String> triggers;
}

class _WorkspaceScope {
  const _WorkspaceScope(this.folderIds, this.missing);

  final Set<String> folderIds;
  final bool missing;
}
