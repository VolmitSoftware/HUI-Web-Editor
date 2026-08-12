/// Image library grid with inline upload, used by the `textImage` editor and by
/// the animated frame list.
///
/// Paths are exactly what HoloUI reads from `plugins/holoui/images/`, so the
/// grid shows the path, not a friendly name.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, EventCallback;

import '../../services/image_library.dart';
import '../common/common.dart';
import 'dom_bridge.dart';
import 'inspector_widgets.dart';

/// A `<label>`-wrapped file input: clicking the label opens the picker without
/// any JavaScript, which a `Button` cannot do.
class ImageUploadButton extends StatefulWidget {
  const ImageUploadButton({
    required this.images,
    required this.inputId,
    this.label = 'Upload images',
    this.onAdded,
    super.key,
  });

  final ImageLibrary images;

  /// Must be unique in the document: the change handler reads the files back
  /// out of the DOM by id.
  final String inputId;
  final String label;

  /// Called with the paths that were stored, so the caller can select one.
  final void Function(List<String> paths)? onAdded;

  @override
  State<ImageUploadButton> createState() => _ImageUploadButtonState();
}

class _ImageUploadButtonState extends State<ImageUploadButton> {
  bool _busy = false;
  String? _message;

  Future<void> _handleFiles() async {
    final List<Object> files = readInputFiles(component.inputId);
    resetFileInput(component.inputId);
    if (files.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ImageAddOutcome outcome = await component.images.addFromFiles(files);
    final List<String> paths = outcome.added
        .map((StoredImage image) => image.path)
        .toList();
    if (paths.isNotEmpty) component.onAdded?.call(paths);
    setState(() {
      _busy = false;
      _message = outcome.errors.isNotEmpty
          ? outcome.errors.first
          : (outcome.warnings.isNotEmpty ? outcome.warnings.first : null);
    });
  }

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-image-upload', <Widget>[
        dom.label(
          classes: classNames(<String?>[
            'hui-image-upload-button',
            _busy ? 'is-busy' : null,
          ]),
          attributes: <String, String>{'for': component.inputId},
          <Widget>[
            ArcaneIcon.upload(size: IconSize.sm),
            dom.span(<Widget>[Text(_busy ? 'Storing...' : component.label)]),
          ],
        ),
        Component.element(
          tag: 'input',
          id: component.inputId,
          classes: 'hui-visually-hidden-input',
          attributes: <String, String>{
            'type': 'file',
            'accept': 'image/*',
            'multiple': 'multiple',
          },
          styles: const dom.Styles(
            raw: <String, String>{
              'position': 'absolute',
              'width': '1px',
              'height': '1px',
              'opacity': '0',
              'pointer-events': 'none',
            },
          ),
          events: <String, EventCallback>{'change': (_) => _handleFiles()},
        ),
        if (_message != null) HuiNote(_message!, tone: HuiNoteTone.warning),
      ]);
}

/// Selectable grid of stored images. [selected] highlights the current path.
class ImagePickerGrid extends StatelessWidget {
  const ImagePickerGrid({
    required this.images,
    required this.onPicked,
    this.selected,
    this.emptyMessage =
        'No images stored yet. Upload PNGs sized like the pixels you want: '
        'HoloUI draws one character per pixel, so 8x8 to 32x32 is the '
        'practical range.',
    super.key,
  });

  final ImageLibrary images;
  final String? selected;
  final void Function(String path) onPicked;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final List<StoredImage> stored = images.images;
    if (stored.isEmpty) {
      return HuiNote(emptyMessage);
    }
    return dom.div(classes: 'hui-image-grid', <Widget>[
      for (final StoredImage image in stored) _tile(image),
    ]);
  }

  Widget _tile(StoredImage image) {
    final bool isSelected = image.path == selected;
    return dom.button(
      classes: classNames(<String?>[
        'hui-image-tile',
        isSelected ? 'is-selected' : null,
      ]),
      attributes: <String, String>{
        'type': 'button',
        'aria-label': '${image.path} (${image.width}x${image.height})',
        if (isSelected) 'aria-current': 'true',
      },
      events: <String, EventCallback>{'click': (_) => onPicked(image.path)},
      <Widget>[
        dom.span(classes: 'hui-image-tile-frame', <Widget>[
          dom.img(
            src: image.dataUri,
            alt: '',
            classes: 'hui-image-tile-img',
            styles: const dom.Styles(
              raw: <String, String>{'image-rendering': 'pixelated'},
            ),
          ),
        ]),
        dom.span(classes: 'hui-image-tile-path', <Widget>[Text(image.path)]),
        dom.span(classes: 'hui-image-tile-size', <Widget>[
          Text('${image.width}x${image.height}'),
        ]),
      ],
    );
  }
}
