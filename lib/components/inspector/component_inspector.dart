/// Properties of the selected component: header, offset, then the per-type
/// sections.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'actions_editor.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'icon_editor.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'placeholder_picker.dart';

/// DOM id of the component id input. `inspector_pane.dart` focuses it when the
/// canvas asks the inspector to take over.
const String huiComponentIdFieldId = 'hui-component-id-field';

class ComponentInspector extends StatelessWidget {
  const ComponentInspector({
    required this.store,
    required this.images,
    required this.catalogs,
    required this.session,
    required this.target,
    this.catalogsLoading = false,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;
  final HuiCatalogs catalogs;
  final InspectorSession session;

  /// True until the shipped catalogue assets have resolved. Only the pickers
  /// that read them care; every free-text control works from the first paint.
  final bool catalogsLoading;

  /// The selected component.
  final HuiComponent target;

  String get _id => target.id;

  List<HuiIssue> get _issues => store.issuesFor(_id);

  List<HuiIssue> _issuesFor(String suffix) =>
      _issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-inspector-body is-component', <Widget>[
        _ComponentHeader(store: store, session: session, target: target),
        _placement(),
        ..._typeSections(),
        _extras(),
      ]);

  Widget _placement() => InspectorSection(
    title: 'Offset',
    children: <Widget>[
      HuiField(
        label: 'From the menu centre',
        required: true,
        trailing: const HuiFieldHelp('component.offset'),
        help: 'Blocks, multiplied by the server uiScale.',
        control: dom.div(<Widget>[
          HuiVec3Field(
            // Typed entry bypasses grid snapping on purpose: an exact
            // number in a field should survive, unlike a canvas drag.
            value: target.offset,
            onChanged: (Vec3 value) => store.editComponent(
              _id,
              'offset',
              (HuiComponent edited) => edited.offset = value,
            ),
          ),
          HuiInlineIssues(_issuesFor('.offset')),
        ]),
      ),
      const HuiMore(
        summary: 'What z does',
        children: <Widget>[
          HuiNote(
            'z moves the component toward or away from the player. It is '
            'invisible in a flat view but still changes draw order, so two '
            'components at the same x and y stack by z.',
          ),
        ],
      ),
    ],
  );

  List<Widget> _typeSections() {
    final HuiComponentData data = target.data;
    // Icon first. It is the most-edited section of the pane by a wide margin,
    // and it used to open two scrolls down behind Highlight and Hitbox — two
    // sections most components never touch.
    if (data is HuiButtonData) {
      return <Widget>[
        _iconEditor(IconSlot.icon),
        _highlight(data),
        _hitbox(data),
        ActionsEditor(
          store: store,
          catalogs: catalogs,
          catalogsLoading: catalogsLoading,
          session: session,
          componentId: _id,
          slot: ActionSlot.actions,
          actions: data.actions,
          description:
              'Matching actions run in order for each configured click.',
          issues: _issues,
        ),
      ];
    }
    if (data is HuiDecorationData) {
      return <Widget>[
        const dom.div(classes: 'hui-inspector-aside', <Widget>[
          HuiMore(
            summary: 'How a decoration behaves',
            children: <Widget>[
              HuiNote(
                'Draw-only: no hitbox, never receives a click and never leans '
                'toward the player. Use a button if you need either.',
              ),
            ],
          ),
        ]),
        _iconEditor(IconSlot.icon),
      ];
    }
    final HuiToggleData toggle = data as HuiToggleData;
    return <Widget>[
      _condition(toggle),
      _toggleIcons(),
      _highlight(toggle),
      _hitbox(toggle),
      ActionsEditor(
        store: store,
        catalogs: catalogs,
        catalogsLoading: catalogsLoading,
        session: session,
        componentId: _id,
        slot: ActionSlot.trueActions,
        actions: toggle.trueActions,
        description: 'Fire on a click made while the false icon is showing.',
        issues: _issues,
      ),
      ActionsEditor(
        store: store,
        catalogs: catalogs,
        catalogsLoading: catalogsLoading,
        session: session,
        componentId: _id,
        slot: ActionSlot.falseActions,
        actions: toggle.falseActions,
        description: 'Fire on a click made while the true icon is showing.',
        issues: _issues,
      ),
    ];
  }

  Widget _highlight(HuiComponentData data) {
    final double value = switch (data) {
      HuiButtonData(:final double highlightModifier) => highlightModifier,
      HuiToggleData(:final double highlightModifier) => highlightModifier,
      HuiDecorationData() => 0,
    };
    final int duration = switch (data) {
      HuiButtonData(:final int hoverDurationTicks) => hoverDurationTicks,
      HuiToggleData(:final int hoverDurationTicks) => hoverDurationTicks,
      HuiDecorationData() => huiRuntimeDefaultHoverDurationTicks,
    };
    final HuiHoverEasing easing = switch (data) {
      HuiButtonData(:final HuiHoverEasing hoverEasing) => hoverEasing,
      HuiToggleData(:final HuiHoverEasing hoverEasing) => hoverEasing,
      HuiDecorationData() => huiRuntimeDefaultHoverEasing,
    };
    return InspectorSection(
      title: 'Highlight',
      sectionKey: 'component.highlight',
      children: <Widget>[
        HuiField(
          label: 'Highlight modifier',
          trailing: const HuiFieldHelp('button.highlightModifier'),
          help:
              'Blocks the icon leans toward the player under the cursor. '
              '0.05 is usual; 0 disables the lean.',
          control: dom.div(<Widget>[
            HuiSliderField(
              label: 'Highlight modifier',
              value: value,
              min: 0,
              max: 1,
              step: 0.01,
              decimals: 3,
              // The shipped-example value and what a new component is born
              // with, so it is the one worth getting back to.
              resetTo: huiDefaultHighlightModifier,
              onChanged: (double next) =>
                  _editHover('highlight modifier', modifier: next),
            ),
            HuiInlineIssues(_issuesFor('.highlightModifier')),
          ]),
        ),
        HuiField(
          label: 'Duration',
          trailing: const HuiFieldHelp('button.hoverDurationTicks'),
          help: 'Ticks to enter or leave the hovered pose. 0 is instant.',
          defaultValue: '$huiRuntimeDefaultHoverDurationTicks ticks',
          onReset: duration == huiRuntimeDefaultHoverDurationTicks
              ? null
              : () => _editHover(
                  'hover duration',
                  duration: huiRuntimeDefaultHoverDurationTicks,
                ),
          control: dom.div(<Widget>[
            HuiDurationField(
              value: duration.toDouble(),
              unit: HuiDurationUnit.ticks,
              min: 0,
              max: 40,
              onChanged: (double next) =>
                  _editHover('hover duration', duration: next.round()),
            ),
            HuiInlineIssues(_issuesFor('.hoverDurationTicks')),
          ]),
        ),
        HuiField(
          label: 'Easing',
          trailing: const HuiFieldHelp('button.hoverEasing'),
          help: 'Curve used for both hover entry and exit.',
          defaultValue: huiRuntimeDefaultHoverEasing.label,
          onReset: easing == huiRuntimeDefaultHoverEasing
              ? null
              : () => _editHover(
                  'hover easing',
                  easing: huiRuntimeDefaultHoverEasing,
                ),
          control: ArcaneSelect(
            value: easing.jsonValue,
            fullWidth: true,
            size: ComponentSize.sm,
            options: <ArcaneSelectOption>[
              for (final HuiHoverEasing value in HuiHoverEasing.values)
                ArcaneSelectOption(label: value.label, value: value.jsonValue),
            ],
            onChange: (String next) => _editHover(
              'hover easing',
              easing: HuiHoverEasing.fromJson(next),
            ),
          ),
        ),
      ],
    );
  }

  void _editHover(
    String label, {
    double? modifier,
    int? duration,
    HuiHoverEasing? easing,
  }) {
    store.editComponent(_id, label, (HuiComponent edited) {
      switch (edited.data) {
        case final HuiButtonData data:
          if (modifier != null) data.highlightModifier = modifier;
          if (duration != null) data.hoverDurationTicks = duration;
          if (easing != null) data.hoverEasing = easing;
        case final HuiToggleData data:
          if (modifier != null) data.highlightModifier = modifier;
          if (duration != null) data.hoverDurationTicks = duration;
          if (easing != null) data.hoverEasing = easing;
        case HuiDecorationData():
          break;
      }
    });
  }

  Widget _hitbox(HuiComponentData data) {
    final HuiHitbox? hitbox = switch (data) {
      HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
      HuiToggleData(:final HuiHitbox? hitbox) => hitbox,
      HuiDecorationData() => null,
    };
    return InspectorSection(
      title: 'Hitbox',
      sectionKey: 'component.hitbox',
      description:
          'The click plane stays fixed while the icon animates on hover.',
      children: <Widget>[
        HuiSwitchRow(
          label: 'Move with component',
          value: hitbox?.anchor != HuiHitboxAnchor.menu,
          trailing: const HuiFieldHelp('button.hitbox'),
          help: hitbox?.anchor == HuiHitboxAnchor.menu
              ? 'Detached: drag the component and outlined plane independently.'
              : 'Linked: moving the component carries its click plane.',
          onChanged: (bool linked) => store.setHitboxAnchor(
            _id,
            linked ? HuiHitboxAnchor.button : HuiHitboxAnchor.menu,
          ),
        ),
        HuiField(
          label: hitbox?.anchor == HuiHitboxAnchor.menu
              ? 'From the menu centre'
              : 'From the component',
          trailing: const HuiFieldHelp('button.hitbox'),
          help: 'Right, up and forward in blocks at uiScale 1.',
          control: dom.div(<Widget>[
            HuiVec3Field(
              value: hitbox?.offset ?? Vec3.zero(),
              onChanged: (Vec3 value) => store.setHitboxOffset(_id, value),
            ),
            HuiInlineIssues(_issuesFor('.hitbox.offset')),
          ]),
        ),
        HuiSwitchRow(
          label: 'Custom size',
          value: hitbox?.hasCustomSize ?? false,
          trailing: const HuiFieldHelp('button.hitbox'),
          help: !(hitbox?.hasCustomSize ?? false)
              ? 'Automatic: follows the rendered icon and resizes when it changes.'
              : 'Fixed dimensions in blocks at uiScale 1.',
          onChanged: (bool enabled) => store.editComponent(
            _id,
            enabled ? 'enable custom hitbox' : 'use automatic hitbox',
            (HuiComponent edited) {
              final HuiComponentData editedData = edited.data;
              final HuiHitbox? existing = switch (editedData) {
                HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
                HuiToggleData(:final HuiHitbox? hitbox) => hitbox,
                HuiDecorationData() => null,
              };
              if (editedData is! HuiDecorationData) {
                final HuiHitbox editedHitbox = existing ?? HuiHitbox();
                editedHitbox
                  ..width = enabled ? huiDefaultHitboxWidth : null
                  ..height = enabled ? huiDefaultHitboxHeight : null;
                final HuiHitbox? next = editedHitbox.isDefault
                    ? null
                    : editedHitbox;
                switch (editedData) {
                  case HuiButtonData():
                    editedData.hitbox = next;
                  case HuiToggleData():
                    editedData.hitbox = next;
                  case HuiDecorationData():
                    break;
                }
              }
            },
          ),
        ),
        if (hitbox?.hasCustomSize ?? false) ...<Widget>[
          HuiField(
            label: 'Width',
            required: true,
            // The value "custom size" is switched on with — the plane a new
            // custom hitbox is born at, so it is the one worth getting back to.
            defaultValue: '$huiDefaultHitboxWidth',
            onReset: hitbox!.width == huiDefaultHitboxWidth
                ? null
                : () => _editHitbox(
                    'hitbox width',
                    (HuiHitbox edited) => edited.width = huiDefaultHitboxWidth,
                  ),
            control: dom.div(<Widget>[
              HuiNumberField(
                value: hitbox.width!,
                min: 0.01,
                step: 0.05,
                suffix: 'blocks',
                onChanged: (double value) => _editHitbox(
                  'hitbox width',
                  (HuiHitbox edited) => edited.width = value,
                ),
              ),
              HuiInlineIssues(_issuesFor('.hitbox.width')),
            ]),
          ),
          HuiField(
            label: 'Height',
            required: true,
            defaultValue: '$huiDefaultHitboxHeight',
            onReset: hitbox.height == huiDefaultHitboxHeight
                ? null
                : () => _editHitbox(
                    'hitbox height',
                    (HuiHitbox edited) =>
                        edited.height = huiDefaultHitboxHeight,
                  ),
            control: dom.div(<Widget>[
              HuiNumberField(
                value: hitbox.height!,
                min: 0.01,
                step: 0.05,
                suffix: 'blocks',
                onChanged: (double value) => _editHitbox(
                  'hitbox height',
                  (HuiHitbox edited) => edited.height = value,
                ),
              ),
              HuiInlineIssues(_issuesFor('.hitbox.height')),
            ]),
          ),
        ],
      ],
    );
  }

  void _editHitbox(String label, void Function(HuiHitbox hitbox) edit) {
    store.editComponent(_id, label, (HuiComponent edited) {
      final HuiComponentData data = edited.data;
      final HuiHitbox? hitbox = switch (data) {
        HuiButtonData(:final HuiHitbox? hitbox) => hitbox,
        HuiToggleData(:final HuiHitbox? hitbox) => hitbox,
        HuiDecorationData() => null,
      };
      if (hitbox != null) {
        edit(hitbox);
      }
    });
  }

  Widget _iconEditor(IconSlot slot) => IconEditor(
    store: store,
    images: images,
    catalogs: catalogs,
    catalogsLoading: catalogsLoading,
    session: session,
    componentId: _id,
    slot: slot,
    icon: readIconSlot(target.data, slot),
    issues: _issues,
  );

  Widget _condition(HuiToggleData toggle) => InspectorSection(
    title: 'Condition',
    description: 'Decides which icon the toggle starts on.',
    children: <Widget>[
      HuiField(
        label: 'Placeholder',
        required: true,
        trailing: dom.div(classes: 'hui-field-tools', <Widget>[
          PlaceholderPicker(
            catalogs: catalogs,
            onPicked: (String placeholder) => store.editComponent(
              _id,
              'toggle condition',
              (HuiComponent edited) {
                final HuiComponentData data = edited.data;
                if (data is HuiToggleData) data.condition = placeholder;
              },
            ),
          ),
          const HuiFieldHelp('toggle.condition'),
        ]),
        help: 'Expanded once, when the menu opens.',
        control: dom.div(<Widget>[
          TextInput(
            value: toggle.condition,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: '%essentials_fly%',
            onInput: (String value) => store.editComponent(
              _id,
              'toggle condition',
              (HuiComponent edited) {
                final HuiComponentData data = edited.data;
                if (data is HuiToggleData) data.condition = value;
              },
            ),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          HuiInlineIssues(_issuesFor('.condition')),
        ]),
      ),
      HuiField(
        label: 'Expected value',
        required: true,
        trailing: const HuiFieldHelp('toggle.expectedValue'),
        help: 'Case-insensitive, so "TRUE" and "true" match.',
        control: dom.div(<Widget>[
          TextInput(
            value: toggle.expectedValue,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: 'true',
            onInput: (String value) => store.editComponent(
              _id,
              'toggle expected value',
              (HuiComponent edited) {
                final HuiComponentData data = edited.data;
                if (data is HuiToggleData) data.expectedValue = value;
              },
            ),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          HuiInlineIssues(_issuesFor('.expectedValue')),
        ]),
      ),
      const HuiMore(
        summary: 'How the comparison works',
        children: <Widget>[
          HuiNote(
            'The condition is read once at open and never again. After that '
            'the state only changes when a player clicks. Placeholders '
            'outside Gloss need PlaceholderAPI installed; without it the '
            'string is compared literally.',
            tone: HuiNoteTone.info,
            title: 'Evaluated once',
          ),
          HuiNote(
            'String equality is the only comparison in the format. There '
            'are no operators, no ranges and no visibility conditions on '
            'other component types.',
          ),
        ],
      ),
    ],
  );

  /// Both icons at once. They are built together at open
  /// (`ToggleComponent.java:43-44`), so an editor that only ever showed the
  /// previewed one hid half of what the menu has to load — and the segmented
  /// control now means only what it says: which one the canvas draws.
  Widget _toggleIcons() {
    final bool showTrue = store.togglePreviewFor(_id);
    return dom.div(classes: 'hui-toggle-icons', <Widget>[
      InspectorSection(
        title: 'Icons',
        description:
            'Both are built at open, so a broken one breaks the '
            'open even if it is never shown.',
        trailing: HuiSegmented(
          value: showTrue ? 'true' : 'false',
          onChanged: (String value) =>
              store.setTogglePreview(_id, value == 'true'),
          segments: const <HuiSegment>[
            HuiSegment(
              value: 'true',
              label: 'True',
              hint: 'Preview the true icon on the canvas.',
            ),
            HuiSegment(
              value: 'false',
              label: 'False',
              hint: 'Preview the false icon on the canvas.',
            ),
          ],
        ),
        children: <Widget>[
          _copyAcross(),
          dom.div(classes: 'hui-toggle-icon-grid', <Widget>[
            dom.div(
              classes: classNames(<String?>[
                'hui-toggle-icon-cell',
                showTrue ? 'is-previewed' : null,
              ]),
              <Widget>[_iconEditor(IconSlot.trueIcon)],
            ),
            dom.div(
              classes: classNames(<String?>[
                'hui-toggle-icon-cell',
                showTrue ? null : 'is-previewed',
              ]),
              <Widget>[_iconEditor(IconSlot.falseIcon)],
            ),
          ]),
        ],
      ),
    ]);
  }

  Widget _copyAcross() => dom.div(classes: 'hui-toggle-copy', <Widget>[
    Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.sm,
      icon: ArcaneIcon.arrowDown(size: IconSize.sm),
      onPressed: () =>
          _copyIcon(from: IconSlot.trueIcon, to: IconSlot.falseIcon),
      child: const Text('True to false'),
    ),
    Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.sm,
      icon: ArcaneIcon.arrowUp(size: IconSize.sm),
      onPressed: () =>
          _copyIcon(from: IconSlot.falseIcon, to: IconSlot.trueIcon),
      child: const Text('False to true'),
    ),
  ]);

  /// Plain overwrite, no confirm: the toast names what happened and undo takes
  /// it back in one step.
  void _copyIcon({required IconSlot from, required IconSlot to}) {
    final String fromName = from == IconSlot.trueIcon ? 'true' : 'false';
    final String toName = to == IconSlot.trueIcon ? 'true' : 'false';
    store.editComponent(_id, 'copy $fromName icon to $toName', (
      HuiComponent edited,
    ) {
      writeIconSlot(edited.data, to, readIconSlot(edited.data, from)?.copy());
    });
    ArcaneSonner.success('Copied the $fromName icon onto the $toName icon.');
  }

  /// Two objects carry unknown keys here, and they are not the same object: the
  /// wrapper holds `id`, `offset` and `data`, while the data holds the type's
  /// own fields. A key on the wrong one still round-trips, it just sits
  /// somewhere else in the exported JSON.
  Widget _extras() => InspectorSection(
    title: 'Extra keys',
    // Closed until asked for: unknown keys are a round-trip guarantee, not
    // something an author edits on the way past.
    sectionKey: 'component.extras',
    initiallyOpen: false,
    children: <Widget>[
      ExtrasEditor(
        title: 'Component',
        extras: target.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            store.editComponent(
              _id,
              label,
              (HuiComponent edited) => edited.extras = next,
            ),
      ),
      ExtrasEditor(
        title: '${target.data.type} data',
        extras: target.data.extras,
        onChanged: (String label, Map<String, dynamic> next) =>
            store.editComponent(
              _id,
              label,
              (HuiComponent edited) => edited.data.extras = next,
            ),
      ),
    ],
  );
}

/// Type badge, id field with live duplicate detection, duplicate and delete.
class _ComponentHeader extends StatefulWidget {
  const _ComponentHeader({
    required this.store,
    required this.session,
    required this.target,
  });

  final EditorStore store;
  final InspectorSession session;
  final HuiComponent target;

  @override
  State<_ComponentHeader> createState() => _ComponentHeaderState();
}

class _ComponentHeaderState extends State<_ComponentHeader> {
  late String _draft;

  @override
  void initState() {
    super.initState();
    _draft = component.target.id;
  }

  @override
  void didUpdateComponent(_ComponentHeader oldComponent) {
    super.didUpdateComponent(oldComponent);
    // Only follow the document when the id actually changed elsewhere, so a
    // rename round trip never fights what is being typed.
    if (oldComponent.target.id != component.target.id &&
        _draft != component.target.id) {
      _draft = component.target.id;
    }
  }

  String get _currentId => component.target.id;

  bool get _isDuplicate {
    final String sanitized = sanitizeComponentId(_draft);
    int count = 0;
    for (final HuiComponent other in component.store.menu.components) {
      if (other.id == sanitized) count++;
    }
    return sanitized == _currentId ? count > 1 : count > 0;
  }

  void _commit() {
    final String sanitized = sanitizeComponentId(_draft);
    if (sanitized == _currentId) {
      if (_draft != sanitized) setState(() => _draft = sanitized);
      return;
    }
    component.session.renameComponent(_currentId, sanitized);
    component.store.renameComponent(_currentId, sanitized);
    setState(() => _draft = sanitized);
  }

  String get _typeLabel => switch (component.target.data) {
    HuiButtonData() => 'Button',
    HuiDecorationData() => 'Decoration',
    HuiToggleData() => 'Toggle',
  };

  @override
  Widget build(BuildContext context) {
    final String type = component.target.data.type;
    // `display: contents` (04-inspector.css): the three rows below have to be
    // direct children of the scrolling body, or `position: sticky` on the
    // header would only hold for the height of this wrapper.
    return dom.div(classes: 'hui-inspector-headgroup', <Widget>[
      // Sticky: the badge, the id and the destructive actions stay on screen
      // for the whole scroll, so what is being edited is never in doubt.
      dom.div(classes: 'hui-inspector-header is-component', <Widget>[
        dom.div(classes: 'hui-inspector-header-top', <Widget>[
          dom.span(classes: 'hui-type-badge is-$type', <Widget>[
            Text(_typeLabel),
          ]),
          dom.div(
            classes: classNames(<String?>[
              'hui-inspector-header-id',
              _isDuplicate ? 'is-invalid' : null,
            ]),
            <Widget>[
              TextInput(
                value: _draft,
                size: ComponentSize.sm,
                fullWidth: true,
                placeholder: 'component-id',
                prefix: const Text('id', color: TextColor.muted),
                onInput: (String value) => setState(() => _draft = value),
                onBlur: _commit,
                onSubmit: (String _) => _commit(),
                // Fixed id: a canvas double-click pulls focus here through
                // `hui-inspector-focus`, which can only address the DOM.
                attributes: const <String, String>{
                  'id': huiComponentIdFieldId,
                  'aria-label': 'Component id',
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                },
              ),
            ],
          ),
          dom.div(classes: 'hui-inspector-header-actions', <Widget>[
            const HuiFieldHelp('component.id'),
            HuiIconButton(
              icon: ArcaneIcon.copy(size: IconSize.sm),
              label: 'Duplicate component',
              onPressed: () => component.store.duplicateComponent(_currentId),
            ),
            HuiArmedButton(
              label: 'Delete component',
              armedLabel: 'Delete',
              icon: ArcaneIcon.trash2(size: IconSize.sm),
              iconOnly: true,
              variant: ButtonVariant.ghost,
              onConfirm: () => component.store.deleteComponent(_currentId),
            ),
          ]),
        ]),
        if (_isDuplicate)
          const dom.p(classes: 'hui-inspector-header-error', <Widget>[
            Text(
              'Another component already uses this id. Both still render, '
              'but only the first can be addressed by the API.',
            ),
          ]),
      ]),
      dom.p(classes: 'hui-inspector-lede', <Widget>[
        Text(huiComponentTypeDescriptions[type] ?? ''),
      ]),
      const dom.div(classes: 'hui-inspector-aside', <Widget>[
        HuiMore(
          summary: 'About the id',
          children: <Widget>[
            HuiNote(
              'How the Java API addresses this component, and what shows up '
              'in server logs. Allowed characters: letters, digits, dot, '
              'dash and underscore.',
            ),
          ],
        ),
      ]),
    ]);
  }
}
