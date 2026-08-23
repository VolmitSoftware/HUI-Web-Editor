/// The animation player surface: the current frame large, transport controls,
/// a frame scrubber and the frame strip.
///
/// Playing mirrors the server exactly — `AnimationClip.frameAt` over the wall
/// clock, so what this shows at a given millisecond is what every hologram or
/// scoreboard referencing `|animation.<id>|` shows in game. Pause freezes,
/// the scrubber addresses frames directly, and resume rejoins the live
/// timeline. Playback state lives in `logic/gloss_animation_player.dart`
/// under an injectable clock; this file owns only the repaint timer and DOM.
///
/// With `gameContext` the current frame mounts alone into the shared
/// game-screen frame — an animation has no HUD slot of its own, so it is
/// shown in-world at the size a hologram would draw it, with the transport
/// floated over the frame.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../../logic/gloss_animation_player.dart';
import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class AnimationView extends StatefulWidget {
  const AnimationView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Mounts the current frame inside the shared Minecraft game-screen frame
  /// instead of the editor player. False renders exactly the editor surface.
  final bool gameContext;

  @override
  State<AnimationView> createState() => _AnimationViewState();
}

class _AnimationViewState extends State<AnimationView> {
  final GlossAnimationPlayer _player = GlossAnimationPlayer();
  Timer? _ticker;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant AnimationView oldComponent) {
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

  /// Repaints at the clip cadence, floored so a 1 ms clip does not spin a
  /// millisecond timer — frames faster than the screen can show still land
  /// on the right index every repaint because the index is clock-derived.
  void _syncTicker(GlossAnimationDoc doc) {
    final bool wanted =
        _player.playing && _store.animationsPlaying && doc.frames.length > 1;
    if (!wanted) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    final int period = doc.effectiveFrameIntervalMs.clamp(33, 1000);
    if (_ticker != null && _tickerPeriodMs == period) return;
    _ticker?.cancel();
    _tickerPeriodMs = period;
    _ticker = Timer.periodic(Duration(milliseconds: period), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  int _tickerPeriodMs = 0;

  @override
  Widget build(BuildContext context) {
    final GlossAnimationDoc? doc = _store.animationDoc;
    if (doc == null) {
      _ticker?.cancel();
      _ticker = null;
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.world,
          label: huiText('Animation frame in game'),
        );
      }
      return const dom.div(
        classes: 'hui-animation-player is-empty',
        <Widget>[],
      );
    }
    _syncTicker(doc);
    final String id = _store.menuId;
    final int index = _player.frameIndex(doc, id);
    final String frame = _player.frameText(doc, id);

    final Widget currentFrame = dom
        .div(classes: 'hui-animation-frame-large', <Widget>[
          GlossTextLine(
            render: renderGlossAnimationFramePreview(
              frame,
              emoji: _store.workspaceEmoji,
            ),
          ),
        ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.world,
        label: huiText('Animation frame in game'),
        controls: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.iconSm,
            onPressed: () => setState(() => _player.toggle(doc, id)),
            attributes: <String, String>{
              'aria-label': _player.playing
                  ? huiText('Pause')
                  : huiText('Play'),
              'title': _player.playing ? huiText('Pause') : huiText('Play'),
            },
            child: _player.playing
                ? ArcaneIcon.pause(size: IconSize.sm)
                : ArcaneIcon.play(size: IconSize.sm),
          ),
        ],
        child: currentFrame,
      );
    }

    return dom.div(classes: 'hui-animation-player', <Widget>[
      dom.div(classes: 'hui-animation-frame-stage', <Widget>[
        currentFrame,
        dom.div(classes: 'hui-animation-frame-meta', <Widget>[
          Text(
            doc.frames.isEmpty
                ? huiText('No frames')
                : huiText(
                    'Frame {current} of {total} · {interval} ms · '
                    '{mode}{paused}',
                    <String, Object?>{
                      'current': index + 1,
                      'total': doc.frames.length,
                      'interval': doc.effectiveFrameIntervalMs,
                      'mode':
                          doc.normalizedMode ??
                          huiText('{mode} (invalid)', <String, Object?>{
                            'mode': doc.mode,
                          }),
                      'paused': _player.playing ? '' : huiText(' · paused'),
                    },
                  ),
          ),
        ]),
      ]),
      _transport(doc, id, index),
      _strip(doc, id, index),
    ]);
  }

  Widget _transport(GlossAnimationDoc doc, String id, int index) =>
      dom.div(classes: 'hui-animation-transport', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.iconSm,
          onPressed: () => setState(() => _player.step(-1, doc, id)),
          attributes: <String, String>{'aria-label': huiText('Previous frame')},
          child: ArcaneIcon.skipBack(size: IconSize.sm),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.iconSm,
          onPressed: () => setState(() => _player.toggle(doc, id)),
          attributes: <String, String>{
            'aria-label': _player.playing ? huiText('Pause') : huiText('Play'),
          },
          child: _player.playing
              ? ArcaneIcon.pause(size: IconSize.sm)
              : ArcaneIcon.play(size: IconSize.sm),
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.iconSm,
          onPressed: () => setState(() => _player.step(1, doc, id)),
          attributes: <String, String>{'aria-label': huiText('Next frame')},
          child: ArcaneIcon.skipForward(size: IconSize.sm),
        ),
        dom.input(
          classes: 'hui-animation-scrub',
          attributes: <String, String>{
            'type': 'range',
            'min': '0',
            'max': '${doc.frames.isEmpty ? 0 : doc.frames.length - 1}',
            'step': '1',
            'value': '$index',
            'aria-label': huiText('Scrub frames'),
          },
          events: <String, EventCallback>{
            'input': (Object? event) {
              final String? raw = _rangeValue(event);
              final int? next = raw == null ? null : int.tryParse(raw);
              if (next != null) {
                setState(() => _player.scrubTo(next, doc));
              }
            },
          },
        ),
      ]);

  Widget _strip(GlossAnimationDoc doc, String id, int index) => dom.div(
    classes: 'hui-animation-strip',
    <Widget>[
      for (int i = 0; i < doc.frames.length; i++)
        dom.button(
          classes: 'hui-animation-strip-frame${i == index ? ' is-active' : ''}',
          attributes: <String, String>{
            'type': 'button',
            'aria-label': huiText("Show frame {value}", <String, Object?>{
              'value': i + 1,
            }),
          },
          events: <String, EventCallback>{
            'click': (Object? _) => setState(() => _player.scrubTo(i, doc)),
          },
          <Widget>[
            dom.span(classes: 'hui-animation-strip-index', <Widget>[
              Text(huiText("{value}", <String, Object?>{'value': i + 1})),
            ]),
            GlossTextLine(
              render: renderGlossAnimationFramePreview(
                doc.frames[i],
                emoji: _store.workspaceEmoji,
              ),
            ),
          ],
        ),
    ],
  );

  /// The range input's value, off `event.target.value`.
  static String? _rangeValue(Object? event) {
    final JSObject? object = event as JSObject?;
    final JSAny? target = object?.getProperty<JSAny?>('target'.toJS);
    if (target == null || !target.isA<JSObject>()) return null;
    final JSAny? value = (target as JSObject).getProperty<JSAny?>('value'.toJS);
    return value.isA<JSString>() ? (value! as JSString).toDart : null;
  }
}
