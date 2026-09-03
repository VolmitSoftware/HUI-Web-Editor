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
import '../scoreboard/scoreboard_selection.dart';
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
  String _world = 'world';
  double _health = 20;

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
    final List<String> text = <String>[
      doc.headerFooter.presentation.header,
      doc.headerFooter.presentation.footer,
      doc.listNames.presentation.format,
      for (final GlossTablistHeaderFooterVariant variant
          in doc.headerFooter.variants) ...<String>[
        variant.presentation.header,
        variant.presentation.footer,
      ],
      for (final GlossTablistListNameVariant variant in doc.listNames.variants)
        variant.presentation.format,
    ];
    for (final String value in text) {
      if (renderGlossLine(value, animations: animations).isAnimated) {
        return true;
      }
    }
    return false;
  }

  /// The rendered list name for one mock player: `chooseListName`, token
  /// substitution, then the pipeline. Vanilla (plain name) when
  /// groupListNames is off or the chosen template is blank.
  String _listNameRaw(GlossTablistDoc doc, _MockPlayer player) {
    if (!doc.listNames.enabled) return player.name;
    final GlossTablistListNamePresentation presentation =
        glossResolveTablistListName(
          doc,
          _conditionContext(
            subjectName: player.name,
            subjectGroup: player.group,
            subjectOp: player.op,
          ),
        );
    if (presentation.format.trim().isEmpty) return player.name;
    return glossTablistSubstituteTokens(
      presentation.format,
      player.name,
      player.group,
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
    final GlossConditionContext viewerContext = _conditionContext();
    final GlossTablistHeaderFooterPresentation headerFooter =
        glossResolveTablistHeaderFooter(doc, viewerContext);
    final String? headerFooterVariant =
        glossResolveTablistHeaderFooterVariantId(doc, viewerContext);

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
      if (doc.headerFooter.enabled)
        dom.div(
          classes: 'hui-tablist-header',
          pipelineLines(headerFooter.header),
        ),
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
      if (doc.headerFooter.enabled)
        dom.div(
          classes: 'hui-tablist-footer',
          pipelineLines(headerFooter.footer),
        ),
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
      _conditionControls(headerFooterVariant),
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
    icon: _store.animationsPlaying
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  String _readout(GlossTablistDoc doc) {
    final List<String> parts = <String>[
      doc.headerFooter.enabled
          ? huiText('header/footer on')
          : huiText(
              'header/footer off — the tab screen keeps its vanilla top and '
              'bottom',
            ),
      doc.listNames.enabled
          ? huiText('conditional list names on')
          : huiText('list names vanilla'),
      huiText('ping bars and filler players are client cosmetics'),
    ];
    return parts.join(' · ');
  }

  GlossConditionContext _conditionContext({
    String subjectName = 'Cyberpwn',
    String? subjectGroup,
    bool subjectOp = false,
  }) {
    const double maxHealth = 20;
    return GlossConditionContext(
      variables: <String, Object?>{
        'viewer.name': 'Cyberpwn',
        'viewer.health': _health,
        'viewer.maxHealth': maxHealth,
        'viewer.healthPercent': _health * 100 / maxHealth,
        'viewer.world': _world,
        'world.name': _world,
        'viewer.op': false,
        'viewer.ping': 42.0,
        'subject.name': subjectName,
        'subject.op': subjectOp,
        'subject.world': _world,
        'server.online': 30.0,
        'server.maxPlayers': 100.0,
        'server.tps': 20.0,
      },
      groupsByRole: <String, Set<String>>{
        'subject': <String>{
          if (subjectGroup != null && subjectGroup.isNotEmpty)
            subjectGroup.toLowerCase(),
        },
      },
      metrics: <String, double>{'react.tick-ms': 50},
    );
  }

  Widget _conditionControls(String? headerFooterVariant) =>
      dom.div(classes: 'hui-scoreboard-sim-controls', <Widget>[
        dom.label(classes: 'hui-scoreboard-sim-field', <Widget>[
          dom.span(classes: 'hui-scoreboard-sim-label', <Widget>[
            Text(huiText('Viewer world')),
          ]),
          TextInput(
            value: _world,
            size: ComponentSize.sm,
            onInput: (String value) => setState(() => _world = value),
          ),
        ]),
        dom.label(classes: 'hui-scoreboard-sim-field', <Widget>[
          dom.span(classes: 'hui-scoreboard-sim-label', <Widget>[
            Text(huiText('Viewer health')),
          ]),
          TextInput(
            value: '$_health',
            size: ComponentSize.sm,
            onInput: (String value) {
              final double? parsed = double.tryParse(value);
              if (parsed != null) {
                setState(() => _health = parsed.clamp(0, 20));
              }
            },
          ),
        ]),
        dom.span(classes: 'hui-scoreboard-sim-verdict', <Widget>[
          Text(
            headerFooterVariant == null
                ? huiText('default header/footer presentation')
                : huiText('header/footer variant: {id}', <String, Object?>{
                    'id': headerFooterVariant,
                  }),
          ),
        ]),
      ]);
}
