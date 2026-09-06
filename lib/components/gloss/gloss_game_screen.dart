/// The shared Minecraft game-screen frame every Gloss surface mounts into
/// when the shell asks for `gameContext`.
///
/// Each surface on its own answers "what does this document render"; this
/// frame answers "where does the player actually see it". It draws the same
/// chrome the client draws — a live 3D world at the client's own eye, the
/// crosshair, the hotbar with its health, hunger and armor rows from the
/// client's own sprites, and a faded chat region — then anchors the surface
/// where vanilla puts it ([GlossGameAnchor]). Nothing here reads a document:
/// the caller passes the already-rendered surface as [child], so a frame
/// costs one wrapper div per anchor and no extra pipeline work.
///
/// The world is an [McStage]; a caller that draws in the world hands the
/// frame its own controller and anchored text instead of drawing a scene of
/// its own. Chrome is DOM and CSS (`web/styles/12-gloss-fidelity.css`), the
/// HUD sprites come from the pack under `web/assets/mc/26.2/hud/`.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:gloss_editor/l10n/hui_localizations.dart';

import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_scene.dart';
import '../mc/mc_stage.dart';
import '../mc/mc_stage_controller.dart';

/// Where in the client's screen a surface belongs.
enum GlossGameAnchor {
  /// Right edge, vertically centred: the sidebar objective slot.
  sidebar,

  /// Top centre, over the world: the tab-key player list.
  tabOverlay,

  /// Lower left: the chat region, which the surface replaces.
  chat,

  /// Centred over the player, where a chat bubble floats.
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

/// One idle world per anchor, shared across rebuilds so the canvas is not
/// recreated every time a HUD surface repaints.
final Map<GlossGameAnchor, McStageController> _idleWorlds = <GlossGameAnchor, McStageController>{};

McStageController glossGameWorldController(GlossGameAnchor anchor) =>
    _idleWorlds.putIfAbsent(anchor, () {
      final McStageController controller = McStageController(
        kind: McStageKind.frame,
        homePivot: const McVec3(0.5, 0, 0.5),
        freeCamera: false,
      );
      if (anchor == GlossGameAnchor.overPlayer) {
        controller.scene = McScene(<McSceneNode>[
          McRigNode(
            key: 'frame-player',
            rigId: 'player',
            textureId: 'player',
            // Rigs are meshed facing +Z, toward the frame camera standing south.
            transform: McMat4.translation(0.5, 0, 0.5),
            poseTimeMs: 0,
            hurt: 0,
            capeTextureId: 'player_cape',
          ),
        ]);
      }
      return controller;
    });

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
    this.world,
    this.worldOverlay = const <Widget>[],
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

  /// The world behind the HUD. A caller that draws in the world passes its
  /// own controller (scene + anchored text); every other anchor gets the
  /// frame's idle world with a fixed client-style camera.
  final McStageController? world;

  /// Text the caller anchors in the world (drops label, hologram lines).
  final List<Widget> worldOverlay;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-gloss-game is-${anchor.slug}',
    attributes: <String, String>{'role': 'img', 'aria-label': label},
    <Widget>[
      dom.div(classes: 'hui-gloss-game-world', <Widget>[
        McStage(
          controller: world ?? glossGameWorldController(anchor),
          overlay: worldOverlay,
          label: label,
        ),
      ]),
      dom.div(classes: 'hui-gloss-game-anchor', <Widget>[child]),
      if (anchor.drawsHud) _crosshair(),
      if (anchor.drawsIdleChat)
        dom.div(classes: 'hui-gloss-game-chat', <Widget>[
          for (final String line in _idleChat)
            dom.div(classes: 'hui-gloss-game-chat-line', <Widget>[Text(line)]),
        ]),
      if (anchor.drawsHud) _hud(),
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

  Widget _crosshair() => const dom.div(classes: 'hui-gloss-game-crosshair', <Widget>[]);

  /// The client's bottom HUD from its own sprites at GUI scale 2: hotbar
  /// 182x22 flush to the bottom, XP bar 29 px up, hearts left and food right
  /// 39 px up, armor 49 px up (GUI pixels).
  Widget _hud() => dom.div(classes: 'hui-gloss-game-hud', <Widget>[
    dom.div(classes: 'hui-gloss-game-armor', <Widget>[
      for (int i = 0; i < 10; i++)
        dom.span(classes: 'hui-gloss-game-sprite is-armor-${i < 2 ? 'full' : 'empty'}', const <Widget>[]),
    ]),
    dom.div(classes: 'hui-gloss-game-hearts', <Widget>[
      for (int i = 0; i < 10; i++)
        dom.span(classes: 'hui-gloss-game-sprite is-heart-container', <Widget>[
          if (i < 9) dom.span(classes: 'hui-gloss-game-sprite is-heart-${i < 8 ? 'full' : 'half'}', const <Widget>[]),
        ]),
    ]),
    dom.div(classes: 'hui-gloss-game-food', <Widget>[
      for (int i = 0; i < 10; i++)
        dom.span(classes: 'hui-gloss-game-sprite is-food-empty', <Widget>[
          if (i < 8) dom.span(classes: 'hui-gloss-game-sprite is-food-${i < 7 ? 'full' : 'half'}', const <Widget>[]),
        ]),
    ]),
    const dom.div(classes: 'hui-gloss-game-sprite is-xp-background', <Widget>[
      dom.div(classes: 'hui-gloss-game-sprite is-xp-progress', <Widget>[]),
    ]),
    const dom.div(classes: 'hui-gloss-game-sprite is-hotbar', <Widget>[
      dom.div(classes: 'hui-gloss-game-sprite is-hotbar-selection', <Widget>[]),
    ]),
  ]);
}
