/// Document-level inspector for a container-preview document: shown whenever
/// no element is selected, the way [MenuInspector] shows the menu root.
///
/// `match`/`variants` are kept deliberately simple, per the task brief:
/// blocks/entities are plain chip lists (globs are just a chip with a `*` in
/// it — the same string either way), `special` is a small fixed choice, and
/// `vars` is key/value rows with a colour swatch affordance for anything
/// starting with `#`. There is no dedicated glob builder or drag-reorder for
/// variants beyond the same up/down tools every other list in this editor
/// already has.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/links.dart';
import '../../logic/validation.dart';
import '../../model/preview_doc.dart';
import '../../model/particle_layer.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'preview_color_swatch.dart';
import 'preview_expr_field.dart';
import 'particle_layers_editor.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

const List<String> _specialValues = <String>[
  'enderChest',
  'locked',
  'anyInventoryHolder',
];

String _specialValueLabel(String value) => switch (value) {
  'enderChest' => huiText('Ender chest'),
  'locked' => huiText('Locked'),
  'anyInventoryHolder' => huiText('Any inventory holder'),
  _ => value,
};

final RegExp _identifierPattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

class PreviewMatchEditor extends StatelessWidget {
  const PreviewMatchEditor({required this.store, super.key});

  final EditorStore store;

  HuiPreviewDoc get _doc => store.previewDoc!;

  /// Document-level issues only: no `elements[...]` prefix.
  List<HuiIssue> _issuesFor(String path) => store.issues
      .where(
        (HuiIssue issue) =>
            issue.path == path || issue.path.startsWith('$path.'),
      )
      .toList();

  void _mutate(String label, void Function(HuiPreviewDoc doc) fn) =>
      store.mutatePreview(label, fn);

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-inspector-body is-menu', <Widget>[
    _header(),
    _matchSection(),
    _variantsSection(),
    _cardSection(),
    ParticleLayersEditor(
      layers: _doc.particleLayers,
      sectionKey: 'preview.particleLayers',
      mutate: (String label, void Function(List<GlossParticleLayer>) edit) =>
          _mutate(label, (HuiPreviewDoc doc) => edit(doc.particleLayers)),
    ),
    _install(),
    _extras(),
  ]);

  Widget _header() => dom.div(classes: 'hui-inspector-headgroup', <Widget>[
    dom.div(classes: 'hui-inspector-header is-menu', <Widget>[
      HuiEyebrow(huiText('Container preview')),
      dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
        Text(store.menuId),
      ]),
    ]),
    dom.p(classes: 'hui-inspector-lede', <Widget>[
      Text(
        huiText(
          'Nothing is selected, so these are the document-wide '
          'settings: which blocks and entities draw this card, its '
          'variants, and the chrome around it. Pick an element in the '
          'list to edit it.',
        ),
      ),
    ]),
  ]);

  Widget _matchSection() => InspectorSection(
    title: huiText('Match'),
    sectionKey: 'preview.match',
    trailing: const HuiFieldHelp('preview.match'),
    description: huiText(
      'Which blocks, entities or special targets this '
      'document draws over. The highest-priority document naming a '
      'target wins.',
    ),
    children: <Widget>[
      PreviewExprField(
        label: huiText('Visibility expression'),
        raw: _doc.show,
        showCondition: true,
        kind: PreviewExprKind.boolean,
        placeholder: huiText('true'),
        trailing: const HuiFieldHelp('preview.show'),
        issues: _issuesFor('show'),
        onChanged: (Object? value) =>
            _mutate('show', (HuiPreviewDoc doc) => doc.show = value),
      ),
      _PreviewNameChips(
        label: huiText('Blocks'),
        docKey: 'preview.match.blocks',
        values: _doc.match.blocks,
        help: huiText(
          '"*" is the only wildcard, e.g. "OAK_*" or "*_SHULKER_BOX".',
        ),
        onChanged: (List<String> next) =>
            _mutate('match blocks', (HuiPreviewDoc d) => d.match.blocks = next),
      ),
      HuiInlineIssues(_issuesFor('match.blocks')),
      _PreviewNameChips(
        label: huiText('Entities'),
        docKey: 'preview.match.entities',
        values: _doc.match.entities,
        help: huiText('Same glob rule as blocks.'),
        onChanged: (List<String> next) => _mutate(
          'match entities',
          (HuiPreviewDoc d) => d.match.entities = next,
        ),
      ),
      HuiInlineIssues(_issuesFor('match.entities')),
      _specialField(),
      HuiField(
        label: huiText('Priority'),
        trailing: const HuiFieldHelp('preview.match.priority'),
        help: huiText(
          'Highest priority wins. Shipped documents use 10, so a user '
          'document at 20 overrides one.',
        ),
        defaultValue: '0',
        onReset: (_doc.match.priority ?? 0) == 0
            ? null
            : () => _mutate(
                'match priority',
                (HuiPreviewDoc d) => d.match.priority = 0,
              ),
        control: HuiNumberField(
          value: (_doc.match.priority ?? 0).toDouble(),
          integer: true,
          min: -1000000,
          max: 1000000,
          onChanged: (double value) => _mutate(
            'match priority',
            (HuiPreviewDoc d) => d.match.priority = value.round(),
          ),
        ),
      ),
      const HuiDivider(),
      _PreviewVarsRows(
        title: huiText('vars'),
        docKey: 'preview.vars',
        vars: _doc.match.vars,
        onChanged: (Map<String, dynamic> next) =>
            _mutate('match vars', (HuiPreviewDoc d) => d.match.vars = next),
      ),
      HuiInlineIssues(_issuesFor('match.vars')),
      ExtrasEditor(
        title: huiText('Match'),
        extras: _doc.match.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            _mutate(label, (HuiPreviewDoc d) => d.match.extras = next),
      ),
      HuiInlineIssues(_issuesFor('match')),
    ],
  );

  Widget _specialField() {
    final String? special = _doc.match.special;
    return HuiField(
      label: huiText('Special'),
      trailing: const HuiFieldHelp('preview.match.special'),
      help: huiText(
        'enderChest draws from the viewer\'s own ender chest, locked is '
        'the access-denied card, anyInventoryHolder is the entity fallback.',
      ),
      control: dom.div(<Widget>[
        HuiSegmented(
          value: special ?? 'none',
          segments: <HuiSegment>[
            HuiSegment(value: 'none', label: huiText('None')),
            for (final String value in _specialValues)
              HuiSegment(value: value, label: _specialValueLabel(value)),
          ],
          onChanged: (String value) => _mutate(
            'match special',
            (HuiPreviewDoc d) =>
                d.match.special = value == 'none' ? null : value,
          ),
        ),
        HuiInlineIssues(_issuesFor('match.special')),
      ]),
    );
  }

  Widget _variantsSection() => InspectorSection(
    title: huiText('Variants'),
    sectionKey: 'preview.variants',
    description: huiText(
      'Extra vars (and optionally extra blocks/entities) for a '
      'subset of targets, tried in order — the first one whose blocks '
      'or entities match wins.',
    ),
    trailing: Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.sm,
      icon: ArcaneIcon.plus(size: IconSize.sm),
      onPressed: () => _mutate(
        'add variant',
        (HuiPreviewDoc d) => d.variants.add(HuiPreviewVariant()),
      ),
      label: huiText('Add'),
    ),
    children: <Widget>[
      if (_doc.variants.isEmpty)
        HuiNote(
          huiText('No variants. Every target uses the document\'s own vars.'),
        )
      else
        for (int i = 0; i < _doc.variants.length; i++) _variantCard(i),
    ],
  );

  Widget _variantCard(int index) {
    final HuiPreviewVariant variant = _doc.variants[index];
    final String path = 'variants[$index]';
    return dom.div(
      classes: 'hui-inspector-section',
      styles: const dom.Styles(
        raw: <String, String>{
          'border': '1px solid var(--hui-border-soft)',
          'border-radius': 'var(--hui-radius)',
          'padding': '10px',
        },
      ),
      <Widget>[
        dom.div(
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'flex',
              'align-items': 'center',
              'justify-content': 'space-between',
              'margin-bottom': '8px',
            },
          ),
          <Widget>[
            HuiEyebrow(
              huiText("Variant {value}", <String, Object?>{'value': index + 1}),
            ),
            HuiRowTools(
              onMoveUp: index == 0
                  ? null
                  : () => _mutate('move variant', (HuiPreviewDoc d) {
                      final HuiPreviewVariant v = d.variants.removeAt(index);
                      d.variants.insert(index - 1, v);
                    }),
              onMoveDown: index >= _doc.variants.length - 1
                  ? null
                  : () => _mutate('move variant', (HuiPreviewDoc d) {
                      final HuiPreviewVariant v = d.variants.removeAt(index);
                      d.variants.insert(index + 1, v);
                    }),
              onRemove: () => _mutate(
                'remove variant',
                (HuiPreviewDoc d) => d.variants.removeAt(index),
              ),
              removeLabel: huiText('Delete variant {number}', <String, Object?>{
                'number': index + 1,
              }),
            ),
          ],
        ),
        _PreviewNameChips(
          label: huiText('Blocks'),
          docKey: 'preview.variant.blocks',
          values: variant.blocks,
          onChanged: (List<String> next) => _mutate(
            'variant blocks',
            (HuiPreviewDoc d) => d.variants[index].blocks = next,
          ),
        ),
        HuiInlineIssues(_issuesFor('$path.blocks')),
        _PreviewNameChips(
          label: huiText('Entities'),
          docKey: 'preview.variant.entities',
          values: variant.entities,
          onChanged: (List<String> next) => _mutate(
            'variant entities',
            (HuiPreviewDoc d) => d.variants[index].entities = next,
          ),
        ),
        HuiInlineIssues(_issuesFor('$path.entities')),
        _variantSpecialField(index, variant, path),
        HuiField(
          label: huiText('Priority'),
          help: huiText(
            'Overrides the document priority when this variant matches.',
          ),
          control: HuiNumberField(
            value: (variant.priority ?? 0).toDouble(),
            integer: true,
            min: -1000000,
            max: 1000000,
            onChanged: (double value) => _mutate(
              'variant priority',
              (HuiPreviewDoc d) => d.variants[index].priority = value.round(),
            ),
          ),
        ),
        _PreviewVarsRows(
          title: huiText('vars'),
          docKey: 'preview.variant.vars',
          vars: variant.vars,
          onChanged: (Map<String, dynamic> next) => _mutate(
            'variant vars',
            (HuiPreviewDoc d) => d.variants[index].vars = next,
          ),
        ),
        HuiInlineIssues(_issuesFor('$path.vars')),
        ExtrasEditor(
          title: huiText('Variant'),
          extras: variant.extras,
          onChanged: (String label, Map<String, dynamic> next) => _mutate(
            label,
            (HuiPreviewDoc d) => d.variants[index].extras = next,
          ),
        ),
      ],
    );
  }

  Widget _variantSpecialField(
    int index,
    HuiPreviewVariant variant,
    String path,
  ) => HuiField(
    label: huiText('Special'),
    help: huiText(
      'Optionally limits this variant to an ender chest, locked target or '
      'inventory-holder fallback.',
    ),
    control: HuiSegmented(
      value: variant.special ?? 'none',
      segments: <HuiSegment>[
        HuiSegment(value: 'none', label: huiText('None')),
        for (final String value in _specialValues)
          HuiSegment(value: value, label: _specialValueLabel(value)),
      ],
      onChanged: (String value) => _mutate(
        'variant special',
        (HuiPreviewDoc d) =>
            d.variants[index].special = value == 'none' ? null : value,
      ),
    ),
    trailing: HuiInlineIssues(_issuesFor('$path.special')),
  );

  Widget _cardSection() {
    final HuiPreviewCard? card = _doc.card;
    return InspectorSection(
      title: huiText('Card'),
      sectionKey: 'preview.card',
      trailing: const HuiFieldHelp('preview.card'),
      description: huiText(
        'The chrome drawn around the elements. Omit it entirely '
        'for bare content with no frame.',
      ),
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Draw card chrome'),
          value: card != null,
          onChanged: (bool value) => _mutate(
            value ? 'add card' : 'remove card',
            (HuiPreviewDoc d) =>
                d.card = value ? HuiPreviewCard(framed: true) : null,
          ),
        ),
        if (card != null) ..._cardFields(card),
      ],
    );
  }

  List<Widget> _cardFields(HuiPreviewCard card) => <Widget>[
    PreviewExprField(
      label: huiText('Visibility expression'),
      raw: card.show,
      showCondition: true,
      kind: PreviewExprKind.boolean,
      placeholder: huiText('true'),
      trailing: const HuiFieldHelp('preview.card.show'),
      issues: _issuesFor('card.show'),
      onChanged: (Object? value) =>
          _mutate('card show', (HuiPreviewDoc doc) => doc.card?.show = value),
    ),
    PreviewExprField(
      label: huiText('Framed'),
      raw: card.framed,
      kind: PreviewExprKind.boolean,
      placeholder: huiText('true'),
      trailing: const HuiFieldHelp('preview.card.framed'),
      issues: _issuesFor('card.framed'),
      onChanged: (Object? v) =>
          _mutate('card framed', (HuiPreviewDoc d) => d.card?.framed = v),
    ),
    PreviewExprField(
      label: huiText('Title'),
      raw: card.title,
      kind: PreviewExprKind.string,
      placeholder: huiText("'Furnace'"),
      trailing: const HuiFieldHelp('preview.card.title'),
      issues: _issuesFor('card.title'),
      onChanged: (Object? v) => _mutate(
        'card title',
        (HuiPreviewDoc d) => d.card?.title = v as String?,
      ),
    ),
    PreviewExprField(
      label: huiText('Accent'),
      raw: card.accent,
      kind: PreviewExprKind.string,
      placeholder: huiText('#FF808080'),
      trailing: dom.div(classes: 'hui-field-tools', <Widget>[
        ?previewColorPicker(
          card.accent,
          label: huiText('card accent'),
          onPicked: (String hex) =>
              _mutate('card accent', (HuiPreviewDoc d) => d.card?.accent = hex),
        ),
        const HuiFieldHelp('preview.card.accent'),
      ]),
      issues: _issuesFor('card.accent'),
      onChanged: (Object? v) => _mutate(
        'card accent',
        (HuiPreviewDoc d) => d.card?.accent = v as String?,
      ),
    ),
    HuiField(
      label: huiText('Min half width'),
      trailing: const HuiFieldHelp('preview.card.minHalfWidth'),
      help: huiText(
        'Minimum panel half-width in pixels, so a narrow card does not '
        'collapse around a short title.',
      ),
      defaultValue: '82',
      onReset: (card.minHalfWidth ?? 82) == 82
          ? null
          : () => _mutate(
              'card minHalfWidth',
              (HuiPreviewDoc d) => d.card?.minHalfWidth = 82,
            ),
      control: HuiNumberField(
        value: (card.minHalfWidth ?? 82).toDouble(),
        integer: true,
        min: 0,
        max: 2000,
        onChanged: (double value) => _mutate(
          'card minHalfWidth',
          (HuiPreviewDoc d) => d.card?.minHalfWidth = value.round(),
        ),
      ),
    ),
    ExtrasEditor(
      title: huiText('Card'),
      extras: card.extras,
      onChanged: (String label, Map<String, dynamic> next) =>
          _mutate(label, (HuiPreviewDoc d) => d.card?.extras = next),
    ),
  ];

  Widget _install() => InspectorSection(
    title: huiText('Install on the server'),
    children: <Widget>[
      HuiDetailRow(
        huiText('Preview file'),
        '$huiPreviewFolder${store.menuId}.json',
      ),
      HuiDetailRow(huiText('Permission'), 'gloss.preview'),
    ],
  );

  Widget _extras() => InspectorSection(
    title: huiText('Extra keys'),
    sectionKey: 'previewDoc.extras',
    initiallyOpen: false,
    children: <Widget>[
      ExtrasEditor(
        title: huiText('Document'),
        extras: _doc.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            _mutate(label, (HuiPreviewDoc d) => d.extras = next),
      ),
    ],
  );
}

/// Editable chip list for `match.blocks`/`match.entities` (and their variant
/// equivalents): plain uppercase names, `*` is the only wildcard.
class _PreviewNameChips extends StatefulWidget {
  const _PreviewNameChips({
    required this.label,
    required this.values,
    required this.onChanged,
    this.help,
    this.docKey,
  });

  final String label;
  final List<String> values;
  final void Function(List<String> next) onChanged;

  /// Field-doc key mounted beside the label; null renders no help affordance.
  final String? docKey;
  final String? help;

  @override
  State<_PreviewNameChips> createState() => _PreviewNameChipsState();
}

class _PreviewNameChipsState extends State<_PreviewNameChips> {
  String _draft = '';

  void _add() {
    final String value = _draft.trim().toUpperCase();
    if (value.isEmpty) return;
    setState(() => _draft = '');
    if (component.values.contains(value)) return;
    component.onChanged(<String>[...component.values, value]);
  }

  void _remove(String value) => component.onChanged(
    component.values.where((String v) => v != value).toList(),
  );

  @override
  Widget build(BuildContext context) => HuiField(
    label: component.label,
    help: component.help,
    trailing: component.docKey == null ? null : HuiFieldHelp(component.docKey!),
    control: dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '6px',
          'min-width': '0',
        },
      ),
      <Widget>[
        if (component.values.isNotEmpty)
          dom.div(classes: 'hui-chips', <Widget>[
            for (final String value in component.values) _chip(value),
          ]),
        dom.div(
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'grid',
              'grid-template-columns': 'minmax(0, 1fr) auto',
              'gap': '8px',
              'min-width': '0',
            },
          ),
          <Widget>[
            TextInput(
              value: _draft,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: huiText('CHEST or OAK_*'),
              onInput: (String value) => setState(() => _draft = value),
              styles: huiTechnicalInputStyles,
              attributes: huiTechnicalInputAttributes,
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.sm,
              icon: ArcaneIcon.plus(size: IconSize.sm),
              onPressed: _add,
              label: huiText('Add'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _chip(String value) => dom.span(
    classes: 'hui-chip',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'inline-flex',
        'align-items': 'center',
        'gap': '4px',
      },
    ),
    <Widget>[
      Text(value),
      dom.button(
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'inline-flex',
            'border': '0',
            'padding': '0',
            'background': 'transparent',
            'color': 'inherit',
            'cursor': 'pointer',
            'opacity': '0.7',
          },
        ),
        attributes: <String, String>{
          'type': 'button',
          'aria-label': huiText("Remove {value}", <String, Object?>{
            'value': value,
          }),
        },
        events: <String, void Function(Object)>{
          'click': (Object _) => _remove(value),
        },
        <Widget>[ArcaneIcon.x(size: IconSize.sm)],
      ),
    ],
  );
}

/// Key/value rows for `vars`: value text with a colour swatch affordance for
/// anything starting with `#`. A value commits as `true`/`false`/a number
/// when the text is exactly that; anything else (including a `#RRGGBB`
/// literal, left exactly as typed) is a plain string, matching
/// `PreviewDocumentParser.compileVars`.
class _PreviewVarsRows extends StatefulWidget {
  const _PreviewVarsRows({
    required this.title,
    required this.vars,
    required this.onChanged,
    this.docKey,
  });

  final String title;
  final Map<String, dynamic> vars;
  final void Function(Map<String, dynamic> next) onChanged;

  /// Field-doc key mounted beside the group's eyebrow.
  final String? docKey;

  @override
  State<_PreviewVarsRows> createState() => _PreviewVarsRowsState();
}

class _PreviewVarsRowsState extends State<_PreviewVarsRows> {
  final Map<String, String> _drafts = <String, String>{};
  String _newKey = '';
  String Function()? _newKeyError;

  @override
  void didUpdateComponent(_PreviewVarsRows oldComponent) {
    super.didUpdateComponent(oldComponent);
    // Undo, redo and a code-view commit all rewrite `vars` behind this
    // widget's back (mirrors `ExtrasEditor`'s own resync). Without this, a
    // key whose committed value moved kept showing its stale draft, and the
    // next keystroke on that row committed starting from that stale text -
    // silently re-reverting whatever the user just undid.
    final Map<String, dynamic> next = component.vars;
    _drafts.removeWhere((String key, String draft) {
      if (!next.containsKey(key)) return true;
      final Object? was = oldComponent.vars[key];
      final Object? now = next[key];
      return _format(was) != _format(now);
    });
  }

  String _valueText(String key) => _drafts[key] ?? _format(component.vars[key]);

  static String _format(Object? value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) {
      final double d = value.toDouble();
      return d == d.roundToDouble() && d.isFinite
          ? d.toInt().toString()
          : d.toString();
    }
    return value.toString();
  }

  static Object _encode(String text) {
    final String trimmed = text.trim();
    final String lower = trimmed.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    final double? number = double.tryParse(trimmed);
    if (number != null) return number;
    return trimmed;
  }

  void _editValue(String key, String raw) {
    setState(() => _drafts[key] = raw);
    final Map<String, dynamic> next = Map<String, dynamic>.of(component.vars);
    next[key] = _encode(raw);
    component.onChanged(next);
  }

  void _remove(String key) {
    _drafts.remove(key);
    final Map<String, dynamic> next = Map<String, dynamic>.of(component.vars)
      ..remove(key);
    setState(() {});
    component.onChanged(next);
  }

  void _add() {
    final String key = _newKey.trim();
    if (key.isEmpty) {
      setState(() => _newKeyError = () => huiText('Give the var a name.'));
      return;
    }
    if (!_identifierPattern.hasMatch(key)) {
      setState(
        () =>
            _newKeyError = () =>
                huiText('Letters, digits and underscore only.'),
      );
      return;
    }
    if (component.vars.containsKey(key)) {
      setState(
        () => _newKeyError = () =>
            huiText('{key} is already here.', <String, Object?>{'key': key}),
      );
      return;
    }
    setState(() {
      _newKey = '';
      _newKeyError = null;
    });
    final Map<String, dynamic> next = Map<String, dynamic>.of(component.vars);
    next[key] = 0.0;
    component.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => dom.div(
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '8px',
        'min-width': '0',
      },
    ),
    <Widget>[
      dom.div(
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'gap': '2px',
          },
        ),
        <Widget>[
          HuiEyebrow(component.title),
          if (component.docKey != null) HuiFieldHelp(component.docKey!),
        ],
      ),
      for (final String key in component.vars.keys.toList()) _row(key),
      _addRow(),
    ],
  );

  Widget _row(String key) {
    final Object? value = component.vars[key];
    final Widget? swatch = value is String && value.startsWith('#')
        ? previewColorPicker(
            value,
            label: huiText("{key} colour", <String, Object?>{'key': key}),
            onPicked: (String hex) => _editValue(key, hex),
          )
        : null;
    return HuiField(
      label: key,
      trailing: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.iconSm,
        onPressed: () => _remove(key),
        attributes: <String, String>{
          'aria-label': huiText("Remove {key}", <String, Object?>{'key': key}),
        },
        icon: ArcaneIcon.trash2(size: IconSize.sm),
      ),
      help: huiText(
        'A leading "#" is read as a colour literal (#RGB, #RRGGBB or '
        '#AARRGGBB); anything else is a plain string, never parsed as an '
        'expression.',
      ),
      control: dom.div(
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'gap': '8px',
            'min-width': '0',
          },
        ),
        <Widget>[
          ?swatch,
          dom.div(
            styles: const dom.Styles(
              raw: <String, String>{'flex': '1 1 auto', 'min-width': '0'},
            ),
            <Widget>[
              TextInput(
                value: _valueText(key),
                size: ComponentSize.sm,
                fullWidth: true,
                placeholder: huiText('value or #RRGGBB'),
                onInput: (String value) => _editValue(key, value),
                attributes: const <String, String>{
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addRow() => HuiField(
    label: huiText('Add a var'),
    error: _newKeyError?.call(),
    control: dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'grid',
          'grid-template-columns': 'minmax(0, 1fr) auto',
          'align-items': 'center',
          'gap': '8px',
          'min-width': '0',
        },
      ),
      <Widget>[
        TextInput(
          value: _newKey,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: huiText('accent'),
          onInput: (String value) {
            _newKey = value;
            if (_newKeyError != null) setState(() => _newKeyError = null);
          },
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: _add,
          label: huiText('Add'),
        ),
      ],
    ),
  );
}
