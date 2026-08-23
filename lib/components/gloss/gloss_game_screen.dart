/// The shared Minecraft game-screen frame every Gloss surface mounts into
/// when the shell asks for `gameContext`.
///
/// Each surface on its own answers "what does this document render"; this
/// frame answers "where does the player actually see it". It draws the same
/// chrome the client draws — a 16:9 viewport over the backdrop photo, the
/// crosshair, the hotbar with its health and hunger rows, and a faded chat
/// region — then anchors the surface where vanilla puts it
/// ([GlossGameAnchor]). Nothing here reads a document: the caller passes the
/// already-rendered surface as [child], so a frame costs one wrapper div per
/// anchor and no extra pipeline work.
///
/// Pure DOM and CSS (`web/styles/12-gloss-fidelity.css`). The only asset is
/// the backdrop photo the canvas already ships (`huiBackdropAssetUrl` in
/// `render/canvas_assets.dart`), referenced from the stylesheet.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Where in the client's screen a surface belongs.
enum GlossGameAnchor {
  /// Right edge, vertically centred: the sidebar objective slot.
  sidebar,

  /// Top centre, over the world: the tab-key player list.
  tabOverlay,

  /// Lower left: the chat region, which the surface replaces.
  chat,

  /// Centred over the player silhouette, where a chat bubble floats.
  overPlayer,

  /// Free in-world placement filling the viewport, for the surfaces that
  /// draw their own scene (hologram, animation frame).
  world,

  /// A full GUI screen rather than the HUD — the multiplayer server list.
  /// Suppresses the crosshair, hotbar and chat.
  screen,
}

extension on GlossGameAnchor {
  /// The anchor's CSS modifier, kebab-cased so the stylesheet never carries a
  /// mixed-case class name.
  String get slug => switch (this) {
    GlossGameAnchor.sidebar => 'sidebar',
    GlossGameAnchor.tabOverlay => 'tab-overlay',
    GlossGameAnchor.chat => 'chat',
    GlossGameAnchor.overPlayer => 'over-player',
    GlossGameAnchor.world => 'world',
    GlossGameAnchor.screen => 'screen',
  };

  /// GUI screens replace the world view, so the HUD is not drawn behind them.
  bool get drawsHud => this != GlossGameAnchor.screen;

  /// The chat anchor hands the region to the surface instead of drawing the
  /// canned faded lines.
  bool get drawsIdleChat =>
      this != GlossGameAnchor.chat && this != GlossGameAnchor.screen;
}

/// Canned chat scrollback behind the HUD. Cosmetic — it exists so the
/// bottom-left of the frame is not empty, and it fades out the way the
/// client's own history does.
List<String> get _idleChat => <String>[
  huiText('{player} joined the game', <String, Object?>{'player': 'Cyberpwn'}),
  huiText(
    '<{player}> anyone seen the road out past the sawmill',
    <String, Object?>{'player': 'SwiftSwamp'},
  ),
  huiText('<{player}> south of spawn, through the sycamores', <String, Object?>{
    'player': 'Puretie',
  }),
];

/// The frame with nothing anchored in it — what a surface renders under
/// `gameContext` when it has no document to draw.
///
/// The editing surfaces answer that case with a bare `is-empty` stage, which is
/// right for them: the empty artboard is still recognisably the artboard. In
/// the preview mode it is not, because the mode's whole subject is the screen
/// around the surface, and an unframed blank div there reads as a pane that
/// failed to render rather than as a board with nothing on it.
Widget glossGameEmpty({
  required GlossGameAnchor anchor,
  required String label,
}) => GlossGameScreen(
  anchor: anchor,
  label: label,
  child: const dom.div(<Widget>[]),
);

class GlossGameScreen extends StatelessWidget {
  const GlossGameScreen({
    required this.anchor,
    required this.child,
    required this.label,
    this.controls = const <Widget>[],
    super.key,
  });

  /// Where [child] sits in the frame.
  final GlossGameAnchor anchor;

  /// The surface itself, already rendered by the owning view.
  final Widget child;

  /// Accessible name for the frame, e.g. "Scoreboard in game".
  final String label;

  /// Editor affordances floated over the frame — play/pause and friends.
  /// Empty renders no strip at all.
  final List<Widget> controls;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-gloss-game is-${anchor.slug}',
    attributes: <String, String>{'role': 'img', 'aria-label': label},
    <Widget>[
      const dom.div(classes: 'hui-gloss-game-world', <Widget>[]),
      if (anchor.drawsHud)
        const dom.div(classes: 'hui-gloss-game-sun', <Widget>[]),
      if (anchor == GlossGameAnchor.overPlayer) _player(),
      dom.div(classes: 'hui-gloss-game-anchor', <Widget>[child]),
      if (anchor.drawsHud)
        const dom.div(classes: 'hui-gloss-game-crosshair', <Widget>[]),
      if (anchor.drawsIdleChat)
        dom.div(classes: 'hui-gloss-game-chat', <Widget>[
          for (final String line in _idleChat)
            dom.div(classes: 'hui-gloss-game-chat-line', <Widget>[Text(line)]),
        ]),
      if (anchor.drawsHud) _hotbar(),
      if (controls.isNotEmpty)
        dom.div(
          classes: 'hui-gloss-game-controls',
          attributes: <String, String>{
            'role': 'group',
            'aria-label': huiText("{label} controls", <String, Object?>{
              'label': label,
            }),
          },
          controls,
        ),
    ],
  );

  /// The third-person silhouette a bubble floats over. Same three-box shape
  /// the bubble stage draws, so the two surfaces read as one character.
  Widget _player() => const dom.div(classes: 'hui-gloss-game-player', <Widget>[
    dom.div(classes: 'hui-gloss-game-player-head', <Widget>[]),
    dom.div(classes: 'hui-gloss-game-player-body', <Widget>[]),
    dom.div(classes: 'hui-gloss-game-player-arms', <Widget>[]),
  ]);

  /// Health, hunger and the nine slots — the client's bottom HUD. Purely
  /// cosmetic framing; no document drives any of it.
  Widget _hotbar() => dom.div(classes: 'hui-gloss-game-hud', <Widget>[
    dom.div(classes: 'hui-gloss-game-stats', <Widget>[
      dom.div(classes: 'hui-gloss-game-hearts', <Widget>[
        for (int i = 0; i < 10; i++)
          const dom.span(classes: 'hui-gloss-game-heart', <Widget>[]),
      ]),
      dom.div(classes: 'hui-gloss-game-hunger', <Widget>[
        for (int i = 0; i < 10; i++)
          const dom.span(classes: 'hui-gloss-game-drumstick', <Widget>[]),
      ]),
    ]),
    const dom.div(classes: 'hui-gloss-game-xp', <Widget>[
      dom.div(classes: 'hui-gloss-game-xp-fill', <Widget>[]),
    ]),
    dom.div(classes: 'hui-gloss-game-hotbar', <Widget>[
      for (int slot = 0; slot < 9; slot++)
        dom.span(
          classes: 'hui-gloss-game-slot${slot == 0 ? ' is-selected' : ''}',
          const <Widget>[],
        ),
    ]),
  ]);
}
