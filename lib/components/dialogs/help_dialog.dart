/// Help: quick start, the coordinate frame, the text-format cheatsheet, and an
/// explicit list of things Gloss does not do.
///
/// The non-features list is deliberate. Most support questions about the old
/// editor were about backgrounds, per-component scale and localized menu text,
/// none of which exist in the format — saying so up front is cheaper than
/// letting people hunt for the setting.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../config/links.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({
    required this.store,
    required this.isOpen,
    required this.onClose,
    super.key,
  });

  final EditorStore store;
  final bool isOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-help-dialog',
    isOpen: isOpen,
    onClose: onClose,
    title: huiText('Gloss editor help'),
    maxWidth: 880,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: onClose,
        label: huiText('Close'),
      ),
    ],
    children: <Widget>[
      dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
        _quickStart(),
        _coordinates(),
        _textFormat(),
        _customItems(),
        _nonFeatures(),
        _links(),
      ]),
    ],
  );

  Widget _quickStart() => HuiDialogSection(
    title: huiText('Quick start'),
    description: huiText('From an empty canvas to a menu on your server.'),
    children: <Widget>[
      HuiSteps(
        steps: <String>[
          huiText(
            'Start from File → New or a template. A button runs actions, a '
            'decoration only draws, and a toggle picks one of two icons '
            'from a placeholder value.',
          ),
          huiText(
            'Drag them on the canvas or type exact offsets in the inspector. '
            'Offsets are blocks relative to the menu centre.',
          ),
          huiText(
            'Give buttons their actions: run a player or console command, play '
            'a sound, send MiniMessage, teleport, connect through a proxy, '
            'or navigate the viewer\'s page stack.',
          ),
          huiText(
            'Watch the issues chip in the status bar. Errors mean the plugin '
            'will refuse or misbehave, not just that a key is missing.',
          ),
          huiText(
            'This editor does not push files to a default server. Export, '
            'drop the JSON into {menuFolder}, then run '
            '/gloss menu open {menuId}. Live sync needs a capability '
            'link from /gloss web edit menu <id>, or connect the complete '
            'server workspace with /gloss web workspace.',
            <String, Object?>{
              'menuFolder': huiMenuFolder,
              'menuId': store.menuId,
            },
          ),
          huiText(
            'To re-anchor that open session, stand at its new origin and run '
            '/gloss menu move. It keeps the configured offset and opening '
            'direction; it does not rewrite the menu file.',
          ),
        ],
      ),
      HuiCodeBlock(
        text:
            '$huiMenuFolder${store.exportFileName}\n'
            '${huiImageFolder}your-icon.png\n\n'
            '/gloss menu open ${store.menuId}\n'
            '/gloss menu move',
      ),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            'Saving a menu file re-registers it within about 5 ticks and '
            'closes any session that has it open. New and deleted files are '
            'picked up within about 20 ticks. Players need gloss.menus.open, '
            'gloss.open.<id> and gloss.menus.move. '
            'The per-menu node is not declared in plugin.yml, so grant it '
            'explicitly.',
          ),
        ),
      ]),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            'A menu added through an editor handoff link keeps its exact '
            'validated JSON in Code view, workspace storage and export, '
            'including formatting and extension keys. The first visual edit or '
            'an explicit Code view Format action writes the normalized form.',
          ),
        ),
      ]),
      ArcaneAlert.info(
        title: huiText('Server sync is always explicit'),
        message: huiText(
          'A capability link from /gloss web workspace connects menus, '
          'container previews, panels, holograms, animations, scoreboards, '
          'MOTDs, emoji, bubble styles, tablists, real-drops settings, and '
          'image assets as one server workspace. Review it before import. Local '
          'autosave never contacts the server: use Publish to Server, then '
          'wait for Applied. Pending, rejected, expired and revision-conflict '
          'states remain visible. Fix a rejected publication and publish it '
          'again; a conflict stays blocked until you export local work or '
          'explicitly refresh from the server copy. Copy Link shares the '
          'same editing capability, so treat it like a password and '
          'disconnect the tab when finished.',
        ),
      ),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            'Workspace publication is an exact server mirror: it creates, '
            'updates, and deletes runtime documents and assets to match this '
            'workspace. Unlinked flow maps remain browser-only. Text-image '
            'assets are capped at 16 by 16 pixels, with bounded stored '
            'pixels and repeated image-frame render work across the project. '
            'Projects are capped at 32 MiB by the editor; the '
            'configured relay may use a lower limit. If tab storage is blocked, '
            'the capability remains in the URL and the sync bar asks you to copy '
            'it before reloading.',
          ),
        ),
      ]),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            'Workspace documents autosave through atomic IndexedDB '
            'transactions. The previous committed transaction and any migrated '
            'localStorage workspace are retained for recovery. If another tab '
            'changes or resets the workspace, this tab immediately refuses to '
            'overwrite it and offers Reload; export this tab first if needed. '
            'Hiding or leaving the page starts the final IndexedDB transaction '
            'immediately when no earlier save is still settling. Browsers do '
            'not guarantee that queued or uncommitted work finishes after a '
            'page is frozen, closed, or interrupted by a crash.',
          ),
        ),
      ]),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            'Workspace and server-project imports compensate by restoring the '
            'prior workspace when either the document or image write fails. '
            'Browser localStorage and IndexedDB cannot share one native '
            'transaction, so force-closing the browser between those two writes '
            'can still leave a partial import.',
          ),
        ),
      ]),
    ],
  );

  Widget _coordinates() => HuiDialogSection(
    title: huiText('Coordinates'),
    description: huiText(
      'Blocks relative to the player and menu centre. uiScale '
      'applies to component offsets and icons, not the menu offset.',
    ),
    children: <Widget>[
      dom.div(classes: 'hui-axis', <Widget>[
        dom.div(classes: 'hui-axis-stage', <Widget>[
          dom.span(classes: 'hui-axis-tick is-menu', <Widget>[
            Text(huiText('menu centre  y 1.7  z 2.5')),
          ]),
          dom.span(classes: 'hui-axis-tick is-eye', <Widget>[
            Text(huiText('eye level  y 1.62')),
          ]),
          dom.span(classes: 'hui-axis-tick is-feet', <Widget>[
            Text(huiText("player's feet  y 0")),
          ]),
          dom.span(classes: 'hui-axis-ground', <Widget>[
            Text(huiText('ground')),
          ]),
        ]),
        HuiChips(
          labels: <String>[
            huiText('x  right'),
            huiText('y  up'),
            huiText('z  forward, away from the player'),
            huiText('unit  1 block'),
          ],
        ),
      ]),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            "The menu offset is measured from the player's feet, not the "
            'eyes: y 1.7 puts the menu at head height. Component offsets '
            'are then relative to that centre. The server uiScale scales '
            'component offsets and icons, which is why the canvas has a '
            'preview slider for it.',
          ),
        ),
      ]),
    ],
  );

  Widget _textFormat() => HuiDialogSection(
    title: huiText('Text formatting'),
    description: huiText(
      'Text icons accept legacy codes and a MiniMessage subset. '
      'Each line is parsed on its own.',
    ),
    children: <Widget>[
      _cheatTable(huiText('Legacy codes'), <List<String>>[
        <String>[
          '&0 … &9, &a … &f',
          huiText('Colours, dark blue through white'),
        ],
        <String>['&l', huiText('Bold')],
        <String>['&m', huiText('Strikethrough')],
        <String>['&n', huiText('Underlined')],
        <String>['&o', huiText('Italic')],
        <String>['&k', huiText('Obfuscated')],
        <String>['&r', huiText('Reset to plain white')],
      ]),
      _cheatTable(huiText('MiniMessage subset'), <List<String>>[
        <String>['<red>, <gold>, <gray>', huiText('Named colours')],
        <String>['<#ff8800>', huiText('Hex colour')],
        <String>['<color:gold>', huiText('Explicit colour tag')],
        <String>[
          '<gradient:#ff0000:#00ff00>',
          huiText('Per-character gradient across the rest of the line'),
        ],
        <String>[
          '<b> <i> <u> <st> <obf>',
          huiText('Bold, italic, underline, strikethrough, obfuscated'),
        ],
        <String>['</b>, </gradient>', huiText('Closing tags')],
        <String>['<reset>', huiText('Back to plain white')],
      ]),
      _cheatTable(huiText('Other rules'), <List<String>>[
        <String>[
          r'\n',
          huiText(
            'Splits the icon into one text display per line. Styles do not '
            'carry from one line to the next.',
          ),
        ],
        <String>[
          '%papi_placeholder%',
          huiText(
            'Text icons expand initially and every refreshTicks; toggle '
            'conditions expand only at open. Never in commands, ids or '
            'image paths.',
          ),
        ],
        <String>[
          huiText('Unknown tag'),
          huiText('Rendered as literal text, exactly as it is in-game.'),
        ],
      ]),
    ],
  );

  Widget _customItems() => HuiDialogSection(
    title: huiText('Items from other plugins'),
    description: huiText(
      'The Custom icon type resolves an id through a '
      'custom-item plugin on your server and renders whatever stack it '
      'hands back.',
    ),
    children: <Widget>[
      const HuiCodeBlock(
        text:
            '{ "type": "customItem", "provider": "itemsadder",\n'
            '  "item": "myitems:ruby", "count": 1 }',
      ),
      dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(
          huiText(
            'provider is optional and defaults to auto, which asks every '
            'installed provider in activation order and takes the first hit. Name one '
            'explicitly when the same bare id exists in two plugins. The '
            'id is passed through verbatim, case included, because most of '
            'these plugins look ids up in case-sensitive maps.',
          ),
        ),
      ]),
      _cheatTable(huiText('Provider ids and their id formats'), <List<String>>[
        for (final String provider in huiCustomItemProviders)
          <String>[provider, _providerHelp(provider)],
      ]),
      ArcaneAlert.warning(
        title: huiText('The editor cannot verify these ids'),
        message: huiText(
          'The static catalog and optional menu-sync scope do not expose '
          'your server\'s plugin registries, so an id the editor has never '
          'heard of is never an error. If the '
          'provider is missing or the id is wrong, Gloss logs a warning '
          'naming both and draws its magenta/black placeholder; the rest '
          'of the menu still opens.',
        ),
      ),
      HuiSteps(
        steps: <String>[
          huiText(
            'Run /gloss item status on the server to see which providers are '
            'present, ready, and how many ids they expose.',
          ),
          huiText('Run /gloss item export to write {file}.', <String, Object?>{
            'file': '${huiPluginFolder}custom-items.json',
          }),
          huiText(
            'Open Settings in the hosted editor and import that file. The '
            'plugin does not host or upload it.',
          ),
          huiText(
            'With a catalog loaded you get id autocomplete, an approximate '
            'canvas sprite, and a note when an id is missing from your '
            'export.',
          ),
        ],
      ),
      const HuiCodeBlock(text: '/gloss item status\n/gloss item export'),
    ],
  );

  Widget _cheatTable(String caption, List<List<String>> rows) =>
      dom.div(classes: 'hui-cheat', <Widget>[
        HuiEyebrow(caption),
        dom.dl(classes: 'hui-cheat-list', <Widget>[
          for (final List<String> row in rows) ...<Widget>[
            dom.dt(<Widget>[
              dom.code(<Widget>[Text(row[0])]),
            ]),
            dom.dd(<Widget>[Text(row[1])]),
          ],
        ]),
      ]);

  Widget _nonFeatures() => HuiDialogSection(
    title: huiText('What Gloss does not do'),
    description: huiText(
      'These do not exist in the format. The editor will not '
      'offer them, so you do not go looking.',
    ),
    children: <Widget>[
      dom.ul(classes: 'hui-nonfeatures', <Widget>[
        for (final String item in _nonFeatureList)
          dom.li(<Widget>[Text(huiText(item))]),
      ]),
    ],
  );

  String _providerHelp(String provider) {
    final HuiItemProviderInfo? info = huiItemProviderInfo[provider];
    if (info == null) return huiText('See the plugin documentation.');
    return huiText('{label}: {format} ({example})', <String, Object?>{
      'label': huiText(info.label),
      'format': huiText(info.idFormat),
      'example': info.example,
    });
  }

  Widget _links() => HuiDialogSection(
    title: huiText('Links'),
    description: huiText('Docs, source and support.'),
    children: <Widget>[
      dom.div(classes: 'hui-link-grid', <Widget>[
        for (final HuiLink link in huiLinks)
          dom.a(
            href: link.url,
            target: dom.Target.blank,
            classes: 'hui-link-card hui-lift',
            attributes: const <String, String>{'rel': 'noopener noreferrer'},
            <Widget>[
              dom.span(classes: 'hui-link-icon', <Widget>[
                _linkIcon(link.icon),
              ]),
              dom.span(classes: 'hui-link-text', <Widget>[
                dom.strong(<Widget>[Text(huiText(link.label))]),
                dom.span(<Widget>[Text(huiText(link.description))]),
              ]),
              ArcaneIcon.externalLink(size: IconSize.sm),
            ],
          ),
      ]),
    ],
  );

  Widget _linkIcon(String name) => switch (name) {
    'github' => ArcaneIcon.github(size: IconSize.sm),
    'chat' => ArcaneIcon.messageCircle(size: IconSize.sm),
    'globe' => ArcaneIcon.globe(size: IconSize.sm),
    _ => ArcaneIcon.bookOpen(size: IconSize.sm),
  };
}

const List<String> _nonFeatureList = <String>[
  'No background: a menu has no panel, colour or image behind its components.',
  'No independent component transform beyond offset. Display-backed icons '
      'can own scale and alignment, while a persistent panel rotates and '
      'scales the whole menu.',
  "No localization of menu text. language.yml only translates the plugin's own "
      'messages, never the contents of a menu.',
  'No per-component permission or visibility rule. The only condition is a '
      'toggle comparing one placeholder value with equalsIgnoreCase.',
  'No comparators: a toggle can only test equality, never greater-than or '
      'contains.',
  'Text placeholders refresh every 10 ticks by default. Set refreshTicks to 0 '
      'when a text icon should stay frozen after its initial render.',
  "%player% and %player_name% become the clicking player's name; all other command tokens stay literal.",
  'Only three component types (button, decoration, toggle), eight icon types '
      '(text, textImage, animatedTextImage, item, block, customItem, entity, '
      'playerHead) and six action '
      'types (command, sound, message, teleport, connect, navigate). '
      'itemStack is API-only and cannot be parsed from JSON; fontImage is not '
      'a current icon type.',
  'No enchantments, lore or NBT on an item icon. A customItem icon inherits '
      'whatever its provider plugin builds, but the JSON cannot add to it.',
  'No format version or migration: what you export is exactly what the plugin '
      'reads.',
  'Persistent world panels open automatically for eligible nearby players. '
      'Menu JSON has no join, block or NPC trigger; personal menus still open '
      'through a command or the Java API.',
];
