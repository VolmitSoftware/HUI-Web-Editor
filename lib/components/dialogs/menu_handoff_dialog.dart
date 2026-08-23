library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../state/workspace_route.dart';
import 'dialog_parts.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class MenuHandoffDialog extends StatelessWidget {
  const MenuHandoffDialog({
    required this.envelope,
    required this.onConfirm,
    required this.onClose,
    super.key,
  });

  final WorkspaceMenuImportEnvelope? envelope;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final WorkspaceMenuImportEnvelope? pending = envelope;
    final HuiMenu? menu = pending == null ? null : decodeHuiMenu(pending.json);
    return ArcaneDialog(
      id: 'hui-menu-handoff-dialog',
      isOpen: pending != null,
      onClose: onClose,
      title: huiText('Import menu from server'),
      maxWidth: 720,
      actions: <Widget>[
        Button(
          variant: ButtonVariant.outline,
          onPressed: onClose,
          label: huiText('Cancel'),
        ),
        Button(
          variant: ButtonVariant.primary,
          disabled: pending == null,
          onPressed: pending == null ? null : onConfirm,
          icon: ArcaneIcon.filePlus(size: IconSize.sm),
          label: huiText('Add to library'),
        ),
      ],
      children: <Widget>[
        if (pending != null && menu != null)
          dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
            ArcaneAlert.warning(
              message: huiText(
                'This link cannot replace a document automatically. Review the menu, then add it as a new workspace document.',
              ),
            ),
            HuiDialogSection(
              title: huiText('Proposed document'),
              description: huiText(
                'The runtime id is preserved exactly, including nested '
                'folder segments.',
              ),
              children: <Widget>[
                dom.dl(classes: 'hui-handoff-details', <Widget>[
                  dom.dt(<Widget>[Text(huiText('Runtime id'))]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[Text(pending.runtimeId)]),
                  ]),
                  dom.dt(<Widget>[Text(huiText('Components'))]),
                  dom.dd(<Widget>[
                    Text(
                      huiText("{length}", <String, Object?>{
                        'length': menu.components.length,
                      }),
                    ),
                  ]),
                ]),
              ],
            ),
            HuiDialogSection(
              title: huiText('Menu JSON'),
              children: <Widget>[
                HuiCodeBlock(
                  text: pending.json.length <= 12000
                      ? pending.json
                      : '${pending.json.substring(0, 12000)}\n…',
                  scroll: true,
                ),
              ],
            ),
          ]),
      ],
    );
  }
}
