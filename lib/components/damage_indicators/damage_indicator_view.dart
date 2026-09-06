library;

import 'dart:async';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/damage_indicator_preview.dart';
import '../../logic/gloss_particle_text.dart';
import '../../logic/gloss_show.dart';
import '../../logic/gloss_text.dart';
import '../../mc/rigs/mc_rig.dart';
import '../../mc/rigs/mc_rigs.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_scene.dart';
import '../../model/model.dart';
import '../../preview/projection.dart';
import '../../state/editor_store.dart';
import '../common/hui_number_field.dart';
import '../gloss/gloss_display_text.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../gloss/gloss_text_line.dart';
import '../mc/mc_asset_loader.dart';
import '../mc/mc_dom_layer.dart';
import '../mc/mc_stage.dart';
import '../mc/mc_stage_controller.dart';
import '../scoreboard/scoreboard_selection.dart';

const Duration _tickPeriod = Duration(milliseconds: 50);

/// Hit reaction windows, milliseconds into the cycle: the red overlay on the
/// rig, then the crit stars around it.
const int _hurtMs = 500;
const int _critMs = 200;

class DamageIndicatorView extends StatefulWidget {
  const DamageIndicatorView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;
  final bool gameContext;

  @override
  State<DamageIndicatorView> createState() => _DamageIndicatorViewState();
}

class _DamageIndicatorViewState extends State<DamageIndicatorView> {
  Timer? _ticker;
  bool _playing = true;
  late bool _workspaceAnimationsPlaying;
  int _clockOffsetMs = 0;
  int _heldMs = 0;
  int _seed = 1;
  double _amount = 7;
  bool _critical = false;
  DamageIndicatorPreviewKind _kind = DamageIndicatorPreviewKind.damage;

  /// Which rig takes the hit.
  String _target = 'zombie';

  /// When the hit landed, on the cycle clock. Every replay restarts that
  /// clock, so the flash repeats with the loop.
  int _hitAtMs = 0;

  /// The editor stage frames the target's midriff and orbits; the game frame
  /// stands at the client's eye over the target and does not.
  late final McStageController _stage = McStageController(
    kind: component.gameContext ? McStageKind.frame : McStageKind.indicators,
    homePivot: McVec3(0.5, component.gameContext ? mcCameraEyeHeight : 0.9, 0.5),
    freeCamera: !component.gameContext,
  );
  late McCamera _lastCamera = _stage.camera;
  late bool _lastWebGl = _stage.webGlAvailable;

  EditorStore get _store => component.store;

  McRig get _rig => mcRigById(
    _target,
    slim: McAssetLoader.loaded?.manifest.player.slim ?? false,
  )!;

  @override
  void initState() {
    super.initState();
    _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
    _workspaceAnimationsPlaying = _store.animationsPlaying;
    _store.addListener(_onStoreChanged);
    _stage.addListener(_onStageChanged);
    _stage.spriteFor = _spriteFor;
  }

  /// The no-WebGL sprite for a node, off the catalogs the store holds now.
  String? _spriteFor(McSceneNode node) => mcCatalogSpriteFor(_store.catalogs, node);

  @override
  void didUpdateComponent(covariant DamageIndicatorView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
      _workspaceAnimationsPlaying = _store.animationsPlaying;
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _stage.removeListener(_onStageChanged);
    _stage.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    final bool animationsPlaying = _store.animationsPlaying;
    if (animationsPlaying != _workspaceAnimationsPlaying) {
      if (!animationsPlaying && _playing) {
        _heldMs = _elapsedMs();
      }
      _workspaceAnimationsPlaying = animationsPlaying;
      if (animationsPlaying && _playing) {
        _clockOffsetMs = DateTime.now().millisecondsSinceEpoch - _heldMs;
      }
    }
    if (mounted) setState(() {});
  }

  /// Only a camera move or a lost WebGL context needs a rebuild here: the
  /// anchor transforms and the readout are built in [build], every other
  /// notification is this view's own scene write.
  void _onStageChanged() {
    if (_lastCamera == _stage.camera && _lastWebGl == _stage.webGlAvailable) {
      return;
    }
    _lastCamera = _stage.camera;
    _lastWebGl = _stage.webGlAvailable;
    if (mounted) setState(() {});
  }

  int _elapsedMs() => _playing && _workspaceAnimationsPlaying
      ? DateTime.now().millisecondsSinceEpoch - _clockOffsetMs
      : _heldMs;

  void _syncTicker() {
    if (!_playing || !_workspaceAnimationsPlaying) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(_tickPeriod, (Timer _) {
      if (!mounted) return;
      if (_store.damageIndicatorsDoc == null) {
        _ticker?.cancel();
        _ticker = null;
        return;
      }
      setState(() {});
    });
  }

  void _togglePlaying() {
    setState(() {
      if (_playing) {
        _heldMs = _elapsedMs();
        _playing = false;
      } else {
        _clockOffsetMs = DateTime.now().millisecondsSinceEpoch - _heldMs;
        _playing = true;
      }
    });
  }

  void _replay({bool nextSeed = false}) {
    setState(() {
      if (nextSeed) _seed++;
      _heldMs = 0;
      _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
      _playing = true;
      _hitAtMs = _elapsedMs();
    });
  }

  void _selectKind(DamageIndicatorPreviewKind kind) {
    _kind = kind;
    if (kind == DamageIndicatorPreviewKind.healing) _critical = false;
    _replay();
  }

  void _selectTarget(String id) {
    _target = id;
    _replay();
  }

  void _toggleCritical() {
    _critical = !_critical;
    _replay();
  }

  @override
  Widget build(BuildContext context) {
    final GlossDamageIndicatorsDoc? doc = _store.damageIndicatorsDoc;
    if (doc == null) {
      _ticker?.cancel();
      _ticker = null;
      _stage.animating = false;
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.world,
          label: huiText('Damage indicators in game'),
        );
      }
      return const dom.div(
        classes: 'hui-damage-indicator-stage is-empty',
        <Widget>[],
      );
    }

    _syncTicker();
    final GlossDamageIndicatorStyle style =
        _kind == DamageIndicatorPreviewKind.damage ? doc.damage : doc.healing;
    final GlossConditionContext styleContext =
        buildDamageIndicatorPreviewConditionContext(
          kind: _kind,
          amount: _amount,
          critical: _critical,
        );
    final GlossConditionContext audienceContext =
        buildDamageIndicatorPreviewConditionContext(
          kind: _kind,
          amount: _amount,
          critical: _critical,
          includeViewer: true,
        );
    final GlossDamageIndicatorPresentation? presentation =
        resolveDamageIndicatorPresentation(style, styleContext);
    final ({bool matches, String? error}) audience = glossConditionMatches(
      doc.audience.when,
      audienceContext,
    );
    final DamageIndicatorPreviewCycle cycle =
        resolveDamageIndicatorPreviewCycle(
          lifetimeMs: doc.limits.lifetimeMs,
          totalElapsedMs: _elapsedMs(),
          baseSeed: _seed,
        );
    final DamageIndicatorPreviewFrame frame = resolveDamageIndicatorFrame(
      presentation: presentation ?? style.presentation,
      lifetimeMs: doc.limits.lifetimeMs,
      elapsedMs: cycle.elapsedMs,
      seed: cycle.seed,
    );
    final String formatted = renderDamageIndicatorText(
      presentation ?? style.presentation,
      _amount,
      doc.limits.decimals,
    );
    final bool shown =
        presentation != null &&
        audience.matches &&
        glossShowMatches(
          doc.extras['show'],
          scope: audienceContext,
          nowMs: cycle.elapsedMs,
        );

    final int sinceHit = cycle.elapsedMs - _hitAtMs;
    final double hurt = sinceHit >= 0 && sinceHit < _hurtMs
        ? 1 - sinceHit / _hurtMs
        : 0;
    final double originY = _rig.heightBlocks / 2;
    if (!component.gameContext) _stage.homePivot = McVec3(0.5, originY, 0.5);
    _stage.scene = McScene(<McSceneNode>[
      McRigNode(
        key: 'target',
        rigId: _target,
        textureId: _target == 'player' ? 'player' : _target,
        // Rigs are meshed facing +Z, toward the stage camera.
        transform: McMat4.translation(0.5, 0, 0.5),
        poseTimeMs: cycle.elapsedMs,
        hurt: hurt,
        capeTextureId: _target == 'player' ? 'player_cape' : null,
        overlayTextureId: _target == 'sheep' ? 'sheep_wool' : null,
      ),
      if (_critical && sinceHit >= 0 && sinceHit < _critMs)
        for (int i = 0; i < 6; i++)
          McParticleNode(
            key: 'crit-$i',
            textureId: 'critical_hit',
            position: McVec3(
              0.5 + 0.6 * math.cos(i * 1.047 + sinceHit / 80),
              _rig.heightBlocks * 0.6 + 0.3 * math.sin(i * 1.3 + sinceHit / 60),
              0.5 + 0.6 * math.sin(i * 1.047 + sinceHit / 80),
            ),
            sizeBlocks: 0.25,
            alpha: 1 - sinceHit / _critMs,
          ),
    ]);
    _stage.animating = _playing && _workspaceAnimationsPlaying;

    final List<Widget> overlay = shown
        ? _overlay(frame, formatted, cycle.elapsedMs, presentation, originY)
        : const <Widget>[];
    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: huiText('Damage indicators in game'),
        controls: <Widget>[
          _playPauseButton(),
          _replayButton(),
          if (_kind == DamageIndicatorPreviewKind.damage) _criticalButton(),
        ],
        world: _stage,
        worldOverlay: overlay,
        child: shown ? const dom.div(<Widget>[]) : _conditionFalseScene(),
      );
    }
    return dom.div(classes: 'hui-damage-indicator-stage', <Widget>[
      dom.div(classes: 'hui-damage-indicator-sky', <Widget>[
        McStage(
          controller: _stage,
          overlay: overlay,
          label: huiText('Damage indicators in game'),
        ),
        if (!shown) _conditionFalseScene(),
      ]),
      _controls(doc, cycle),
    ]);
  }

  /// The stage's CSS-3D layer: the origin marker at the entity origin and the
  /// number at the trajectory's world position, both anchored off the camera.
  List<Widget> _overlay(
    DamageIndicatorPreviewFrame frame,
    String formatted,
    int elapsed,
    GlossDamageIndicatorPresentation presentation,
    double originY,
  ) => <Widget>[
    _anchor(
      position: McVec3(0.5, originY, 0.5),
      child: dom.div(
        classes: 'hui-damage-indicator-origin',
        styles: const dom.Styles(
          raw: <String, String>{
            'left': '0',
            'bottom': 'auto',
            'transform': 'translate(-50%, -50%) rotate(45deg)',
          },
        ),
        <Widget>[
          dom.span(<Widget>[Text(huiText('Entity origin'))]),
        ],
      ),
    ),
    if (frame.visible)
      _anchor(
        position: McVec3(0.5 + frame.x, originY + frame.y, 0.5 + frame.z),
        billboard: McBillboardMode.parse(presentation.style.billboard),
        child: dom.div(
          classes: 'hui-damage-indicator-number',
          styles: dom.Styles(
            raw: <String, String>{
              'left': '0',
              'bottom': 'auto',
              'transform':
                  'translate(0, 0) '
                  'rotate(${frame.rollDegrees.toStringAsFixed(2)}deg) '
                  'scale3d('
                  '${(frame.scale * presentation.style.scaleX).toStringAsFixed(4)},'
                  '${(frame.scale * presentation.style.scaleY).toStringAsFixed(4)},'
                  '${(frame.scale * presentation.style.scaleZ).toStringAsFixed(4)})',
              'opacity': frame.opacity.toStringAsFixed(4),
            },
          ),
          <Widget>[
            GlossParticleOverlay(
              layers: presentation.particleLayers,
              pixelsPerBlock: huiPreviewPxPerBlock,
              tick: elapsed ~/ 50,
              renderedText: _particleText(formatted, elapsed),
            ),
            GlossDisplayText(
              style: presentation.style,
              box: presentation.box,
              child: GlossTextLine(
                render: renderGlossLine(
                  formatted,
                  richText: true,
                  animations: _store.workspaceAnimations,
                  emoji: _store.workspaceEmoji,
                  nowMs: elapsed,
                ),
              ),
            ),
          ],
        ),
      ),
  ];

  Widget _anchor({
    required McVec3 position,
    required Widget child,
    McBillboardMode billboard = McBillboardMode.center,
  }) => dom.div(
    classes: 'hui-mc-anchor',
    styles: dom.Styles(
      raw: <String, String>{
        'transform': mcDomAnchorTransform(
          camera: _stage.camera,
          position: position,
          billboard: billboard,
        ),
      },
    ),
    <Widget>[child],
  );

  GlossParticleTextRendered _particleText(String formatted, int elapsed) {
    final GlossLineRender render = renderGlossLine(
      formatted,
      richText: true,
      animations: _store.workspaceAnimations,
      emoji: _store.workspaceEmoji,
      nowMs: elapsed,
    );
    return GlossParticleTextRendered(
      text: render.renderedText,
      spans: render.particleSpans,
    );
  }

  /// Drawn over the stage, so the rig stays visible while the condition hides
  /// the indicator.
  Widget _conditionFalseScene() => dom.div(
    classes: 'hui-damage-indicator-empty-state',
    styles: const dom.Styles(
      raw: <String, String>{
        'position': 'absolute',
        'inset': '0',
        'pointer-events': 'none',
      },
    ),
    <Widget>[
      dom.span(<Widget>[Text(huiText('condition false'))]),
    ],
  );

  Widget _controls(
    GlossDamageIndicatorsDoc doc,
    DamageIndicatorPreviewCycle cycle,
  ) => dom.div(classes: 'hui-damage-indicator-controls', <Widget>[
    dom.div(
      classes: 'hui-damage-indicator-kind',
      attributes: <String, String>{
        'role': 'group',
        'aria-label': huiText('Indicator type'),
      },
      <Widget>[
        _kindButton(DamageIndicatorPreviewKind.damage, huiText('Damage')),
        _kindButton(DamageIndicatorPreviewKind.healing, huiText('Healing')),
      ],
    ),
    dom.div(
      classes: 'hui-damage-indicator-kind',
      attributes: <String, String>{
        'role': 'group',
        'aria-label': huiText('Target'),
      },
      <Widget>[
        for (final String id in mcRiggedEntityTypes)
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () => _selectTarget(id),
            attributes: <String, String>{
              'aria-pressed': (_target == id).toString(),
              'title': _targetLabel(id),
            },
            label: _targetLabel(id),
          ),
      ],
    ),
    _playPauseButton(),
    _replayButton(),
    if (_kind == DamageIndicatorPreviewKind.damage) _criticalButton(),
    Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.iconSm,
      onPressed: () => _replay(nextSeed: true),
      attributes: <String, String>{
        'aria-label': huiText('Next trajectory'),
        'title': huiText('Next trajectory'),
      },
      icon: ArcaneIcon.shuffle(size: IconSize.sm),
    ),
    Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.sm,
      onPressed: _stage.resetCamera,
      attributes: <String, String>{'title': huiText('Reset view')},
      label: huiText('Reset view'),
    ),
    dom.label(classes: 'hui-damage-indicator-amount', <Widget>[
      dom.span(<Widget>[Text(huiText('Sample amount'))]),
      dom.div(classes: 'hui-damage-indicator-amount-field', <Widget>[
        HuiNumberField(
          value: _amount,
          step: 0.25,
          decimals: 2,
          steppers: false,
          fullWidth: false,
          onChanged: (double value) {
            _amount = value;
            _replay();
          },
        ),
      ]),
    ]),
    dom.span(classes: 'hui-damage-indicator-readout', <Widget>[
      Text(
        huiText(
          '{elapsed} / {lifetime} ms · seed {seed} · {rate}/s global cap',
          <String, Object?>{
            'elapsed': cycle.elapsedMs,
            'lifetime': doc.limits.lifetimeMs,
            'seed': cycle.seed,
            'rate': doc.limits.maxPerSecond,
          },
        ),
      ),
      if (!_stage.webGlAvailable) Text(' · ${_noWebGlNote()}'),
    ]),
  ]);

  /// Appended to the readout when the stage fell back to the still.
  String _noWebGlNote() => huiText(
    'No WebGL2 in this browser: the world is a still and models are '
    'sprites',
  );

  String _targetLabel(String id) => switch (id) {
    'player' => huiText('Player'),
    'zombie' => huiText('Zombie'),
    'skeleton' => huiText('Skeleton'),
    'creeper' => huiText('Creeper'),
    'pig' => huiText('Pig'),
    'cow' => huiText('Cow'),
    _ => huiText('Sheep'),
  };

  Widget _kindButton(DamageIndicatorPreviewKind kind, String label) => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.sm,
    onPressed: () => _selectKind(kind),
    attributes: <String, String>{
      'aria-pressed': (_kind == kind).toString(),
      'title': label,
    },
    label: label,
  );

  Widget _playPauseButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _togglePlaying,
    attributes: <String, String>{
      'aria-label': _playing ? huiText('Pause') : huiText('Play'),
      'title': _playing ? huiText('Pause') : huiText('Play'),
    },
    icon: _playing
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  Widget _replayButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _replay,
    attributes: <String, String>{
      'aria-label': huiText('Replay'),
      'title': huiText('Replay'),
    },
    icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
  );

  Widget _criticalButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.sm,
    onPressed: _toggleCritical,
    attributes: <String, String>{
      'aria-pressed': _critical.toString(),
      'title': huiText('Critical hit'),
    },
    label: huiText('Critical hit'),
  );
}
