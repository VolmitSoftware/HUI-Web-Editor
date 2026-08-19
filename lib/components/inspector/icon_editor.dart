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
import 'field_help.dart';
import 'image_picker_grid.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'item_picker.dart';
import 'preview_color_swatch.dart';
import 'reorder_list.dart';
import 'text_icon_editor.dart';

/// Which icon field of a component data object is being edited.
enum IconSlot { icon, trueIcon, falseIcon }

extension IconSlotNames on IconSlot {
  String get jsonKey => switch (this) {
    IconSlot.icon => 'icon',
    IconSlot.trueIcon => 'trueIcon',
    IconSlot.falseIcon => 'falseIcon',
  };

  String get label => switch (this) {
    IconSlot.icon => 'Icon',
    IconSlot.trueIcon => 'True icon',
    IconSlot.falseIcon => 'False icon',
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
                  label: 'Remove icon',
                  armedLabel: 'Remove',
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
          label: 'Text',
          icon: ArcaneIcon.baseline(size: IconSize.sm),
          hint: huiIconTypeDescriptions['text'],
        ),
        HuiSegment(
          value: 'textImage',
          label: 'Image',
          icon: ArcaneIcon.image(size: IconSize.sm),
          hint: huiIconTypeDescriptions['textImage'],
        ),
        HuiSegment(
          value: 'animatedTextImage',
          label: 'Animated',
          icon: ArcaneIcon.film(size: IconSize.sm),
          hint: huiIconTypeDescriptions['animatedTextImage'],
        ),
        HuiSegment(
          value: 'item',
          label: 'Item',
          icon: ArcaneIcon.package(size: IconSize.sm),
          hint: huiIconTypeDescriptions['item'],
        ),
        HuiSegment(
          value: 'block',
          label: 'Block',
          icon: ArcaneIcon.package(size: IconSize.sm),
          hint: huiIconTypeDescriptions['block'],
        ),
        HuiSegment(
          value: 'customItem',
          label: 'Custom',
          icon: ArcaneIcon.boxes(size: IconSize.sm),
          hint: huiIconTypeDescriptions['customItem'],
        ),
        HuiSegment(
          value: 'entity',
          label: 'Entity',
          icon: ArcaneIcon.user(size: IconSize.sm),
          hint: huiIconTypeDescriptions['entity'],
        ),
      ],
    ),
    HuiHelpCluster(
      huiIconTypeDocKeys[icon!.type] ?? const <String>[],
      label: 'Fields',
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
          label: 'Text',
          onChanged: (String label, String value) => _write(
            label,
            HuiTextIcon(value, text.style?.copy(), text.refreshTicks)
              ..extras = huiDeepCopyMap(text.extras),
          ),
        ),
        HuiField(
          label: 'Placeholder refresh',
          help: 'Ticks between live PlaceholderAPI updates; 0 freezes text.',
          trailing: const HuiFieldHelp('icon.text.refreshTicks'),
          control: dom.div(<Widget>[
            HuiNumberField(
              value: (text.refreshTicks ?? 10).toDouble(),
              min: 0,
              max: 1200,
              step: 1,
              integer: true,
              suffix: 'ticks',
              onChanged: (double value) => _write(
                'placeholder refresh',
                HuiTextIcon(text.text, text.style?.copy(), value.round())
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
    },
    if (icon is! HuiEntityIcon)
      _DisplayStyleEditor(
        style: icon!.style,
        issues: _slotIssues
            .where((HuiIssue issue) => issue.path.contains('.style'))
            .toList(),
        onChanged: _writeStyle,
      ),
    ExtrasEditor(title: 'Icon', extras: icon!.extras, onChanged: _writeExtras),
  ];

  Widget _emptyState() => dom.div(classes: 'hui-icon-empty', <Widget>[
    HuiEmptyState(
      icon: ArcaneIcon.imageOff(size: IconSize.md),
      title: 'No icon',
      body:
          'Gloss draws its magenta checker here, and a button keeps '
          'its hitbox. Pick a type to start one.',
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
            child: Text(_typeLabel(type)),
          ),
      ],
    ),
  ]);

  static String _typeLabel(String type) => switch (type) {
    'text' => 'Text',
    'textImage' => 'Image',
    'animatedTextImage' => 'Animated',
    'item' => 'Item',
    'block' => 'Block',
    'customItem' => 'Custom item',
    'entity' => 'Entity',
    _ => type,
  };
}

class _DisplayStyleEditor extends StatelessWidget {
  const _DisplayStyleEditor({
    required this.style,
    required this.onChanged,
    required this.issues,
  });

  final HuiIconStyle? style;
  final void Function(String label, HuiIconStyle? style) onChanged;
  final List<HuiIssue> issues;

  HuiIconStyle _next(void Function(HuiIconStyle style) update) {
    final HuiIconStyle next = style?.copy() ?? createDefaultIconStyle();
    update(next);
    return next;
  }

  List<ArcaneSelectOption> _options(List<String> values, String current) =>
      <ArcaneSelectOption>[
        for (final String value in values)
          ArcaneSelectOption(label: _label(value), value: value),
        if (!values.contains(current))
          ArcaneSelectOption(label: '$current (unknown)', value: current),
      ];

  @override
  Widget build(BuildContext context) {
    final HuiIconStyle? current = style;
    if (current == null) {
      return InspectorSection(
        title: 'Display style',
        description: 'Uses the runtime display-entity defaults.',
        children: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () =>
                onChanged('add display style', createDefaultIconStyle()),
            child: const Text('Customize display'),
          ),
        ],
      );
    }

    return InspectorSection(
      title: 'Display style',
      description:
          'Packet display metadata shared by text, image and item icons.',
      trailing: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => onChanged('remove display style', null),
        child: const Text('Use defaults'),
      ),
      children: <Widget>[
        HuiField(
          label: 'Billboard',
          help: 'Fixed follows the menu transform; other modes face viewers.',
          control: ArcaneSelect(
            value: current.billboard,
            size: ComponentSize.sm,
            fullWidth: true,
            options: _options(huiIconBillboards, current.billboard),
            onChange: (String value) => onChanged(
              'icon billboard',
              _next((HuiIconStyle next) => next.billboard = value),
            ),
          ),
        ),
        HuiField(
          label: 'Non-uniform scale',
          help: 'Multiplies the menu scale and the automatic click plane.',
          control: _numberGrid(<Widget>[
            _number(
              'X',
              current.scaleX,
              0.01,
              64,
              (double value) => onChanged(
                'icon scale X',
                _next((HuiIconStyle next) => next.scaleX = value),
              ),
            ),
            _number(
              'Y',
              current.scaleY,
              0.01,
              64,
              (double value) => onChanged(
                'icon scale Y',
                _next((HuiIconStyle next) => next.scaleY = value),
              ),
            ),
            _number(
              'Z',
              current.scaleZ,
              0.01,
              64,
              (double value) => onChanged(
                'icon scale Z',
                _next((HuiIconStyle next) => next.scaleZ = value),
              ),
            ),
          ]),
        ),
        HuiMore(
          summary: 'Text appearance',
          children: <Widget>[
            HuiSwitchRow(
              label: 'Text shadow',
              value: current.shadow,
              onChanged: (bool value) => onChanged(
                'text shadow',
                _next((HuiIconStyle next) => next.shadow = value),
              ),
            ),
            HuiSwitchRow(
              label: 'See through blocks',
              value: current.seeThrough,
              onChanged: (bool value) => onChanged(
                'text see through',
                _next((HuiIconStyle next) => next.seeThrough = value),
              ),
            ),
            HuiField(
              label: 'Alignment',
              control: ArcaneSelect(
                value: current.textAlignment,
                size: ComponentSize.sm,
                fullWidth: true,
                options: _options(huiIconTextAlignments, current.textAlignment),
                onChange: (String value) => onChanged(
                  'text alignment',
                  _next((HuiIconStyle next) => next.textAlignment = value),
                ),
              ),
            ),
            _colorField(
              label: 'Background ARGB',
              value: current.backgroundArgb,
              placeholder: '#00000000',
              onInput: (String value) => onChanged(
                'text background',
                _next((HuiIconStyle next) => next.backgroundArgb = value),
              ),
            ),
            HuiField(
              label: 'Opacity',
              control: HuiNumberField(
                value: current.textOpacity.toDouble(),
                min: 0,
                max: 255,
                step: 1,
                integer: true,
                onChanged: (double value) => onChanged(
                  'text opacity',
                  _next(
                    (HuiIconStyle next) => next.textOpacity = value.round(),
                  ),
                ),
              ),
            ),
            HuiField(
              label: 'Line width',
              help: 'Vanilla text-display wrap width in font pixels.',
              control: HuiNumberField(
                value: current.lineWidth.toDouble(),
                min: 1,
                max: 16384,
                step: 1,
                integer: true,
                onChanged: (double value) => onChanged(
                  'text line width',
                  _next((HuiIconStyle next) => next.lineWidth = value.round()),
                ),
              ),
            ),
          ],
        ),
        HuiMore(
          summary: 'Lighting, shadow and culling',
          children: <Widget>[
            HuiSwitchRow(
              label: 'Override brightness',
              value: current.hasBrightnessOverride,
              onChanged: (bool value) => onChanged(
                'brightness override',
                _next((HuiIconStyle next) {
                  next.blockLight = value ? 15 : null;
                  next.skyLight = value ? 15 : null;
                }),
              ),
            ),
            if (current.hasBrightnessOverride)
              _numberGrid(<Widget>[
                _number(
                  'Block',
                  (current.blockLight ?? 15).toDouble(),
                  0,
                  15,
                  (double value) => onChanged(
                    'block light',
                    _next(
                      (HuiIconStyle next) => next.blockLight = value.round(),
                    ),
                  ),
                  integer: true,
                ),
                _number(
                  'Sky',
                  (current.skyLight ?? 15).toDouble(),
                  0,
                  15,
                  (double value) => onChanged(
                    'sky light',
                    _next((HuiIconStyle next) => next.skyLight = value.round()),
                  ),
                  integer: true,
                ),
              ]),
            HuiField(
              label: 'Display view range',
              help: 'Multiplier applied by the Minecraft client.',
              control: HuiNumberField(
                value: current.viewRange,
                min: 0.01,
                max: 64,
                onChanged: (double value) => onChanged(
                  'display view range',
                  _next((HuiIconStyle next) => next.viewRange = value),
                ),
              ),
            ),
            _numberGrid(<Widget>[
              _number(
                'Shadow radius',
                current.shadowRadius,
                0,
                64,
                (double value) => onChanged(
                  'shadow radius',
                  _next((HuiIconStyle next) => next.shadowRadius = value),
                ),
              ),
              _number(
                'Strength',
                current.shadowStrength,
                0,
                1,
                (double value) => onChanged(
                  'shadow strength',
                  _next((HuiIconStyle next) => next.shadowStrength = value),
                ),
              ),
            ]),
            _numberGrid(<Widget>[
              _number(
                'Cull width',
                current.cullingWidth,
                0,
                4096,
                (double value) => onChanged(
                  'culling width',
                  _next((HuiIconStyle next) => next.cullingWidth = value),
                ),
              ),
              _number(
                'Cull height',
                current.cullingHeight,
                0,
                4096,
                (double value) => onChanged(
                  'culling height',
                  _next((HuiIconStyle next) => next.cullingHeight = value),
                ),
              ),
            ]),
            HuiSwitchRow(
              label: 'Glow outline',
              value: current.glowColor != null,
              onChanged: (bool value) => onChanged(
                'glow outline',
                _next(
                  (HuiIconStyle next) =>
                      next.glowColor = value ? '#FFFFFFFF' : null,
                ),
              ),
            ),
            if (current.glowColor != null)
              _colorField(
                label: 'Glow ARGB',
                value: current.glowColor!,
                placeholder: '#FFFFFFFF',
                onInput: (String value) => onChanged(
                  'glow color',
                  _next((HuiIconStyle next) => next.glowColor = value),
                ),
              ),
          ],
        ),
        HuiInlineIssues(issues),
      ],
    );
  }

  Widget _number(
    String axis,
    double value,
    double minimum,
    double maximum,
    void Function(double value) onChanged, {
    bool integer = false,
  }) => HuiNumberField(
    value: value,
    min: minimum,
    max: maximum,
    step: integer ? 1 : 0.05,
    integer: integer,
    prefixLabel: axis,
    onChanged: onChanged,
  );

  Widget _numberGrid(List<Widget> children) => dom.div(
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'grid',
        'grid-template-columns': 'repeat(auto-fit, minmax(92px, 1fr))',
        'gap': '8px',
      },
    ),
    children,
  );

  Widget _colorField({
    required String label,
    required String value,
    required String placeholder,
    required void Function(String value) onInput,
  }) => HuiField(
    label: label,
    trailing: previewColorSwatch(value),
    help: 'Eight hexadecimal digits in #AARRGGBB order.',
    control: TextInput(
      value: value,
      size: ComponentSize.sm,
      fullWidth: true,
      placeholder: placeholder,
      onInput: onInput,
      attributes: const <String, String>{
        'autocomplete': 'off',
        'spellcheck': 'false',
      },
    ),
  );

  static String _label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
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
        label: 'Path',
        required: true,
        trailing: const HuiFieldHelp('icon.textImage.path'),
        help: 'Relative to plugins/Gloss/images/.',
        control: dom.div(<Widget>[
          TextInput(
            value: icon.path,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: 'logo.png',
            onInput: _setPath,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          HuiInlineIssues(issues),
        ]),
      ),
      if (stored != null) ...<Widget>[
        _imagePreview(stored),
        HuiDetailRow(
          'Source size',
          '${stored.width}x${stored.height} px '
              '(${stored.width} chars wide, ${stored.height} lines tall)',
        ),
        HuiDetailRow(
          'In-game size',
          '${_blocks(stored.width)} x ${_blocks(stored.height)} blocks '
              'at uiScale 1',
        ),
      ],
      dom.div(classes: 'hui-icon-image-library', <Widget>[
        const HuiEyebrow('Image library'),
        ImagePickerGrid(
          images: images,
          selected: icon.path,
          onPicked: _setPath,
        ),
        ImageUploadButton(
          images: images,
          inputId: inputId,
          onAdded: (List<String> paths) {
            if (paths.isNotEmpty) _setPath(paths.first);
          },
        ),
      ]),
      const HuiMore(
        summary: 'Path rules and image cost',
        children: <Widget>[
          HuiNote(
            'No leading slash, no "..", no drive letters - the path is read '
            'inside plugins/Gloss/images/ and nowhere else.',
          ),
          HuiNote(
            'Gloss draws one character per source pixel with no resizing, so '
            'a 64x64 image becomes 64 text displays of 64 characters. Keep '
            'images small.',
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
    _emit(
      added.length == 1 ? 'add frame' : 'add ${added.length} frames',
      <String>[..._source, ...added],
    );
  }

  void _addFrames(List<String> paths) {
    if (paths.isEmpty) return;
    _emit(
      paths.length == 1 ? 'add frame' : 'add ${paths.length} frames',
      <String>[..._source, ...paths],
    );
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
    final int ms = (speed < 1 ? 1 : speed) * 50;
    return dom.div(classes: 'hui-icon-animated', <Widget>[
      InspectorSection(
        title: 'Frames',
        description: 'Played in this order and looped.',
        trailing: dom.div(classes: 'hui-frame-tools', <Widget>[
          HuiIconButton(
            icon: ArcaneIcon.arrowUpDown(size: IconSize.sm),
            label: 'Reverse frame order',
            disabled: _source.length < 2,
            onPressed: _reverse,
          ),
          const HuiFieldHelp('icon.animated.source'),
          dom.span(classes: 'hui-count-chip', <Widget>[
            Text('${_source.length}'),
          ]),
        ]),
        children: <Widget>[
          if (_source.isEmpty)
            HuiEmptyState(
              icon: ArcaneIcon.triangleAlert(size: IconSize.md),
              title: 'No frames',
              body:
                  'An animated icon with an empty source list falls back to '
                  'the missing-icon placeholder in game. Add at least one '
                  'frame.',
              tone: HuiNoteTone.danger,
            )
          else
            HuiReorderList(
              itemCount: _source.length,
              handleLabel: 'Drag to reorder frames',
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
        label: 'Speed',
        required: true,
        help: 'Ticks per frame, at 20 ticks per second.',
        trailing: dom.div(classes: 'hui-field-tools', <Widget>[
          dom.span(classes: 'hui-unit-chip', <Widget>[
            Text('${speed}t = ${ms}ms per frame'),
          ]),
          const HuiFieldHelp('icon.animated.speed'),
        ]),
        control: dom.div(<Widget>[
          HuiNumberField(
            value: speed.toDouble(),
            min: 1,
            step: 1,
            integer: true,
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
      const HuiMore(
        summary: 'Frame padding and tick limits',
        children: <Widget>[
          HuiNote(
            'Every frame is padded to the tallest frame with blank rows.',
          ),
          HuiNote(
            '1 tick is the fastest the plugin can go; 0 or less also advances '
            'every tick.',
          ),
        ],
      ),
    ]);
  }

  Widget _library() => dom.div(classes: 'hui-icon-animated-library', <Widget>[
    const HuiEyebrow('Add from library'),
    const HuiNote(
      'Click images to line them up, then add them in one go. The same '
      'image can be used in more than one frame.',
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
            'aria-label': 'Remove ${_staged[i]} from the queue',
          },
          events: dom.events<Null>(onClick: () => _toggleStaged(_staged[i])),
          <Widget>[
            Text('${i + 1}. ${_staged[i]}'),
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
        child: Text(
          _staged.length == 1 ? 'Add 1 frame' : 'Add ${_staged.length} frames',
        ),
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => setState(_staged.clear),
        child: const Text('Clear'),
      ),
    ]),
  ]);

  Widget _frameRow(int index) {
    final String path = _source[index];
    final StoredImage? stored = component.images.byPath(path);
    return dom.div(classes: 'hui-frame-row', <Widget>[
      dom.span(classes: 'hui-frame-index', <Widget>[Text('${index + 1}')]),
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
          onInput: (String value) => _setFrame(index, value),
          attributes: const <String, String>{
            'autocomplete': 'off',
            'spellcheck': 'false',
          },
        ),
      ]),
      HuiIconButton(
        icon: ArcaneIcon.copy(size: IconSize.sm),
        label: 'Duplicate frame ${index + 1}',
        onPressed: () => _duplicateFrame(index),
      ),
      HuiRowTools(
        onMoveUp: index == 0 ? null : () => _moveFrame(index, -1),
        onMoveDown: index == _source.length - 1
            ? null
            : () => _moveFrame(index, 1),
        onRemove: () => _removeFrame(index),
        removeLabel: 'Remove frame ${index + 1}',
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
    final int ticks = component.speed < 1 ? 1 : component.speed;
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
          label: _playing ? 'Pause preview' : 'Play preview',
          onPressed: _togglePlay,
        ),
        dom.span(classes: 'hui-animated-preview-count', <Widget>[
          Text('frame ${index + 1} of ${component.frames.length}'),
        ]),
      ]),
    ]);
  }
}
