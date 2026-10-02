library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import '../../logic/channel_preview.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../inspector/inspector_widgets.dart';
import '../gloss/gloss_game_screen.dart';
import '../gloss/gloss_text_line.dart';

class ChannelView extends StatefulWidget {
  const ChannelView({required this.store, this.gameContext = false, super.key});
  final EditorStore store;
  final bool gameContext;
  @override
  State<ChannelView> createState() => _ChannelViewState();
}

class _ChannelViewState extends State<ChannelView> {
  String _message = 'Hello @Steve, come see the new build!';
  bool _allowed = true;
  String _viewer = 'Steve';
  @override
  void initState() {
    super.initState();
    component.store.addListener(_changed);
  }

  @override
  void dispose() {
    component.store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final GlossDoc? active = component.store.glossDoc;
    if (active is! GlossChannelDoc) return const dom.div(<Widget>[]);
    final GlossChannelDoc doc = active;
    final ChannelPreview preview = channelPreview(
      doc,
      message: _message,
      viewer: _viewer,
      allowed: _allowed,
      names: component.store.workspaceNames,
      animations: component.store.workspaceAnimations,
      emoji: component.store.workspaceEmoji,
    );
    final Widget chat = dom.div(classes: 'hui-connections-chat', <Widget>[
      dom.div(
        classes: 'hui-connections-line',
        attributes: <String, String>{'title': preview.hoverText},
        <Widget>[GlossTextLine(render: preview.render)],
      ),
    ]);
    final List<Widget> controls = <Widget>[
      HuiSegmented(
        value: _viewer,
        segments: const <HuiSegment>[
          HuiSegment(value: 'Steve', label: 'Steve'),
          HuiSegment(value: 'Morgan', label: 'Morgan'),
        ],
        onChanged: (String value) => setState(() => _viewer = value),
      ),
      TextInput(
        value: _message,
        placeholder: 'Type a message with @Steve',
        size: ComponentSize.sm,
        attributes: const <String, String>{
          'aria-label': 'Preview chat message',
        },
        onChanged: (String value) => setState(() => _message = value),
      ),
      HuiSwitchRow(
        label: 'Sender can mention players',
        value: _allowed,
        onChanged: (bool value) => setState(() => _allowed = value),
      ),
      Text(
        preview.mentioned && doc.mentions.sound.isNotEmpty
            ? 'Tagged player sound: ${doc.mentions.sound}'
            : 'No mention sound for this viewer',
      ),
    ];
    if (component.gameContext) {
      return GlossGameScreen(
        anchor: GlossGameAnchor.chat,
        label: 'Chat and mention preview',
        controls: controls,
        child: chat,
      );
    }
    return dom.div(classes: 'hui-connections-stage', <Widget>[
      dom.div(classes: 'hui-connections-screen', <Widget>[chat, ...controls]),
    ]);
  }
}
