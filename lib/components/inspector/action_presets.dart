/// One-click starting points for an action list.
///
/// Every preset is a command action, because commands and sounds are the only
/// action types the format has and menu chaining is a command
/// (`HoloCommand.java:81,107,125` — `open`, `back`, `close`). All three of those
/// subcommands refuse a non-player sender, so they are emitted as `player`; the
/// generic pair emits `player` and `server` explicitly. Nothing here ever leaves
/// `source` out, even though an omitted source now takes the `player` default
/// (`CommandMenuAction.java:34-40`): the file should say which sender it meant.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
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

  @override
  Widget build(BuildContext context) => dom.div(
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
                'holoui open $menuId, as the player. Chaining menus is a '
                'command - there is no open-menu action type. The player '
                'needs holoui.command.open and holoui.open.$menuId.',
            build: () => HuiCommandAction('holoui open $menuId', 'player'),
          ),
          _preset(
            label: 'Back',
            icon: ArcaneIcon.undo(size: IconSize.sm),
            hint:
                'holoui back, as the player. Reopens whichever menu they '
                'had before this one.',
            build: () => HuiCommandAction('holoui back', 'player'),
          ),
          _preset(
            label: 'Close',
            icon: ArcaneIcon.x(size: IconSize.sm),
            hint:
                'holoui close, as the player. Closes the session they are '
                'clicking in.',
            build: () => HuiCommandAction('holoui close', 'player'),
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
            'Presets always write source: a command that leaves it out runs '
            'as the player, but the file reads better when it says so. '
            'Open, back and close only work as the player - the console is '
            'not in a menu.',
          ),
        ],
      ),
    ],
  );

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
