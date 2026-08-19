/// The tablist surface: a Minecraft tab-screen mock — header, the player
/// grid with cosmetic ping bars, footer.
///
/// Fidelity notes, all from `TablistService.java`: header, footer and every
/// list name render through the text pipeline per viewer (`renderSafe`), so
/// `|animation.<id>|` references play here through the workspace-scoped
/// resolver; list-name resolution is `chooseListName` — `_op` first for
/// operators, then the primary group, then `default`, then the literal
/// `$player` fallback — mirrored in `logic/tablist_selection.dart`; a blank
/// chosen template resets to the vanilla name. With `useHeaderFooter` off
/// the header and footer rows drop out, and with `groupListNames` off every
/// name shows vanilla. The ping bars and the filler players are cosmetic —
/// the client fills the grid, never the plugin.
///
/// Owns a playback clock while any rendered text plays an animation and the
/// store's animations toggle is on. Mounted only while the tablist view is
/// active.
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/tablist_selection.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';

/// Animation repaint period, matching the hologram stage.
const Duration _tickPeriod = Duration(milliseconds: 100);

/// One mock player row.
typedef _MockPlayer = ({String name, String? group, bool op, int pingBars});

const List<_MockPlayer> _players = <_MockPlayer>[
  (name: 'Cyberpwn', group: 'owner', op: true, pingBars: 5),
  (name: 'Magic_Psycho', group: 'developer', op: false, pingBars: 5),
  (name: 'SwiftSwamp', group: 'moderator', op: false, pingBars: 4),
  (name: 'Puretie', group: 'vip', op: false, pingBars: 5),
  (name: 'Squid', group: null, op: false, pingBars: 3),
  (name: 'Creeper_Fan', group: null, op: false, pingBars: 5),
  (name: 'RedstoneRik', group: null, op: false, pingBars: 4),
  (name: 'Pigstep', group: null, op: false, pingBars: 2),
  (name: 'EnderMae', group: null, op: false, pingBars: 5),
  (name: 'ShovelKnight', group: null, op: false, pingBars: 4),
  (name: 'Glowb3rry', group: null, op: false, pingBars: 3),
  (name: 'Axolotl_99', group: null, op: false, pingBars: 5),
  (name: 'BeeKeeperBob', group: null, op: false, pingBars: 1),
  (name: 'Cartographer', group: null, op: false, pingBars: 4),
  (name: 'DiamondDana', group: null, op: false, pingBars: 5),
  (name: 'Furn4ce', group: null, op: false, pingBars: 3),
  (name: 'GhastlyGwen', group: null, op: false, pingBars: 2),
  (name: 'Hoglin_Hank', group: null, op: false, pingBars: 4),
  (name: 'IronGolemIna', group: null, op: false, pingBars: 5),
  (name: 'JungleJune', group: null, op: false, pingBars: 4),
  (name: 'Kelp_Farmer', group: null, op: false, pingBars: 3),
];

class TablistView extends StatefulWidget {
  const TablistView({required this.store, super.key});

  final EditorStore store;

  @override
  State<TablistView> createState() => _TablistViewState();
}

class _TablistViewState extends State<TablistView> {
  Timer? _ticker;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant TablistView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _syncTicker(bool animated) {
    final bool wanted = animated && _store.animationsPlaying;
    if (wanted && _ticker == null) {
      _ticker = Timer.periodic(_tickPeriod, (Timer _) {
        if (mounted) setState(() {});
      });
    } else if (!wanted && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool _isAnimated(GlossTablistDoc doc, GlossAnimationResolver animations) {
    if (doc.useHeaderFooter &&
        (glossLineAnimationRefs(doc.header, animations).isNotEmpty ||
            glossLineAnimationRefs(doc.footer, animations).isNotEmpty)) {
      return true;
    }
    if (doc.groupListNames) {
      for (final String format in doc.effectiveNameFormats.values) {
        if (glossLineAnimationRefs(format, animations).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// The rendered list name for one mock player: `chooseListName`, token
  /// substitution, then the pipeline. Vanilla (plain name) when
  /// groupListNames is off or the chosen template is blank.
  String _listNameRaw(GlossTablistDoc doc, _MockPlayer player) {
    if (!doc.groupListNames) return player.name;
    final GlossTablistChoice choice = glossTablistChooseListName(
      player.op,
      player.group,
      doc.effectiveNameFormats,
    );
    if (choice.template.trim().isEmpty) return player.name;
    return glossTablistSubstituteTokens(
      choice.template,
      player.name,
      choice.groupName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final GlossTablistDoc? doc = _store.tablistDoc;
    if (doc == null) {
      _syncTicker(false);
      return const dom.div(classes: 'hui-tablist-stage is-empty', <Widget>[]);
    }
    final GlossAnimationResolver animations = _store.workspaceAnimations;
    final GlossEmojiResolver emoji = _store.workspaceEmoji;
    _syncTicker(_isAnimated(doc, animations));
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    List<Widget> pipelineLines(String text) => <Widget>[
      for (final String line in text.split('\n'))
        dom.div(classes: 'hui-tablist-pipeline-line', <Widget>[
          GlossTextLine(
            render: renderGlossLine(
              line,
              animations: animations,
              emoji: emoji,
              nowMs: nowMs,
            ),
          ),
        ]),
    ];

    return dom.div(classes: 'hui-tablist-stage', <Widget>[
      dom.div(classes: 'hui-tablist-sky', <Widget>[
        GlossPreviewZoom(
          label: 'Tab list preview',
          alignment: GlossPreviewAlignment.top,
          child: dom.div(classes: 'hui-tablist-screen', <Widget>[
            if (doc.useHeaderFooter)
              dom.div(classes: 'hui-tablist-header', pipelineLines(doc.header)),
            dom.div(classes: 'hui-tablist-grid', <Widget>[
              for (final _MockPlayer player in _players)
                dom.div(classes: 'hui-tablist-row', <Widget>[
                  const dom.span(classes: 'hui-tablist-row-face', <Widget>[]),
                  dom.span(classes: 'hui-tablist-row-name', <Widget>[
                    GlossTextLine(
                      render: renderGlossLine(
                        _listNameRaw(doc, player),
                        animations: animations,
                        emoji: emoji,
                        nowMs: nowMs,
                      ),
                    ),
                  ]),
                  dom.span(classes: 'hui-tablist-row-ping', <Widget>[
                    for (int bar = 0; bar < 5; bar++)
                      dom.span(
                        classes:
                            'hui-tablist-ping-bar'
                            '${bar < player.pingBars ? ' is-filled' : ''}',
                        const <Widget>[],
                      ),
                  ]),
                ]),
            ]),
            if (doc.useHeaderFooter)
              dom.div(classes: 'hui-tablist-footer', pipelineLines(doc.footer)),
          ]),
        ),
      ]),
      dom.div(classes: 'hui-tablist-readout', <Widget>[Text(_readout(doc))]),
    ]);
  }

  String _readout(GlossTablistDoc doc) {
    final List<String> parts = <String>[
      doc.useHeaderFooter
          ? 'header/footer on'
          : 'header/footer off — the tab screen keeps its vanilla top and '
                'bottom',
      doc.groupListNames
          ? 'list names: Cyberpwn→_op, Magic_Psycho→developer, '
                'SwiftSwamp→moderator, Puretie→vip'
          : 'list names vanilla (groupListNames off)',
      'ping bars and filler players are client cosmetics',
    ];
    return parts.join(' · ');
  }
}
