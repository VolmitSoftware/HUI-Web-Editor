library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/tablist_selection.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class TablistInspector extends StatefulWidget {
  const TablistInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<TablistInspector> createState() => _TablistInspectorState();
}

class _TablistInspectorState extends State<TablistInspector> {
  EditorStore get _store => component.store;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossTablistDoc? doc = _store.tablistDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-tablist', <Widget>[
      _header(doc),
      _headerFooter(doc),
      _listNames(doc),
    ]);
  }

  Widget _header(GlossTablistDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-tablist', <Widget>[
          HuiEyebrow(huiText('Tablist')),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('tablist.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              'Header/footer and list names select their own complete '
              'presentation per viewer and listed player.',
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]);

  Widget _headerFooter(GlossTablistDoc doc) => InspectorSection(
    title: huiText('Header and footer'),
    children: <Widget>[
      HuiSwitchRow(
        label: huiText('Enabled'),
        trailing: const HuiFieldHelp('tablist.headerFooter.enabled'),
        value: doc.headerFooter.enabled,
        onChanged: (bool value) => _store.mutateTablist(
          'tablist header/footer enabled',
          (GlossTablistDoc edited) => edited.headerFooter.enabled = value,
        ),
      ),
      _headerFooterPresentation(
        doc.headerFooter.presentation,
        r'$.headerFooter.presentation',
        (void Function(GlossTablistHeaderFooterPresentation) mutate) =>
            _store.mutateTablist(
              'tablist header/footer presentation',
              (GlossTablistDoc edited) =>
                  mutate(edited.headerFooter.presentation),
            ),
      ),
      for (int index = 0; index < doc.headerFooter.variants.length; index++)
        _headerFooterVariant(doc, index),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: () => _store.mutateTablist(
          'add header/footer variant',
          (GlossTablistDoc edited) => edited.headerFooter.variants.add(
            GlossTablistHeaderFooterVariant(
              id: _nextHeaderFooterId(edited),
              when: "viewer.world == 'world_nether'",
              presentation: edited.headerFooter.presentation.copy(),
            ),
          ),
        ),
        child: Text(huiText('Add header/footer variant')),
      ),
    ],
  );

  Widget _headerFooterVariant(GlossTablistDoc doc, int index) {
    final GlossTablistHeaderFooterVariant variant =
        doc.headerFooter.variants[index];
    final String path =
        r'$.headerFooter.variants['
        '$index]';
    return dom.div(classes: 'hui-tablist-variant', <Widget>[
      _variantHeader(
        id: variant.id,
        index: index,
        onDelete: () => _store.mutateTablist(
          'delete header/footer variant',
          (GlossTablistDoc edited) =>
              edited.headerFooter.variants.removeAt(index),
        ),
      ),
      _idField(
        value: variant.id,
        path: '$path.id',
        onChanged: (String value) => _store.mutateTablist(
          'header/footer variant id',
          (GlossTablistDoc edited) =>
              edited.headerFooter.variants[index].id = value,
        ),
      ),
      _priorityField(
        value: variant.priority,
        path: '$path.priority',
        onChanged: (int value) => _store.mutateTablist(
          'header/footer variant priority',
          (GlossTablistDoc edited) =>
              edited.headerFooter.variants[index].priority = value,
        ),
      ),
      _conditionField(
        value: variant.when,
        path: '$path.when',
        onChanged: (String value) => _store.mutateTablist(
          'header/footer variant condition',
          (GlossTablistDoc edited) =>
              edited.headerFooter.variants[index].when = value,
        ),
      ),
      _headerFooterPresentation(
        variant.presentation,
        '$path.presentation',
        (void Function(GlossTablistHeaderFooterPresentation) mutate) =>
            _store.mutateTablist(
              'header/footer variant presentation',
              (GlossTablistDoc edited) =>
                  mutate(edited.headerFooter.variants[index].presentation),
            ),
      ),
    ]);
  }

  Widget _headerFooterPresentation(
    GlossTablistHeaderFooterPresentation presentation,
    String path,
    void Function(void Function(GlossTablistHeaderFooterPresentation)) mutate,
  ) => dom.div(classes: 'hui-tablist-presentation', <Widget>[
    _textField(
      label: huiText('Header'),
      value: presentation.header,
      path: '$path.header',
      helpKey: 'tablist.headerFooter.presentation.header',
      onChanged: (String value) =>
          mutate((GlossTablistHeaderFooterPresentation edited) {
            edited.header = value;
          }),
    ),
    _textField(
      label: huiText('Footer'),
      value: presentation.footer,
      path: '$path.footer',
      helpKey: 'tablist.headerFooter.presentation.footer',
      onChanged: (String value) =>
          mutate((GlossTablistHeaderFooterPresentation edited) {
            edited.footer = value;
          }),
    ),
  ]);

  Widget _listNames(GlossTablistDoc doc) => InspectorSection(
    title: huiText('List names'),
    children: <Widget>[
      HuiSwitchRow(
        label: huiText('Enabled'),
        trailing: const HuiFieldHelp('tablist.listNames.enabled'),
        value: doc.listNames.enabled,
        onChanged: (bool value) => _store.mutateTablist(
          'tablist list names enabled',
          (GlossTablistDoc edited) => edited.listNames.enabled = value,
        ),
      ),
      _formatField(
        label: huiText('Default format'),
        presentation: doc.listNames.presentation,
        path: r'$.listNames.presentation',
        onChanged: (String value) => _store.mutateTablist(
          'tablist default list-name format',
          (GlossTablistDoc edited) =>
              edited.listNames.presentation.format = value,
        ),
      ),
      for (int index = 0; index < doc.listNames.variants.length; index++)
        _listNameVariant(doc, index),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: () => _store.mutateTablist(
          'add list-name variant',
          (GlossTablistDoc edited) => edited.listNames.variants.add(
            GlossTablistListNameVariant(
              id: _nextListNameId(edited),
              when: "inGroup('subject', 'vip')",
              presentation: edited.listNames.presentation.copy(),
            ),
          ),
        ),
        child: Text(huiText('Add list-name variant')),
      ),
      HuiNote(
        huiText(
          r'Use $player and $group in formats. Highest priority wins; equal '
          'priorities use the smaller variant id.',
        ),
      ),
    ],
  );

  Widget _listNameVariant(GlossTablistDoc doc, int index) {
    final GlossTablistListNameVariant variant = doc.listNames.variants[index];
    final String path =
        r'$.listNames.variants['
        '$index]';
    return dom.div(classes: 'hui-tablist-variant', <Widget>[
      _variantHeader(
        id: variant.id,
        index: index,
        onDelete: () => _store.mutateTablist(
          'delete list-name variant',
          (GlossTablistDoc edited) => edited.listNames.variants.removeAt(index),
        ),
      ),
      _idField(
        value: variant.id,
        path: '$path.id',
        onChanged: (String value) => _store.mutateTablist(
          'list-name variant id',
          (GlossTablistDoc edited) =>
              edited.listNames.variants[index].id = value,
        ),
      ),
      _priorityField(
        value: variant.priority,
        path: '$path.priority',
        onChanged: (int value) => _store.mutateTablist(
          'list-name variant priority',
          (GlossTablistDoc edited) =>
              edited.listNames.variants[index].priority = value,
        ),
      ),
      _conditionField(
        value: variant.when,
        path: '$path.when',
        onChanged: (String value) => _store.mutateTablist(
          'list-name variant condition',
          (GlossTablistDoc edited) =>
              edited.listNames.variants[index].when = value,
        ),
      ),
      _formatField(
        label: huiText('Variant format'),
        presentation: variant.presentation,
        path: '$path.presentation',
        onChanged: (String value) => _store.mutateTablist(
          'list-name variant format',
          (GlossTablistDoc edited) =>
              edited.listNames.variants[index].presentation.format = value,
        ),
      ),
    ]);
  }

  Widget _variantHeader({
    required String id,
    required int index,
    required void Function() onDelete,
  }) => dom.div(classes: 'hui-inspector-title-row', <Widget>[
    HuiEyebrow(
      huiText('Variant {id}', <String, Object?>{
        'id': id.isEmpty ? index + 1 : id,
      }),
    ),
    HuiIconButton(
      label: huiText('Delete variant'),
      icon: ArcaneIcon.trash2(size: IconSize.sm),
      onPressed: onDelete,
    ),
  ]);

  Widget _idField({
    required String value,
    required String path,
    required void Function(String) onChanged,
  }) => HuiField(
    label: huiText('Id'),
    control: dom.div(<Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        onInput: onChanged,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _priorityField({
    required int value,
    required String path,
    required void Function(int) onChanged,
  }) => HuiField(
    label: huiText('Priority'),
    control: dom.div(<Widget>[
      TextInput(
        value: '$value',
        size: ComponentSize.sm,
        fullWidth: true,
        onInput: (String raw) {
          final int? parsed = int.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        },
        styles: huiTechnicalInputStyles,
        attributes: <String, String>{
          ...huiTechnicalInputAttributes,
          'inputmode': 'numeric',
        },
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _conditionField({
    required String value,
    required String path,
    required void Function(String) onChanged,
  }) => HuiField(
    label: huiText('When'),
    trailing: const HuiFieldHelp('condition.when'),
    control: dom.div(<Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText("viewer.world == 'world'"),
        onInput: onChanged,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _textField({
    required String label,
    required String value,
    required String path,
    required String helpKey,
    required void Function(String) onChanged,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(helpKey),
    control: dom.div(<Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        onInput: onChanged,
        attributes: const <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
        },
      ),
      _pipelinePreview(value),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _formatField({
    required String label,
    required GlossTablistListNamePresentation presentation,
    required String path,
    required void Function(String) onChanged,
  }) => HuiField(
    label: label,
    trailing: const HuiFieldHelp('tablist.listNames.presentation.format'),
    control: dom.div(<Widget>[
      TextInput(
        value: presentation.format,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText(r'&7$player'),
        onInput: onChanged,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      GlossTextLine(
        render: renderGlossLine(
          glossTablistSubstituteTokens(
            presentation.format,
            'Cyberpwn',
            'owner',
          ),
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
        ),
      ),
      HuiInlineIssues(_issuesFor('$path.format')),
    ]),
  );

  Widget _pipelinePreview(String text) =>
      dom.div(classes: 'hui-hologram-line-preview', <Widget>[
        for (final String line in text.split('\n'))
          dom.div(<Widget>[
            GlossTextLine(
              render: renderGlossLine(
                line,
                animations: _store.workspaceAnimations,
                emoji: _store.workspaceEmoji,
              ),
            ),
          ]),
      ]);

  String _nextHeaderFooterId(GlossTablistDoc doc) => _nextId(<String>[
    for (final GlossTablistHeaderFooterVariant variant
        in doc.headerFooter.variants)
      variant.id,
  ]);

  String _nextListNameId(GlossTablistDoc doc) => _nextId(<String>[
    for (final GlossTablistListNameVariant variant in doc.listNames.variants)
      variant.id,
  ]);

  String _nextId(List<String> ids) {
    int suffix = ids.length + 1;
    String id = 'variant-$suffix';
    while (ids.contains(id)) {
      suffix++;
      id = 'variant-$suffix';
    }
    return id;
  }
}
