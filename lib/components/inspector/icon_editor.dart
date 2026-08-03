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
import 'custom_item_picker.dart';
import 'extras_editor.dart';
import 'field_help.dart';
import 'image_picker_grid.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'item_picker.dart';
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
  'text': <String>['icon.text.text'],
  'textImage': <String>['icon.textImage.path'],
  'animatedTextImage': <String>['icon.animated.source', 'icon.animated.speed'],
  'item': <String>[
    'icon.item.item',
    'icon.item.count',
    'icon.item.customModelValue',
  ],
  'customItem': <String>['icon.customItem.provider', 'icon.customItem.item'],
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

  void _switchType(String nextType) {
    final HuiIcon? current = icon;
    if (current != null && current.type == nextType) return;
    _write(
      '${slot.label.toLowerCase()} type $nextType',
      session.switchIcon(_sessionKey, current, nextType),
    );
  }

  @override
  Widget build(BuildContext context) => dom.div(
        classes: 'hui-icon-editor',
        <Widget>[
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
            children: <Widget>[
              if (icon == null) _emptyState() else ..._body(),
            ],
          ),
        ],
      );

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
              value: 'customItem',
              label: 'Custom',
              icon: ArcaneIcon.boxes(size: IconSize.sm),
              hint: huiIconTypeDescriptions['customItem'],
            ),
          ],
        ),
        HuiHelpCluster(
          huiIconTypeDocKeys[icon!.type] ?? const <String>[],
          label: 'Fields',
        ),
        switch (icon!) {
          final HuiTextIcon text => TextIconEditor(
              // Keyed by field id so flipping a toggle from the true slot to
              // the false slot remounts the textarea. Without it the state is
              // reused, the user-dirty DOM field keeps the previous slot's text
              // and the next keystroke writes it into the other slot.
              key: ValueKey<String>(_fieldId),
              fieldId: _fieldId,
              text: text.text,
              issues: _issuesEndingWith('.text'),
              label: 'Text',
              onChanged: (String label, String value) => _write(
                label,
                HuiTextIcon(value)..extras = huiDeepCopyMap(text.extras),
              ),
            ),
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
          final HuiItemIcon item => dom.div(
              classes: 'hui-icon-item',
              <Widget>[
                if (catalogsLoading) const HuiSkeletonRows(rows: 2),
                ItemIconEditor(
                  icon: item,
                  catalogs: catalogs,
                  issues: _slotIssues,
                  onChanged: (String label, HuiItemIcon next) =>
                      _write(label, next),
                ),
              ],
            ),
          final HuiCustomItemIcon custom => dom.div(
              classes: 'hui-icon-custom',
              <Widget>[
                if (catalogsLoading) const HuiSkeletonRows(rows: 2),
                CustomItemIconEditor(
                  icon: custom,
                  catalogs: catalogs,
                  issues: _slotIssues,
                  onChanged: (String label, HuiCustomItemIcon next) =>
                      _write(label, next),
                ),
              ],
            ),
        },
        ExtrasEditor(
          title: 'Icon',
          extras: icon!.extras,
          onChanged: _writeExtras,
        ),
      ];

  Widget _emptyState() => dom.div(
        classes: 'hui-icon-empty',
        <Widget>[
          HuiEmptyState(
            icon: ArcaneIcon.imageOff(size: IconSize.md),
            title: 'No icon',
            body: 'HoloUI draws its magenta checker here, and a button keeps '
                'its hitbox. Pick a type to start one.',
            tone: HuiNoteTone.warning,
            actions: <Widget>[
              for (final String type in huiIconTypes)
                Button(
                  variant: ButtonVariant.outline,
                  size: ButtonSize.sm,
                  onPressed: () => _write(
                    'add ${slot.label.toLowerCase()}',
                    session.recallIcon(_sessionKey, type) ??
                        createDefaultIcon(type),
                  ),
                  child: Text(_typeLabel(type)),
                ),
            ],
          ),
        ],
      );

  static String _typeLabel(String type) => switch (type) {
        'text' => 'Text',
        'textImage' => 'Image',
        'animatedTextImage' => 'Animated',
        'item' => 'Item',
        'customItem' => 'Custom item',
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
        HuiTextImageIcon(path)..extras = huiDeepCopyMap(icon.extras),
      );

  /// One source pixel is one character cell wide and one text line tall.
  static String _blocks(int pixels) =>
      (pixels * huiCharCell).toStringAsFixed(2);

  Widget _imagePreview(StoredImage stored) => dom.div(
        classes: 'hui-image-preview',
        <Widget>[
          dom.img(
            src: stored.dataUri,
            alt: stored.path,
            styles: const dom.Styles(
              raw: <String, String>{'image-rendering': 'pixelated'},
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final StoredImage? stored = images.byPath(icon.path);
    return dom.div(
      classes: 'hui-icon-image',
      <Widget>[
        HuiField(
          label: 'Path',
          required: true,
          trailing: const HuiFieldHelp('icon.textImage.path'),
          help: 'Relative to plugins/holoui/images/.',
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
        dom.div(
          classes: 'hui-icon-image-library',
          <Widget>[
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
          ],
        ),
        const HuiMore(
          summary: 'Path rules and image cost',
          children: <Widget>[
            HuiNote(
              'No leading slash, no "..", no drive letters - the path is read '
              'inside plugins/holoui/images/ and nowhere else.',
            ),
            HuiNote(
              'HoloUI draws one character per source pixel with no resizing, so '
              'a 64x64 image becomes 64 text displays of 64 characters. Keep '
              'images small.',
            ),
          ],
        ),
      ],
    );
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
      HuiAnimatedImageIcon(source, speed)
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
    return dom.div(
      classes: 'hui-icon-animated',
      <Widget>[
        InspectorSection(
          title: 'Frames',
          description: 'Played in this order and looped.',
          trailing: dom.div(
            classes: 'hui-frame-tools',
            <Widget>[
              HuiIconButton(
                icon: ArcaneIcon.arrowUpDown(size: IconSize.sm),
                label: 'Reverse frame order',
                disabled: _source.length < 2,
                onPressed: _reverse,
              ),
              const HuiFieldHelp('icon.animated.source'),
              dom.span(
                classes: 'hui-count-chip',
                <Widget>[Text('${_source.length}')],
              ),
            ],
          ),
          children: <Widget>[
            if (_source.isEmpty)
              HuiEmptyState(
                icon: ArcaneIcon.triangleAlert(size: IconSize.md),
                title: 'No frames',
                body: 'An animated icon with an empty source list throws while '
                    'the menu is opening, so the whole menu fails to open. Add '
                    'at least one frame.',
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
          trailing: dom.div(
            classes: 'hui-field-tools',
            <Widget>[
              dom.span(
                classes: 'hui-unit-chip',
                <Widget>[Text('${speed}t = ${ms}ms per frame')],
              ),
              const HuiFieldHelp('icon.animated.speed'),
            ],
          ),
          control: dom.div(<Widget>[
            HuiNumberField(
              value: speed.toDouble(),
              min: 1,
              step: 1,
              integer: true,
              onChanged: (double value) => _emit(
                'animation speed',
                <String>[..._source],
                value.round(),
              ),
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
      ],
    );
  }

  Widget _library() => dom.div(
        classes: 'hui-icon-animated-library',
        <Widget>[
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
        ],
      );

  Widget _stagedTray() => dom.div(
        classes: 'hui-frame-staged',
        <Widget>[
          dom.div(
            classes: 'hui-frame-staged-chips',
            <Widget>[
              for (int i = 0; i < _staged.length; i++)
                dom.button(
                  classes: 'hui-frame-staged-chip',
                  attributes: <String, String>{
                    'type': 'button',
                    'aria-label': 'Remove ${_staged[i]} from the queue',
                  },
                  events: dom.events<Null>(
                    onClick: () => _toggleStaged(_staged[i]),
                  ),
                  <Widget>[
                    Text('${i + 1}. ${_staged[i]}'),
                    ArcaneIcon.x(size: IconSize.sm),
                  ],
                ),
            ],
          ),
          dom.div(
            classes: 'hui-frame-staged-actions',
            <Widget>[
              Button(
                variant: ButtonVariant.primary,
                size: ButtonSize.sm,
                icon: ArcaneIcon.plus(size: IconSize.sm),
                onPressed: _addStaged,
                child: Text(_staged.length == 1
                    ? 'Add 1 frame'
                    : 'Add ${_staged.length} frames'),
              ),
              Button(
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                onPressed: () => setState(_staged.clear),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      );

  Widget _frameRow(int index) {
    final String path = _source[index];
    final StoredImage? stored = component.images.byPath(path);
    return dom.div(
      classes: 'hui-frame-row',
      <Widget>[
        dom.span(
          classes: 'hui-frame-index',
          <Widget>[Text('${index + 1}')],
        ),
        dom.span(
          classes: 'hui-frame-thumb',
          <Widget>[
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
          ],
        ),
        dom.div(
          classes: 'hui-frame-path',
          <Widget>[
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
          ],
        ),
        HuiIconButton(
          icon: ArcaneIcon.copy(size: IconSize.sm),
          label: 'Duplicate frame ${index + 1}',
          onPressed: () => _duplicateFrame(index),
        ),
        HuiRowTools(
          onMoveUp: index == 0 ? null : () => _moveFrame(index, -1),
          onMoveDown:
              index == _source.length - 1 ? null : () => _moveFrame(index, 1),
          onRemove: () => _removeFrame(index),
          removeLabel: 'Remove frame ${index + 1}',
        ),
      ],
    );
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
    final int index =
        component.frames.isEmpty ? 0 : _frame % component.frames.length;
    final StoredImage? stored = component.frames.isEmpty
        ? null
        : component.images.byPath(component.frames[index]);
    return dom.div(
      classes: 'hui-animated-preview',
      <Widget>[
        dom.div(
          classes: 'hui-animated-preview-frame',
          <Widget>[
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
          ],
        ),
        dom.div(
          classes: 'hui-animated-preview-meta',
          <Widget>[
            HuiIconButton(
              icon: _playing
                  ? ArcaneIcon.pause(size: IconSize.sm)
                  : ArcaneIcon.play(size: IconSize.sm),
              label: _playing ? 'Pause preview' : 'Play preview',
              onPressed: _togglePlay,
            ),
            dom.span(
              classes: 'hui-animated-preview-count',
              <Widget>[
                Text('frame ${index + 1} of ${component.frames.length}'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
