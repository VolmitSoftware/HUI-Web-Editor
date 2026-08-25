library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../doctype/document_type_registry.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import 'scoreboard_selection.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ScoreboardSelectionSimulator extends StatefulWidget {
  const ScoreboardSelectionSimulator({
    required this.store,
    required this.context,
    super.key,
  });

  final EditorStore store;
  final GlossConditionContext context;

  @override
  State<ScoreboardSelectionSimulator> createState() =>
      _ScoreboardSelectionSimulatorState();
}

class _ScoreboardSelectionSimulatorState
    extends State<ScoreboardSelectionSimulator> {
  List<GlossBoardCandidate>? _candidates;
  String _candidateSignature = '';

  EditorStore get _store => component.store;

  List<GlossBoardCandidate> _boards() {
    final WorkspaceDocKind? kind = DocumentTypeRegistry.byWireKind(
      'scoreboard',
    )?.kind;
    if (kind == null) return const <GlossBoardCandidate>[];
    final List<WorkspaceDoc> docs = <WorkspaceDoc>[
      for (final WorkspaceDoc doc in _store.workspace.docs)
        if (doc.kind == kind && doc.runtimeId != null) doc,
    ];
    final String signature = <String>[
      '${_store.glossRevision}',
      for (final WorkspaceDoc doc in docs) '${doc.runtimeId}:${doc.updatedAt}',
    ].join('\u0000');
    final List<GlossBoardCandidate>? cached = _candidates;
    if (cached != null && signature == _candidateSignature) return cached;

    final GlossScoreboardDoc? open = _store.scoreboardDoc;
    final List<GlossBoardCandidate> built = <GlossBoardCandidate>[];
    for (final WorkspaceDoc doc in docs) {
      final String id = doc.runtimeId!;
      try {
        built.add(
          GlossBoardCandidate.fromDoc(
            id,
            doc.id == _store.workspace.activeId && open != null
                ? open
                : decodeGlossScoreboardDoc(doc.json),
          ),
        );
      } catch (_) {}
    }
    _candidates = built;
    _candidateSignature = signature;
    return built;
  }

  @override
  Widget build(BuildContext context) {
    final List<GlossBoardCandidate> boards = _boards();
    final GlossBoardSelection selection = glossSelectBoard(
      boards: boards,
      context: component.context,
    );
    return dom.div(classes: 'hui-scoreboard-sim', <Widget>[
      dom.div(classes: 'hui-scoreboard-sim-head', <Widget>[
        dom.span(classes: 'hui-scoreboard-sim-title', <Widget>[
          Text(huiText('Board selection')),
        ]),
        dom.span(classes: 'hui-scoreboard-sim-verdict', <Widget>[
          Text(
            selection.boardId == null
                ? huiText('this viewer gets no sidebar')
                : huiText('{id} wins', <String, Object?>{
                    'id': selection.boardId!,
                  }),
          ),
        ]),
      ]),
      if (boards.isEmpty)
        dom.p(classes: 'hui-scoreboard-sim-empty', <Widget>[
          Text(huiText('No scoreboard documents are available.')),
        ])
      else
        dom.ul(classes: 'hui-scoreboard-sim-list', <Widget>[
          for (final GlossBoardCandidate board in boards)
            _row(board, selection),
        ]),
      dom.p(classes: 'hui-scoreboard-sim-note', <Widget>[
        Text(
          huiText(
            'Every matching select.when enters the contest. Highest priority '
            'wins; equal priorities use the smaller board id.',
          ),
        ),
      ]),
    ]);
  }

  Widget _row(GlossBoardCandidate board, GlossBoardSelection selection) {
    final ({bool matches, String? error}) result = glossConditionMatches(
      board.when,
      component.context,
    );
    final bool wins = board.id == selection.boardId;
    return dom.li(
      classes: <String>[
        'hui-scoreboard-sim-row',
        if (wins) 'is-winner',
        if (!result.matches) 'is-hidden-from-viewer',
      ].join(' '),
      <Widget>[
        dom.span(classes: 'hui-scoreboard-sim-id', <Widget>[Text(board.id)]),
        dom.span(classes: 'hui-scoreboard-sim-flags', <Widget>[
          dom.span(classes: 'hui-scoreboard-sim-flag', <Widget>[
            Text(
              huiText('priority {priority}', <String, Object?>{
                'priority': board.priority,
              }),
            ),
          ]),
        ]),
        dom.span(classes: 'hui-scoreboard-sim-state', <Widget>[
          Text(
            wins
                ? huiText('shown')
                : result.error != null
                ? huiText('condition error: {error}', <String, Object?>{
                    'error': result.error!,
                  })
                : result.matches
                ? huiText('outranked')
                : huiText('condition false'),
          ),
        ]),
      ],
    );
  }
}
