library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ScoreboardInspector extends StatefulWidget {
  const ScoreboardInspector({
    required this.store,
    required this.catalogs,
    super.key,
  });

  final EditorStore store;
  final HuiCatalogs catalogs;

  @override
  State<ScoreboardInspector> createState() => _ScoreboardInspectorState();
}

class _ScoreboardInspectorState extends State<ScoreboardInspector> {
  EditorStore get _store => component.store;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossScoreboardDoc? doc = _store.scoreboardDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-scoreboard', <Widget>[
      _header(doc),
      _selection(doc),
      _presentation(
        doc.presentation,
        r'$.presentation',
        huiText('Default presentation'),
        (void Function(GlossScoreboardPresentation) mutate) =>
            _store.mutateScoreboard(
              'scoreboard default presentation',
              (GlossScoreboardDoc edited) => mutate(edited.presentation),
            ),
      ),
      _variants(doc),
    ]);
  }

  Widget _header(
    GlossScoreboardDoc doc,
  ) => dom.div(classes: 'hui-inspector-headgroup', <Widget>[
    dom.div(classes: 'hui-inspector-header is-scoreboard', <Widget>[
      HuiEyebrow(huiText('Scoreboard')),
      dom.div(classes: 'hui-inspector-title-row', <Widget>[
        dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
          Text(_store.menuId),
        ]),
        const HuiFieldHelp('scoreboard.id'),
      ]),
    ]),
    dom.p(classes: 'hui-inspector-lede', <Widget>[
      Text(
        huiText(
          'The highest-priority eligible board is selected per viewer; '
          'its highest-priority matching variant supplies the complete sidebar.',
        ),
      ),
    ]),
    HuiRevisionRow(revision: doc.revision),
  ]);

  Widget _selection(GlossScoreboardDoc doc) => InspectorSection(
    title: huiText('Board selection'),
    children: <Widget>[
      _integerField(
        label: huiText('Priority'),
        value: doc.select.priority,
        path: r'$.select.priority',
        onChanged: (int value) => _store.mutateScoreboard(
          'scoreboard select priority',
          (GlossScoreboardDoc edited) => edited.select.priority = value,
        ),
      ),
      _conditionField(
        label: huiText('When'),
        value: doc.select.when,
        path: r'$.select.when',
        onChanged: (String value) => _store.mutateScoreboard(
          'scoreboard select condition',
          (GlossScoreboardDoc edited) => edited.select.when = value,
        ),
      ),
      HuiNote(
        huiText(
          'Highest priority wins; equal priorities use the smaller board id. '
          'A condition error fails closed.',
        ),
      ),
    ],
  );

  Widget _variants(GlossScoreboardDoc doc) => InspectorSection(
    title: huiText('Conditional variants'),
    children: <Widget>[
      for (int index = 0; index < doc.variants.length; index++)
        _variant(doc, index),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: () => _store.mutateScoreboard(
          'add scoreboard variant',
          (GlossScoreboardDoc edited) => edited.variants.add(
            GlossScoreboardVariant(
              id: _nextVariantId(edited),
              when: 'viewer.healthPercent <= 25',
              presentation: edited.presentation.copy(),
            ),
          ),
        ),
        label: huiText('Add variant'),
      ),
      HuiNote(
        huiText(
          'Variants are complete presentations. Matching variants never merge; '
          'the highest priority wins and the default is the fallback.',
        ),
      ),
    ],
  );

  Widget _variant(GlossScoreboardDoc doc, int index) {
    final GlossScoreboardVariant variant = doc.variants[index];
    final String path =
        r'$.variants['
        '$index]';
    return dom.div(classes: 'hui-scoreboard-variant', <Widget>[
      dom.div(classes: 'hui-inspector-title-row', <Widget>[
        HuiEyebrow(
          huiText('Variant {id}', <String, Object?>{
            'id': variant.id.isEmpty ? index + 1 : variant.id,
          }),
        ),
        HuiIconButton(
          label: huiText('Delete variant'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onPressed: () => _store.mutateScoreboard(
            'delete scoreboard variant',
            (GlossScoreboardDoc edited) => edited.variants.removeAt(index),
          ),
        ),
      ]),
      HuiField(
        label: huiText('Id'),
        control: dom.div(<Widget>[
          TextInput(
            value: variant.id,
            size: ComponentSize.sm,
            fullWidth: true,
            onInput: (String value) => _store.mutateScoreboard(
              'scoreboard variant id',
              (GlossScoreboardDoc edited) => edited.variants[index].id = value,
            ),
            styles: huiTechnicalInputStyles,
            attributes: huiTechnicalInputAttributes,
          ),
          HuiInlineIssues(_issuesFor('$path.id')),
        ]),
      ),
      _integerField(
        label: huiText('Priority'),
        value: variant.priority,
        path: '$path.priority',
        onChanged: (int value) => _store.mutateScoreboard(
          'scoreboard variant priority',
          (GlossScoreboardDoc edited) =>
              edited.variants[index].priority = value,
        ),
      ),
      _conditionField(
        label: huiText('When'),
        value: variant.when,
        path: '$path.when',
        onChanged: (String value) => _store.mutateScoreboard(
          'scoreboard variant condition',
          (GlossScoreboardDoc edited) => edited.variants[index].when = value,
        ),
      ),
      _presentation(
        variant.presentation,
        '$path.presentation',
        huiText('Variant presentation'),
        (void Function(GlossScoreboardPresentation) mutate) =>
            _store.mutateScoreboard(
              'scoreboard variant presentation',
              (GlossScoreboardDoc edited) =>
                  mutate(edited.variants[index].presentation),
            ),
      ),
    ]);
  }

  Widget _presentation(
    GlossScoreboardPresentation presentation,
    String path,
    String title,
    void Function(void Function(GlossScoreboardPresentation)) mutate,
  ) => InspectorSection(
    title: title,
    children: <Widget>[
      HuiField(
        label: huiText('Title'),
        trailing: const HuiFieldHelp('scoreboard.presentation.title'),
        control: dom.div(<Widget>[
          TextInput(
            value: presentation.title,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: huiText('&d&lGloss'),
            onInput: (String value) =>
                mutate((GlossScoreboardPresentation edited) {
                  edited.title = value;
                }),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          dom.div(classes: 'hui-hologram-line-preview', <Widget>[
            GlossTextLine(
              render: renderGlossScoreboardTitle(
                presentation.title,
                animations: _store.workspaceAnimations,
                emoji: _store.workspaceEmoji,
              ),
            ),
          ]),
          HuiInlineIssues(_issuesFor('$path.title')),
        ]),
      ),
      HuiSwitchRow(
        label: huiText('Hide score numbers'),
        trailing: const HuiFieldHelp('scoreboard.presentation.hideNumbers'),
        value: presentation.hideNumbers,
        onChanged: (bool value) => mutate((GlossScoreboardPresentation edited) {
          edited.hideNumbers = value;
        }),
      ),
      HuiLineListSection(
        title: huiText('Lines'),
        docKey: 'scoreboard.presentation.lines',
        addLabel: huiText('Add line'),
        itemCount: presentation.lines.length,
        issues: _issuesFor('$path.lines'),
        emptyBody: huiText('Add a line to put content under the title.'),
        onAdd: () => mutate(
          (GlossScoreboardPresentation edited) => edited.lines.add(''),
        ),
        onReorder: (int from, int to) =>
            mutate((GlossScoreboardPresentation edited) {
              final String moved = edited.lines.removeAt(from);
              edited.lines.insert(to, moved);
            }),
        itemBuilder: (int index) => HuiLineRow(
          value: presentation.lines[index],
          placeholder: huiText('&fText or {{ expression }}'),
          removeLabel: huiText('Delete line {number}', <String, Object?>{
            'number': index + 1,
          }),
          beyondRender: index >= glossBoardMaxLines,
          onChanged: (String value) =>
              mutate((GlossScoreboardPresentation edited) {
                edited.lines[index] = value;
              }),
          preview: GlossTextLine(
            render: renderGlossScoreboardLine(
              presentation.lines[index],
              animations: _store.workspaceAnimations,
              emoji: _store.workspaceEmoji,
            ),
          ),
          chips: const <Widget>[],
          onRemove: () => mutate(
            (GlossScoreboardPresentation edited) =>
                edited.lines.removeAt(index),
          ),
        ),
      ),
    ],
  );

  Widget _integerField({
    required String label,
    required int value,
    required String path,
    required void Function(int) onChanged,
  }) => HuiField(
    label: label,
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
    required String label,
    required String value,
    required String path,
    required void Function(String) onChanged,
  }) => HuiField(
    label: label,
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

  String _nextVariantId(GlossScoreboardDoc doc) {
    int suffix = doc.variants.length + 1;
    String id = 'variant-$suffix';
    while (doc.variants.any((GlossScoreboardVariant item) => item.id == id)) {
      suffix++;
      id = 'variant-$suffix';
    }
    return id;
  }
}
