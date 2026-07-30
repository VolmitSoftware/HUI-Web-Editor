/// Starter templates.
///
/// Applying a template never overwrites the open document: it creates a new
/// workspace entry, so the menu you were editing is still one click away in the
/// document switcher.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/templates.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';

class TemplatesDialog extends StatefulWidget {
  const TemplatesDialog({
    required this.store,
    required this.isOpen,
    required this.onClose,
    super.key,
  });

  final EditorStore store;
  final bool isOpen;
  final VoidCallback onClose;

  @override
  State<TemplatesDialog> createState() => _TemplatesDialogState();
}

class _TemplatesDialogState extends State<TemplatesDialog> {
  String _selectedId = huiTemplates.first.id;

  @override
  void didUpdateComponent(TemplatesDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!oldComponent.isOpen && component.isOpen) {
      _selectedId = huiTemplates.first.id;
    }
  }

  void _apply() {
    final HuiTemplate? template = huiTemplateById(_selectedId);
    if (template == null) return;
    final HuiMenu menu = template.build();
    component.store.createDocumentFromMenu(template.id, menu);
    toast.success(
      'Created "${template.id}" from the ${template.name} template',
    );
    component.onClose();
  }

  @override
  Widget build(BuildContext context) => ArcaneDialog(
        id: 'hui-templates-dialog',
        isOpen: component.isOpen,
        onClose: component.onClose,
        title: 'Start from a template',
        maxWidth: 820,
        actions: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            onPressed: component.onClose,
            label: 'Cancel',
          ),
          Button(
            variant: ButtonVariant.primary,
            onPressed: _apply,
            icon: ArcaneIcon.plus(size: IconSize.sm),
            label: 'Create document',
          ),
        ],
        children: <Widget>[_body()],
      );

  Widget _body() => dom.div(
        classes: 'hui-dialog-body',
        <Widget>[
          const dom.p(
            classes: 'hui-dialog-note',
            <Widget>[
              Text(
                'Every template is valid as-is: sounds carry a category and a '
                'volume, commands carry a source, and no template references an '
                'image you do not have. It opens as a new document, so your '
                'current menu is untouched.',
              ),
            ],
          ),
          dom.div(
            classes: 'hui-option-grid',
            <Widget>[
              for (final HuiTemplate template in huiTemplates) _card(template),
            ],
          ),
        ],
      );

  Widget _card(HuiTemplate template) {
    final bool selected = template.id == _selectedId;
    return dom.button(
      classes: classNames(<String?>[
        'hui-option-card',
        selected ? 'is-selected' : null,
      ]),
      attributes: <String, String>{
        'type': 'button',
        'aria-pressed': selected ? 'true' : 'false',
      },
      events: <String, void Function(Object)>{
        'click': (Object _) => setState(() => _selectedId = template.id),
        'dblclick': (Object _) {
          setState(() => _selectedId = template.id);
          _apply();
        },
      },
      <Widget>[
        dom.div(
          classes: 'hui-option-card-head',
          <Widget>[
            dom.strong(<Widget>[Text(template.name)]),
            dom.code(
              classes: 'hui-option-card-id',
              <Widget>[Text('${template.id}.json')],
            ),
          ],
        ),
        dom.p(
          classes: 'hui-option-card-text',
          <Widget>[Text(template.description)],
        ),
        HuiChips(labels: template.highlights),
      ],
    );
  }
}
