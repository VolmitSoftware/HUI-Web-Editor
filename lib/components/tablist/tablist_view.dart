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
/// With `gameContext` the tab screen mounts into the shared game-screen frame
/// as the top-centre overlay the tab key raises; without it the surface keeps
/// its editor stage and readout.
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
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Animation repaint period, matching the hologram stage.
const Duration _tickPeriod = Duration(milliseconds: 50);

/// One mock player row.
typedef _MockPlayer = ({String name, String? group, bool op, int pingBars});

const List<_MockPlayer> _players = <_MockPlayer>[
  (name: 'Cyberpwn', group: 'owner', op: true, pingBars: 5),
  (name: 'Magic_Psycho', group: 'developer', op: false, pingBars: 5),
  (name: 'SwiftSwamp', group: 'moderator', op: false, pingBars: 4),
  (name: 'Puretie', group: 'vip', op: false, pingBars: 5),
  (name: 'AgentCooper', group: null, op: false, pingBars: 5),
  (name: 'LauraPalmer', group: null, op: false, pingBars: 4),
  (name: 'TheLogLady', group: null, op: false, pingBars: 3),
  (name: 'BobbyBriggs', group: null, op: false, pingBars: 5),
  (name: 'AudreyHorne', group: null, op: false, pingBars: 2),
  (name: 'DeputyHawk', group: null, op: false, pingBars: 4),
  (name: 'ShellyJohnson', group: null, op: false, pingBars: 5),
  (name: 'BigEdHurley', group: null, op: false, pingBars: 3),
  (name: 'NadineHurley', group: null, op: false, pingBars: 4),
  (name: 'LelandPalmer', group: null, op: false, pingBars: 2),
  (name: 'DrJacoby', group: null, op: false, pingBars: 5),
  (name: 'GordonCole', group: null, op: false, pingBars: 3),
  (name: 'DianeEvans', group: null, op: false, pingBars: 4),
  (name: 'JosiePackard', group: null, op: false, pingBars: 5),
  (name: 'PeteMartell', group: null, op: false, pingBars: 2),
  (name: 'CatherineM', group: null, op: false, pingBars: 3),
  (name: 'AndyBrennan', group: null, op: false, pingBars: 5),
  (name: 'LucyMoran', group: null, op: false, pingBars: 4),
  (name: 'DonnaHayward', group: null, op: false, pingBars: 3),
  (name: 'JamesHurley', group: null, op: false, pingBars: 5),
  (name: 'MaddyFerguson', group: null, op: false, pingBars: 4),
  (name: 'WindomEarle', group: null, op: false, pingBars: 2),
  (name: 'TheGiant', group: null, op: false, pingBars: 5),
  (name: 'MrsTremond', group: null, op: false, pingBars: 3),
  (name: 'BenHorne', group: null, op: false, pingBars: 4),
  (name: 'NormaJennings', group: null, op: false, pingBars: 5),
  (name: 'LeoJohnson', group: null, op: false, pingBars: 3),
];

class TablistView extends StatefulWidget {
  const TablistView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;

  /// Mounts the tab screen inside the shared Minecraft game-screen frame
  /// instead of the editor stage. False renders exactly the editor surface.
  final bool gameContext;

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
        (renderGlossLine(doc.header, animations: animations).isAnimated ||
            renderGlossLine(doc.footer, animations: animations).isAnimated)) {
      return true;
    }
    if (doc.groupListNames) {
      for (final String format in doc.effectiveNameFormats.values) {
        if (renderGlossLine(format, animations: animations).isAnimated) {
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
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.tabOverlay,
          label: huiText('Tab list in game'),
        );
      }
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

    final Widget screen = dom.div(classes: 'hui-tablist-screen', <Widget>[
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
    ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.tabOverlay,
        label: huiText('Tab list in game'),
        controls: <Widget>[_playPause()],
        child: screen,
      );
    }

    return dom.div(classes: 'hui-tablist-stage', <Widget>[
      dom.div(classes: 'hui-tablist-sky', <Widget>[
        GlossPreviewZoom(
          label: huiText('Tab list preview'),
          alignment: GlossPreviewAlignment.top,
          child: screen,
        ),
        dom.div(
          classes: 'hui-tablist-view-controls',
          attributes: <String, String>{
            'role': 'group',
            'aria-label': huiText('Tab list preview controls'),
          },
          <Widget>[_playPause()],
        ),
      ]),
      dom.div(classes: 'hui-tablist-readout', <Widget>[Text(_readout(doc))]),
    ]);
  }

  /// The animation transport, the same shape the hologram stage uses. It
  /// drives the store's workspace-wide toggle, so pausing here pauses every
  /// surface that references an animation.
  Widget _playPause() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: () => _store.animationsPlaying = !_store.animationsPlaying,
    attributes: <String, String>{
      'aria-label': _store.animationsPlaying
          ? huiText('Pause animations')
          : huiText('Play animations'),
      'title': _store.animationsPlaying
          ? huiText('Pause animations')
          : huiText('Play animations'),
    },
    child: _store.animationsPlaying
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  String _readout(GlossTablistDoc doc) {
    final List<String> parts = <String>[
      doc.useHeaderFooter
          ? huiText('header/footer on')
          : huiText(
              'header/footer off — the tab screen keeps its vanilla top and '
              'bottom',
            ),
      doc.groupListNames
          ? huiText('list names: {mapping}', <String, Object?>{
              'mapping':
                  'Cyberpwn→_op, Magic_Psycho→developer, '
                  'SwiftSwamp→moderator, Puretie→vip',
            })
          : huiText('list names vanilla (groupListNames off)'),
      huiText('ping bars and filler players are client cosmetics'),
    ];
    return parts.join(' · ');
  }
}
