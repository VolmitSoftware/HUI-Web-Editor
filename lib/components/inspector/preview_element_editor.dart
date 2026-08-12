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
import '../common/common.dart';
import 'extras_editor.dart';
import 'inspector_widgets.dart';
import 'preview_color_swatch.dart';
import 'preview_expr_field.dart';

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
        HuiEyebrow('Element ${index + 1}'),
        dom.h2(classes: 'hui-inspector-title', <Widget>[
          Text(_typeLabel(element.type)),
        ]),
      ]),
      if (errors > 0 || warnings > 0)
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            errors > 0
                ? '$errors problem${errors == 1 ? '' : 's'} on this '
                      'element${warnings > 0 ? ', $warnings warning${warnings == 1 ? '' : 's'}' : ''}.'
                : '$warnings warning${warnings == 1 ? '' : 's'} on this element.',
          ),
        ]),
    ]);
  }

  static String _typeLabel(String type) => switch (type) {
    'panel' => 'Panel',
    'cell' => 'Cell',
    'slot' => 'Slot',
    'label' => 'Label',
    _ => type.isEmpty ? '(no type)' : type,
  };

  Widget _placement() => InspectorSection(
    title: 'Placement',
    children: <Widget>[
      _field(
        'X',
        element.x,
        (Object? v) => _mutate('x', (HuiPreviewElement e) => e.x = v),
        field: 'x',
        placeholder: '0',
      ),
      _field(
        'Y',
        element.y,
        (Object? v) => _mutate('y', (HuiPreviewElement e) => e.y = v),
        field: 'y',
        placeholder: '0',
      ),
      _field(
        'Z',
        element.z,
        (Object? v) => _mutate('z', (HuiPreviewElement e) => e.z = v),
        field: 'z',
        placeholder: _formatDefault(_defaultZ()),
        help:
            'Higher z draws in front. Left blank, this type defaults '
            'to ${_formatDefault(_defaultZ())}.',
      ),
      _field(
        'Visible',
        element.visible,
        (Object? v) =>
            _mutate('visible', (HuiPreviewElement e) => e.visible = v),
        field: 'visible',
        kind: PreviewExprKind.boolean,
        placeholder: 'true',
        help:
            'Evaluated once when the preview opens - hiding an element '
            'at build time keeps it hidden for the life of that preview.',
      ),
    ],
  );

  static String _formatDefault(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Widget _repeatSection() {
    final HuiPreviewRepeat? repeat = element.repeat;
    return InspectorSection(
      title: 'Repeat',
      description:
          'Emits this element several times with an index bound to '
          'a loop variable, instead of drawing it once.',
      children: <Widget>[
        HuiSwitchRow(
          label: 'Repeat this element',
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
            label: 'Count',
            raw: repeat.count,
            required: true,
            placeholder: '2',
            help:
                'Evaluated once, with no variable scope of its own - it '
                'cannot read the loop variable it defines. A constant above '
                '1024, or a total above 4096 across every element, is '
                'rejected by the plugin.',
            issues: _issuesFor('repeat.count'),
            declaredVars: _declaredVars,
            onChanged: (Object? v) => _mutate(
              'repeat count',
              (HuiPreviewElement e) => e.repeat?.count = v,
            ),
          ),
          HuiField(
            label: 'Loop variable',
            help:
                'Defaults to "i". Must be a plain identifier and cannot '
                'reuse a catalog or "vars" name.',
            control: TextInput(
              value: repeat.varName ?? 'i',
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: 'i',
              onInput: (String value) => _mutate(
                'repeat var',
                (HuiPreviewElement e) => e.repeat?.varName = value,
              ),
              attributes: const <String, String>{
                'autocomplete': 'off',
                'spellcheck': 'false',
              },
            ),
            trailing: HuiInlineIssues(_issuesFor('repeat.var')),
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
        title: 'Unknown type',
        children: <Widget>[
          HuiNote(
            element.type.isEmpty
                ? 'This element has no "type" key. The plugin refuses '
                      'to build the document until one of panel, cell, '
                      'slot or label is set.'
                : '"${element.type}" is not a type the plugin knows. '
                      'Delete this element and add a fresh one of the '
                      'right type.',
            tone: HuiNoteTone.danger,
          ),
        ],
      ),
    ],
  };

  Widget _panelSection() => InspectorSection(
    title: 'Panel',
    children: <Widget>[
      _field(
        'Width',
        element.width,
        (Object? v) => _mutate('width', (HuiPreviewElement e) => e.width = v),
        field: 'width',
        required: true,
        placeholder: '40',
      ),
      _field(
        'Height',
        element.height,
        (Object? v) => _mutate('height', (HuiPreviewElement e) => e.height = v),
        field: 'height',
        required: true,
        placeholder: '20',
      ),
      _field(
        'Color',
        element.color,
        (Object? v) => _mutate('color', (HuiPreviewElement e) => e.color = v),
        field: 'color',
        required: true,
        placeholder: '#FF15151B',
        swatch: element.color,
      ),
    ],
  );

  Widget _cellSection() => InspectorSection(
    title: 'Cell',
    children: <Widget>[
      _field(
        'Size',
        element.size,
        (Object? v) => _mutate('size', (HuiPreviewElement e) => e.size = v),
        field: 'size',
        required: true,
        placeholder: '8',
      ),
      _field(
        'Color',
        element.color,
        (Object? v) => _mutate('color', (HuiPreviewElement e) => e.color = v),
        field: 'color',
        required: true,
        placeholder: '#FF15151B',
        swatch: element.color,
        help:
            'The one field that is re-evaluated live, every 4 ticks - '
            'this is where an animated cell reads its own colour.',
      ),
    ],
  );

  Widget _slotSection() => InspectorSection(
    title: 'Slot',
    children: <Widget>[
      _field(
        'Size',
        element.size,
        (Object? v) => _mutate('size', (HuiPreviewElement e) => e.size = v),
        field: 'size',
        required: true,
        placeholder: '18',
      ),
      _field(
        'Index',
        element.index,
        (Object? v) => _mutate('index', (HuiPreviewElement e) => e.index = v),
        field: 'index',
        required: true,
        placeholder: '0',
        help:
            'Which inventory slot to draw. Nothing clamps this - '
            'guard it against inventory.size yourself.',
      ),
      _field(
        'Well color',
        element.wellColor,
        (Object? v) =>
            _mutate('wellColor', (HuiPreviewElement e) => e.wellColor = v),
        field: 'wellColor',
        placeholder: '#FF15151B (default)',
        swatch: element.wellColor,
      ),
    ],
  );

  Widget _labelSection() => InspectorSection(
    title: 'Label',
    children: <Widget>[
      _field(
        'Text',
        element.text,
        (Object? v) =>
            _mutate('text', (HuiPreviewElement e) => e.text = v as String?),
        field: 'text',
        required: true,
        kind: PreviewExprKind.string,
        placeholder: "'Label text'",
        help:
            'The other field that is re-evaluated live, every 4 ticks. '
            'A string literal needs its own quotes: \'like this\'.',
      ),
      _field(
        'Background',
        element.background,
        (Object? v) =>
            _mutate('background', (HuiPreviewElement e) => e.background = v),
        field: 'background',
        placeholder: '0 (transparent)',
        swatch: element.background,
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
    PreviewExprKind kind = PreviewExprKind.numeric,
    String? placeholder,
    String? help,
    Object? swatch,
  }) => PreviewExprField(
    label: label,
    raw: raw,
    required: required,
    kind: kind,
    placeholder: placeholder,
    help: help,
    trailing: swatch == null ? null : previewColorSwatch(swatch),
    issues: _issuesFor(field),
    declaredVars: _declaredVars,
    scope: _scope,
    categoryVariableNames: _categoryVariableNames,
    onChanged: onChanged,
  );

  Widget _extras() => InspectorSection(
    title: 'Extra keys',
    children: <Widget>[
      ExtrasEditor(
        title: 'Element',
        extras: element.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            _mutate(label, (HuiPreviewElement e) => e.extras = next),
      ),
    ],
  );
}
