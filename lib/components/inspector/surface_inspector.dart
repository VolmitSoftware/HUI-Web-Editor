/// Inspector body for a Gloss surface document: the client surface it claims,
/// the selection rule that decides who sees it, the presentation that surface
/// keeps, and the conditional variants that replace it.
///
/// Only the chosen surface's own fields are shown. `Presentation.forKind`
/// rebuilds the record out of that kind's fields and drops the rest, so an
/// editor that offered every field at once would be inviting authors to type
/// into keys the server throws away. Switching surfaces leaves the old values
/// in the file — validation names them instead of the editor deleting work.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_show.dart';
import '../../logic/gloss_text.dart';
import '../../logic/surface_validation.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'field_help.dart';
import 'gloss_visibility_editor.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class SurfaceInspector extends StatefulWidget {
  const SurfaceInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<SurfaceInspector> createState() => _SurfaceInspectorState();
}

class _SurfaceInspectorState extends State<SurfaceInspector> {
  EditorStore get _store => component.store;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossSurfaceDoc? doc = _store.surfaceDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-surface', <Widget>[
      _header(doc),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'surface.visibility',
        issues: _store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => _store.mutateSurface(
          'visibility',
          (GlossSurfaceDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      _kind(doc),
      _selection(doc),
      _presentation(
        doc,
        doc.presentation,
        r'$.presentation',
        huiText('Default presentation'),
        (void Function(GlossSurfacePresentation) mutate) => _store.mutateSurface(
          'surface default presentation',
          (GlossSurfaceDoc edited) => mutate(edited.presentation),
        ),
      ),
      _variants(doc),
    ]);
  }

  Widget _header(GlossSurfaceDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-surface', <Widget>[
          HuiEyebrow(huiText('Surface')),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('surface.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              'One line of the HUD, composed per viewer. The highest-priority '
              'matching variant supplies the whole presentation.',
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]);

  Widget _kind(GlossSurfaceDoc doc) => InspectorSection(
    title: huiText('Client surface'),
    children: <Widget>[
      HuiField(
        label: huiText('Surface'),
        trailing: const HuiFieldHelp('surface.surface'),
        control: dom.div(<Widget>[
          HuiSegmented(
            value: doc.resolvedSurface,
            segments: <HuiSegment>[
              HuiSegment(
                value: glossSurfaceKindActionbar,
                label: huiText('Action bar'),
              ),
              HuiSegment(
                value: glossSurfaceKindBossbar,
                label: huiText('Boss bar'),
              ),
              HuiSegment(
                value: glossSurfaceKindTitle,
                label: huiText('Title card'),
              ),
            ],
            onChanged: (String value) => _store.mutateSurface(
              'surface kind',
              (GlossSurfaceDoc edited) => edited.surface = value,
            ),
          ),
          HuiInlineIssues(_issuesFor(r'$.surface')),
        ]),
      ),
      HuiNote(
        huiText(
          'Changing the surface leaves the other fields in the file. Gloss '
          'keeps only the ones this surface uses and drops the rest without '
          'saying so, which the Problems list calls out.',
        ),
      ),
    ],
  );

  Widget _selection(GlossSurfaceDoc doc) => InspectorSection(
    title: huiText('Surface selection'),
    children: <Widget>[
      _integerField(
        label: huiText('Priority'),
        trailing: const HuiFieldHelp('surface.select.priority'),
        value: doc.select.priority,
        path: r'$.select.priority',
        onChanged: (int value) => _store.mutateSurface(
          'surface select priority',
          (GlossSurfaceDoc edited) => edited.select.priority = value,
        ),
      ),
      _conditionField(
        label: huiText('When'),
        value: doc.select.when,
        path: r'$.select.when',
        onChanged: (String value) => _store.mutateSurface(
          'surface select condition',
          (GlossSurfaceDoc edited) => edited.select.when = value,
        ),
      ),
      HuiNote(
        huiText(
          'A document with no condition takes false, so it never reaches '
          'anyone until you write one. Highest priority wins its lane.',
        ),
      ),
    ],
  );

  Widget _variants(GlossSurfaceDoc doc) => InspectorSection(
    title: huiText('Conditional variants'),
    children: <Widget>[
      for (int index = 0; index < doc.variants.length; index++)
        _variant(doc, index),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: () => _store.mutateSurface(
          'add surface variant',
          (GlossSurfaceDoc edited) => edited.variants.add(
            GlossSurfaceVariant(
              id: _nextVariantId(edited),
              priority: 10,
              when: 'viewer.healthPercent <= 25',
              presentation: edited.presentation.copy(),
            ),
          ),
        ),
        label: huiText('Add variant'),
      ),
      HuiNote(
        huiText(
          'Variants are complete presentations. Matching variants never '
          'merge; the highest priority wins and the default is the fallback.',
        ),
      ),
    ],
  );

  Widget _variant(GlossSurfaceDoc doc, int index) {
    final GlossSurfaceVariant variant = doc.variants[index];
    final String path =
        r'$.variants['
        '$index]';
    return dom.div(classes: 'hui-surface-variant', <Widget>[
      dom.div(classes: 'hui-inspector-title-row', <Widget>[
        HuiEyebrow(
          huiText('Variant {id}', <String, Object?>{
            'id': variant.id.isEmpty ? index + 1 : variant.id,
          }),
        ),
        HuiIconButton(
          label: huiText('Delete variant'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onPressed: () => _store.mutateSurface(
            'delete surface variant',
            (GlossSurfaceDoc edited) => edited.variants.removeAt(index),
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
            onChanged: (String value) => _store.mutateSurface(
              'surface variant id',
              (GlossSurfaceDoc edited) => edited.variants[index].id = value,
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
        onChanged: (int value) => _store.mutateSurface(
          'surface variant priority',
          (GlossSurfaceDoc edited) => edited.variants[index].priority = value,
        ),
      ),
      _conditionField(
        label: huiText('When'),
        value: variant.when,
        path: '$path.when',
        onChanged: (String value) => _store.mutateSurface(
          'surface variant condition',
          (GlossSurfaceDoc edited) => edited.variants[index].when = value,
        ),
      ),
      _presentation(
        doc,
        variant.presentation,
        '$path.presentation',
        huiText('Variant presentation'),
        (void Function(GlossSurfacePresentation) mutate) => _store.mutateSurface(
          'surface variant presentation',
          (GlossSurfaceDoc edited) =>
              mutate(edited.variants[index].presentation),
        ),
      ),
    ]);
  }

  Widget _presentation(
    GlossSurfaceDoc doc,
    GlossSurfacePresentation presentation,
    String path,
    String title,
    void Function(void Function(GlossSurfacePresentation)) mutate,
  ) {
    final String surface = doc.resolvedSurface;
    return InspectorSection(
      title: title,
      children: <Widget>[
        if (surface == glossSurfaceKindActionbar)
          _lineField(
            label: huiText('Text'),
            docKey: 'surface.presentation.text',
            value: presentation.text ?? '',
            path: '$path.text',
            placeholder: huiText(r'&7Welcome, &f{{ player.name }}'),
            onChanged: (String value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.text = value;
                }),
          ),
        if (surface != glossSurfaceKindActionbar)
          _lineField(
            label: huiText('Title'),
            docKey: 'surface.presentation.title',
            value: presentation.title ?? '',
            path: '$path.title',
            placeholder: huiText('&d&lWELCOME BACK'),
            onChanged: (String value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.title = value;
                }),
          ),
        if (surface == glossSurfaceKindTitle)
          _lineField(
            label: huiText('Subtitle'),
            docKey: 'surface.presentation.subtitle',
            value: presentation.subtitle ?? '',
            path: '$path.subtitle',
            placeholder: huiText('&7{{ viewer.name }}'),
            onChanged: (String value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.subtitle = value;
                }),
          ),
        if (surface == glossSurfaceKindBossbar) ...<Widget>[
          _lineField(
            label: huiText('Progress'),
            docKey: 'surface.presentation.progress',
            value: presentation.progress ?? '',
            path: '$path.progress',
            placeholder: huiText('{{ viewer.health / viewer.maxHealth }}'),
            preview: false,
            onChanged: (String value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.progress = value.isEmpty ? null : value;
                }),
          ),
          _nameField(
            label: huiText('Colour'),
            docKey: 'surface.presentation.color',
            value: presentation.color,
            allowed: glossSurfaceColors,
            fallback: glossSurfaceDefaultColor,
            path: '$path.color',
            onChanged: (String? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.color = value;
                }),
          ),
          _nameField(
            label: huiText('Notch style'),
            docKey: 'surface.presentation.style',
            value: presentation.style,
            allowed: glossSurfaceStyles,
            fallback: glossSurfaceDefaultStyle,
            path: '$path.style',
            onChanged: (String? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.style = value;
                }),
          ),
        ],
        if (surface == glossSurfaceKindTitle) ...<Widget>[
          _optionalIntField(
            label: huiText('Fade in'),
            docKey: 'surface.presentation.fadeInTicks',
            value: presentation.fadeInTicks,
            fallback: glossSurfaceDefaultFadeInTicks,
            path: '$path.fadeInTicks',
            onChanged: (int? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.fadeInTicks = value;
                }),
          ),
          _optionalIntField(
            label: huiText('Stay'),
            docKey: 'surface.presentation.stayTicks',
            value: presentation.stayTicks,
            fallback: glossSurfaceDefaultStayTicks,
            path: '$path.stayTicks',
            onChanged: (int? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.stayTicks = value;
                }),
          ),
          _optionalIntField(
            label: huiText('Fade out'),
            docKey: 'surface.presentation.fadeOutTicks',
            value: presentation.fadeOutTicks,
            fallback: glossSurfaceDefaultFadeOutTicks,
            path: '$path.fadeOutTicks',
            onChanged: (int? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.fadeOutTicks = value;
                }),
          ),
          _nameField(
            label: huiText('Trigger'),
            docKey: 'surface.presentation.trigger',
            value: presentation.trigger,
            allowed: glossSurfaceTriggers,
            fallback: glossSurfaceDefaultTrigger,
            path: '$path.trigger',
            onChanged: (String? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.trigger = value;
                }),
          ),
          _optionalIntField(
            label: huiText('Repeat every'),
            docKey: 'surface.presentation.repeatTicks',
            value: presentation.repeatTicks,
            fallback: null,
            path: '$path.repeatTicks',
            onChanged: (int? value) =>
                mutate((GlossSurfacePresentation edited) {
                  edited.repeatTicks = value;
                }),
          ),
        ],
        _slots(presentation, path, mutate),
        _nameField(
          label: huiText('Compositor lane'),
          docKey: 'surface.presentation.priority',
          value: presentation.priority,
          allowed: glossSurfacePriorities,
          fallback: glossSurfaceDefaultPriority,
          path: '$path.priority',
          onChanged: (String? value) =>
              mutate((GlossSurfacePresentation edited) {
                edited.priority = value;
              }),
        ),
        _optionalIntField(
          label: huiText('Lifetime'),
          docKey: 'surface.presentation.ttlTicks',
          value: presentation.ttlTicks,
          fallback: null,
          path: '$path.ttlTicks',
          onChanged: (int? value) => mutate((GlossSurfacePresentation edited) {
            edited.ttlTicks = value;
          }),
        ),
      ],
    );
  }

  Widget _slots(
    GlossSurfacePresentation presentation,
    String path,
    void Function(void Function(GlossSurfacePresentation)) mutate,
  ) {
    final List<String> selected = presentation.slots ?? const <String>[];
    return HuiField(
      label: huiText('Slots'),
      trailing: const HuiFieldHelp('surface.presentation.slots'),
      control: dom.div(<Widget>[
        for (final String slot in glossSurfaceSlots)
          HuiSwitchRow(
            label: slot,
            value: selected.contains(slot),
            onChanged: (bool value) =>
                mutate((GlossSurfacePresentation edited) {
                  final List<String> next = <String>[
                    for (final String candidate in glossSurfaceSlots)
                      if (candidate == slot
                          ? value
                          : (edited.slots ?? const <String>[]).contains(
                              candidate,
                            ))
                        candidate,
                  ];
                  edited.slots = next.isEmpty ? null : next;
                }),
          ),
        HuiInlineIssues(_issuesFor('$path.slots')),
      ]),
    );
  }

  Widget _lineField({
    required String label,
    required String docKey,
    required String value,
    required String path,
    required String placeholder,
    required void Function(String) onChanged,
    bool preview = true,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(docKey),
    control: dom.div(<Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: placeholder,
        onChanged: onChanged,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      if (preview)
        dom.div(classes: 'hui-hologram-line-preview', <Widget>[
          GlossTextLine(
            render: renderGlossLine(
              value,
              animations: _store.workspaceAnimations,
              emoji: _store.workspaceEmoji,
              expressionSamples: glossSurfaceSamples,
            ),
          ),
        ]),
      if (preview)
        dom.div(classes: 'hui-surface-chips', <Widget>[
          ...huiMissingAnimationChips(
            value,
            _store.workspaceAnimations,
            where: 'on the HUD',
          ),
        ]),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  /// A field whose value is one of a fixed set of wire names, plus the
  /// "leave it out" option that takes the runtime default.
  Widget _nameField({
    required String label,
    required String docKey,
    required String? value,
    required List<String> allowed,
    required String fallback,
    required String path,
    required void Function(String?) onChanged,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(docKey),
    control: dom.div(<Widget>[
      ArcaneSelect(
        value: value ?? '',
        options: <ArcaneSelectOption>[
          ArcaneSelectOption(
            value: '',
            label: huiText('Default ({value})', <String, Object?>{
              'value': fallback,
            }),
          ),
          for (final String option in allowed)
            ArcaneSelectOption(value: option, label: option),
        ],
        onChanged: (String next) => onChanged(next.isEmpty ? null : next),
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  /// A tick count the file may leave out. Clearing the box removes the key
  /// rather than writing a zero the server would clamp.
  Widget _optionalIntField({
    required String label,
    required String docKey,
    required int? value,
    required int? fallback,
    required String path,
    required void Function(int?) onChanged,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(docKey),
    help: fallback == null
        ? huiText('Leave empty to leave the key out.')
        : huiText('Leave empty for the default of {value}.', <String, Object?>{
            'value': fallback,
          }),
    control: dom.div(<Widget>[
      TextInput(
        value: value == null ? '' : '$value',
        size: ComponentSize.sm,
        fullWidth: true,
        onChanged: (String raw) {
          if (raw.trim().isEmpty) {
            onChanged(null);
            return;
          }
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

  Widget _integerField({
    required String label,
    required int value,
    required String path,
    required void Function(int) onChanged,
    Widget? trailing,
  }) => HuiField(
    label: label,
    trailing: trailing,
    control: dom.div(<Widget>[
      TextInput(
        value: '$value',
        size: ComponentSize.sm,
        fullWidth: true,
        onChanged: (String raw) {
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
        onChanged: onChanged,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  String _nextVariantId(GlossSurfaceDoc doc) {
    int suffix = doc.variants.length + 1;
    String id = 'variant-$suffix';
    while (doc.variants.any((GlossSurfaceVariant item) => item.id == id)) {
      suffix++;
      id = 'variant-$suffix';
    }
    return id;
  }
}
