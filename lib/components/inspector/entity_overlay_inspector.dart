library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/entity_overlay_preview.dart';
import '../../logic/validation.dart';
import '../../model/gloss_entity_overlays.dart';
import '../../model/gloss_hologram_box.dart';
import '../../model/hui_icons.dart';
import '../../model/particle_layer.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'animation_reference_picker.dart';
import 'display_style_editor.dart';
import 'inspector_widgets.dart';
import 'hologram_box_editor.dart';
import 'particle_layers_editor.dart';
import 'preview_expr_field.dart';
import 'reorder_list.dart';
import 'text_icon_editor.dart';

class EntityOverlayInspector extends StatefulWidget {
  const EntityOverlayInspector({required this.store, super.key});
  final EditorStore store;

  @override
  State<EntityOverlayInspector> createState() => _EntityOverlayInspectorState();
}

class _EntityOverlayInspectorState extends State<EntityOverlayInspector> {
  int _selected = 0;
  EditorStore get _store => component.store;
  GlossEntityOverlaysDoc? get _doc => _store.entityOverlaysDoc;

  @override
  Widget build(BuildContext context) {
    final GlossEntityOverlaysDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-entity-overlays', <Widget>[
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        HuiEyebrow(huiText('Entity overlays')),
        dom.h2(classes: 'hui-inspector-title', <Widget>[Text(_store.menuId)]),
        HuiRevisionRow(revision: doc.revision),
      ]),
      _lines(doc),
      _box(doc),
      DisplayStyleEditor(
        style: doc.style,
        defaults: defaultEntityOverlayStyle(),
        entityOverlay: true,
        issues: _issues(r'$.style'),
        onChanged: (String label, HuiIconStyle? next) =>
            _store.mutateEntityOverlays(
              label,
              (GlossEntityOverlaysDoc edited) =>
                  edited.style = next ?? defaultEntityOverlayStyle(),
            ),
      ),
      ParticleLayersEditor(
        layers: doc.particleLayers,
        sectionKey: 'entity-overlays.particles',
        mutate: (String label, void Function(List<GlossParticleLayer>) edit) =>
            _store.mutateEntityOverlays(
              label,
              (GlossEntityOverlaysDoc edited) => edit(edited.particleLayers),
            ),
      ),
      InspectorSection(
        title: huiText('Visibility'),
        sectionKey: 'entity-overlays.visibility',
        children: <Widget>[
          _toggle(
            'Enabled',
            doc.enabled,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.enabled = value,
          ),
          PreviewExprField(
            label: huiText('Pane visibility'),
            raw: doc.show,
            kind: PreviewExprKind.boolean,
            showCondition: true,
            categoryVariableNames: entityOverlayVariables,
            scope: entityOverlayVariables.toSet(),
            issues: _issues(r'$.show'),
            onChanged: (Object? value) => _store.mutateEntityOverlays(
              'pane visibility',
              (GlossEntityOverlaysDoc edited) => edited.show = value ?? true,
            ),
          ),
          _toggle(
            'Include players',
            doc.includePlayers,
            (GlossEntityOverlaysDoc edited, bool value) =>
                edited.includePlayers = value,
          ),
          _number(
            'Display range',
            'range',
            doc.range,
            'Nearby range in blocks. 1..64.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.range = value,
          ),
          _number(
            'Update interval',
            'updateIntervalTicks',
            doc.updateIntervalTicks,
            'Ticks between entity updates. 1..40.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.updateIntervalTicks = value.round(),
            integer: true,
          ),
          _number(
            'Maximum entities per viewer',
            'maxEntitiesPerViewer',
            doc.maxEntitiesPerViewer,
            'Maximum simultaneous overlays for each viewer. 1..256.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.maxEntitiesPerViewer = value.round(),
            integer: true,
          ),
          _number(
            'Maximum active overlays',
            'maxActiveOverlays',
            doc.maxActiveOverlays,
            'Maximum overlays tracked at once across every viewer. 16..16384.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.maxActiveOverlays = value.round(),
            integer: true,
          ),
          _text(
            'Excluded worlds',
            doc.blacklistWorlds.join(', '),
            'World names, separated by commas.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.blacklistWorlds = _list(value),
          ),
          _text(
            'Excluded entity types',
            doc.excludedEntityTypes.join(', '),
            'Bukkit entity types, separated by commas.',
            (GlossEntityOverlaysDoc edited, String value) =>
                edited.excludedEntityTypes = _list(
                  value,
                ).map((String type) => type.toUpperCase()).toList(),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Health and placement'),
        sectionKey: 'entity-overlays.health',
        children: <Widget>[
          _number(
            'Vertical offset',
            'verticalOffset',
            doc.verticalOffset,
            'Blocks above the entity bounds. -2..8.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.verticalOffset = value,
          ),
          _number(
            'Health segments',
            'healthSegments',
            doc.healthSegments,
            'Number of segments in the health bar. 1..40.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.healthSegments = value.round(),
            integer: true,
          ),
          _number(
            'Hit highlight duration',
            'hitHighlightMs',
            doc.hitHighlightMs,
            'Milliseconds to show lost health segments and damage. 0..10000.',
            (GlossEntityOverlaysDoc edited, double value) =>
                edited.hitHighlightMs = value.round(),
            integer: true,
          ),
        ],
      ),
      InspectorSection(
        title: huiText('React and Adapt'),
        sectionKey: 'entity-overlays.integrations',
        initiallyOpen: false,
        children: <Widget>[
          dom.p(classes: 'hui-inspector-lede', <Widget>[
            Text(
              huiText(
                'React supplies mob stack counts automatically. Adapt Discovery Insight adds details to its selected entity. Adapt can restrict the global overlays to active Insight targets through its own adaptation config.',
              ),
            ),
          ]),
          dom.p(classes: 'hui-inspector-lede', <Widget>[
            Text(
              huiText(
                'Use the sample controls to compare these states. Sample controls do not change server settings.',
              ),
            ),
          ]),
        ],
      ),
    ]);
  }

  Widget _lines(GlossEntityOverlaysDoc doc) => InspectorSection(
    title: huiText('Lines'),
    children: <Widget>[
      dom.div(classes: 'hui-field-tools', <Widget>[
        for (final String type in glossEntityOverlayLineTypes)
          Button(
            label: switch (type) {
              'text' => huiText('Add text'),
              'insight' => huiText('Add Insight'),
              _ => huiText('Add spacer'),
            },
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            disabled: doc.lines.length >= 64,
            onPressed: doc.lines.length >= 64 ? null : () => _addLine(type),
          ),
      ]),
      if (doc.lines.isEmpty)
        HuiNote(huiText('No lines are visible for this sample.')),
      HuiReorderList(
        itemCount: doc.lines.length,
        onReorder: _moveLine,
        itemBuilder: (int index) {
          final GlossEntityOverlayLine line = doc.lines[index];
          return dom.div(classes: 'hui-entity-overlay-line-select', <Widget>[
            Button(
              label: '${index + 1}. ${line.id}',
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              attributes: <String, String>{
                'aria-pressed': (_selected == index).toString(),
              },
              onPressed: () => setState(() => _selected = index),
            ),
            HuiIconButton(
              label: huiText('Move line up'),
              icon: ArcaneIcon.chevronUp(size: IconSize.sm),
              onPressed: index == 0 ? null : () => _moveLine(index, index - 1),
            ),
            HuiIconButton(
              label: huiText('Move line down'),
              icon: ArcaneIcon.chevronDown(size: IconSize.sm),
              onPressed: index == doc.lines.length - 1
                  ? null
                  : () => _moveLine(index, index + 1),
            ),
            HuiIconButton(
              label: huiText('Delete line {number}', <String, Object?>{
                'number': index + 1,
              }),
              icon: ArcaneIcon.trash2(size: IconSize.sm),
              onPressed: () => _store.mutateEntityOverlays(
                'delete line',
                (GlossEntityOverlaysDoc edited) => edited.lines.removeAt(index),
              ),
            ),
          ]);
        },
      ),
      if (doc.lines.isNotEmpty)
        _lineEditor(doc, _selected.clamp(0, doc.lines.length - 1)),
      HuiInlineIssues(_issues(r'$.lines')),
    ],
  );

  Widget _lineEditor(GlossEntityOverlaysDoc doc, int index) {
    final GlossEntityOverlayLine line = doc.lines[index];
    return dom.div(classes: 'hui-entity-overlay-line-editor', <Widget>[
      HuiField(
        label: huiText('Line id'),
        control: TextInput(
          value: line.id,
          size: ComponentSize.sm,
          attributes: <String, String>{'aria-label': huiText('Line id')},
          onChanged: (String value) => _editLine(
            index,
            'line id',
            (GlossEntityOverlayLine edited) => edited.id = value,
          ),
        ),
      ),
      HuiField(
        label: huiText('Line type'),
        control: ArcaneSelect(
          value: line.type,
          size: ComponentSize.sm,
          options: <ArcaneSelectOption>[
            ArcaneSelectOption(value: 'text', label: huiText('Text')),
            ArcaneSelectOption(value: 'insight', label: huiText('Insight')),
            ArcaneSelectOption(value: 'spacer', label: huiText('Spacer')),
          ],
          onChanged: (String value) =>
              _editLine(index, 'line type', (GlossEntityOverlayLine edited) {
                edited.type = value;
                if (value == 'insight' && edited.text.isEmpty) {
                  edited.text = '{insight}';
                }
              }),
        ),
      ),
      PreviewExprField(
        key: ValueKey<String>('entity-line-$index-show'),
        label: huiText('Line visibility'),
        raw: line.show,
        kind: PreviewExprKind.boolean,
        showCondition: true,
        categoryVariableNames: entityOverlayVariables,
        scope: entityOverlayVariables.toSet(),
        issues: _issues('\$.lines[$index].show'),
        onChanged: (Object? value) => _editLine(
          index,
          'line visibility',
          (GlossEntityOverlayLine edited) => edited.show = value ?? true,
        ),
      ),
      if (line.type != 'spacer') ...<Widget>[
        TextIconEditor(
          key: ValueKey<String>('entity-line-$index-text'),
          fieldId: 'entity-line-$index-text',
          text: line.text,
          emoji: _store.workspaceEmoji,
          label: huiText('Line text'),
          issues: _issues('\$.lines[$index].text'),
          onChanged: (String label, String value) => _editLine(
            index,
            label,
            (GlossEntityOverlayLine edited) => edited.text = value,
          ),
        ),
        dom.div(classes: 'hui-field-tools', <Widget>[
          AnimationReferencePicker(
            store: _store,
            onPicked: (String value) => _editLine(
              index,
              'insert animation',
              (GlossEntityOverlayLine edited) => edited.text += value,
            ),
          ),
          ArcaneSelect(
            value: '',
            placeholder: huiText('Insert entity value'),
            size: ComponentSize.sm,
            options: <ArcaneSelectOption>[
              for (final String token in <String>[
                '{name}',
                '{bar}',
                '{health}',
                '{max_health}',
                '{count}',
                '{damage}',
                '{attack}',
                '{armor}',
                '{insight}',
                '{type}',
                '{distance}',
              ])
                ArcaneSelectOption(value: token, label: token),
            ],
            onChanged: (String value) => _editLine(
              index,
              'insert entity value',
              (GlossEntityOverlayLine edited) => edited.text += value,
            ),
          ),
        ]),
        if (line.type == 'insight')
          HuiNote(
            huiText(
              'This line repeats once for each detail supplied by Adapt Insight.',
            ),
          ),
      ],
    ]);
  }

  Widget _box(GlossEntityOverlaysDoc doc) => HologramBoxEditor(
    box: doc.box,
    sectionKey: 'entity-overlays.box',
    issues: _issues(r'$.box'),
    mutate: (String label, void Function(GlossHologramBox) edit) =>
        _store.mutateEntityOverlays(
          label,
          (GlossEntityOverlaysDoc edited) => edit(edited.box),
        ),
  );

  void _addLine(String type) {
    final GlossEntityOverlaysDoc? doc = _doc;
    if (doc == null) return;
    int suffix = doc.lines.length + 1;
    while (doc.lines.any(
      (GlossEntityOverlayLine line) => line.id == 'line-$suffix',
    )) {
      suffix++;
    }
    _store.mutateEntityOverlays(
      'add line',
      (GlossEntityOverlaysDoc edited) => edited.lines.add(
        GlossEntityOverlayLine(
          id: 'line-$suffix',
          type: type,
          text: type == 'insight' ? '{insight}' : '',
        ),
      ),
    );
    setState(() => _selected = doc.lines.length - 1);
  }

  void _moveLine(int from, int to) {
    _store.mutateEntityOverlays('reorder line', (
      GlossEntityOverlaysDoc edited,
    ) {
      final GlossEntityOverlayLine moved = edited.lines.removeAt(from);
      edited.lines.insert(to, moved);
    });
    setState(() => _selected = to);
  }

  void _editLine(
    int index,
    String label,
    void Function(GlossEntityOverlayLine) edit,
  ) => _store.mutateEntityOverlays(
    label,
    (GlossEntityOverlaysDoc edited) => edit(edited.lines[index]),
  );

  List<HuiIssue> _issues(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  Widget _toggle(
    String label,
    bool value,
    void Function(GlossEntityOverlaysDoc, bool) edit,
  ) => ArcaneToggleSwitch(
    label: huiText(label),
    labelLeft: true,
    size: ComponentSize.sm,
    value: value,
    onChanged: (bool next) => _store.mutateEntityOverlays(
      label,
      (GlossEntityOverlaysDoc doc) => edit(doc, next),
    ),
  );

  Widget _number(
    String label,
    String path,
    num value,
    String help,
    void Function(GlossEntityOverlaysDoc, double) edit, {
    bool integer = false,
  }) => HuiField(
    label: huiText(label),
    help: huiText(help),
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value.toDouble(),
        ariaLabel: huiText(label),
        integer: integer,
        decimals: integer ? 0 : 2,
        step: integer ? 1 : 0.05,
        onChanged: (double next) => _store.mutateEntityOverlays(
          label,
          (GlossEntityOverlaysDoc doc) => edit(doc, next),
        ),
      ),
      HuiInlineIssues(_issues('\$.$path')),
    ]),
  );

  Widget _text(
    String label,
    String value,
    String help,
    void Function(GlossEntityOverlaysDoc, String) edit,
  ) => HuiField(
    label: huiText(label),
    help: huiText(help),
    control: TextInput(
      value: value,
      size: ComponentSize.sm,
      fullWidth: true,
      attributes: <String, String>{'aria-label': huiText(label)},
      onChanged: (String next) => _store.mutateEntityOverlays(
        label,
        (GlossEntityOverlaysDoc doc) => edit(doc, next),
      ),
    ),
  );

  static List<String> _list(String source) => source
      .split(',')
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList();
}
