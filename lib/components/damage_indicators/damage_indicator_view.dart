library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/damage_indicator_preview.dart';
import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/hui_number_field.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';
import '../scoreboard/scoreboard_selection.dart';

const Duration _tickPeriod = Duration(milliseconds: 50);
const double _pixelsPerBlock = 72;

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

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
    _workspaceAnimationsPlaying = _store.animationsPlaying;
    _store.addListener(_onStoreChanged);
  }

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
    });
  }

  void _selectKind(DamageIndicatorPreviewKind kind) {
    _kind = kind;
    if (kind == DamageIndicatorPreviewKind.healing) _critical = false;
    _replay();
  }

  void _toggleCritical() {
    setState(() {
      _critical = !_critical;
      _heldMs = 0;
      _clockOffsetMs = DateTime.now().millisecondsSinceEpoch;
      _playing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final GlossDamageIndicatorsDoc? doc = _store.damageIndicatorsDoc;
    if (doc == null) {
      _ticker?.cancel();
      _ticker = null;
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
    final Widget scene = presentation == null || !audience.matches
        ? _conditionFalseScene()
        : _scene(frame, formatted, cycle.elapsedMs);
    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: huiText('Damage indicators in game'),
        controls: <Widget>[
          _playPauseButton(),
          _replayButton(),
          if (_kind == DamageIndicatorPreviewKind.damage) _criticalButton(),
        ],
        child: scene,
      );
    }
    return dom.div(classes: 'hui-damage-indicator-stage', <Widget>[
      dom.div(classes: 'hui-damage-indicator-sky', <Widget>[scene]),
      _controls(doc, cycle),
    ]);
  }

  Widget _scene(
    DamageIndicatorPreviewFrame frame,
    String formatted,
    int elapsed,
  ) => dom.div(classes: 'hui-damage-indicator-scene', <Widget>[
    const dom.div(classes: 'hui-damage-indicator-horizon', <Widget>[]),
    const dom.div(classes: 'hui-damage-indicator-ground', <Widget>[]),
    const dom.div(classes: 'hui-damage-indicator-entity', <Widget>[
      dom.div(classes: 'hui-damage-indicator-entity-shadow', <Widget>[]),
      dom.div(classes: 'hui-damage-indicator-entity-head', <Widget>[]),
      dom.div(classes: 'hui-damage-indicator-entity-body', <Widget>[]),
      dom.div(classes: 'hui-damage-indicator-entity-arms', <Widget>[]),
    ]),
    if (frame.visible)
      dom.div(
        classes: 'hui-damage-indicator-number',
        styles: dom.Styles(
          raw: <String, String>{
            '--hui-indicator-x':
                '${(frame.x * _pixelsPerBlock).toStringAsFixed(2)}px',
            '--hui-indicator-y':
                '${(frame.y * _pixelsPerBlock).toStringAsFixed(2)}px',
            '--hui-indicator-z':
                '${(frame.z * _pixelsPerBlock).toStringAsFixed(2)}px',
            '--hui-indicator-scale': frame.scale.toStringAsFixed(4),
            '--hui-indicator-roll':
                '${frame.rollDegrees.toStringAsFixed(2)}deg',
            'opacity': frame.opacity.toStringAsFixed(4),
          },
        ),
        <Widget>[
          GlossTextLine(
            render: renderGlossLine(
              formatted,
              animations: _store.workspaceAnimations,
              emoji: _store.workspaceEmoji,
              nowMs: elapsed,
            ),
          ),
        ],
      ),
    dom.div(classes: 'hui-damage-indicator-origin', <Widget>[
      dom.span(<Widget>[Text(huiText('Entity origin'))]),
    ]),
  ]);

  Widget _conditionFalseScene() =>
      dom.div(classes: 'hui-damage-indicator-empty-state', <Widget>[
        dom.span(<Widget>[Text(huiText('condition false'))]),
      ]);

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
      child: ArcaneIcon.shuffle(size: IconSize.sm),
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
    ]),
  ]);

  Widget _kindButton(DamageIndicatorPreviewKind kind, String label) => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.sm,
    onPressed: () => _selectKind(kind),
    attributes: <String, String>{
      'aria-pressed': (_kind == kind).toString(),
      'title': label,
    },
    child: Text(label),
  );

  Widget _playPauseButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _togglePlaying,
    attributes: <String, String>{
      'aria-label': _playing ? huiText('Pause') : huiText('Play'),
      'title': _playing ? huiText('Pause') : huiText('Play'),
    },
    child: _playing
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
    child: ArcaneIcon.refreshCcw(size: IconSize.sm),
  );

  Widget _criticalButton() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.sm,
    onPressed: _toggleCritical,
    attributes: <String, String>{
      'aria-pressed': _critical.toString(),
      'title': huiText('Critical hit'),
    },
    child: Text(huiText('Critical hit')),
  );
}
