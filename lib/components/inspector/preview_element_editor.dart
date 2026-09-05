/// Per-element inspector for a container-preview document: the shared
/// x/y/z/visible/repeat fields every element type carries, plus the fields
/// specific to `panel`/`cell`/`slot`/`label`.
///
/// Every expression-capable field is a [PreviewExprField]; there is no
/// separate "constant" vs "expression" mode to pick — typing a bare number or
/// `true`/`false` commits the JSON constant shape, typing anything else
/// commits an expression string, and both compile identically. Kept this
/// simple on purpose: the JSON already erases the distinction (`x: 5` and
/// `x: "5"` behave the same at build time), so a mode toggle would only be
/// UI ceremony over a difference nobody can observe in game.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/preview_card_edit.dart' show previewAutoSimCategory;
import '../../logic/preview_doc_validation.dart';
import '../../logic/preview_sim.dart' show previewCategoryVariableNames;
import '../../logic/validation.dart';
import '../../model/preview_doc.dart';
import '../../state/editor_store.dart';
import '../../config/defaults.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'preview_color_swatch.dart';
import 'preview_expr_field.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class PreviewElementEditor extends StatelessWidget {
  const PreviewElementEditor({
    required this.store,
    required this.index,
    required this.element,
    super.key,
  });

  final EditorStore store;
  final int index;
  final HuiPreviewElement element;

  String get _path => 'elements[$index]';

  List<HuiIssue> get _elementIssues => store.issuesForPreviewElement(index);

  List<HuiIssue> _issuesFor(String field) => _elementIssues
      .where((HuiIssue issue) => issue.path == '$_path.$field')
      .toList();

  Set<String> get _declaredVars {
    final HuiPreviewDoc? doc = store.previewDoc;
    return doc == null ? const <String>{} : previewDeclaredVars(doc);
  }

  Set<String> get _scope {
    final HuiPreviewRepeat? repeat = element.repeat;
    if (repeat == null) return const <String>{};
    final String name = (repeat.varName == null || repeat.varName!.isEmpty)
        ? 'i'
        : repeat.varName!;
    return <String>{name};
  }

  /// Every variable name the document's own auto-detected simulated category
  /// publishes — the "current sim category" driving each field's soft
  /// "not published here" nudge. Empty (which silences the nudge everywhere)
  /// when no preview document is open, which cannot actually happen here.
  ///
  /// [previewCategoryVariableNames] is a pure function of the category
  /// string, not a `PreviewSim` getter: this pane's `build()` calls [_field]
  /// up to a dozen times, each reading this, and while a card is animating
  /// the whole pane rebuilds on every simulation tick, so allocating a whole
  /// `PreviewSim` (its default sample state, slot items included) here would
  /// mean dozens of throwaway allocations a second for a list that depends on
  /// nothing but which category this is.
  List<String> get _categoryVariableNames {
    final HuiPreviewDoc? doc = store.previewDoc;
    if (doc == null) return const <String>[];
    return previewCategoryVariableNames(previewAutoSimCategory(doc));
  }

  void _mutate(String label, void Function(HuiPreviewElement e) fn) =>
      store.editPreviewElement(index, label, fn);

  double _defaultZ() => switch (element.type) {
    'panel' => 1,
    'cell' || 'slot' => 4,
    'label' => 6,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-inspector-body is-preview-element', <Widget>[
        _header(),
        _placement(),
        _repeatSection(),
        ..._typeSection(),
        _extras(),
      ]);

  Widget _header() {
    final int errors = _elementIssues
        .where((HuiIssue i) => i.severity == HuiSeverity.error)
        .length;
    final int warnings = _elementIssues
        .where((HuiIssue i) => i.severity == HuiSeverity.warning)
        .length;
    return dom.div(classes: 'hui-inspector-headgroup', <Widget>[
      dom.div(classes: 'hui-inspector-header is-component', <Widget>[
        HuiEyebrow(
          huiText("Element {value}", <String, Object?>{'value': index + 1}),
        ),
        dom.h2(classes: 'hui-inspector-title', <Widget>[
          Text(_typeLabel(element.type)),
        ]),
      ]),
      // What this element type is, in the same words the "add element" menu
      // uses. The map existed and nothing read it, so the pane never said what
      // a cell was once you had added one.
      if (previewElementTypeDescriptions[element.type] case final String note)
        dom.p(classes: 'hui-inspector-lede', <Widget>[Text(huiText(note))]),
      if (errors > 0 || warnings > 0)
        dom.p(classes: 'hui-inspector-lede is-issue', <Widget>[
          Text(_issueSummary(errors, warnings)),
        ]),
    ]);
  }

  String _issueSummary(int errors, int warnings) {
    final String warningText = warnings == 0
        ? ''
        : huiPlural(
            'element.warning_count',
            warnings,
            oneEnglish: '{count} warning',
            otherEnglish: '{count} warnings',
          );
    if (errors == 0) {
      return huiText('{warnings} on this element.', <String, Object?>{
        'warnings': warningText,
      });
    }
    final String problemText = huiPlural(
      'element.problem_count',
      errors,
      oneEnglish: '{count} problem',
      otherEnglish: '{count} problems',
    );
    return warnings == 0
        ? huiText('{problems} on this element.', <String, Object?>{
            'problems': problemText,
          })
        : huiText('{problems} on this element, {warnings}.', <String, Object?>{
            'problems': problemText,
            'warnings': warningText,
          });
  }

  static String _typeLabel(String type) => switch (type) {
    'panel' => huiText('Panel'),
    'cell' => huiText('Cell'),
    'slot' => huiText('Slot'),
    'label' => huiText('Label'),
    _ => type.isEmpty ? huiText('(no type)') : type,
  };

  Widget _placement() => InspectorSection(
    title: huiText('Placement'),
    sectionKey: 'preview.placement',
    children: <Widget>[
      _field(
        'X',
        element.x,
        (Object? v) => _mutate('x', (HuiPreviewElement e) => e.x = v),
        field: 'x',
        docKey: 'preview.element.x',
        placeholder: '0',
      ),
      _field(
        'Y',
        element.y,
        (Object? v) => _mutate('y', (HuiPreviewElement e) => e.y = v),
        field: 'y',
        docKey: 'preview.element.y',
        placeholder: '0',
      ),
      _field(
        'Z',
        element.z,
        (Object? v) => _mutate('z', (HuiPreviewElement e) => e.z = v),
        field: 'z',
        docKey: 'preview.element.z',
        placeholder: _formatDefault(_defaultZ()),
        help: huiText(
          "Higher z draws in front. Left blank, this type defaults to {formatDefault}.",
          <String, Object?>{'formatDefault': _formatDefault(_defaultZ())},
        ),
      ),
      _field(
        huiText('Visibility expression'),
        element.show,
        (Object? value) => _mutate(
          'show',
          (HuiPreviewElement element) => element.show = value,
        ),
        field: 'show',
        showCondition: true,
        docKey: 'preview.element.show',
        kind: PreviewExprKind.boolean,
        placeholder: huiText('true'),
      ),
      _field(
        huiText('Visible'),
        element.visible,
        (Object? v) =>
            _mutate('visible', (HuiPreviewElement e) => e.visible = v),
        field: 'visible',
        docKey: 'preview.element.visible',
        kind: PreviewExprKind.boolean,
        placeholder: huiText('true'),
        help: huiText(
          'Evaluated once when the preview opens - hiding an element '
          'at build time keeps it hidden for the life of that preview.',
        ),
      ),
    ],
  );

  static String _formatDefault(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Widget _repeatSection() {
    final HuiPreviewRepeat? repeat = element.repeat;
    return InspectorSection(
      title: huiText('Repeat'),
      sectionKey: 'preview.repeat',
      description: huiText(
        'Emits this element several times with an index bound to '
        'a loop variable, instead of drawing it once.',
      ),
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Repeat this element'),
          value: repeat != null,
          onChanged: (bool value) => _mutate(
            value ? 'add repeat' : 'remove repeat',
            (HuiPreviewElement e) => e.repeat = value
                ? HuiPreviewRepeat(count: 2, varName: 'i')
                : null,
          ),
        ),
        if (repeat != null) ...<Widget>[
          PreviewExprField(
            label: huiText('Count'),
            raw: repeat.count,
            required: true,
            placeholder: '2',
            trailing: const HuiFieldHelp('preview.repeat.count'),
            help: huiText(
              'Evaluated once, with no variable scope of its own - it '
              'cannot read the loop variable it defines. A constant above '
              '1024, or a total above 4096 across every element, is '
              'rejected by the plugin.',
            ),
            issues: _issuesFor('repeat.count'),
            declaredVars: _declaredVars,
            onChanged: (Object? v) => _mutate(
              'repeat count',
              (HuiPreviewElement e) => e.repeat?.count = v,
            ),
          ),
          HuiField(
            label: huiText('Loop variable'),
            trailing: const HuiFieldHelp('preview.repeat.var'),
            defaultValue: 'i',
            onReset: (repeat.varName ?? 'i') == 'i'
                ? null
                : () => _mutate(
                    'repeat var',
                    (HuiPreviewElement e) => e.repeat?.varName = 'i',
                  ),
            help: huiText(
              'Defaults to "i". Must be a plain identifier and cannot '
              'reuse a catalog or "vars" name.',
            ),
            // The issues belong under the control, not in the header slot the
            // help and the default chip now share.
            control: dom.div(<Widget>[
              TextInput(
                value: repeat.varName ?? 'i',
                size: ComponentSize.sm,
                fullWidth: true,
                placeholder: huiText('i'),
                onInput: (String value) => _mutate(
                  'repeat var',
                  (HuiPreviewElement e) => e.repeat?.varName = value,
                ),
                attributes: const <String, String>{
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                  'dir': 'ltr',
                },
              ),
              HuiInlineIssues(_issuesFor('repeat.var')),
            ]),
          ),
        ],
      ],
    );
  }

  List<Widget> _typeSection() => switch (element.type) {
    'panel' => <Widget>[_panelSection()],
    'cell' => <Widget>[_cellSection()],
    'slot' => <Widget>[_slotSection()],
    'label' => <Widget>[_labelSection()],
    _ => <Widget>[
      InspectorSection(
        title: huiText('Unknown type'),
        children: <Widget>[
          HuiNote(
            element.type.isEmpty
                ? huiText(
                    'This element has no "type" key. The plugin refuses '
                    'to build the document until one of panel, cell, '
                    'slot or label is set.',
                  )
                : huiText(
                    '"{type}" is not a type the plugin knows. Delete this '
                    'element and add a fresh one of the right type.',
                    <String, Object?>{'type': element.type},
                  ),
            tone: HuiNoteTone.danger,
          ),
        ],
      ),
    ],
  };

  Widget _panelSection() => InspectorSection(
    title: huiText('Panel'),
    children: <Widget>[
      _field(
        huiText('Width'),
        element.width,
        (Object? v) => _mutate('width', (HuiPreviewElement e) => e.width = v),
        field: 'width',
        docKey: 'preview.element.width',
        required: true,
        placeholder: '40',
      ),
      _field(
        huiText('Height'),
        element.height,
        (Object? v) => _mutate('height', (HuiPreviewElement e) => e.height = v),
        field: 'height',
        docKey: 'preview.element.height',
        required: true,
        placeholder: '20',
      ),
      _field(
        huiText('Color'),
        element.color,
        (Object? v) => _mutate('color', (HuiPreviewElement e) => e.color = v),
        field: 'color',
        docKey: 'preview.element.color',
        required: true,
        placeholder: huiText('#FF15151B'),
        colorLabel: huiText('panel colour'),
      ),
    ],
  );

  Widget _cellSection() => InspectorSection(
    title: huiText('Cell'),
    children: <Widget>[
      _field(
        huiText('Size'),
        element.size,
        (Object? v) => _mutate('size', (HuiPreviewElement e) => e.size = v),
        field: 'size',
        docKey: 'preview.element.size',
        required: true,
        placeholder: '8',
      ),
      _field(
        huiText('Color'),
        element.color,
        (Object? v) => _mutate('color', (HuiPreviewElement e) => e.color = v),
        field: 'color',
        docKey: 'preview.element.color',
        required: true,
        placeholder: huiText('#FF15151B'),
        colorLabel: huiText('cell colour'),
        help: huiText(
          'The one field that is re-evaluated live, every 4 ticks - '
          'this is where an animated cell reads its own colour.',
        ),
      ),
    ],
  );

  Widget _slotSection() => InspectorSection(
    title: huiText('Slot'),
    children: <Widget>[
      _field(
        huiText('Size'),
        element.size,
        (Object? v) => _mutate('size', (HuiPreviewElement e) => e.size = v),
        field: 'size',
        docKey: 'preview.element.size',
        required: true,
        placeholder: '18',
      ),
      _field(
        huiText('Index'),
        element.index,
        (Object? v) => _mutate('index', (HuiPreviewElement e) => e.index = v),
        field: 'index',
        docKey: 'preview.element.index',
        required: true,
        placeholder: '0',
        help: huiText(
          'Which inventory slot to draw. Nothing clamps this - '
          'guard it against inventory.size yourself.',
        ),
      ),
      _field(
        huiText('Well color'),
        element.wellColor,
        (Object? v) =>
            _mutate('wellColor', (HuiPreviewElement e) => e.wellColor = v),
        field: 'wellColor',
        docKey: 'preview.element.wellColor',
        placeholder: huiText('#FF15151B (default)'),
        colorLabel: huiText('well colour'),
      ),
    ],
  );

  Widget _labelSection() => InspectorSection(
    title: huiText('Label'),
    children: <Widget>[
      _field(
        huiText('Text'),
        element.text,
        (Object? v) =>
            _mutate('text', (HuiPreviewElement e) => e.text = v as String?),
        field: 'text',
        docKey: 'preview.element.text',
        required: true,
        kind: PreviewExprKind.string,
        placeholder: huiText("'Label text'"),
        help: huiText(
          'The other field that is re-evaluated live, every 4 ticks. '
          'A string literal needs its own quotes: \'like this\'.',
        ),
      ),
      _field(
        huiText('Background'),
        element.background,
        (Object? v) =>
            _mutate('background', (HuiPreviewElement e) => e.background = v),
        field: 'background',
        docKey: 'preview.element.background',
        placeholder: huiText('0 (transparent)'),
        colorLabel: huiText('label background'),
      ),
    ],
  );

  /// One [PreviewExprField], wired to this element's issues, declared vars,
  /// repeat scope and simulated-category hint set. [field] is the raw JSON
  /// key (`x`, `width`, ...), used only to filter [_issuesFor].
  Widget _field(
    String label,
    Object? raw,
    void Function(Object? value) onChanged, {
    required String field,
    bool required = false,
    bool showCondition = false,
    PreviewExprKind kind = PreviewExprKind.numeric,
    String? placeholder,
    String? help,
    String? docKey,
    String? colorLabel,
  }) => PreviewExprField(
    label: label,
    raw: raw,
    required: required,
    showCondition: showCondition,
    kind: kind,
    placeholder: placeholder,
    help: help,
    trailing: _trailing(raw, onChanged, docKey, colorLabel),
    issues: _issuesFor(field),
    declaredVars: _declaredVars,
    scope: _scope,
    categoryVariableNames: _categoryVariableNames,
    onChanged: onChanged,
  );

  /// The colour picker, the help button, or both. A colour field whose value
  /// is a live expression gets the help alone: there is no one colour to open
  /// a picker on, and picking would overwrite the expression.
  Widget? _trailing(
    Object? raw,
    void Function(Object? value) onChanged,
    String? docKey,
    String? colorLabel,
  ) {
    final Widget? picker = colorLabel == null
        ? null
        : previewColorPicker(
            raw,
            label: colorLabel,
            onPicked: (String hex) => onChanged(hex),
          );
    if (picker == null) return docKey == null ? null : HuiFieldHelp(docKey);
    if (docKey == null) return picker;
    return dom.div(classes: 'hui-field-tools', <Widget>[
      picker,
      HuiFieldHelp(docKey),
    ]);
  }

  Widget _extras() => InspectorSection(
    title: huiText('Extra keys'),
    sectionKey: 'preview.extras',
    initiallyOpen: false,
    children: <Widget>[
      ExtrasEditor(
        title: huiText('Element'),
        extras: element.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            _mutate(label, (HuiPreviewElement e) => e.extras = next),
      ),
    ],
  );
}
