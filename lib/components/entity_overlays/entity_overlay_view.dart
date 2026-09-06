library;

import 'dart:async';
import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/entity_overlay_preview.dart';
import '../../logic/gloss_text.dart';
import '../../logic/gloss_particle_preview.dart';
import '../gloss/gloss_particle_overlay.dart';
import '../../model/gloss_entity_overlays.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';

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

  @override
  void initState() {
    super.initState();
    component.store.addListener(_changed);
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
    super.dispose();
  }

  void _changed() {
    _syncClock();
    if (mounted) setState(() {});
  }

  void _syncClock() {
    final GlossEntityOverlaysDoc? doc = component.store.entityOverlaysDoc;
    final bool active =
        doc != null &&
        (doc.particleLayers.isNotEmpty ||
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
        if (mounted) setState(() {});
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
    });
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
    final Widget scene = _scene(doc, preview);
    return dom.div(classes: 'hui-entity-overlay-stage', <Widget>[
      if (component.gameContext)
        GlossGameScreen(
          anchor: GlossGameAnchor.world,
          label: huiText('Entity overlay sample in game'),
          child: scene,
        )
      else
        dom.div(classes: 'hui-entity-overlay-sky', <Widget>[scene]),
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

  Widget _scene(
    GlossEntityOverlaysDoc doc,
    EntityOverlayPreview preview,
  ) => dom.div(
    classes: 'hui-entity-overlay-scene',
    attributes: <String, String>{
      'aria-label': huiText('Sample entity overlay'),
    },
    <Widget>[
      const dom.div(classes: 'hui-damage-indicator-horizon', <Widget>[]),
      const dom.div(classes: 'hui-damage-indicator-ground', <Widget>[]),
      const dom.div(classes: 'hui-damage-indicator-entity', <Widget>[
        dom.div(classes: 'hui-damage-indicator-entity-shadow', <Widget>[]),
        dom.div(classes: 'hui-damage-indicator-entity-head', <Widget>[]),
        dom.div(classes: 'hui-damage-indicator-entity-body', <Widget>[]),
        dom.div(classes: 'hui-damage-indicator-entity-arms', <Widget>[]),
      ]),
      if (preview.visible)
        dom.div(
          classes: 'hui-entity-overlay-label',
          styles: dom.Styles(
            raw: <String, String>{
              'transform':
                  'translate(-50%, ${-doc.verticalOffset.clamp(-2, 8) * 36}px) scale(${doc.style.scaleX.clamp(0.01, 64)}, ${doc.style.scaleY.clamp(0.01, 64)})',
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
        )
      else
        dom.div(
          classes: 'hui-entity-overlay-hidden',
          attributes: const <String, String>{'role': 'status'},
          <Widget>[Text(huiText(preview.hiddenReason!))],
        ),
      dom.span(classes: 'hui-entity-overlay-sample-note', <Widget>[
        Text(huiText('Sample entity in world')),
      ]),
    ],
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
