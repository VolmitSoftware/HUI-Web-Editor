/// One-click starting points for an action list.
///
/// Navigation presets use the runtime's native page action. Move remains a
/// player command because it changes the live personal session's anchor.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../state/editor_scope.dart';
import '../../state/workspace.dart';
import '../common/class_names.dart';

class ActionPresetsRow extends StatelessWidget {
  const ActionPresetsRow({
    required this.menuId,
    required this.onInsert,
    this.classes = '',
    super.key,
  });

  /// This document's id, prefilled into the open-menu preset. It is also the
  /// permission node suffix the opening player needs.
  final String menuId;

  final void Function(HuiAction action) onInsert;
  final String classes;

  List<HuiNavigateAction> _workspaceMenuPresets(BuildContext context) {
    final Workspace workspace = EditorScope.of(context).workspace;
    final List<WorkspaceDoc> menus = workspace.docs
        .where((WorkspaceDoc doc) => doc.kind == WorkspaceDocKind.menu)
        .toList();
    menus.sort((WorkspaceDoc left, WorkspaceDoc right) {
      final int recent = right.updatedAt.compareTo(left.updatedAt);
      return recent != 0 ? recent : left.runtimeId!.compareTo(right.runtimeId!);
    });
    return <HuiNavigateAction>[
      for (final WorkspaceDoc doc in menus.take(6))
        HuiNavigateAction(doc.runtimeId!, 'push'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<HuiNavigateAction> workspacePresets = _workspaceMenuPresets(
      context,
    );
    return dom.div(
      classes: classNames(<String?>['hui-action-presets', classes]),
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '6px',
          'min-width': '0',
        },
      ),
      <Widget>[
        dom.div(
          classes: 'hui-action-presets-row',
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'flex',
              'flex-wrap': 'wrap',
              'align-items': 'center',
              'gap': '6px',
              'min-width': '0',
            },
          ),
          <Widget>[
            _preset(
              label: 'Open menu',
              icon: ArcaneIcon.externalLink(size: IconSize.sm),
              hint:
                  'Pushes $menuId onto this viewer\'s native page stack. The '
                  'viewer needs holoui.open.$menuId.',
              build: () => HuiNavigateAction(menuId, 'push'),
            ),
            for (final HuiNavigateAction navigation in workspacePresets)
              _preset(
                label: 'Open ${navigation.target.split('/').last}',
                icon: ArcaneIcon.folderInput(size: IconSize.sm),
                hint:
                    'Opens ${navigation.target} and pushes this page onto the '
                    'viewer\'s native menu stack.',
                build: () => HuiNavigateAction(navigation.target, 'push'),
              ),
            _preset(
              label: 'Back',
              icon: ArcaneIcon.undo(size: IconSize.sm),
              hint:
                  'Pops the viewer\'s native page stack without dispatching a '
                  'command.',
              build: () => HuiNavigateAction('', 'back'),
            ),
            _preset(
              label: 'Close',
              icon: ArcaneIcon.x(size: IconSize.sm),
              hint:
                  'Closes the viewer\'s current menu flow without dispatching a '
                  'command.',
              build: () => HuiNavigateAction('', 'close'),
            ),
            _preset(
              label: 'Move here',
              icon: ArcaneIcon.move(size: IconSize.sm),
              hint:
                  'holoui move, as the player. Reanchors the open menu from '
                  'their current position using its configured offset. The '
                  'player needs holoui.command and holoui.command.move.',
              build: () => HuiCommandAction('holoui move', 'player'),
            ),
            _preset(
              label: 'Tell player',
              icon: ArcaneIcon.messageCircle(size: IconSize.sm),
              hint:
                  'Sends MiniMessage text to the clicking player. %player% and '
                  'PlaceholderAPI placeholders resolve for that player.',
              build: () => HuiMessageAction(
                '<gold>Hello <white>%player%</white></gold>',
              ),
            ),
            _preset(
              label: 'Teleport',
              icon: ArcaneIcon.locateFixed(size: IconSize.sm),
              hint:
                  'Asynchronously teleports the clicking player to coordinates '
                  'in an already-loaded namespaced world.',
              build: () =>
                  HuiTeleportAction('minecraft:overworld', 0, 64, 0, 0, 0),
            ),
            _preset(
              label: 'Connect server',
              icon: ArcaneIcon.share2(size: IconSize.sm),
              hint:
                  'Requests the proxy server named lobby through the fixed '
                  'BungeeCord Connect channel.',
              build: () => HuiConnectAction('lobby'),
            ),
            _preset(
              label: 'Run as player',
              icon: ArcaneIcon.mousePointerClick(size: IconSize.sm),
              hint:
                  'An empty command run as the clicking player, with their '
                  'own permissions.',
              build: () => HuiCommandAction('', 'player'),
            ),
            _preset(
              label: 'Run as console',
              icon: ArcaneIcon.terminal(size: IconSize.sm),
              hint:
                  'An empty command run from the server console, with full '
                  'privileges and no permission check against the player.',
              build: () => HuiCommandAction('', 'server'),
            ),
          ],
        ),
        const dom.p(
          classes: 'hui-action-presets-note',
          styles: dom.Styles(
            raw: <String, String>{
              'margin': '0',
              'font-size': '0.72rem',
              'line-height': '1.45',
              'color': 'var(--muted-foreground)',
            },
          ),
          <Widget>[
            Text(
              'Command presets always write source: a command that leaves it out runs '
              'as the player, but the file reads better when it says so. '
              'Navigation is native and per viewer. Move still runs as the '
              'player because the console is not in a menu. Presets start on '
              'Any click; each inserted row can use a different trigger.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _preset({
    required String label,
    required Widget icon,
    required String hint,
    required HuiAction Function() build,
  }) => ArcaneTooltip(
    text: hint,
    child: Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.sm,
      icon: icon,
      onPressed: () => onInsert(build()),
      attributes: <String, String>{'aria-label': 'Add action: $label'},
      child: Text(label),
    ),
  );
}
