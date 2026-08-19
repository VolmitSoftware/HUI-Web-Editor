/// The scoreboard surface: a vanilla-style sidebar mock, right-anchored the
/// way the client draws it.
///
/// The title renders through Gloss's text pipeline, then VolmLib safely caps
/// it at 32 UTF-16 units including colour codes. At most 15 lines reach the
/// client; VolmLib maps every rendered line into
/// its 16-character team prefix plus 16-character suffix, including carried
/// colour codes. The dimmed score column stands in for the vanilla sidebar's
/// row scores.
///
/// Owns a playback clock while any rendered line (or the title) plays an
/// animation and the store's animations toggle is on. Mounted only while the
/// scoreboard view is active.
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';

/// Animation repaint period, matching the hologram stage.
const Duration _tickPeriod = Duration(milliseconds: 100);

class ScoreboardView extends StatefulWidget {
  const ScoreboardView({required this.store, super.key});

  final EditorStore store;

  @override
  State<ScoreboardView> createState() => _ScoreboardViewState();
}

class _ScoreboardViewState extends State<ScoreboardView> {
  Timer? _ticker;
  bool _sceneBackdrop = false;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(covariant ScoreboardView oldComponent) {
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

  bool _isAnimated(GlossScoreboardDoc doc, GlossAnimationResolver animations) {
    if (renderGlossLine(doc.title, animations: animations).isAnimated) {
      return true;
    }
    final int rendered = doc.lines.length > glossBoardMaxLines
        ? glossBoardMaxLines
        : doc.lines.length;
    for (int index = 0; index < rendered; index++) {
      if (renderGlossLine(
        doc.lines[index],
        animations: animations,
      ).isAnimated) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final GlossScoreboardDoc? doc = _store.scoreboardDoc;
    if (doc == null) {
      _syncTicker(false);
      return const dom.div(
        classes: 'hui-scoreboard-stage is-empty',
        <Widget>[],
      );
    }
    final GlossAnimationResolver animations = _store.workspaceAnimations;
    final GlossEmojiResolver emoji = _store.workspaceEmoji;
    _syncTicker(_isAnimated(doc, animations));
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    final int rendered = doc.lines.length > glossBoardMaxLines
        ? glossBoardMaxLines
        : doc.lines.length;
    final int clipped = doc.lines.length - rendered;
    final bool titleTruncated =
        glossTranslatedLength(doc.title, animations, emoji: emoji) >
        glossBoardMaxTitleLength;

    return dom.div(classes: 'hui-scoreboard-stage', <Widget>[
      dom.div(
        classes: 'hui-scoreboard-sky${_sceneBackdrop ? ' is-scene' : ''}',
        <Widget>[
          GlossPreviewZoom(
            label: 'Scoreboard preview',
            alignment: _sceneBackdrop
                ? GlossPreviewAlignment.end
                : GlossPreviewAlignment.center,
            child: dom.div(classes: 'hui-scoreboard-sidebar', <Widget>[
              dom.div(classes: 'hui-scoreboard-title', <Widget>[
                GlossTextLine(
                  render: renderGlossScoreboardTitle(
                    doc.title,
                    animations: animations,
                    emoji: emoji,
                    nowMs: nowMs,
                  ),
                ),
              ]),
              for (int index = 0; index < rendered; index++)
                dom.div(classes: 'hui-scoreboard-row', <Widget>[
                  dom.span(classes: 'hui-scoreboard-row-text', <Widget>[
                    GlossTextLine(
                      render: renderGlossScoreboardLine(
                        doc.lines[index],
                        animations: animations,
                        emoji: emoji,
                        nowMs: nowMs,
                      ),
                    ),
                  ]),
                  if (!doc.hideNumbers)
                    dom.span(classes: 'hui-scoreboard-score', <Widget>[
                      Text('${glossBoardScoreForRow(index)}'),
                    ]),
                ]),
            ]),
          ),
          dom.div(classes: 'hui-scoreboard-view-controls', <Widget>[
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: () => setState(() => _sceneBackdrop = !_sceneBackdrop),
              icon: ArcaneIcon.image(size: IconSize.sm),
              label: _sceneBackdrop ? 'Centered stage' : 'Right-side scene',
            ),
          ]),
        ],
      ),
      dom.div(classes: 'hui-scoreboard-readout', <Widget>[
        Text(_readout(doc, clipped, titleTruncated)),
      ]),
    ]);
  }

  String _readout(GlossScoreboardDoc doc, int clipped, bool titleTruncated) {
    final List<String> parts = <String>[
      doc.primary ? 'primary' : 'not primary',
      doc.hideNumbers
          ? 'score numbers hidden on supported runtimes'
          : 'score numbers visible',
      doc.permissionGated
          ? 'needs $glossBoardPermissionNodePrefix${doc.effectivePermission}'
          : 'everyone',
      if (doc.effectiveGroups.isNotEmpty)
        'groups: ${doc.effectiveGroups.join(', ')}',
      if (clipped > 0)
        '$clipped line${clipped == 1 ? '' : 's'} past the 15-line render cap',
      if (titleTruncated) 'title exceeds the 32-unit in-game cap',
    ];
    return parts.join(' · ');
  }
}
