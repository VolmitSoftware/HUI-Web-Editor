/// Starter templates.
///
/// Applying a template never overwrites the open document: it creates a new
/// workspace entry, so the menu you were editing is still one click away in the
/// document switcher.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/preview_templates.dart';
import '../../config/templates.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';

enum _TemplateKind { menu, preview }

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
  _TemplateKind _kind = _TemplateKind.menu;
  String _selectedMenuId = huiTemplates.first.id;
  String _selectedPreviewId = huiPreviewTemplates.first.id;

  @override
  void didUpdateComponent(TemplatesDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!oldComponent.isOpen && component.isOpen) {
      // Opening on top of a container-preview document starts the picker on
      // the matching tab: a menu template would just create an unrelated
      // second document.
      _kind = component.store.isPreviewDoc
          ? _TemplateKind.preview
          : _TemplateKind.menu;
      _selectedMenuId = huiTemplates.first.id;
      _selectedPreviewId = huiPreviewTemplates.first.id;
    }
  }

  void _apply() {
    switch (_kind) {
      case _TemplateKind.menu:
        final HuiTemplate? template = huiTemplateById(_selectedMenuId);
        if (template == null) return;
        component.store.createDocumentFromMenu(template.id, template.build());
        toast.success(
          'Created "${template.id}" from the ${template.name} template',
        );
      case _TemplateKind.preview:
        final HuiPreviewTemplate? template = huiPreviewTemplateById(
          _selectedPreviewId,
        );
        if (template == null) return;
        component.store.createDocumentFromPreview(
          template.id,
          template.build(),
        );
        toast.success(
          'Created "${template.id}" from the ${template.name} template',
        );
    }
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

  Widget _body() => dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
    dom.div(
      styles: const dom.Styles(raw: <String, String>{'margin-bottom': '12px'}),
      <Widget>[
        ArcaneToggleGroup(
          value: _kind.name,
          variant: ToggleGroupVariant.outline,
          size: ToggleGroupSize.sm,
          onChanged: (String? value) {
            if (value == null) return;
            setState(() => _kind = _TemplateKind.values.byName(value));
          },
          items: const <ToggleGroupItem>[
            ToggleGroupItem(value: 'menu', child: Text('Menu')),
            ToggleGroupItem(value: 'preview', child: Text('Container preview')),
          ],
        ),
      ],
    ),
    dom.p(classes: 'hui-dialog-note', <Widget>[
      Text(
        _kind == _TemplateKind.menu
            ? 'Every template is valid as-is: sounds carry a category '
                  'and a volume, commands carry a source, and no '
                  'template references an image you do not have. It '
                  'opens as a new document, so your current one is '
                  'untouched.'
            : 'On the server are the thirteen cards the plugin extracts '
                  'into plugins/holoui/previews/, byte for byte. Starters '
                  'are teaching documents the jar does not ship. Every '
                  'template opens as a new document, so your current one '
                  'is untouched.',
      ),
    ]),
    if (_kind == _TemplateKind.menu)
      dom.div(
        classes: 'hui-option-grid',
        <Widget>[for (final HuiTemplate t in huiTemplates) _menuCard(t)],
      )
    else
      _previewGroups(),
  ]);

  Widget _previewGroups() =>
      dom.div(classes: 'hui-option-groups', <Widget>[
        _groupHeading(
          'On the server',
          'These are the cards HoloUI already draws in game.',
        ),
        dom.div(classes: 'hui-option-grid', <Widget>[
          for (final HuiPreviewTemplate template in huiPreviewTemplates)
            if (template.inGame) _previewCard(template),
        ]),
        _groupHeading(
          'Starters',
          'Teaching documents. They are not extracted by the plugin.',
        ),
        dom.div(classes: 'hui-option-grid', <Widget>[
          for (final HuiPreviewTemplate template in huiPreviewTemplates)
            if (!template.inGame) _previewCard(template),
        ]),
      ]);

  Widget _groupHeading(String title, String note) =>
      dom.div(classes: 'hui-option-group-head', <Widget>[
        HuiEyebrow(title),
        dom.p(classes: 'hui-dialog-note', <Widget>[Text(note)]),
      ]);

  Widget _menuCard(HuiTemplate template) => _card(
    id: template.id,
    name: template.name,
    description: template.description,
    highlights: template.highlights,
    selected: template.id == _selectedMenuId,
    onSelect: () => setState(() => _selectedMenuId = template.id),
  );

  Widget _previewCard(HuiPreviewTemplate template) => _card(
    id: template.id,
    name: template.name,
    description: template.description,
    highlights: template.highlights,
    selected: template.id == _selectedPreviewId,
    onSelect: () => setState(() => _selectedPreviewId = template.id),
  );

  Widget _card({
    required String id,
    required String name,
    required String description,
    required List<String> highlights,
    required bool selected,
    required void Function() onSelect,
  }) => dom.button(
    classes: classNames(<String?>[
      'hui-option-card',
      'hui-lift',
      selected ? 'is-selected' : null,
    ]),
    attributes: <String, String>{
      'type': 'button',
      'aria-pressed': selected ? 'true' : 'false',
    },
    events: <String, void Function(Object)>{
      'click': (Object _) => onSelect(),
      'dblclick': (Object _) {
        onSelect();
        _apply();
      },
    },
    <Widget>[
      dom.div(classes: 'hui-option-card-head', <Widget>[
        dom.strong(<Widget>[Text(name)]),
        dom.code(classes: 'hui-option-card-id', <Widget>[Text('$id.json')]),
      ]),
      dom.p(classes: 'hui-option-card-text', <Widget>[Text(description)]),
      HuiChips(labels: highlights),
    ],
  );
}
