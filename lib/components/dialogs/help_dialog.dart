/// Help: quick start, the coordinate frame, the text-format cheatsheet, and an
/// explicit list of things HoloUI does not do.
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
        title: 'HoloUI editor help',
        maxWidth: 880,
        actions: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            onPressed: onClose,
            label: 'Close',
          ),
        ],
        children: <Widget>[
          dom.div(
            classes: 'hui-dialog-body hui-stagger',
            <Widget>[
              _quickStart(),
              _coordinates(),
              _textFormat(),
              _customItems(),
              _nonFeatures(),
              _links(),
            ],
          ),
        ],
      );

  Widget _quickStart() => HuiDialogSection(
        title: 'Quick start',
        description: 'From an empty canvas to a menu on your server.',
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              'Add components in the left rail. A button runs actions, a '
                  'decoration only draws, and a toggle picks one of two icons '
                  'from a placeholder value.',
              'Drag them on the canvas or type exact offsets in the inspector. '
                  'Offsets are blocks relative to the menu centre.',
              'Give buttons their actions: a command runs as the player or as '
                  'the console, a sound needs a category plus volume and pitch.',
              'Watch the issues chip in the status bar. Errors mean the plugin '
                  'will refuse or misbehave, not just that a key is missing.',
              'Export, drop the file into $huiMenuFolder, then run '
                  '/holoui open ${store.menuId}.',
            ],
          ),
          HuiCodeBlock(
            text: '$huiMenuFolder${store.exportFileName}\n'
                '${huiImageFolder}your-icon.png\n\n'
                '/holoui open ${store.menuId}',
          ),
          const dom.p(
            classes: 'hui-dialog-note',
            <Widget>[
              Text(
                'Saving a menu file re-registers it within about 5 ticks and '
                'closes any session that has it open. New and deleted files are '
                'picked up within about 20 ticks. Players need '
                'holoui.command.open plus holoui.open.<id>; the per-menu node '
                'is not declared in plugin.yml, so grant it explicitly.',
              ),
            ],
          ),
        ],
      );

  Widget _coordinates() => const HuiDialogSection(
        title: 'Coordinates',
        description: 'Blocks, relative to the player, multiplied by the '
            'server uiScale.',
        children: <Widget>[
          dom.div(
            classes: 'hui-axis',
            <Widget>[
              dom.div(
                classes: 'hui-axis-stage',
                <Widget>[
                  dom.span(
                    classes: 'hui-axis-tick is-menu',
                    <Widget>[Text('menu centre  y 1.7  z 2.5')],
                  ),
                  dom.span(
                    classes: 'hui-axis-tick is-eye',
                    <Widget>[Text('eye level  y 1.62')],
                  ),
                  dom.span(
                    classes: 'hui-axis-tick is-feet',
                    <Widget>[Text('player feet  y 0')],
                  ),
                  dom.span(
                    classes: 'hui-axis-ground',
                    <Widget>[Text('ground')],
                  ),
                ],
              ),
              HuiChips(
                labels: <String>[
                  'x  right',
                  'y  up',
                  'z  forward, away from the player',
                  'unit  1 block',
                ],
              ),
            ],
          ),
          dom.p(
            classes: 'hui-dialog-note',
            <Widget>[
              Text(
                'The menu offset is measured from the player feet, not the '
                'eyes: y 1.7 puts the menu at head height. Component offsets '
                'are then relative to that centre. The server uiScale scales '
                'both the offsets and the icons, which is why the canvas has a '
                'preview slider for it.',
              ),
            ],
          ),
        ],
      );

  Widget _textFormat() => HuiDialogSection(
        title: 'Text formatting',
        description: 'Text icons accept legacy codes and a MiniMessage subset. '
            'Each line is parsed on its own.',
        children: <Widget>[
          _cheatTable(
            'Legacy codes',
            const <List<String>>[
              <String>['&0 … &9, &a … &f', 'Colours, dark blue through white'],
              <String>['&l', 'Bold'],
              <String>['&m', 'Strikethrough'],
              <String>['&o', 'Italic'],
              <String>['&r', 'Reset to plain white'],
            ],
          ),
          const ArcaneAlert.warning(
            title: '&n and &k are broken in HoloUI',
            message: 'The plugin translates them to <underline> and <magic>, '
                'which MiniMessage does not know, so the tag is drawn as '
                'literal text in-game. Use <u>…</u> and <obf>…</obf> instead.',
          ),
          _cheatTable(
            'MiniMessage subset',
            const <List<String>>[
              <String>['<red>, <gold>, <gray>', 'Named colours'],
              <String>['<#ff8800>', 'Hex colour'],
              <String>['<color:gold>', 'Explicit colour tag'],
              <String>[
                '<gradient:#ff0000:#00ff00>',
                'Per-character gradient across the rest of the line',
              ],
              <String>['<b> <i> <u> <st> <obf>', 'Bold, italic, underline, '
                  'strikethrough, obfuscated'],
              <String>['</b>, </gradient>', 'Closing tags'],
              <String>['<reset>', 'Back to plain white'],
            ],
          ),
          _cheatTable(
            'Other rules',
            const <List<String>>[
              <String>[
                r'\n',
                'Splits the icon into one text display per line. Styles do not '
                    'carry from one line to the next.',
              ],
              <String>[
                '%papi_placeholder%',
                'Expanded once, when the menu opens, in text icons and in a '
                    'toggle condition. Never in commands, ids or image paths.',
              ],
              <String>[
                'Unknown tag',
                'Rendered as literal text, exactly as it is in-game.',
              ],
            ],
          ),
        ],
      );

  Widget _customItems() => HuiDialogSection(
        title: 'Items from other plugins',
        description: 'The Custom icon type resolves an id through a '
            'custom-item plugin on your server and renders whatever stack it '
            'hands back.',
        children: <Widget>[
          const HuiCodeBlock(
            text: '{ "type": "customItem", "provider": "itemsadder",\n'
                '  "item": "myitems:ruby", "count": 1 }',
          ),
          const dom.p(
            classes: 'hui-dialog-note',
            <Widget>[
              Text(
                'provider is optional and defaults to auto, which asks every '
                'installed provider in order and takes the first hit. Name one '
                'explicitly when the same bare id exists in two plugins. The '
                'id is passed through verbatim, case included, because most of '
                'these plugins look ids up in case-sensitive maps.',
              ),
            ],
          ),
          _cheatTable(
            'Provider ids and their id formats',
            <List<String>>[
              for (final String provider in huiCustomItemProviders)
                <String>[
                  provider,
                  '${huiItemProviderInfo[provider]?.label ?? provider}: '
                      '${huiItemProviderInfo[provider]?.idFormat ?? 'see the '
                          'plugin docs'}'
                      '${huiItemProviderInfo[provider] == null ? '' : ' '
                          '(${huiItemProviderInfo[provider]!.example})'}',
                ],
            ],
          ),
          const ArcaneAlert.warning(
            title: 'The editor cannot verify these ids',
            message: 'It is a static page with no connection to your server, '
                'so an id it has never heard of is never an error. If the '
                'provider is missing or the id is wrong, HoloUI logs a warning '
                'naming both and draws its magenta/black placeholder; the rest '
                'of the menu still opens.',
          ),
          const HuiSteps(
            steps: <String>[
              'Run /holoui items on the server to see which providers are '
                  'present, ready, and how many ids they expose.',
              'Run /holoui items export to write '
                  '${huiPluginFolder}custom-items.json.',
              'The self-hosted editor (/holoui builder start) serves that file '
                  'and picks it up on its own. On the public site, import it '
                  'from Settings instead.',
              'With a catalog loaded you get id autocomplete, an approximate '
                  'canvas sprite, and a note when an id is missing from your '
                  'export.',
            ],
          ),
          const HuiCodeBlock(
            text: '/holoui items\n/holoui items export',
          ),
        ],
      );

  Widget _cheatTable(String caption, List<List<String>> rows) => dom.div(
        classes: 'hui-cheat',
        <Widget>[
          HuiEyebrow(caption),
          dom.dl(
            classes: 'hui-cheat-list',
            <Widget>[
              for (final List<String> row in rows) ...<Widget>[
                dom.dt(<Widget>[
                  dom.code(<Widget>[Text(row[0])]),
                ]),
                dom.dd(<Widget>[Text(row[1])]),
              ],
            ],
          ),
        ],
      );

  Widget _nonFeatures() => HuiDialogSection(
        title: 'What HoloUI does not do',
        description: 'These do not exist in the format. The editor will not '
            'offer them, so you do not go looking.',
        children: <Widget>[
          dom.ul(
            classes: 'hui-nonfeatures',
            <Widget>[
              for (final String item in _nonFeatureList)
                dom.li(<Widget>[Text(item)]),
            ],
          ),
        ],
      );

  Widget _links() => HuiDialogSection(
        title: 'Links',
        description: 'Docs, source and support.',
        children: <Widget>[
          dom.div(
            classes: 'hui-link-grid',
            <Widget>[
              for (final HuiLink link in huiLinks)
                dom.a(
                  href: link.url,
                  target: dom.Target.blank,
                  classes: 'hui-link-card hui-lift',
                  attributes: const <String, String>{
                    'rel': 'noopener noreferrer',
                  },
                  <Widget>[
                    dom.span(
                      classes: 'hui-link-icon',
                      <Widget>[_linkIcon(link.icon)],
                    ),
                    dom.span(
                      classes: 'hui-link-text',
                      <Widget>[
                        dom.strong(<Widget>[Text(link.label)]),
                        dom.span(<Widget>[Text(link.description)]),
                      ],
                    ),
                    ArcaneIcon.externalLink(size: IconSize.sm),
                  ],
                ),
            ],
          ),
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
  'No per-component scale, rotation or alignment. Size comes from the server '
      'uiScale and the icon itself.',
  'No localization of menu text. language.yml only translates the plugin own '
      'messages, never the contents of a menu.',
  'No per-component permission or visibility rule. The only condition is a '
      'toggle comparing one placeholder value with equalsIgnoreCase.',
  'No comparators: a toggle can only test equality, never greater-than or '
      'contains.',
  'No live placeholder refresh. Values are read once, when the menu opens, and '
      'stay frozen for the session.',
  'No placeholders in commands. The command string is dispatched verbatim.',
  'Only three component types (button, decoration, toggle), five icon types '
      '(text, textImage, animatedTextImage, item, customItem) and two action '
      'types (command, sound). fontImage and itemStack exist in the plugin '
      'enum but cannot be parsed.',
  'No enchantments, lore or NBT on an item icon. A customItem icon inherits '
      'whatever its provider plugin builds, but the JSON cannot add to it.',
  'No format version or migration: what you export is exactly what the plugin '
      'reads.',
  'No trigger other than a command or the Java API. Nothing in the JSON opens '
      'a menu on join, on a block, or from an NPC.',
];
