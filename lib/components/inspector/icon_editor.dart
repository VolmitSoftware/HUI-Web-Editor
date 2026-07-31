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
import 'image_picker_grid.dart';
import 'inspector_session.dart';
import 'inspector_widgets.dart';
import 'item_picker.dart';
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

class IconEditor extends StatelessWidget {
  const IconEditor({
    required this.store,
    required this.images,
    required this.catalogs,
    required this.session,
    required this.componentId,
    required this.slot,
    required this.icon,
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
          final HuiItemIcon item => ItemIconEditor(
              icon: item,
              catalogs: catalogs,
              issues: _slotIssues,
              onChanged: (String label, HuiItemIcon next) =>
                  _write(label, next),
            ),
          final HuiCustomItemIcon custom => CustomItemIconEditor(
              icon: custom,
              catalogs: catalogs,
              issues: _slotIssues,
              onChanged: (String label, HuiCustomItemIcon next) =>
                  _write(label, next),
            ),
        },
      ];

  Widget _emptyState() => dom.div(
        classes: 'hui-icon-empty',
        <Widget>[
          const HuiNote(
            'No icon: HoloUI draws its magenta checker here, and a button '
            'keeps its hitbox.',
            tone: HuiNoteTone.warning,
          ),
          dom.div(
            classes: 'hui-icon-empty-actions',
            <Widget>[
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

class _AnimatedIconEditor extends StatelessWidget {
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

  HuiAnimatedImageIcon _with(List<String> source, int speed) =>
      HuiAnimatedImageIcon(source, speed)
        ..extras = huiDeepCopyMap(icon.extras);

  void _addFrame(String path) => onChanged(
        'add frame',
        _with(<String>[...icon.source, path], icon.speed),
      );

  void _removeFrame(int index) {
    final List<String> next = <String>[...icon.source]..removeAt(index);
    onChanged('remove frame', _with(next, icon.speed));
  }

  void _moveFrame(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= icon.source.length) return;
    final List<String> next = <String>[...icon.source];
    final String moved = next.removeAt(index);
    next.insert(target, moved);
    onChanged('reorder frames', _with(next, icon.speed));
  }

  void _setFrame(int index, String path) {
    final List<String> next = <String>[...icon.source];
    next[index] = path;
    onChanged('frame path', _with(next, icon.speed));
  }

  @override
  Widget build(BuildContext context) {
    final int speed = icon.speed;
    final int ms = (speed < 1 ? 1 : speed) * 50;
    return dom.div(
      classes: 'hui-icon-animated',
      <Widget>[
        InspectorSection(
          title: 'Frames',
          description: 'Played in this order and looped.',
          trailing: dom.span(
            classes: 'hui-count-chip',
            <Widget>[
              Text('${icon.source.length}'),
            ],
          ),
          children: <Widget>[
            if (icon.source.isEmpty)
              const HuiNote(
                'An animated icon with no frames crashes the menu open. Add at '
                'least one frame.',
                tone: HuiNoteTone.danger,
              )
            else
              for (int i = 0; i < icon.source.length; i++) _frameRow(i),
            HuiInlineIssues(
              issues
                  .where((HuiIssue issue) => issue.path.contains('.source'))
                  .toList(),
            ),
          ],
        ),
        if (icon.source.isNotEmpty)
          AnimatedIconPreview(
            images: images,
            frames: icon.source,
            speed: speed,
          ),
        dom.div(
          classes: 'hui-icon-animated-library',
          <Widget>[
            const HuiEyebrow('Add from library'),
            ImagePickerGrid(images: images, onPicked: _addFrame),
            ImageUploadButton(
              images: images,
              inputId: inputId,
              onAdded: (List<String> paths) {
                for (final String path in paths) {
                  _addFrame(path);
                }
              },
            ),
          ],
        ),
        HuiField(
          label: 'Speed',
          required: true,
          help: 'Ticks per frame, at 20 ticks per second.',
          trailing: dom.span(
            classes: 'hui-unit-chip',
            <Widget>[Text('${speed}t = ${ms}ms per frame')],
          ),
          control: dom.div(<Widget>[
            HuiNumberField(
              value: speed.toDouble(),
              min: 1,
              step: 1,
              integer: true,
              onChanged: (double value) => onChanged(
                'animation speed',
                _with(<String>[...icon.source], value.round()),
              ),
            ),
            HuiInlineIssues(
              issues
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

  Widget _frameRow(int index) {
    final String path = icon.source[index];
    final StoredImage? stored = images.byPath(path);
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
        HuiRowTools(
          onMoveUp: index == 0 ? null : () => _moveFrame(index, -1),
          onMoveDown: index == icon.source.length - 1
              ? null
              : () => _moveFrame(index, 1),
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
