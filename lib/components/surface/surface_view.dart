/// The surface stage: the client's HUD with this document's line drawn where
/// the client draws it.
///
/// What the mock shows is the RESOLVED presentation — the highest-priority
/// variant whose condition holds for the sampled viewer, put through
/// `Presentation.forKind`. That is the only honest thing to draw: the server
/// never sends the authored record, it sends what survives the kind filter
/// with its defaults filled in, so a bossbar carrying `text` shows no text
/// here either.
///
/// Fidelity notes: the action bar sits above the hotbar in the lanes the
/// document claims, the boss bar carries its colour and notch style, and the
/// title card shows both lines at once rather than playing the fade timing —
/// the timing is reported instead, because a browser cannot show a client's
/// title queue. When `select.when` is false for the sampled viewer nothing
/// draws and the reason is named, the same way the connection-message stage
/// explains its silence.
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/surface_selection.dart';
import '../../logic/surface_validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Animation repaint period, matching the scoreboard stage.
const Duration _tickPeriod = Duration(milliseconds: 50);

/// The nine hotbar cells the action bar sits above.
const int _hotbarSlots = 9;

class SurfaceView extends StatefulWidget {
  const SurfaceView({required this.store, this.gameContext = false, super.key});

  final EditorStore store;

  /// Mounts the HUD line inside the shared Minecraft game-screen frame, which
  /// draws the real hotbar, instead of the editor stage's mock one.
  final bool gameContext;

  @override
  State<SurfaceView> createState() => _SurfaceViewState();
}

class _SurfaceViewState extends State<SurfaceView> {
  Timer? _ticker;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
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

  @override
  Widget build(BuildContext context) {
    final GlossSurfaceDoc? doc = _store.surfaceDoc;
    if (doc == null) {
      _syncTicker(false);
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.hud,
          label: huiText('Surface in game'),
        );
      }
      return const dom.div(classes: 'hui-surface-stage is-empty', <Widget>[]);
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final GlossSurfaceSilence? silence = glossSurfaceSilence(doc, nowMs: nowMs);
    final GlossSurfacePresentation resolved =
        glossResolveEffectiveSurfacePresentation(doc);
    final String? variantId = glossResolveSurfaceVariantId(doc);
    _syncTicker(
      silence == null &&
          <String>[
            resolved.text ?? '',
            resolved.title ?? '',
            resolved.subtitle ?? '',
          ].any(
            (String line) => renderGlossLine(
              line,
              animations: _store.workspaceAnimations,
            ).isAnimated,
          ),
    );

    final Widget hud = dom.div(
      classes:
          'hui-surface-hud is-${doc.resolvedSurface}'
          '${component.gameContext ? ' is-game' : ''}',
      <Widget>[
        if (silence != null) _silent(silence),
        if (silence == null && doc.resolvedSurface == glossSurfaceKindBossbar)
          _bossbar(resolved, nowMs),
        if (silence == null && doc.resolvedSurface == glossSurfaceKindTitle)
          _title(resolved, nowMs),
        if (silence == null &&
            doc.resolvedSurface == glossSurfaceKindActionbar)
          _actionbar(resolved, nowMs),
        if (!component.gameContext) _hotbar(),
      ],
    );

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.hud,
        label: huiText('Surface in game'),
        controls: <Widget>[_playPause()],
        child: hud,
      );
    }

    return dom.div(classes: 'hui-surface-stage', <Widget>[
      GlossPreviewZoom(
        label: huiText('Surface preview'),
        child: dom.div(classes: 'hui-surface-screen', <Widget>[
          hud,
          dom.div(classes: 'hui-surface-controls', <Widget>[
            dom.span(classes: 'hui-surface-viewer', <Widget>[
              Text(
                huiText('Seen by {name}', <String, Object?>{
                  'name': glossSurfaceSampleViewerName,
                }),
              ),
            ]),
            _playPause(),
          ]),
        ]),
      ),
      dom.div(classes: 'hui-surface-readout', <Widget>[
        Text(_readout(doc, resolved, variantId, silence)),
      ]),
    ]);
  }

  Widget _actionbar(GlossSurfacePresentation resolved, int nowMs) {
    final List<String> slots = resolved.slots ?? const <String>['center'];
    return dom.div(classes: 'hui-surface-actionbar', <Widget>[
      for (final String slot in glossSurfaceSlots)
        dom.div(classes: 'hui-surface-lane is-$slot', <Widget>[
          if (slots.contains(slot)) _line(resolved.text ?? '', nowMs),
        ]),
    ]);
  }

  Widget _bossbar(GlossSurfacePresentation resolved, int nowMs) {
    final double progress = glossSurfaceProgressValue(resolved.progress);
    final int segments = glossSurfaceStyleSegments(resolved.style);
    return dom.div(classes: 'hui-surface-bossbar', <Widget>[
      dom.div(classes: 'hui-surface-bossbar-title', <Widget>[
        _line(resolved.title ?? '', nowMs),
      ]),
      dom.div(
        classes: 'hui-surface-bossbar-track is-${resolved.color ?? 'white'}',
        <Widget>[
          dom.div(
            classes: 'hui-surface-bossbar-fill',
            styles: dom.Styles(
              raw: <String, String>{
                'width': '${(progress * 100).toStringAsFixed(1)}%',
              },
            ),
            const <Widget>[],
          ),
          if (segments > 1)
            dom.div(classes: 'hui-surface-bossbar-notches', <Widget>[
              for (int index = 1; index < segments; index++)
                dom.span(
                  classes: 'hui-surface-bossbar-notch',
                  styles: dom.Styles(
                    raw: <String, String>{
                      'left': '${(index * 100 / segments).toStringAsFixed(3)}%',
                    },
                  ),
                  const <Widget>[],
                ),
            ]),
        ],
      ),
    ]);
  }

  Widget _title(GlossSurfacePresentation resolved, int nowMs) =>
      dom.div(classes: 'hui-surface-title', <Widget>[
        dom.div(classes: 'hui-surface-title-line', <Widget>[
          _line(resolved.title ?? '', nowMs),
        ]),
        if ((resolved.subtitle ?? '').isNotEmpty)
          dom.div(classes: 'hui-surface-subtitle-line', <Widget>[
            _line(resolved.subtitle!, nowMs),
          ]),
      ]);

  Widget _line(String raw, int nowMs) => GlossTextLine(
    render: renderGlossLine(
      raw,
      animations: _store.workspaceAnimations,
      emoji: _store.workspaceEmoji,
      nowMs: nowMs,
      expressionSamples: glossSurfaceSamples,
    ),
  );

  Widget _hotbar() => dom.div(classes: 'hui-surface-hotbar', <Widget>[
    for (int index = 0; index < _hotbarSlots; index++)
      dom.span(
        classes:
            'hui-surface-hotbar-slot${index == 0 ? ' is-selected' : ''}',
        const <Widget>[],
      ),
  ]);

  Widget _silent(GlossSurfaceSilence silence) =>
      dom.div(classes: 'hui-surface-silent', <Widget>[
        Text(_silentReason(silence)),
      ]);

  String _silentReason(GlossSurfaceSilence silence) => switch (silence) {
    GlossSurfaceSilence.documentHidden => huiText(
      'The document show condition is false right now, so nothing is drawn.',
    ),
    GlossSurfaceSilence.notSelected => huiText(
      'The selection condition is false for this viewer, so nothing is drawn.',
    ),
    GlossSurfaceSilence.brokenCondition => huiText(
      'The selection condition does not compile, and a broken condition '
      'fails closed, so nothing is drawn.',
    ),
  };

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

  String _readout(
    GlossSurfaceDoc doc,
    GlossSurfacePresentation resolved,
    String? variantId,
    GlossSurfaceSilence? silence,
  ) {
    final List<String> parts = <String>[
      doc.resolvedSurface,
      variantId == null
          ? huiText('default presentation')
          : huiText('variant: {id}', <String, Object?>{'id': variantId}),
      huiText('lane {name}', <String, Object?>{
        'name': resolved.priority ?? glossSurfaceDefaultPriority,
      }),
      huiText('slots {names}', <String, Object?>{
        'names': (resolved.slots ?? const <String>['center']).join(', '),
      }),
      if (resolved.ttlTicks != null)
        huiText('lives {ticks} ticks', <String, Object?>{
          'ticks': resolved.ttlTicks,
        }),
      if (doc.resolvedSurface == glossSurfaceKindTitle)
        huiText(
          'fade {fadeIn}/{stay}/{fadeOut} ticks, trigger {trigger}',
          <String, Object?>{
            'fadeIn': resolved.fadeInTicks,
            'stay': resolved.stayTicks,
            'fadeOut': resolved.fadeOutTicks,
            'trigger': resolved.trigger,
          },
        ),
      if (silence != null) _silentReason(silence),
    ];
    return parts.join(' · ');
  }
}
