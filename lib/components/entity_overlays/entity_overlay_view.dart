library;

import 'dart:async';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/entity_overlay_preview.dart';
import '../../logic/gloss_text.dart';
import '../../logic/gloss_particle_preview.dart';
import '../../mc/rigs/mc_rig.dart';
import '../../mc/rigs/mc_rigs.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_scene.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../../model/gloss_entity_overlays.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';
import '../mc/mc_asset_loader.dart';
import '../mc/mc_dom_layer.dart';
import '../mc/mc_stage.dart';
import '../mc/mc_stage_controller.dart';

class EntityOverlayView extends StatefulWidget {
  const EntityOverlayView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

  @override
  State<EntityOverlayView> createState() => _EntityOverlayViewState();
}

class _EntityOverlayViewState extends State<EntityOverlayView> {
  Timer? _hitTimer;
  Timer? _animationTimer;
  final Stopwatch _clock = Stopwatch();
  String _name = 'Sample sentinel';
  double _health = 14;
  double _maxHealth = 20;
  double _attack = 3;
  double _armor = 2;
  double _distance = 6;
  double _damage = 0;
  int _stackCount = 4;
  bool _react = false;
  bool _adapt = false;
  bool _insight = false;
  bool _exclusive = false;
  bool _player = false;

  /// Clock time of the last `_strike()`; the rig's red hurt overlay shows
  /// for 500 ms after this regardless of `doc.hitHighlightMs`.
  int _hitAtMs = -1000;

  /// The editor stage frames the sample's midriff and orbits; the game frame
  /// stands at the client's eye over the sample and does not.
  late final McStageController _stage = McStageController(
    kind: component.gameContext ? McStageKind.frame : McStageKind.overlays,
    homePivot: McVec3(0.5, component.gameContext ? mcCameraEyeHeight : 0.9, 0.5),
    freeCamera: !component.gameContext,
  );

  /// The last camera and WebGL verdict this view rendered against, so a
  /// notification raised by its own scene write is told apart from one that
  /// actually moves the anchored label.
  late McCamera _lastCamera = _stage.camera;
  late bool _lastWebGl = _stage.webGlAvailable;

  /// The instant the rig is posed at. It follows the sample clock while frames
  /// are being drawn and holds its last value once they stop, so a parked
  /// stage keeps the pose it froze on.
  int _poseTimeMs = 0;

  @override
  void initState() {
    super.initState();
    component.store.addListener(_changed);
    _stage.addListener(_onStageChanged);
    _stage.spriteFor = _spriteFor;
    _clock.start();
    _syncClock();
  }

  @override
  void didUpdateComponent(covariant EntityOverlayView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_changed);
      component.store.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _hitTimer?.cancel();
    _animationTimer?.cancel();
    _clock.stop();
    component.store.removeListener(_changed);
    _stage.removeListener(_onStageChanged);
    _stage.dispose();
    super.dispose();
  }

  void _changed() {
    _syncClock();
    if (mounted) setState(() {});
  }

  /// The camera moved, or the stage gave up on WebGL: the label anchor is
  /// this view's, so it is re-projected here. The scene and the animating
  /// flag are this view's own writes, and the controller stays quiet on an
  /// unchanged scene, so neither reaches this.
  void _onStageChanged() {
    if (!mounted) return;
    if (_lastCamera == _stage.camera && _lastWebGl == _stage.webGlAvailable) {
      return;
    }
    _lastCamera = _stage.camera;
    _lastWebGl = _stage.webGlAvailable;
    setState(() {});
  }

  /// The no-WebGL sprite for a node, off the catalogs the store holds now.
  String? _spriteFor(McSceneNode node) =>
      mcCatalogSpriteFor(component.store.catalogs, node);

  void _syncClock() {
    final GlossEntityOverlaysDoc? doc = component.store.entityOverlaysDoc;
    final bool hitFlashing =
        _damage > 0 && _clock.elapsedMilliseconds - _hitAtMs < 500;
    final bool active =
        doc != null &&
        (hitFlashing ||
            doc.particleLayers.isNotEmpty ||
            doc.show.toString().contains('time.') ||
            doc.lines.any(
              (GlossEntityOverlayLine line) =>
                  glossTextRequiresFastRefresh(line.text) ||
                  line.show.toString().contains('time.'),
            ));
    if (!active) {
      _animationTimer?.cancel();
      _animationTimer = null;
    } else {
      _animationTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) setState(_syncClock);
      });
    }
  }

  void _strike() {
    final GlossEntityOverlaysDoc? doc = component.store.entityOverlaysDoc;
    if (doc == null) return;
    _hitTimer?.cancel();
    setState(() {
      if (_health <= 0) _health = _maxHealth;
      _damage = math.min(3, _health);
      _health -= _damage;
      _hitAtMs = _clock.elapsedMilliseconds;
    });
    _syncClock();
    _hitTimer = Timer(
      Duration(milliseconds: doc.hitHighlightMs.clamp(0, 10000)),
      () {
        if (mounted) setState(() => _damage = 0);
      },
    );
  }

  void _restore() {
    _hitTimer?.cancel();
    setState(() {
      _health = _maxHealth;
      _damage = 0;
    });
    _syncClock();
  }

  @override
  Widget build(BuildContext context) {
    final GlossEntityOverlaysDoc? doc = component.store.entityOverlaysDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    final EntityOverlaySample sample = EntityOverlaySample(
      name: _name,
      health: _health,
      maxHealth: _maxHealth,
      attack: _attack,
      armor: _armor,
      distance: _distance,
      damage: _damage,
      stackCount: _stackCount,
      react: _react,
      adapt: _adapt,
      insight: _insight,
      adaptExclusive: _exclusive,
      player: _player,
      entityType: _player ? 'PLAYER' : 'ZOMBIE',
    );
    final EntityOverlayPreview preview = resolveEntityOverlayPreview(
      doc,
      sample,
      animations: component.store.workspaceAnimations,
      emoji: component.store.workspaceEmoji,
      nowMs: _clock.elapsedMilliseconds,
    );
    final String rigId = mcRigForEntityType(sample.entityType) ?? 'zombie';
    final bool slim = McAssetLoader.loaded?.manifest.player.slim ?? false;
    final McRig rig = mcRigById(rigId, slim: slim)!;
    final bool isPlayer = rigId == 'player';
    final bool isSheep = rigId == 'sheep';
    final double hurt =
        _damage > 0 && _clock.elapsedMilliseconds - _hitAtMs < 500 ? 1.0 : 0.0;
    final bool animating =
        (_hitTimer != null || _animationTimer != null) &&
        component.store.animationsPlaying;
    if (animating) _poseTimeMs = _clock.elapsedMilliseconds;
    if (!component.gameContext) {
      _stage.homePivot = McVec3(0.5, rig.heightBlocks / 2, 0.5);
    }
    _stage.scene = McScene(<McSceneNode>[
      McRigNode(
        key: 'sample',
        rigId: rigId,
        textureId: isPlayer ? 'player' : rigId,
        transform: McMat4.translation(0.5, 0, 0.5),
        poseTimeMs: _poseTimeMs,
        hurt: hurt,
        capeTextureId: isPlayer ? 'player_cape' : null,
        overlayTextureId: isSheep ? 'sheep_wool' : null,
      ),
    ]);
    _stage.animating = animating;
    final List<Widget> overlay = preview.visible
        ? <Widget>[_labelAnchor(doc, preview, rig)]
        : const <Widget>[];
    final Widget chrome = _chrome(preview);
    return dom.div(classes: 'hui-entity-overlay-stage', <Widget>[
      if (component.gameContext)
        GlossGameScreen(
          anchor: GlossGameAnchor.world,
          label: huiText('Entity overlay sample in game'),
          world: _stage,
          worldOverlay: overlay,
          child: chrome,
        )
      else
        dom.div(classes: 'hui-entity-overlay-sky', <Widget>[
          McStage(
            controller: _stage,
            overlay: overlay,
            label: huiText('Sample entity overlay'),
          ),
          chrome,
        ]),
      if (preview.errors.isNotEmpty)
        dom.div(
          classes: 'hui-entity-overlay-hidden',
          attributes: const <String, String>{'role': 'alert'},
          <Widget>[
            for (final String error in preview.errors)
              dom.p(<Widget>[Text(error)]),
          ],
        ),
      _controls(),
    ]);
  }

  /// The overlay text anchored above the rig, in the stage's CSS-3D layer.
  Widget _labelAnchor(
    GlossEntityOverlaysDoc doc,
    EntityOverlayPreview preview,
    McRig rig,
  ) {
    final McVec3 position = McVec3(
      0.5,
      rig.heightBlocks + doc.verticalOffset.clamp(-2, 8) * 0.25,
      0.5,
    );
    return dom.div(
      classes: 'hui-mc-anchor',
      styles: dom.Styles(
        raw: <String, String>{
          'transform': mcDomAnchorTransform(
            camera: _stage.camera,
            position: position,
            billboard: McBillboardMode.center,
          ),
        },
      ),
      <Widget>[
        dom.div(
          classes: 'hui-entity-overlay-label',
          styles: dom.Styles(
            raw: <String, String>{
              // The anchor places this bottom-centred; only the document scale
              // rides on the element itself.
              'transform-origin': '50% 100%',
              'transform':
                  'scale(${doc.style.scaleX.clamp(0.01, 64)}, ${doc.style.scaleY.clamp(0.01, 64)})',
              'text-align': doc.style.textAlignment,
              'padding':
                  '${doc.box.enabled ? doc.box.padding.clamp(0, 64) * 2 : 0}px',
              'border': doc.box.enabled
                  ? '${doc.box.borderWidth.clamp(0, 16) * 2}px solid ${_argb(doc.box.borderArgb)}'
                  : 'none',
              'background': doc.box.enabled
                  ? _argb(doc.box.backgroundArgb)
                  : 'transparent',
              'background-clip': 'padding-box',
            },
          ),
          <Widget>[
            GlossParticleOverlay(
              layers: doc.particleLayers,
              pixelsPerBlock: 80,
              tick: _clock.elapsedMilliseconds ~/ 50,
              renderedText: preview.particleText,
              textScale: 1,
              scopeBounds: <String, List<GlossParticleRect>>{
                'projection': <GlossParticleRect>[
                  glossParticleTextBounds(preview.particleText.text, 1),
                ],
              },
            ),
            dom.div(
              classes: 'hui-entity-overlay-text',
              styles: dom.Styles(
                raw: <String, String>{
                  'background': _argb(doc.style.backgroundArgb),
                  'opacity': (doc.style.textOpacity.clamp(0, 255) / 255)
                      .toString(),
                  'max-width': '${doc.style.lineWidth.clamp(1, 16384) * 2}px',
                  'text-shadow': doc.style.shadow
                      ? '2px 2px rgba(0,0,0,.65)'
                      : 'none',
                },
              ),
              <Widget>[
                for (final GlossLineRender line in preview.rows)
                  GlossTextLine(render: line),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Non-anchored chrome over the stage: the hidden-state banner and the
  /// sample-entity note. `pointer-events: none` so it never blocks orbit
  /// dragging on the stage beneath it.
  Widget _chrome(EntityOverlayPreview preview) => dom.div(
    classes: 'hui-entity-overlay-scene',
    styles: const dom.Styles(raw: <String, String>{'pointer-events': 'none'}),
    <Widget>[
      if (!preview.visible)
        dom.div(
          classes: 'hui-entity-overlay-hidden',
          attributes: const <String, String>{'role': 'status'},
          <Widget>[Text(huiText(preview.hiddenReason!))],
        ),
      dom.span(classes: 'hui-entity-overlay-sample-note', <Widget>[
        Text(huiText('Sample entity in world')),
        if (!_stage.webGlAvailable) Text(' · ${_noWebGlNote()}'),
      ]),
    ],
  );

  /// Appended to the sample note when the stage fell back to the still.
  String _noWebGlNote() => huiText(
    'No WebGL2 in this browser: the world is a still and models are '
    'sprites',
  );

  Widget _controls() => dom.div(
    classes: 'hui-entity-overlay-controls',
    <Widget>[
      dom.div(classes: 'hui-entity-overlay-control-row', <Widget>[
        dom.strong(<Widget>[Text(huiText('Sample controls'))]),
        Button(
          label: huiText('Strike sample'),
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: _strike,
        ),
        Button(
          label: huiText('Restore health'),
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: _restore,
        ),
      ]),
      dom.div(classes: 'hui-entity-overlay-control-row', <Widget>[
        dom.label(classes: 'hui-entity-overlay-sample-name', <Widget>[
          dom.span(<Widget>[Text(huiText('Sample name'))]),
          TextInput(
            value: _name,
            size: ComponentSize.sm,
            attributes: <String, String>{'aria-label': huiText('Sample name')},
            onInput: (String value) => setState(() => _name = value),
          ),
        ]),
        _number(
          'Sample health',
          _health,
          (double value) => _health = value.clamp(0, _maxHealth),
        ),
        _number('Sample max health', _maxHealth, (double value) {
          _maxHealth = math.max(1, value);
          _health = math.min(_health, _maxHealth);
        }),
        _number(
          'Sample attack',
          _attack,
          (double value) => _attack = math.max(0, value),
        ),
        _number(
          'Sample armor',
          _armor,
          (double value) => _armor = math.max(0, value),
        ),
        _number(
          'Sample distance',
          _distance,
          (double value) => _distance = math.max(0, value),
        ),
      ]),
      dom.div(classes: 'hui-entity-overlay-control-row', <Widget>[
        _toggle('Player sample', _player, () => _player = !_player),
        _toggle('React installed', _react, () => _react = !_react),
        if (_react)
          _number(
            'Sample stack count',
            _stackCount.toDouble(),
            (double value) => _stackCount = math.max(1, value.round()),
          ),
        _toggle('Adapt installed', _adapt, () => _adapt = !_adapt),
        if (_adapt) ...<Widget>[
          _toggle('Insight active', _insight, () => _insight = !_insight),
          _toggle(
            'Adapt exclusive',
            _exclusive,
            () => _exclusive = !_exclusive,
          ),
        ],
      ]),
    ],
  );

  Widget _number(String label, double value, void Function(double) edit) =>
      dom.label(classes: 'hui-entity-overlay-sample-number', <Widget>[
        dom.span(<Widget>[Text(huiText(label))]),
        HuiNumberField(
          value: value,
          decimals: 1,
          step: 1,
          steppers: false,
          onChanged: (double next) => setState(() {
            _damage = 0;
            edit(next);
          }),
        ),
      ]);

  Widget _toggle(String label, bool value, void Function() edit) => Button(
    label: huiText(label),
    variant: ButtonVariant.outline,
    size: ButtonSize.sm,
    attributes: <String, String>{'aria-pressed': value.toString()},
    onPressed: () => setState(edit),
  );
  static String _argb(String value) {
    if (!RegExp(r'^#[a-fA-F0-9]{8}$').hasMatch(value)) return 'transparent';
    return '#${value.substring(3)}${value.substring(1, 3)}';
  }
}
