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
    if (icon is! HuiEntityIcon)
      _DisplayStyleEditor(
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
            child: Text(_typeLabel(type)),
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

  List<ArcaneSelectOption> _options(
    List<String> values,
    String current,
    String Function(String value) label,
  ) => <ArcaneSelectOption>[
    for (final String value in values)
      ArcaneSelectOption(label: label(value), value: value),
    if (!values.contains(current))
      ArcaneSelectOption(
        label: huiText("{current} (unknown)", <String, Object?>{
          'current': current,
        }),
        value: current,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final HuiIconStyle? current = style;
    if (current == null) {
      return InspectorSection(
        title: huiText('Display style'),
        description: huiText('Uses the runtime display-entity defaults.'),
        children: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () =>
                onChanged('add display style', createDefaultIconStyle()),
            child: Text(huiText('Customize display')),
          ),
        ],
      );
    }

    return InspectorSection(
      title: huiText('Display style'),
      sectionKey: 'icon.style',
      description: huiText(
        'Packet display metadata shared by text, image, item and block '
        'icons. Entity icons reject it outright.',
      ),
      trailing: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => onChanged('remove display style', null),
        child: Text(huiText('Use defaults')),
      ),
      children: <Widget>[
        HuiField(
          label: huiText('Billboard'),
          help: huiText(
            'Fixed follows the menu transform; other modes face viewers.',
          ),
          trailing: const HuiFieldHelp('icon.style.billboard'),
          defaultValue: _billboardLabel('fixed'),
          onReset: current.billboard == 'fixed'
              ? null
              : () => onChanged(
                  'icon billboard',
                  _next((HuiIconStyle next) => next.billboard = 'fixed'),
                ),
          control: ArcaneSelect(
            value: current.billboard,
            size: ComponentSize.sm,
            fullWidth: true,
            options: _options(
              huiIconBillboards,
              current.billboard,
              _billboardLabel,
            ),
            onChange: (String value) => onChanged(
              'icon billboard',
              _next((HuiIconStyle next) => next.billboard = value),
            ),
          ),
        ),
        HuiField(
          label: huiText('Non-uniform scale'),
          help: huiText(
            'Multiplied by the server uiScale. X and Y also resize the '
            'automatic click plane; Z never does.',
          ),
          defaultValue: '1, 1, 1',
          onReset:
              current.scaleX == 1 && current.scaleY == 1 && current.scaleZ == 1
              ? null
              : () => onChanged(
                  'icon scale',
                  _next((HuiIconStyle next) {
                    next.scaleX = 1;
                    next.scaleY = 1;
                    next.scaleZ = 1;
                  }),
                ),
          control: dom.div(<Widget>[
            HuiVec3Field(
              value: Vec3(current.scaleX, current.scaleY, current.scaleZ),
              step: 0.05,
              decimals: 2,
              axisHints: <String>[
                huiText('x: width, and the click plane with it'),
                huiText('y: height, which also re-spaces multi-line text'),
                huiText('z: depth. Visible on block and item icons only'),
              ],
              onChanged: (Vec3 value) => onChanged(
                'icon scale',
                _next((HuiIconStyle next) {
                  next.scaleX = value.x;
                  next.scaleY = value.y;
                  next.scaleZ = value.z;
                }),
              ),
            ),
            HuiHelpCluster(<String>[
              'icon.style.scaleX',
              'icon.style.scaleY',
              'icon.style.scaleZ',
            ], label: huiText('Per axis')),
          ]),
        ),
        HuiMore(
          summary: huiText('Text appearance'),
          children: <Widget>[
            HuiNote(
              huiText(
                'Text displays only. On an item, custom-item or block icon '
                'every field in this group is silently inert — image icons do '
                'honour them, because Gloss draws them as text.',
              ),
              tone: HuiNoteTone.info,
            ),
            HuiSwitchRow(
              label: huiText('Text shadow'),
              value: current.shadow,
              trailing: const HuiFieldHelp('icon.style.shadow'),
              onChanged: (bool value) => onChanged(
                'text shadow',
                _next((HuiIconStyle next) => next.shadow = value),
              ),
            ),
            HuiSwitchRow(
              label: huiText('See through blocks'),
              value: current.seeThrough,
              trailing: const HuiFieldHelp('icon.style.seeThrough'),
              onChanged: (bool value) => onChanged(
                'text see through',
                _next((HuiIconStyle next) => next.seeThrough = value),
              ),
            ),
            HuiField(
              label: huiText('Alignment'),
              trailing: const HuiFieldHelp('icon.style.textAlignment'),
              defaultValue: _alignmentLabel('center'),
              onReset: current.textAlignment == 'center'
                  ? null
                  : () => onChanged(
                      'text alignment',
                      _next(
                        (HuiIconStyle next) => next.textAlignment = 'center',
                      ),
                    ),
              control: ArcaneSelect(
                value: current.textAlignment,
                size: ComponentSize.sm,
                fullWidth: true,
                options: _options(
                  huiIconTextAlignments,
                  current.textAlignment,
                  _alignmentLabel,
                ),
                onChange: (String value) => onChanged(
                  'text alignment',
                  _next((HuiIconStyle next) => next.textAlignment = value),
                ),
              ),
            ),
            HuiField(
              label: huiText('Background'),
              trailing: const HuiFieldHelp('icon.style.backgroundArgb'),
              help: huiText('Eight hexadecimal digits in #AARRGGBB order.'),
              defaultValue: '#00000000',
              onReset: current.backgroundArgb == '#00000000'
                  ? null
                  : () => onChanged(
                      'text background',
                      _next(
                        (HuiIconStyle next) =>
                            next.backgroundArgb = '#00000000',
                      ),
                    ),
              control: HuiColorField(
                value: current.backgroundArgb,
                label: huiText('text background'),
                placeholder: '#00000000',
                onChanged: (String value) => onChanged(
                  'text background',
                  _next((HuiIconStyle next) => next.backgroundArgb = value),
                ),
              ),
            ),
            HuiField(
              label: huiText('Opacity'),
              trailing: const HuiFieldHelp('icon.style.textOpacity'),
              defaultValue: '255',
              onReset: current.textOpacity == 255
                  ? null
                  : () => onChanged(
                      'text opacity',
                      _next((HuiIconStyle next) => next.textOpacity = 255),
                    ),
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
              label: huiText('Line width'),
              help: huiText('Vanilla text-display wrap width in font pixels.'),
              trailing: const HuiFieldHelp('icon.style.lineWidth'),
              defaultValue: '2000',
              onReset: current.lineWidth == 2000
                  ? null
                  : () => onChanged(
                      'text line width',
                      _next((HuiIconStyle next) => next.lineWidth = 2000),
                    ),
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
          summary: huiText('Lighting, shadow and culling'),
          children: <Widget>[
            HuiSwitchRow(
              label: huiText('Override brightness'),
              value: current.hasBrightnessOverride,
              help: huiText(
                'Pins the icon to a constant light level. Both channels '
                'travel together; one alone is rejected.',
              ),
              trailing: const HuiFieldHelp('icon.style.blockLight'),
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
                HuiField(
                  label: huiText('Block light'),
                  trailing: const HuiFieldHelp('icon.style.blockLight'),
                  control: _number(
                    huiText('Block'),
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
                ),
                HuiField(
                  label: huiText('Sky light'),
                  trailing: const HuiFieldHelp('icon.style.skyLight'),
                  control: _number(
                    huiText('Sky'),
                    (current.skyLight ?? 15).toDouble(),
                    0,
                    15,
                    (double value) => onChanged(
                      'sky light',
                      _next(
                        (HuiIconStyle next) => next.skyLight = value.round(),
                      ),
                    ),
                    integer: true,
                  ),
                ),
              ]),
            HuiField(
              label: huiText('Display view range'),
              help: huiText(
                'A multiplier on the client cull distance, not blocks.',
              ),
              trailing: const HuiFieldHelp('icon.style.viewRange'),
              defaultValue: '1',
              onReset: current.viewRange == 1
                  ? null
                  : () => onChanged(
                      'display view range',
                      _next((HuiIconStyle next) => next.viewRange = 1),
                    ),
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
              HuiField(
                label: huiText('Shadow radius'),
                trailing: const HuiFieldHelp('icon.style.shadowRadius'),
                control: _number(
                  huiText('Radius'),
                  current.shadowRadius,
                  0,
                  64,
                  (double value) => onChanged(
                    'shadow radius',
                    _next((HuiIconStyle next) => next.shadowRadius = value),
                  ),
                ),
              ),
              HuiField(
                label: huiText('Shadow strength'),
                trailing: const HuiFieldHelp('icon.style.shadowStrength'),
                control: _number(
                  huiText('Strength'),
                  current.shadowStrength,
                  0,
                  1,
                  (double value) => onChanged(
                    'shadow strength',
                    _next((HuiIconStyle next) => next.shadowStrength = value),
                  ),
                ),
              ),
            ]),
            _numberGrid(<Widget>[
              HuiField(
                label: huiText('Cull width'),
                trailing: const HuiFieldHelp('icon.style.cullingWidth'),
                control: _number(
                  huiText('Width'),
                  current.cullingWidth,
                  0,
                  4096,
                  (double value) => onChanged(
                    'culling width',
                    _next((HuiIconStyle next) => next.cullingWidth = value),
                  ),
                ),
              ),
              HuiField(
                label: huiText('Cull height'),
                trailing: const HuiFieldHelp('icon.style.cullingHeight'),
                control: _number(
                  huiText('Height'),
                  current.cullingHeight,
                  0,
                  4096,
                  (double value) => onChanged(
                    'culling height',
                    _next((HuiIconStyle next) => next.cullingHeight = value),
                  ),
                ),
              ),
            ]),
            HuiSwitchRow(
              label: huiText('Glow outline'),
              value: current.glowColor != null,
              help: huiText(
                'Setting the colour is what turns the outline on; there is '
                'no separate glowing flag.',
              ),
              trailing: const HuiFieldHelp('icon.style.glowColor'),
              onChanged: (bool value) => onChanged(
                'glow outline',
                _next(
                  (HuiIconStyle next) =>
                      next.glowColor = value ? '#FFFFFFFF' : null,
                ),
              ),
            ),
            if (current.glowColor != null)
              HuiField(
                label: huiText('Glow colour'),
                trailing: const HuiFieldHelp('icon.style.glowColor'),
                help: huiText('Eight hexadecimal digits in #AARRGGBB order.'),
                control: HuiColorField(
                  value: current.glowColor!,
                  label: huiText('glow colour'),
                  placeholder: huiText('#FFFFFFFF'),
                  onChanged: (String value) => onChanged(
                    'glow color',
                    _next((HuiIconStyle next) => next.glowColor = value),
                  ),
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

  /// Two or three fields on one line when the pane is wide enough for it.
  Widget _numberGrid(List<Widget> children) => dom.div(
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'grid',
        'grid-template-columns': 'repeat(auto-fit, minmax(120px, 1fr))',
        'gap': '8px',
      },
    ),
    children,
  );

  static String _billboardLabel(String value) => switch (value) {
    'fixed' => huiText('Fixed'),
    'vertical' => huiText('Vertical'),
    'horizontal' => huiText('Horizontal'),
    'center' => huiTextKey('billboard.center', 'Center'),
    _ => value,
  };

  static String _alignmentLabel(String value) => switch (value) {
    'center' => huiTextKey('alignment.center', 'Center'),
    'left' => huiText('Left'),
    'right' => huiText('Right'),
    _ => value,
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
            onInput: _setPath,
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
        child: Text(
          huiPlural(
            'icon.frames_add.count',
            _staged.length,
            oneEnglish: 'Add {count} frame',
            otherEnglish: 'Add {count} frames',
          ),
        ),
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => setState(_staged.clear),
        child: Text(huiText('Clear')),
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
          onInput: (String value) => _setFrame(index, value),
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
