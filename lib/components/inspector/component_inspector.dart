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
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-inspector-body is-component',
        <Widget>[
          _ComponentHeader(store: store, session: session, target: target),
          _placement(),
          ..._typeSections(),
          _extras(),
        ],
      );

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
    if (data is HuiButtonData) {
      return <Widget>[
        _highlight(data.highlightModifier, (double value) {
          store.editComponent(_id, 'highlight modifier',
              (HuiComponent edited) {
            final HuiComponentData editedData = edited.data;
            if (editedData is HuiButtonData) {
              editedData.highlightModifier = value;
            }
          });
        }),
        _iconEditor(IconSlot.icon),
        ActionsEditor(
          store: store,
          catalogs: catalogs,
          catalogsLoading: catalogsLoading,
          session: session,
          componentId: _id,
          slot: ActionSlot.actions,
          actions: data.actions,
          description: 'Run in order on every left click.',
          issues: _issues,
        ),
      ];
    }
    if (data is HuiDecorationData) {
      return <Widget>[
        const dom.div(
          classes: 'hui-inspector-aside',
          <Widget>[
            HuiMore(
              summary: 'How a decoration behaves',
              children: <Widget>[
                HuiNote(
                  'Draw-only: no hitbox, never receives a click and never leans '
                  'toward the player. Use a button if you need either.',
                ),
              ],
            ),
          ],
        ),
        _iconEditor(IconSlot.icon),
      ];
    }
    final HuiToggleData toggle = data as HuiToggleData;
    return <Widget>[
      _highlight(toggle.highlightModifier, (double value) {
        store.editComponent(_id, 'highlight modifier', (HuiComponent edited) {
          final HuiComponentData editedData = edited.data;
          if (editedData is HuiToggleData) {
            editedData.highlightModifier = value;
          }
        });
      }),
      _condition(toggle),
      _toggleIcons(),
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

  Widget _highlight(double value, void Function(double value) onChanged) =>
      InspectorSection(
        title: 'Highlight',
        children: <Widget>[
          HuiField(
            label: 'Highlight modifier',
            trailing: const HuiFieldHelp('button.highlightModifier'),
            help: 'Blocks the icon leans toward the player under the cursor. '
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
                onChanged: onChanged,
              ),
              HuiInlineIssues(_issuesFor('.highlightModifier')),
            ]),
          ),
        ],
      );

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
            trailing: dom.div(
              classes: 'hui-field-tools',
              <Widget>[
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
              ],
            ),
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
                'outside HoloUI need PlaceholderAPI installed; without it the '
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
    return dom.div(
      classes: 'hui-toggle-icons',
      <Widget>[
        InspectorSection(
          title: 'Icons',
          description: 'Both are built at open, so a broken one breaks the '
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
            dom.div(
              classes: 'hui-toggle-icon-grid',
              <Widget>[
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
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _copyAcross() => dom.div(
        classes: 'hui-toggle-copy',
        <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.arrowDown(size: IconSize.sm),
            onPressed: () => _copyIcon(
              from: IconSlot.trueIcon,
              to: IconSlot.falseIcon,
            ),
            child: const Text('True to false'),
          ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.arrowUp(size: IconSize.sm),
            onPressed: () => _copyIcon(
              from: IconSlot.falseIcon,
              to: IconSlot.trueIcon,
            ),
            child: const Text('False to true'),
          ),
        ],
      );

  /// Plain overwrite, no confirm: the toast names what happened and undo takes
  /// it back in one step.
  void _copyIcon({required IconSlot from, required IconSlot to}) {
    final String fromName = from == IconSlot.trueIcon ? 'true' : 'false';
    final String toName = to == IconSlot.trueIcon ? 'true' : 'false';
    store.editComponent(_id, 'copy $fromName icon to $toName',
        (HuiComponent edited) {
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
      dom.div(
        classes: 'hui-inspector-header is-component',
        <Widget>[
          dom.div(
            classes: 'hui-inspector-header-top',
            <Widget>[
              dom.span(
                classes: 'hui-type-badge is-$type',
                <Widget>[Text(_typeLabel)],
              ),
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
              dom.div(
                classes: 'hui-inspector-header-actions',
                <Widget>[
                  const HuiFieldHelp('component.id'),
                  HuiIconButton(
                    icon: ArcaneIcon.copy(size: IconSize.sm),
                    label: 'Duplicate component',
                    onPressed: () =>
                        component.store.duplicateComponent(_currentId),
                  ),
                  HuiArmedButton(
                    label: 'Delete component',
                    armedLabel: 'Delete',
                    icon: ArcaneIcon.trash2(size: IconSize.sm),
                    iconOnly: true,
                    variant: ButtonVariant.ghost,
                    onConfirm: () => component.store.deleteComponent(_currentId),
                  ),
                ],
              ),
            ],
          ),
          if (_isDuplicate)
            const dom.p(
              classes: 'hui-inspector-header-error',
              <Widget>[
                Text(
                  'Another component already uses this id. Both still render, '
                  'but only the first can be addressed by the API.',
                ),
              ],
            ),
        ],
      ),
      dom.p(
        classes: 'hui-inspector-lede',
        <Widget>[
          Text(huiComponentTypeDescriptions[type] ?? ''),
        ],
      ),
      const dom.div(
        classes: 'hui-inspector-aside',
        <Widget>[
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
        ],
      ),
    ]);
  }
}
