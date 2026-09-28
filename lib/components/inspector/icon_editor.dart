/// The shared icon editor: a Text | Image | Animated | Item segmented control
/// over one icon slot, plus the per-type body.
///
/// Switching type never destroys work — the outgoing icon is parked in the
/// session cache and handed back on the way home (see `inspector_session.dart`).
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/hui_geometry.dart';
import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'block_picker.dart';
import 'custom_item_picker.dart';
import 'entity_picker.dart';
import 'extras_editor.dart';
import 'display_style_editor.dart';
import 'hologram_box_editor.dart';
import '../../model/gloss_hologram_box.dart';
import 'field_help.dart';
import 'image_picker_grid.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'item_picker.dart';
import 'player_head_picker.dart';
import 'reorder_list.dart';
import 'text_icon_editor.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// Which icon field of a component data object is being edited.
enum IconSlot { icon, trueIcon, falseIcon }

extension IconSlotNames on IconSlot {
  String get jsonKey => switch (this) {
    IconSlot.icon => 'icon',
    IconSlot.trueIcon => 'trueIcon',
    IconSlot.falseIcon => 'falseIcon',
  };

  String get label => switch (this) {
    IconSlot.icon => huiText('Icon'),
    IconSlot.trueIcon => huiText('True icon'),
    IconSlot.falseIcon => huiText('False icon'),
  };
}

/// Reads the icon a slot currently holds.
HuiIcon? readIconSlot(HuiComponentData data, IconSlot slot) => switch (data) {
  final HuiButtonData button => button.icon,
  final HuiDecorationData decoration => decoration.icon,
  final HuiToggleData toggle =>
    slot == IconSlot.falseIcon ? toggle.falseIcon : toggle.trueIcon,
};

/// Writes an icon back into a slot. Slot/type pairs that do not exist are
/// ignored rather than thrown: the inspector only renders slots the type has.
void writeIconSlot(HuiComponentData data, IconSlot slot, HuiIcon? icon) {
  if (data is HuiButtonData) {
    data.icon = icon;
    return;
  }
  if (data is HuiDecorationData) {
    data.icon = icon;
    return;
  }
  if (data is HuiToggleData) {
    if (slot == IconSlot.falseIcon) {
      data.falseIcon = icon;
    } else {
      data.trueIcon = icon;
    }
  }
}

/// Doc keys for the fields of one icon type, in the order the editor shows
/// them. Text, item and custom item are edited by widgets this file only
/// mounts, so their help rides in a [HuiHelpCluster] under the type switch.
const Map<String, List<String>> huiIconTypeDocKeys = <String, List<String>>{
  'text': <String>['icon.text.text', 'icon.text.refreshTicks'],
  'textImage': <String>['icon.textImage.path'],
  'animatedTextImage': <String>['icon.animated.source', 'icon.animated.speed'],
  'item': <String>[
    'icon.item.item',
    'icon.item.count',
    'icon.item.customModelValue',
  ],
  'block': <String>['icon.block.block'],
  'customItem': <String>[
    'icon.customItem.provider',
    'icon.customItem.item',
    'icon.customItem.count',
  ],
  'entity': <String>[
    'icon.entity.entity',
    'icon.entity.width',
    'icon.entity.height',
  ],
  'playerHead': <String>[
    'icon.playerHead.player',
    'icon.playerHead.refreshTicks',
  ],
};

class IconEditor extends StatelessWidget {
  const IconEditor({
    required this.store,
    required this.images,
    required this.catalogs,
    required this.session,
    required this.componentId,
    required this.slot,
    required this.icon,
    this.catalogsLoading = false,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;
  final HuiCatalogs catalogs;
  final InspectorSession session;
  final String componentId;
  final IconSlot slot;
  final HuiIcon? icon;

  /// True until `assets/catalog/*.json` resolves; the item pickers show a
  /// skeleton for the browse row rather than letting it appear under the
  /// pointer a moment later.
  final bool catalogsLoading;

  /// Issues for this component, already filtered by the caller.
  final List<HuiIssue> issues;

  String get _sessionKey =>
      InspectorSession.iconSlot(componentId, slot.jsonKey);

  String get _fieldId => 'hui-icon-$componentId-${slot.jsonKey}';

  List<HuiIssue> get _slotIssues {
    final String marker = '.${slot.jsonKey}';
    return issues
        .where((HuiIssue issue) => issue.path.contains(marker))
        .toList();
  }

  List<HuiIssue> _issuesEndingWith(String suffix) => _slotIssues
      .where((HuiIssue issue) => issue.path.endsWith(suffix))
      .toList();

  void _write(String label, HuiIcon? next) {
    store.editComponent(componentId, label, (HuiComponent component) {
      writeIconSlot(component.data, slot, next);
    });
  }

  /// Extras are written onto the icon the store just snapshotted, not the one
  /// this widget was handed: `editComponent` runs inside `mutate`, so the
  /// object here is the live document's.
  void _writeExtras(String label, Map<String, dynamic> next) {
    store.editComponent(componentId, label, (HuiComponent component) {
      readIconSlot(component.data, slot)?.extras = next;
    });
  }

  void _writeStyle(String label, HuiIconStyle? next) {
    store.editComponent(componentId, label, (HuiComponent component) {
      readIconSlot(component.data, slot)?.style = next?.copy();
    });
  }

  void _switchType(String nextType) {
    final HuiIcon? current = icon;
    if (current != null && current.type == nextType) return;
    _write(
      '${slot.label.toLowerCase()} type $nextType',
      session.switchIcon(_sessionKey, current, nextType),
    );
  }

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-icon-editor', <Widget>[
        InspectorSection(
          title: slot.label,
          trailing: icon == null
              ? null
              : HuiArmedButton(
                  label: huiText('Remove icon'),
                  armedLabel: huiText('Remove'),
                  icon: ArcaneIcon.trash2(size: IconSize.sm),
                  iconOnly: true,
                  onConfirm: () {
                    session.rememberIcon(_sessionKey, icon);
                    _write('clear ${slot.label.toLowerCase()}', null);
                  },
                ),
          children: <Widget>[if (icon == null) _emptyState() else ..._body()],
        ),
      ]);

  List<Widget> _body() => <Widget>[
    HuiSegmented(
      value: icon!.type,
      onChanged: _switchType,
      segments: <HuiSegment>[
        HuiSegment(
          value: 'text',
          label: huiText('Text'),
          icon: ArcaneIcon.baseline(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['text']!),
        ),
        HuiSegment(
          value: 'textImage',
          label: huiText('Image'),
          icon: ArcaneIcon.image(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['textImage']!),
        ),
        HuiSegment(
          value: 'animatedTextImage',
          label: huiText('Animated'),
          icon: ArcaneIcon.film(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['animatedTextImage']!),
        ),
        HuiSegment(
          value: 'item',
          label: huiText('Item'),
          icon: ArcaneIcon.package(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['item']!),
        ),
        HuiSegment(
          value: 'block',
          label: huiText('Block'),
          icon: ArcaneIcon.package(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['block']!),
        ),
        HuiSegment(
          value: 'customItem',
          label: huiText('Custom'),
          icon: ArcaneIcon.boxes(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['customItem']!),
        ),
        HuiSegment(
          value: 'entity',
          label: huiText('Entity'),
          icon: ArcaneIcon.user(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['entity']!),
        ),
        HuiSegment(
          value: 'playerHead',
          label: huiText('Head'),
          icon: ArcaneIcon.circleUser(size: IconSize.sm),
          hint: huiText(huiIconTypeDescriptions['playerHead']!),
        ),
      ],
    ),
    HuiHelpCluster(
      huiIconTypeDocKeys[icon!.type] ?? const <String>[],
      label: huiText('Fields'),
    ),
    switch (icon!) {
      final HuiTextIcon text => dom.div(<Widget>[
        TextIconEditor(
          // Keyed by field id so flipping a toggle from the true slot to
          // the false slot remounts the textarea. Without it the state is
          // reused, the user-dirty DOM field keeps the previous slot's text
          // and the next keystroke writes it into the other slot.
          key: ValueKey<String>(_fieldId),
          fieldId: _fieldId,
          text: text.text,
          emoji: store.workspaceEmoji,
          issues: _issuesEndingWith('.text'),
          label: huiText('Text'),
          onChanged: (String label, String value) => _write(
            label,
            HuiTextIcon(value, text.style?.copy(), text.refreshTicks)
              ..box = text.box?.copy()
              ..extras = huiDeepCopyMap(text.extras),
          ),
        ),
        HuiField(
          label: huiText('Dynamic text refresh'),
          help: huiText(
            'Ticks between live function, expression and PAPI updates; '
            '0 freezes text.',
          ),
          trailing: const HuiFieldHelp('icon.text.refreshTicks'),
          defaultValue: huiPlural(
            'duration.tick_count',
            glossTextRequiresFastRefresh(text.text)
                ? 1
                : huiRuntimeDefaultTextRefreshTicks,
            oneEnglish: '{count} tick',
            otherEnglish: '{count} ticks',
          ),
          onReset: text.refreshTicks == null
              ? null
              : () => _write(
                  'dynamic text refresh',
                  HuiTextIcon(text.text, text.style?.copy(), null)
                    ..box = text.box?.copy()
                    ..extras = huiDeepCopyMap(text.extras),
                ),
          control: dom.div(<Widget>[
            HuiDurationField(
              value:
                  (text.refreshTicks ??
                          (glossTextRequiresFastRefresh(text.text)
                              ? 1
                              : huiRuntimeDefaultTextRefreshTicks))
                      .toDouble(),
              unit: HuiDurationUnit.ticks,
              min: 0,
              max: 1200,
              onChanged: (double value) => _write(
                'dynamic text refresh',
                HuiTextIcon(text.text, text.style?.copy(), value.round())
                  ..box = text.box?.copy()
                  ..extras = huiDeepCopyMap(text.extras),
              ),
            ),
            HuiInlineIssues(_issuesEndingWith('.refreshTicks')),
          ]),
        ),
      ]),
      final HuiTextImageIcon image => _ImageIconEditor(
        icon: image,
        images: images,
        inputId: '$_fieldId-upload',
        issues: _issuesEndingWith('.path'),
        onChanged: _write,
      ),
      final HuiAnimatedImageIcon animated => _AnimatedIconEditor(
        icon: animated,
        images: images,
        inputId: '$_fieldId-upload',
        issues: _slotIssues,
        onChanged: _write,
      ),
      final HuiItemIcon item => dom.div(classes: 'hui-icon-item', <Widget>[
        if (catalogsLoading) const HuiSkeletonRows(rows: 2),
        ItemIconEditor(
          icon: item,
          catalogs: catalogs,
          issues: _slotIssues,
          onChanged: (String label, HuiItemIcon next) => _write(label, next),
        ),
      ]),
      final HuiBlockIcon block => dom.div(classes: 'hui-icon-block', <Widget>[
        if (catalogsLoading) const HuiSkeletonRows(rows: 2),
        BlockIconEditor(
          icon: block,
          catalogs: catalogs,
          issues: _slotIssues,
          onChanged: (String label, HuiBlockIcon next) => _write(label, next),
        ),
      ]),
      final HuiCustomItemIcon custom =>
        dom.div(classes: 'hui-icon-custom', <Widget>[
          if (catalogsLoading) const HuiSkeletonRows(rows: 2),
          CustomItemIconEditor(
            icon: custom,
            catalogs: catalogs,
            issues: _slotIssues,
            onChanged: (String label, HuiCustomItemIcon next) =>
                _write(label, next),
          ),
        ]),
      final HuiEntityIcon entity => EntityIconEditor(
        icon: entity,
        issues: _slotIssues,
        onChanged: (String label, HuiEntityIcon next) => _write(label, next),
      ),
      final HuiPlayerHeadIcon head => PlayerHeadIconEditor(
        icon: head,
        issues: _slotIssues,
        onChanged: (String label, HuiPlayerHeadIcon next) =>
            _write(label, next),
      ),
    },
    if (icon case final HuiTextIcon text)
      HologramBoxEditor(
        box: text.box ?? GlossHologramBox(),
        issues: _slotIssues
            .where((HuiIssue issue) => issue.path.contains('.box'))
            .toList(),
        mutate: (String label, void Function(GlossHologramBox) edit) {
          final HuiTextIcon next = text.copy();
          next.box ??= GlossHologramBox();
          edit(next.box!);
          _write(label, next);
        },
      ),
    if (icon is! HuiEntityIcon)
      DisplayStyleEditor(
        style: icon!.style,
        issues: _slotIssues
            .where((HuiIssue issue) => issue.path.contains('.style'))
            .toList(),
        onChanged: _writeStyle,
      ),
    ExtrasEditor(
      title: huiText('Icon'),
      extras: icon!.extras,
      onChanged: _writeExtras,
    ),
  ];

  Widget _emptyState() => dom.div(classes: 'hui-icon-empty', <Widget>[
    HuiEmptyState(
      icon: ArcaneIcon.imageOff(size: IconSize.md),
      title: huiText('No icon'),
      body: huiText(
        'Gloss draws its magenta checker here, and a button keeps '
        'its hitbox. Pick a type to start one.',
      ),
      tone: HuiNoteTone.warning,
      actions: <Widget>[
        for (final String type in huiIconTypes)
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () => _write(
              'add ${slot.label.toLowerCase()}',
              session.recallIcon(_sessionKey, type) ?? createDefaultIcon(type),
            ),
            label: _typeLabel(type),
          ),
      ],
    ),
  ]);

  static String _typeLabel(String type) => switch (type) {
    'text' => huiText('Text'),
    'textImage' => huiText('Image'),
    'animatedTextImage' => huiText('Animated'),
    'item' => huiText('Item'),
    'block' => huiText('Block'),
    'customItem' => huiText('Custom item'),
    'entity' => huiText('Entity'),
    'playerHead' => huiText('Player head'),
    _ => type,
  };
}

class _ImageIconEditor extends StatelessWidget {
  const _ImageIconEditor({
    required this.icon,
    required this.images,
    required this.inputId,
    required this.onChanged,
    required this.issues,
  });

  final HuiTextImageIcon icon;
  final ImageLibrary images;
  final String inputId;
  final void Function(String label, HuiIcon icon) onChanged;
  final List<HuiIssue> issues;

  void _setPath(String path) => onChanged(
    'image path',
    HuiTextImageIcon(path, icon.style?.copy())
      ..extras = huiDeepCopyMap(icon.extras),
  );

  /// One source pixel is one character cell wide and one text line tall.
  static String _blocks(int pixels) =>
      (pixels * huiCharCell).toStringAsFixed(2);

  Widget _imagePreview(StoredImage stored) =>
      dom.div(classes: 'hui-image-preview', <Widget>[
        dom.img(
          src: stored.dataUri,
          alt: stored.path,
          styles: const dom.Styles(
            raw: <String, String>{'image-rendering': 'pixelated'},
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final StoredImage? stored = images.byPath(icon.path);
    return dom.div(classes: 'hui-icon-image', <Widget>[
      HuiField(
        label: huiText('Path'),
        required: true,
        trailing: const HuiFieldHelp('icon.textImage.path'),
        help: huiText('Relative to plugins/Gloss/images/.'),
        control: dom.div(<Widget>[
          TextInput(
            value: icon.path,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: huiText('logo.png'),
            onChanged: _setPath,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
              'dir': 'ltr',
            },
          ),
          HuiInlineIssues(issues),
        ]),
      ),
      if (stored != null) ...<Widget>[
        _imagePreview(stored),
        HuiDetailRow(
          huiText('Source size'),
          huiText(
            '{width}x{height} px ({characterWidth}, {lineHeight})',
            <String, Object?>{
              'width': stored.width,
              'height': stored.height,
              'characterWidth': huiPlural(
                'image.width_characters.count',
                stored.width,
                oneEnglish: '{count} character wide',
                otherEnglish: '{count} characters wide',
              ),
              'lineHeight': huiPlural(
                'image.height_lines.count',
                stored.height,
                oneEnglish: '{count} line tall',
                otherEnglish: '{count} lines tall',
              ),
            },
          ),
        ),
        HuiDetailRow(
          huiText('In-game size'),
          huiText('{width} x {height} blocks at uiScale 1', <String, Object?>{
            'width': _blocks(stored.width),
            'height': _blocks(stored.height),
          }),
        ),
      ],
      dom.div(classes: 'hui-icon-image-library', <Widget>[
        HuiEyebrow(huiText('Image library')),
        ImagePickerGrid(
          images: images,
          selected: icon.path,
          onPicked: _setPath,
        ),
        ImageUploadButton(
          images: images,
          inputId: inputId,
          label: huiText('Upload PNG, WebP or GIF'),
          onAdded: (List<String> paths) {
            if (paths.isNotEmpty) _setPath(paths.first);
          },
        ),
      ]),
      HuiMore(
        summary: huiText('Path rules and image cost'),
        children: <Widget>[
          HuiNote(
            huiText(
              'No leading slash, no "..", no drive letters - the path is read '
              'inside plugins/Gloss/images/ and nowhere else.',
            ),
          ),
          HuiNote(
            huiText(
              'Gloss draws one character per source pixel. Imports are resized '
              'to at most 16x16 because the text renderer is for compact pixel '
              'art and larger glyph walls cause poor client performance.',
            ),
          ),
        ],
      ),
    ]);
  }
}

class _AnimatedIconEditor extends StatefulWidget {
  const _AnimatedIconEditor({
    required this.icon,
    required this.images,
    required this.inputId,
    required this.onChanged,
    required this.issues,
  });

  final HuiAnimatedImageIcon icon;
  final ImageLibrary images;
  final String inputId;
  final void Function(String label, HuiIcon icon) onChanged;
  final List<HuiIssue> issues;

  @override
  State<_AnimatedIconEditor> createState() => _AnimatedIconEditorState();
}

class _AnimatedIconEditorState extends State<_AnimatedIconEditor> {
  /// Library paths picked but not yet added, in the order they were picked —
  /// which is the order they land in as frames. Staging is what makes the grid
  /// a multi-select: one click per frame, then one edit, then one undo step.
  final List<String> _staged = <String>[];

  HuiAnimatedImageIcon get _icon => component.icon;

  List<String> get _source => _icon.source;

  HuiAnimatedImageIcon _with(List<String> source, int speed) =>
      HuiAnimatedImageIcon(source, speed, _icon.style?.copy())
        ..extras = huiDeepCopyMap(_icon.extras);

  void _emit(String label, List<String> source, [int? speed]) =>
      component.onChanged(label, _with(source, speed ?? _icon.speed));

  void _toggleStaged(String path) => setState(() {
    if (!_staged.remove(path)) _staged.add(path);
  });

  void _addStaged() {
    if (_staged.isEmpty) return;
    final List<String> added = <String>[..._staged];
    setState(_staged.clear);
    _emit('frames.add:${added.length}', <String>[..._source, ...added]);
  }

  void _addFrames(List<String> paths) {
    if (paths.isEmpty) return;
    _emit('frames.add:${paths.length}', <String>[..._source, ...paths]);
  }

  void _removeFrame(int index) =>
      _emit('remove frame', <String>[..._source]..removeAt(index));

  void _duplicateFrame(int index) => _emit(
    'duplicate frame',
    <String>[..._source]..insert(index + 1, _source[index]),
  );

  void _reverse() =>
      _emit('reverse frames', _source.reversed.toList(growable: false));

  void _moveFrame(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= _source.length) return;
    _reorder(index, target);
  }

  /// The two indices are exactly `removeAt(from)` then `insert(to, moved)`,
  /// which is what [HuiReorderList] promises and what keeps a drop to a single
  /// document edit.
  void _reorder(int from, int to) {
    final List<String> next = <String>[..._source];
    final String moved = next.removeAt(from);
    next.insert(to, moved);
    _emit('reorder frames', next);
  }

  void _setFrame(int index, String path) {
    final List<String> next = <String>[..._source];
    next[index] = path;
    _emit('frame path', next);
  }

  @override
  Widget build(BuildContext context) {
    final int speed = _icon.speed;
    return dom.div(classes: 'hui-icon-animated', <Widget>[
      InspectorSection(
        title: huiText('Frames'),
        description: huiText('Played in this order and looped.'),
        trailing: dom.div(classes: 'hui-frame-tools', <Widget>[
          HuiIconButton(
            icon: ArcaneIcon.arrowUpDown(size: IconSize.sm),
            label: huiText('Reverse frame order'),
            disabled: _source.length < 2,
            onPressed: _reverse,
          ),
          const HuiFieldHelp('icon.animated.source'),
          dom.span(classes: 'hui-count-chip', <Widget>[
            Text(
              huiText("{length}", <String, Object?>{'length': _source.length}),
            ),
          ]),
        ]),
        children: <Widget>[
          if (_source.isEmpty)
            HuiEmptyState(
              icon: ArcaneIcon.triangleAlert(size: IconSize.md),
              title: huiText('No frames'),
              body: huiText(
                'An animated icon with an empty source list falls back to '
                'the missing-icon placeholder in game. Add at least one '
                'frame.',
              ),
              tone: HuiNoteTone.danger,
            )
          else
            HuiReorderList(
              itemCount: _source.length,
              handleLabel: huiText('Drag to reorder frames'),
              classes: 'hui-frame-list',
              onReorder: _reorder,
              itemBuilder: _frameRow,
            ),
          HuiInlineIssues(
            component.issues
                .where((HuiIssue issue) => issue.path.contains('.source'))
                .toList(),
          ),
        ],
      ),
      if (_source.isNotEmpty)
        AnimatedIconPreview(
          images: component.images,
          frames: _source,
          speed: speed,
        ),
      _library(),
      HuiField(
        label: huiText('Speed'),
        required: true,
        help: huiText('Ticks per frame, at 20 ticks per second.'),
        trailing: const HuiFieldHelp('icon.animated.speed'),
        defaultValue: huiPlural(
          'duration.tick_count',
          huiDefaultAnimationSpeed,
          oneEnglish: '{count} tick',
          otherEnglish: '{count} ticks',
        ),
        onReset: speed == huiDefaultAnimationSpeed
            ? null
            : () => _emit('animation speed', <String>[
                ..._source,
              ], huiDefaultAnimationSpeed),
        control: dom.div(<Widget>[
          HuiDurationField(
            value: speed.toDouble(),
            unit: HuiDurationUnit.ticks,
            min: 2,
            perLabel: huiText('per frame'),
            onChanged: (double value) =>
                _emit('animation speed', <String>[..._source], value.round()),
          ),
          HuiInlineIssues(
            component.issues
                .where((HuiIssue issue) => issue.path.endsWith('.speed'))
                .toList(),
          ),
        ]),
      ),
      HuiMore(
        summary: huiText('Frame padding and tick limits'),
        children: <Widget>[
          HuiNote(
            huiText(
              'Every frame is padded to the tallest frame with blank rows.',
            ),
          ),
          HuiNote(
            huiText(
              '1 tick is the fastest the plugin can go; 0 or less also advances '
              'every tick.',
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _library() => dom.div(classes: 'hui-icon-animated-library', <Widget>[
    HuiEyebrow(huiText('Add from library')),
    HuiNote(
      huiText(
        'Click images to line them up, then add them in one go. The same '
        'image can be used in more than one frame.',
      ),
    ),
    ImagePickerGrid(
      images: component.images,
      selected: _staged.isEmpty ? null : _staged.last,
      onPicked: _toggleStaged,
    ),
    if (_staged.isNotEmpty) _stagedTray(),
    ImageUploadButton(
      images: component.images,
      inputId: component.inputId,
      label: huiText('Upload image or GIF frames'),
      onAdded: _addFrames,
    ),
  ]);

  Widget _stagedTray() => dom.div(classes: 'hui-frame-staged', <Widget>[
    dom.div(classes: 'hui-frame-staged-chips', <Widget>[
      for (int i = 0; i < _staged.length; i++)
        dom.button(
          classes: 'hui-frame-staged-chip',
          attributes: <String, String>{
            'type': 'button',
            'aria-label': huiText(
              "Remove {value} from the queue",
              <String, Object?>{'value': _staged[i]},
            ),
          },
          events: dom.events<Null>(onClick: () => _toggleStaged(_staged[i])),
          <Widget>[
            Text(
              huiText("{value}. {value2}", <String, Object?>{
                'value': i + 1,
                'value2': _staged[i],
              }),
            ),
            ArcaneIcon.x(size: IconSize.sm),
          ],
        ),
    ]),
    dom.div(classes: 'hui-frame-staged-actions', <Widget>[
      Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: _addStaged,
        label: huiPlural(
          'icon.frames_add.count',
          _staged.length,
          oneEnglish: 'Add {count} frame',
          otherEnglish: 'Add {count} frames',
        ),
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => setState(_staged.clear),
        label: huiText('Clear'),
      ),
    ]),
  ]);

  Widget _frameRow(int index) {
    final String path = _source[index];
    final StoredImage? stored = component.images.byPath(path);
    return dom.div(classes: 'hui-frame-row', <Widget>[
      dom.span(classes: 'hui-frame-index', <Widget>[
        Text(huiText("{value}", <String, Object?>{'value': index + 1})),
      ]),
      dom.span(classes: 'hui-frame-thumb', <Widget>[
        if (stored != null)
          dom.img(
            src: stored.dataUri,
            alt: '',
            styles: const dom.Styles(
              raw: <String, String>{'image-rendering': 'pixelated'},
            ),
          )
        else
          const dom.span(classes: 'hui-frame-thumb-missing', <Widget>[]),
      ]),
      dom.div(classes: 'hui-frame-path', <Widget>[
        TextInput(
          value: path,
          size: ComponentSize.sm,
          fullWidth: true,
          onChanged: (String value) => _setFrame(index, value),
          attributes: const <String, String>{
            'autocomplete': 'off',
            'spellcheck': 'false',
            'dir': 'ltr',
          },
        ),
      ]),
      HuiIconButton(
        icon: ArcaneIcon.copy(size: IconSize.sm),
        label: huiText("Duplicate frame {value}", <String, Object?>{
          'value': index + 1,
        }),
        onPressed: () => _duplicateFrame(index),
      ),
      HuiRowTools(
        onMoveUp: index == 0 ? null : () => _moveFrame(index, -1),
        onMoveDown: index == _source.length - 1
            ? null
            : () => _moveFrame(index, 1),
        onRemove: () => _removeFrame(index),
        removeLabel: huiText('Remove frame {number}', <String, Object?>{
          'number': index + 1,
        }),
      ),
    ]);
  }
}

/// Inline playback of an animated icon at the real tick rate.
///
/// One frame every `speed` ticks, 50 ms per tick, exactly like
/// `AnimatedImageMenuIcon.tick`.
class AnimatedIconPreview extends StatefulWidget {
  const AnimatedIconPreview({
    required this.images,
    required this.frames,
    required this.speed,
    super.key,
  });

  final ImageLibrary images;
  final List<String> frames;
  final int speed;

  @override
  State<AnimatedIconPreview> createState() => _AnimatedIconPreviewState();
}

class _AnimatedIconPreviewState extends State<AnimatedIconPreview> {
  Timer? _timer;
  int _frame = 0;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateComponent(AnimatedIconPreview oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.speed != component.speed ||
        oldComponent.frames.length != component.frames.length) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (!_playing || component.frames.length < 2) return;
    final int ticks = component.speed < 2 ? 2 : component.speed;
    _timer = Timer.periodic(Duration(milliseconds: ticks * 50), (Timer _) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % component.frames.length);
    });
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final int index = component.frames.isEmpty
        ? 0
        : _frame % component.frames.length;
    final StoredImage? stored = component.frames.isEmpty
        ? null
        : component.images.byPath(component.frames[index]);
    return dom.div(classes: 'hui-animated-preview', <Widget>[
      dom.div(classes: 'hui-animated-preview-frame', <Widget>[
        if (stored != null)
          dom.img(
            src: stored.dataUri,
            alt: stored.path,
            styles: const dom.Styles(
              raw: <String, String>{'image-rendering': 'pixelated'},
            ),
          )
        else
          const dom.span(classes: 'hui-frame-thumb-missing', <Widget>[]),
      ]),
      dom.div(classes: 'hui-animated-preview-meta', <Widget>[
        HuiIconButton(
          icon: _playing
              ? ArcaneIcon.pause(size: IconSize.sm)
              : ArcaneIcon.play(size: IconSize.sm),
          label: _playing ? huiText('Pause preview') : huiText('Play preview'),
          onPressed: _togglePlay,
        ),
        dom.span(classes: 'hui-animated-preview-count', <Widget>[
          Text(
            huiText("frame {value} of {length}", <String, Object?>{
              'value': index + 1,
              'length': component.frames.length,
            }),
          ),
        ]),
      ]),
    ]);
  }
}
