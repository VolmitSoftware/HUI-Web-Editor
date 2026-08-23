/// The scoreboard surface: a vanilla-style sidebar mock, right-anchored the
/// way the client draws it.
///
/// The title renders through Gloss's text pipeline, then VolmLib safely caps
/// it at 32 UTF-16 units including colour codes. An empty title is not blank
/// in game — `GlossBoardMeta.fromDoc` falls back to the board id — so the
/// preview shows the id too. At most 15 lines reach the client; VolmLib maps
/// every rendered line into its 16-character team prefix plus 16-character
/// suffix, including carried colour codes. The dimmed score column stands in
/// for the vanilla sidebar's row scores.
///
/// With `gameContext` the sidebar mounts into the shared game-screen frame at
/// the right edge, where the client actually draws it; without it the surface
/// keeps its editor stage, readout and the board-selection simulator.
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
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import 'scoreboard_selection_simulator.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Animation repaint period, matching the hologram stage.
const Duration _tickPeriod = Duration(milliseconds: 100);

class ScoreboardView extends StatefulWidget {
  const ScoreboardView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Mounts the sidebar inside the shared Minecraft game-screen frame instead
  /// of the editor stage. False renders exactly the editor surface.
  final bool gameContext;

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
    if (renderGlossLine(
      doc.effectiveTitle(_store.menuId),
      animations: animations,
    ).isAnimated) {
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
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.sidebar,
          label: huiText('Scoreboard in game'),
        );
      }
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
    final String title = doc.effectiveTitle(_store.menuId);
    final bool titleFellBack = doc.title.isEmpty;
    final bool titleTruncated =
        glossTranslatedLength(title, animations, emoji: emoji) >
        glossBoardMaxTitleLength;

    final Widget sidebar = dom.div(classes: 'hui-scoreboard-sidebar', <Widget>[
      dom.div(classes: 'hui-scoreboard-title', <Widget>[
        GlossTextLine(
          render: renderGlossScoreboardTitle(
            title,
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
              Text(
                huiText("{glossBoardScoreForRow}", <String, Object?>{
                  'glossBoardScoreForRow': glossBoardScoreForRow(index),
                }),
              ),
            ]),
        ]),
    ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.sidebar,
        label: huiText('Scoreboard in game'),
        controls: <Widget>[_playPause()],
        child: sidebar,
      );
    }

    return dom.div(classes: 'hui-scoreboard-stage', <Widget>[
      dom.div(
        classes: 'hui-scoreboard-sky${_sceneBackdrop ? ' is-scene' : ''}',
        <Widget>[
          GlossPreviewZoom(
            label: huiText('Scoreboard preview'),
            alignment: _sceneBackdrop
                ? GlossPreviewAlignment.end
                : GlossPreviewAlignment.center,
            child: sidebar,
          ),
          dom.div(
            classes: 'hui-scoreboard-view-controls',
            attributes: <String, String>{
              'role': 'group',
              'aria-label': huiText('Scoreboard preview controls'),
            },
            <Widget>[
              _playPause(),
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.small,
                onPressed: () =>
                    setState(() => _sceneBackdrop = !_sceneBackdrop),
                icon: ArcaneIcon.image(size: IconSize.sm),
                label: _sceneBackdrop
                    ? huiText('Centered stage')
                    : huiText('Right-side scene'),
              ),
            ],
          ),
        ],
      ),
      dom.div(classes: 'hui-scoreboard-readout', <Widget>[
        Text(_readout(doc, clipped, titleTruncated, titleFellBack)),
      ]),
      ScoreboardSelectionSimulator(store: _store),
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
    child: _store.animationsPlaying
        ? ArcaneIcon.pause(size: IconSize.sm)
        : ArcaneIcon.play(size: IconSize.sm),
  );

  String _readout(
    GlossScoreboardDoc doc,
    int clipped,
    bool titleTruncated,
    bool titleFellBack,
  ) {
    final List<String> parts = <String>[
      doc.primary ? huiText('primary') : huiText('not primary'),
      doc.hideNumbers
          ? huiText(
              'score numbers hidden — 1.20.3 and newer only; older servers '
              'still draw the red column',
            )
          : huiText('score numbers visible'),
      doc.permissionGated
          ? huiText('needs {permission}', <String, Object?>{
              'permission':
                  '$glossBoardPermissionNodePrefix${doc.effectivePermission}',
            })
          : huiText('everyone'),
      if (doc.effectiveGroups.isNotEmpty)
        huiText('groups: {groups}', <String, Object?>{
          'groups': doc.effectiveGroups.join(', '),
        }),
      if (titleFellBack) huiText('blank title falls back to the board id'),
      if (clipped > 0)
        huiPlural(
          'scoreboard.readout.clipped-lines',
          clipped,
          oneEnglish: '{count} line past the 15-line render cap',
          otherEnglish: '{count} lines past the 15-line render cap',
        ),
      if (titleTruncated) huiText('title exceeds the 32-unit in-game cap'),
    ];
    return parts.join(' · ');
  }
}
