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
import 'icon_editor.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'placeholder_picker.dart';

class ComponentInspector extends StatelessWidget {
  const ComponentInspector({
    required this.store,
    required this.images,
    required this.catalogs,
    required this.session,
    required this.target,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;
  final HuiCatalogs catalogs;
  final InspectorSession session;

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
        ],
      );

  Widget _placement() => InspectorSection(
        title: 'Offset',
        children: <Widget>[
          HuiField(
            label: 'Offset from the menu centre',
            required: true,
            help: 'In blocks, multiplied by the server uiScale. z moves the '
                'component toward or away from the player; it is invisible in '
                'a flat view but still changes draw order.',
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
          session: session,
          componentId: _id,
          slot: ActionSlot.actions,
          actions: data.actions,
          description: 'Run in order on every left click, after the click '
              'event fires.',
          issues: _issues,
        ),
      ];
    }
    if (data is HuiDecorationData) {
      return <Widget>[
        const InspectorSection(
          title: 'Behaviour',
          children: <Widget>[
            HuiNote(
              'A decoration is draw-only. It has no hitbox, never receives a '
              'click and never leans toward the player. Use a button if you '
              'need either.',
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
        session: session,
        componentId: _id,
        slot: ActionSlot.trueActions,
        actions: toggle.trueActions,
        description: 'Fire when the toggle switches TO true, which is a click '
            'made while it is showing the false icon.',
        issues: _issues,
      ),
      ActionsEditor(
        store: store,
        catalogs: catalogs,
        session: session,
        componentId: _id,
        slot: ActionSlot.falseActions,
        actions: toggle.falseActions,
        description: 'Fire when the toggle switches TO false, which is a click '
            'made while it is showing the true icon.',
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
            help: 'Blocks the icon leans toward the player while the cursor is '
                'on it. 0.05 is the usual value; 0 disables the lean.',
            control: dom.div(<Widget>[
              HuiSliderField(
                value: value,
                min: 0,
                max: 1,
                step: 0.01,
                decimals: 3,
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
            label: 'Condition',
            required: true,
            trailing: PlaceholderPicker(
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
            help: 'Expanded once, at the moment the menu opens, then compared '
                'against the expected value.',
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
            help: 'Compared with equalsIgnoreCase, so "TRUE" and "true" match.',
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
          const HuiNote(
            'The condition is read once at open and never again. After that '
            'the state only changes when a player clicks. Placeholders outside '
            'HoloUI need PlaceholderAPI installed; without it the string is '
            'compared literally.',
            tone: HuiNoteTone.info,
            title: 'Evaluated once',
          ),
          const HuiNote(
            'String equality is the only comparison in the format. There are '
            'no operators, no ranges and no visibility conditions on other '
            'component types.',
          ),
        ],
      );

  Widget _toggleIcons() {
    final bool showTrue = store.togglePreviewFor(_id);
    return dom.div(
      classes: 'hui-toggle-icons',
      <Widget>[
        InspectorSection(
          title: 'Icons',
          description: 'Both icons are built when the menu opens, so a broken '
              'image breaks the open even if that state is never shown.',
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
            _iconEditor(showTrue ? IconSlot.trueIcon : IconSlot.falseIcon),
          ],
        ),
      ],
    );
  }
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
    return dom.div(
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
              classes: 'hui-inspector-header-actions',
              <Widget>[
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
        HuiField(
          label: 'Component id',
          required: true,
          help: 'How the Java API addresses this component, and what shows up '
              'in server logs. Allowed characters: letters, digits, dot, dash '
              'and underscore.',
          error: _isDuplicate
              ? 'Another component already uses this id. Both still render and '
                  'both still click, but only the first can be addressed by the '
                  'API.'
              : null,
          control: TextInput(
            value: _draft,
            size: ComponentSize.sm,
            fullWidth: true,
            onInput: (String value) => setState(() => _draft = value),
            onBlur: _commit,
            onSubmit: (String _) => _commit(),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
        ),
        dom.p(
          classes: 'hui-inspector-subtitle',
          <Widget>[
            Text(huiComponentTypeDescriptions[type] ?? ''),
          ],
        ),
      ],
    );
  }
}
