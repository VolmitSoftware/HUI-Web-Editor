/// Menu root properties, shown whenever nothing is selected.
///
/// Every field here is one of the seven keys `MenuDefinitionData` actually
/// reads. There is no background, scale, rotation, title, permission or version
/// at the menu root, and the help copy says so out loud so nobody goes looking.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

class MenuInspector extends StatelessWidget {
  const MenuInspector({required this.store, super.key});

  final EditorStore store;

  HuiMenu get _menu => store.menu;

  /// Root-level issues only: anything carrying a component id belongs to that
  /// component's inspector instead.
  List<HuiIssue> _issuesFor(String path) => store.issues
      .where(
        (HuiIssue issue) =>
            issue.componentId == null && issue.path.startsWith(path),
      )
      .toList();

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-inspector-body is-menu', <Widget>[
        _header(),
        _placement(),
        _lifetime(),
        _install(),
        _extras(),
        _nonFeatures(),
      ]);

  /// `display: contents` on the wrapper keeps the header a direct child of the
  /// scrolling body, which is what `position: sticky` needs.
  Widget _header() => dom.div(classes: 'hui-inspector-headgroup', <Widget>[
    dom.div(classes: 'hui-inspector-header is-menu', <Widget>[
      const HuiEyebrow('Menu'),
      dom.div(classes: 'hui-inspector-title-row', <Widget>[
        dom.h2(classes: 'hui-inspector-title', <Widget>[Text(store.menuId)]),
        const HuiFieldHelp('menu.id'),
      ]),
    ]),
    const dom.p(classes: 'hui-inspector-lede', <Widget>[
      Text(
        'Nothing is selected, so these are the settings for the whole '
        'menu. Pick a component to edit it.',
      ),
    ]),
  ]);

  Widget _placement() => InspectorSection(
    title: 'Placement',
    children: <Widget>[
      HuiField(
        label: 'Offset',
        required: true,
        trailing: const HuiFieldHelp('menu.offset'),
        help: 'Blocks from the player\'s feet at the moment it opens.',
        // Eye level, arm's length forward — what a new document and every
        // template open at.
        defaultValue: '0, $huiDefaultMenuHeight, $huiDefaultMenuDistance',
        onReset:
            _menu.offset.x == 0 &&
                _menu.offset.y == huiDefaultMenuHeight &&
                _menu.offset.z == huiDefaultMenuDistance
            ? null
            : () => store.mutate(
                'menu offset',
                (HuiMenu menu) => menu.offset = Vec3(
                  0,
                  huiDefaultMenuHeight,
                  huiDefaultMenuDistance,
                ),
              ),
        control: dom.div(<Widget>[
          HuiVec3Field(
            value: _menu.offset,
            onChanged: (Vec3 value) => store.mutate(
              'menu offset',
              (HuiMenu menu) => menu.offset = value,
            ),
          ),
          HuiInlineIssues(_issuesFor('offset')),
        ]),
      ),
      HuiSwitchRow(
        label: 'Lock position',
        value: _menu.lockPosition,
        help: 'Freezes the player while the menu is open.',
        trailing: const HuiFieldHelp('menu.lockPosition'),
        onChanged: (bool value) => store.mutate(
          'menu lockPosition',
          (HuiMenu menu) => menu.lockPosition = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Follow player',
        value: _menu.followPlayer,
        help: 'Re-centres and turns the menu as the player moves or looks.',
        warning: _menu.lockPosition && _menu.followPlayer
            ? 'Position stays locked, but look changes can still turn it.'
            : null,
        trailing: const HuiFieldHelp('menu.followPlayer'),
        onChanged: (bool value) => store.mutate(
          'menu followPlayer',
          (HuiMenu menu) => menu.followPlayer = value,
        ),
      ),
      _maxDistance(),
      const HuiMore(
        summary: 'How placement is applied',
        children: <Widget>[
          HuiNote(
            'The offset is measured from the player\'s feet, so y 1.7 is '
            'about eye level and z is how far in front of them the menu '
            'floats.',
          ),
          HuiNote(
            'Lock position rewrites movement back and zeroes velocity every '
            'tick. The player can still look; follow player turns the menu '
            'with that yaw.',
          ),
        ],
      ),
    ],
  );

  Widget _maxDistance() {
    final double? value = _menu.maxDistance;
    final bool unlimited = value == null;
    return HuiField(
      label: 'Max distance',
      help: 'Closes the menu once the player is further away than this.',
      trailing: dom.div(classes: 'hui-inline-check', <Widget>[
        ArcaneCheckbox(
          checked: unlimited,
          size: ComponentSize.sm,
          label: 'Unlimited',
          onChanged: (bool checked) => store.mutate(
            'menu maxDistance',
            (HuiMenu menu) => menu.maxDistance = checked ? null : 8,
          ),
        ),
        const HuiFieldHelp('menu.maxDistance'),
      ]),
      control: dom.div(<Widget>[
        if (unlimited)
          const HuiNote(
            'The key is left out of the JSON, which the plugin reads as '
            '60000000 blocks.',
          )
        else
          HuiNumberField(
            value: value,
            min: 0,
            max: huiMaxDistanceCeiling,
            step: 1,
            decimals: 2,
            suffix: 'blocks',
            onChanged: (double next) => store.mutate(
              'menu maxDistance',
              (HuiMenu menu) => menu.maxDistance = next,
            ),
          ),
        HuiInlineIssues(_issuesFor('maxDistance')),
      ]),
    );
  }

  Widget _lifetime() => InspectorSection(
    title: 'Auto close',
    sectionKey: 'menu.autoClose',
    description:
        'A player can only have one menu open at a time; opening '
        'another replaces this one.',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Close on death',
        value: _menu.closeOnDeath,
        help: 'Closes when the player dies.',
        trailing: const HuiFieldHelp('menu.closeOnDeath'),
        onChanged: (bool value) => store.mutate(
          'menu closeOnDeath',
          (HuiMenu menu) => menu.closeOnDeath = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Close on teleport',
        value: _menu.closeOnTeleport,
        help: 'Closes on any teleport, including portals.',
        trailing: const HuiFieldHelp('menu.closeOnTeleport'),
        onChanged: (bool value) => store.mutate(
          'menu closeOnTeleport',
          (HuiMenu menu) => menu.closeOnTeleport = value,
        ),
      ),
    ],
  );

  /// Reference facts, not controls: the four paths stay visible because they
  /// are one line each, the three traps sit behind a closed disclosure.
  Widget _install() => InspectorSection(
    title: 'Install on the server',
    sectionKey: 'menu.install',
    children: <Widget>[
      HuiDetailRow('Menu file', 'plugins/Gloss/menus/${store.menuId}.json'),
      const HuiDetailRow('Images', 'plugins/Gloss/images/'),
      HuiDetailRow('Test command', '/gloss menu open ${store.menuId}'),
      HuiDetailRow(
        'Permissions',
        'gloss.menus.open + gloss.open.${store.menuId}',
      ),
      const HuiMore(
        summary: 'Directory rules, hot reload and the permission trap',
        children: <Widget>[
          HuiNote(
            'The menu id is the file base name, so renaming the file '
            'renames the menu. Slash-separated ids map to matching subfolders '
            'under menus/, such as shop/tools.json for shop/tools.',
            title: 'Nested menu ids',
          ),
          HuiNote(
            'Saving over an existing file re-registers it within about 5 '
            'ticks and closes every session that had it open. New and '
            'deleted files are picked up within about 20 ticks.',
            title: 'Hot reload',
          ),
          HuiNote(
            'gloss.open.<id> is not declared in plugin.yml, so it has to '
            'be granted explicitly in your permissions plugin. Command '
            'aliases: gl, glo, gg.',
            tone: HuiNoteTone.info,
            title: 'Permission trap',
          ),
        ],
      ),
    ],
  );

  /// Unknown keys at the menu root. `name` is the one that turns up in real
  /// files: the plugin ignores it and takes the id from the filename, so seeing
  /// it here is the only way to learn it does nothing.
  Widget _extras() => InspectorSection(
    title: 'Extra keys',
    sectionKey: 'menu.extras',
    initiallyOpen: false,
    children: <Widget>[
      ExtrasEditor(
        title: 'Menu',
        extras: _menu.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            store.mutate(label, (HuiMenu menu) => menu.extras = next),
      ),
    ],
  );

  Widget _nonFeatures() =>
      const dom.div(classes: 'hui-inspector-aside', <Widget>[
        HuiMore(
          summary: 'Not in this format',
          children: <Widget>[
            HuiNote(
              'The menu root has exactly seven keys. There is no background, '
              'no scale or rotation, no title, no per-menu permission, no '
              'version and no localization of menu text - none of those exist '
              'in the plugin, so the editor does not offer them.',
            ),
          ],
        ),
      ]);
}
