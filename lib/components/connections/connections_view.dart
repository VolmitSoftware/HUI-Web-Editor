/// The connection-message surface: the join and leave lines as chat rows.
///
/// Fidelity notes, all from `ConnectionsService.java`: a section broadcasts
/// only when it is present and enabled (`Section.active`), the document and
/// section `show` conditions both gate it (`announce`), and the text is
/// rendered once per recipient rather than once per event
/// (`ConnectionsService.render`) — so the scope carries `subject.*` for the
/// player who connected and `viewer.*` for whoever is reading. The preview
/// picks one sampled reader and shows the line they would see, with the
/// highest-priority matching variant already applied.
///
/// The chat window itself is a mock: colours, text functions and expressions
/// are real, but the client's own wrapping, history and opacity are not.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/connections_selection.dart';
import '../../logic/connections_validation.dart';
import '../../logic/gloss_show.dart';
import '../../logic/gloss_text.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_preview_zoom.dart';
import '../gloss/gloss_text_line.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ConnectionsView extends StatefulWidget {
  const ConnectionsView({
    required this.store,
    this.gameContext = false,
    super.key,
  });

  final EditorStore store;

  /// Mounts the chat rows inside the shared Minecraft game-screen frame
  /// instead of the editor stage.
  final bool gameContext;

  @override
  State<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends State<ConnectionsView> {
  // The shell hands every surface the one long-lived store, so the
  // subscription taken in initState is the only one this state ever needs.
  int _sampledAtMs = DateTime.now().millisecondsSinceEpoch;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _refreshSample() {
    setState(() => _sampledAtMs = DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final GlossConnectionsDoc? doc = _store.connectionsDoc;
    if (doc == null) {
      if (component.gameContext) {
        return glossGameEmpty(
          anchor: GlossGameAnchor.chat,
          label: huiText('Connection messages in chat'),
        );
      }
      return const dom.div(
        classes: 'hui-connections-stage is-empty',
        <Widget>[],
      );
    }

    final Widget chat = dom.div(classes: 'hui-connections-chat', <Widget>[
      for (final String key in glossConnectionsSectionKeys) _row(doc, key),
    ]);

    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.chat,
        label: huiText('Connection messages in chat'),
        controls: <Widget>[_refresh()],
        child: chat,
      );
    }

    return dom.div(classes: 'hui-connections-stage', <Widget>[
      GlossPreviewZoom(
        label: huiText('Connection message preview'),
        child: dom.div(classes: 'hui-connections-screen', <Widget>[
          chat,
          dom.div(classes: 'hui-connections-controls', <Widget>[
            dom.span(classes: 'hui-connections-reader', <Widget>[
              Text(
                huiText('Read by {name}', <String, Object?>{
                  'name': glossConnectionsSampleViewerName,
                }),
              ),
            ]),
            _refresh(),
          ]),
        ]),
      ),
      dom.div(classes: 'hui-connections-readout', <Widget>[
        Text(_readout(doc)),
      ]),
    ]);
  }

  /// One section as the sampled reader would see it, or as the reason it
  /// stays silent.
  Widget _row(GlossConnectionsDoc doc, String key) {
    final GlossConnectionsSection section = doc.section(key);
    final String label = key == 'leave' ? huiText('Leave') : huiText('Join');
    if (!glossConnectionsSectionBroadcasts(doc, key, nowMs: _sampledAtMs)) {
      return dom.div(classes: 'hui-connections-line is-silent', <Widget>[
        dom.span(classes: 'hui-connections-event', <Widget>[Text(label)]),
        Text(_silentReason(doc, section)),
      ]);
    }
    final GlossConnectionsPresentation resolved =
        glossResolveConnectionsPresentation(doc, key);
    if (resolved.text.trim().isEmpty) {
      return dom.div(classes: 'hui-connections-line is-silent', <Widget>[
        dom.span(classes: 'hui-connections-event', <Widget>[Text(label)]),
        Text(huiText('No text, so nothing is sent.')),
      ]);
    }
    return dom.div(classes: 'hui-connections-line', <Widget>[
      dom.span(classes: 'hui-connections-event', <Widget>[Text(label)]),
      GlossTextLine(
        render: renderGlossLine(
          resolved.text,
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
          nowMs: _sampledAtMs,
          expressionSamples: glossConnectionsSamples,
        ),
      ),
    ]);
  }

  String _silentReason(
    GlossConnectionsDoc doc,
    GlossConnectionsSection section,
  ) {
    if (!section.present) {
      return huiText('No block in the file, so nothing is sent.');
    }
    if (!section.enabled) return huiText('Turned off, so nothing is sent.');
    if (!glossShowMatches(doc.extras['show'], nowMs: _sampledAtMs)) {
      return huiText('The document show condition is false right now.');
    }
    return huiText('The section show condition is false right now.');
  }

  Widget _refresh() => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: _refreshSample,
    attributes: <String, String>{
      'aria-label': huiText('Refresh'),
      'title': huiText('Refresh'),
    },
    icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
  );

  String _readout(GlossConnectionsDoc doc) {
    final int live = <String>[
      for (final String key in glossConnectionsSectionKeys)
        if (glossConnectionsSectionBroadcasts(doc, key, nowMs: _sampledAtMs))
          key,
    ].length;
    return <String>[
      huiText('{live} of 2 messages broadcast', <String, Object?>{
        'live': live,
      }),
      huiText('rendered once per reader, not once per event'),
      huiText('subject is the player who connected, viewer is the one reading'),
    ].join(' · ');
  }
}
