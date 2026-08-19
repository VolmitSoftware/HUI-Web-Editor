/// Starter templates.
///
/// Applying a template never overwrites the open document: it creates a new
/// workspace entry, so the menu you were editing is still one click away in the
/// document switcher.
///
/// The tabs, notes and template grids all come from the document-type
/// registry: a kind offers templates by returning a
/// [DocumentTypeAdapter.templatesTabLabel] and sections, so a new kind never
/// touches this dialog.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../doctype/doctype.dart';
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
  static final List<DocumentTypeAdapter> _tabs = <DocumentTypeAdapter>[
    for (final DocumentTypeAdapter type in DocumentTypeRegistry.all)
      if (type.templatesTabLabel != null) type,
  ];

  DocumentTypeAdapter _kind = _tabs.first;
  final Map<DocumentTypeAdapter, String> _selected =
      <DocumentTypeAdapter, String>{};

  @override
  void didUpdateComponent(TemplatesDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!oldComponent.isOpen && component.isOpen) {
      // Opening on top of a document whose kind has templates starts the
      // picker on the matching tab: another kind's template would just create
      // an unrelated second document.
      final DocumentTypeAdapter active = component.store.docType;
      _kind = active.templatesTabLabel != null ? active : _tabs.first;
      for (final DocumentTypeAdapter type in _tabs) {
        _selected[type] = _firstTemplateId(type);
      }
    }
  }

  static String _firstTemplateId(DocumentTypeAdapter type) =>
      type.templateSections.first.templates.first.id;

  DocumentTemplate? _selectedTemplate() {
    final String? id = _selected[_kind] ?? _firstTemplateIdOrNull(_kind);
    if (id == null) return null;
    for (final DocumentTemplateSection section in _kind.templateSections) {
      for (final DocumentTemplate template in section.templates) {
        if (template.id == id) return template;
      }
    }
    return null;
  }

  static String? _firstTemplateIdOrNull(DocumentTypeAdapter type) {
    for (final DocumentTemplateSection section in type.templateSections) {
      for (final DocumentTemplate template in section.templates) {
        return template.id;
      }
    }
    return null;
  }

  void _apply() {
    final DocumentTemplate? template = _selectedTemplate();
    if (template == null) return;
    template.create(component.store);
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
    maxWidth: 1120,
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
    classes: 'hui-dialog-body hui-template-dialog-body hui-stagger',
    <Widget>[
      dom.div(classes: 'hui-template-tabs', <Widget>[
        ArcaneToggleGroup(
          value: _kind.kind.name,
          variant: ToggleGroupVariant.outline,
          size: ToggleGroupSize.sm,
          onChanged: (String? value) {
            if (value == null) return;
            for (final DocumentTypeAdapter type in _tabs) {
              if (type.kind.name == value) setState(() => _kind = type);
            }
          },
          items: <ToggleGroupItem>[
            for (final DocumentTypeAdapter type in _tabs)
              ToggleGroupItem(
                value: type.kind.name,
                child: Text(type.templatesTabLabel!),
              ),
          ],
        ),
      ]),
      dom.p(classes: 'hui-dialog-note', <Widget>[Text(_kind.templatesNote)]),
      ..._sections(),
    ],
  );

  List<Widget> _sections() {
    final List<DocumentTemplateSection> sections = _kind.templateSections;
    if (sections.length == 1 && sections.single.title == null) {
      return <Widget>[_grid(sections.single.templates)];
    }
    return <Widget>[
      dom.div(classes: 'hui-option-groups', <Widget>[
        for (final DocumentTemplateSection section in sections) ...<Widget>[
          _groupHeading(section.title ?? '', section.note ?? ''),
          _grid(section.templates),
        ],
      ]),
    ];
  }

  Widget _grid(List<DocumentTemplate> templates) =>
      dom.div(classes: 'hui-option-grid', <Widget>[
        for (final DocumentTemplate template in templates) _card(template),
      ]);

  Widget _groupHeading(String title, String note) =>
      dom.div(classes: 'hui-option-group-head', <Widget>[
        HuiEyebrow(title),
        dom.p(classes: 'hui-dialog-note', <Widget>[Text(note)]),
      ]);

  Widget _card(DocumentTemplate template) {
    final bool selected =
        (_selected[_kind] ?? _firstTemplateIdOrNull(_kind)) == template.id;
    return dom.button(
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
        'click': (Object _) => setState(() => _selected[_kind] = template.id),
        'dblclick': (Object _) {
          setState(() => _selected[_kind] = template.id);
          _apply();
        },
      },
      <Widget>[
        dom.div(classes: 'hui-option-card-head', <Widget>[
          dom.strong(<Widget>[Text(template.name)]),
          dom.code(classes: 'hui-option-card-id', <Widget>[
            Text('${template.id}.json'),
          ]),
        ]),
        dom.p(classes: 'hui-option-card-text', <Widget>[
          Text(template.description),
        ]),
        HuiChips(labels: template.highlights),
      ],
    );
  }
}
