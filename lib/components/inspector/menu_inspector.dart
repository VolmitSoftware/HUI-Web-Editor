/// Menu root properties, shown whenever nothing is selected.
///
/// Every field here is one of the seven keys `MenuDefinitionData` actually
/// reads. There is no background, scale, rotation, title, permission or version
/// at the menu root, and the help copy says so out loud so nobody goes looking.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class MenuInspector extends StatelessWidget {
  const MenuInspector({required this.store, super.key});

  final EditorStore store;

  HuiMenu get _menu => store.menu;

  /// Root-level issues only: anything carrying a component id belongs to that
  /// component's inspector instead.
  List<HuiIssue> _issuesFor(String path) => store.issues
      .where((HuiIssue issue) =>
          issue.componentId == null && issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-inspector-body is-menu',
        <Widget>[
          _header(),
          _placement(),
          _lifetime(),
          _install(),
          _nonFeatures(),
        ],
      );

  Widget _header() => dom.div(
        classes: 'hui-inspector-header is-menu',
        <Widget>[
          const HuiEyebrow('Menu'),
          dom.h2(
            classes: 'hui-inspector-title',
            <Widget>[Text(store.menuId)],
          ),
          const dom.p(
            classes: 'hui-inspector-subtitle',
            <Widget>[
              Text(
                'Nothing is selected, so these are the settings for the whole '
                'menu. Pick a component to edit it.',
              ),
            ],
          ),
        ],
      );

  Widget _placement() => InspectorSection(
        title: 'Placement',
        children: <Widget>[
          HuiField(
            label: 'Offset',
            required: true,
            help: 'Where the menu sits relative to the player, in blocks, at '
                'the moment it opens. Measured from the feet, so y 1.7 is about '
                'eye level and z is how far in front of them it floats.',
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
            help: 'Freezes the player while the menu is open: movement is '
                'rewritten back and velocity is zeroed every tick.',
            onChanged: (bool value) => store.mutate(
              'menu lockPosition',
              (HuiMenu menu) => menu.lockPosition = value,
            ),
          ),
          HuiSwitchRow(
            label: 'Follow player',
            value: _menu.followPlayer,
            help: 'Re-centres the menu on the player as they move, keeping the '
                'facing it opened with.',
            warning: _menu.lockPosition && _menu.followPlayer
                ? 'Lock position is on, which freezes the player, so this '
                    'never runs. Turn lock position off if you want the menu to '
                    'follow.'
                : null,
            onChanged: (bool value) => store.mutate(
              'menu followPlayer',
              (HuiMenu menu) => menu.followPlayer = value,
            ),
          ),
          _maxDistance(),
        ],
      );

  Widget _maxDistance() {
    final double? value = _menu.maxDistance;
    final bool unlimited = value == null;
    return HuiField(
      label: 'Max distance',
      help: 'Closes the menu when the player gets further than this from the '
          'menu centre. Clamped by the plugin to 0 - 60000000.',
      trailing: dom.div(
        classes: 'hui-inline-check',
        <Widget>[
          ArcaneCheckbox(
            checked: unlimited,
            size: ComponentSize.sm,
            label: 'Unlimited',
            onChanged: (bool checked) => store.mutate(
              'menu maxDistance',
              (HuiMenu menu) => menu.maxDistance = checked ? null : 8,
            ),
          ),
        ],
      ),
      control: dom.div(<Widget>[
        if (unlimited)
          const HuiNote(
            'Unlimited: the key is left out of the JSON entirely, which the '
            'plugin reads as 60000000 blocks.',
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
        description: 'A player can only have one menu open at a time; opening '
            'another replaces this one.',
        children: <Widget>[
          HuiSwitchRow(
            label: 'Close on death',
            value: _menu.closeOnDeath,
            help: 'Closes when the player dies.',
            onChanged: (bool value) => store.mutate(
              'menu closeOnDeath',
              (HuiMenu menu) => menu.closeOnDeath = value,
            ),
          ),
          HuiSwitchRow(
            label: 'Close on teleport',
            value: _menu.closeOnTeleport,
            help: 'Closes on any teleport, including plugin teleports and '
                'portals. Missing from the shipped JSON schema, but the plugin '
                'honours it.',
            onChanged: (bool value) => store.mutate(
              'menu closeOnTeleport',
              (HuiMenu menu) => menu.closeOnTeleport = value,
            ),
          ),
        ],
      );

  Widget _install() => InspectorSection(
        title: 'Install on the server',
        children: <Widget>[
          HuiDetailRow('Menu file', 'plugins/holoui/menus/${store.menuId}.json'),
          const HuiDetailRow('Images', 'plugins/holoui/images/'),
          HuiDetailRow('Test command', '/holoui open ${store.menuId}'),
          HuiDetailRow(
            'Permissions',
            'holoui.command.open + holoui.open.${store.menuId}',
          ),
          const HuiNote(
            'The menu id is the file base name, so renaming the file renames '
            'the menu. Only the direct children of menus/ are registered - '
            'subfolders are ignored.',
            title: 'Flat directory',
          ),
          const HuiNote(
            'Saving over an existing file re-registers it within about 5 ticks '
            'and closes every session that had it open. New and deleted files '
            'are picked up within about 20 ticks.',
            title: 'Hot reload',
          ),
          const HuiNote(
            'holoui.open.<id> is not declared in plugin.yml, so it has to be '
            'granted explicitly in your permissions plugin. Command aliases: '
            'holo, hui, holou, hu.',
            tone: HuiNoteTone.info,
            title: 'Permission trap',
          ),
        ],
      );

  Widget _nonFeatures() => const InspectorSection(
        title: 'Not in this format',
        children: <Widget>[
          HuiNote(
            'The menu root has exactly seven keys. There is no background, no '
            'scale or rotation, no title, no per-menu permission, no version '
            'and no localization of menu text - none of those exist in the '
            'plugin, so the editor does not offer them.',
          ),
        ],
      );
}
