/// Image manager: the local library that backs textImage and animatedTextImage
/// icons.
///
/// The stored path is simultaneously the JSON value, the zip entry name and the
/// file name on the server, so it is editable here and validated with the same
/// rules the plugin applies. Renaming also repoints the icons that use the old
/// path, otherwise the menu would silently render missing-icon placeholders.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../config/links.dart';
import '../../model/model.dart';
import '../../services/file_transfer.dart';
import '../../services/image_library.dart';
import '../../services/storage_service.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../panels/two_step_button.dart';
import 'dialog_parts.dart';
import 'image_picker.dart';

class ImageManagerDialog extends StatefulWidget {
  const ImageManagerDialog({
    required this.store,
    required this.images,
    required this.isOpen,
    required this.onClose,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;
  final bool isOpen;
  final VoidCallback onClose;

  @override
  State<ImageManagerDialog> createState() => _ImageManagerDialogState();
}

class _ImageManagerDialogState extends State<ImageManagerDialog> {
  final Map<String, String> _drafts = <String, String>{};
  final Map<String, String> _errors = <String, String>{};
  bool _busy = false;

  EditorStore get _store => component.store;

  ImageLibrary get _library => component.images;

  @override
  void didUpdateComponent(ImageManagerDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!oldComponent.isOpen && component.isOpen) {
      _drafts.clear();
      _errors.clear();
    }
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    final List<Object> files = await pickImageFiles();
    if (!mounted) return;
    if (files.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final ImageAddOutcome outcome = await _library.addFromFiles(files);
    if (!mounted) return;
    setState(() => _busy = false);
    _reportOutcome(outcome);
  }

  void _reportOutcome(ImageAddOutcome outcome) {
    for (final String error in outcome.errors) {
      toast.error(error);
    }
    for (final String warning in outcome.warnings) {
      toast.warning(warning);
    }
    if (outcome.added.isNotEmpty) {
      toast.success(
        'Added ${outcome.added.length} image'
        '${outcome.added.length == 1 ? '' : 's'}',
      );
    }
  }

  void _commitRename(String path) {
    final String draft = _drafts[path] ?? path;
    if (draft == path) {
      setState(() {
        _drafts.remove(path);
        _errors.remove(path);
      });
      return;
    }
    // The library sanitizes the path and forces a .png extension because every
    // upload is re-encoded as PNG; mirror that so the preview, the validation
    // message and the repointed icons all agree.
    final String next = _expectedPath(draft);
    final String? problem = validateImagePath(next);
    if (problem != null) {
      setState(() => _errors[path] = problem);
      return;
    }
    final bool renamed = _library.rename(path, next);
    if (!renamed) {
      setState(() => _errors[path] = _library.lastError ?? 'Rename failed.');
      return;
    }
    _store.mutate('rename image', (HuiMenu menu) {
      huiRepointImagePaths(menu, path, next);
    });
    setState(() {
      _drafts.remove(path);
      _errors.remove(path);
    });
  }

  String _expectedPath(String raw) {
    final String path = sanitizeImagePath(raw);
    final int dot = path.lastIndexOf('.');
    final int slash = path.lastIndexOf('/');
    if (dot > slash && dot > 0) return '${path.substring(0, dot)}.png';
    return '$path.png';
  }

  void _remove(String path) {
    _library.remove(path);
    setState(() {
      _drafts.remove(path);
      _errors.remove(path);
    });
  }

  void _downloadOne(StoredImage image) {
    final List<int>? bytes = decodeDataUriBytes(image.dataUri);
    if (bytes == null) {
      toast.error('That image could not be decoded.');
      return;
    }
    final int slash = image.path.lastIndexOf('/');
    final String name = slash >= 0
        ? image.path.substring(slash + 1)
        : image.path;
    downloadBytes(name, bytes, mime: 'image/png');
  }

  Future<void> _downloadZip() async {
    setState(() => _busy = true);
    final List<int> bytes = await _library.exportZipBytes();
    if (!mounted) return;
    setState(() => _busy = false);
    downloadBytes('images.zip', bytes, mime: 'application/zip');
    toast.success('Saved images.zip (${huiFormatBytes(bytes.length)})');
  }

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-image-dialog',
    isOpen: component.isOpen,
    onClose: component.onClose,
    title: 'Images',
    maxWidth: 860,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: component.onClose,
        label: 'Close',
      ),
    ],
    children: <Widget>[
      ListenableBuilder(
        listenable: _library,
        builder: (BuildContext inner) => _body(),
      ),
    ],
  );

  Widget _body() {
    final List<StoredImage> images = _library.images;
    final Set<String> used = huiUsedImagePaths(_store.menu);
    return dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
      if (_library.lastError != null)
        ArcaneAlert.error(message: _library.lastError!),
      _toolbar(images.isNotEmpty),
      _quota(),
      // Every upload is decoded, re-encoded as PNG and measured before it
      // reaches the grid, which is long enough to see on a batch. The
      // placeholders sit where the new cards will land so the grid grows
      // once, when the images arrive, rather than twice.
      if (images.isEmpty && !_busy)
        _empty()
      else
        dom.div(classes: 'hui-image-grid', <Widget>[
          for (final StoredImage image in images)
            _card(image, used.contains(image.path)),
          if (_busy)
            const HuiSkeleton(
              label: 'Reading images',
              block: true,
              lines: 2,
              classes: 'hui-skeleton-card',
            ),
        ]),
    ]);
  }

  Widget _toolbar(bool hasImages) =>
      dom.div(classes: 'hui-image-toolbar', <Widget>[
        dom.div(classes: 'hui-dialog-actions', <Widget>[
          Button(
            variant: ButtonVariant.primary,
            size: ButtonSize.small,
            loading: _busy,
            onPressed: _upload,
            icon: ArcaneIcon.upload(size: IconSize.sm),
            label: 'Upload images',
          ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.small,
            disabled: !hasImages || _busy,
            onPressed: hasImages ? _downloadZip : null,
            icon: ArcaneIcon.fileArchive(size: IconSize.sm),
            label: 'Download images.zip',
          ),
        ]),
        const dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            'You can also drop image files anywhere in the editor. Unzip '
            'images.zip into plugins/Gloss/images/ and the paths below '
            'resolve unchanged.',
          ),
        ]),
      ]);

  Widget _quota() {
    final int used = StorageService.estimateUsageBytes();
    const int quota = StorageService.approximateQuotaBytes;
    final double ratio = quota <= 0 ? 0 : (used / quota).clamp(0, 1).toDouble();
    final int percent = (ratio * 100).round();
    return dom.div(
      classes: classNames(<String?>[
        'hui-quota',
        percent >= 80 ? 'is-critical' : (percent >= 60 ? 'is-warning' : null),
      ]),
      <Widget>[
        dom.div(classes: 'hui-quota-head', <Widget>[
          const HuiEyebrow('browser storage'),
          dom.span(classes: 'hui-quota-value', <Widget>[
            Text(
              '${huiFormatBytes(used)} of about '
              '${huiFormatBytes(quota)} ($percent%)',
            ),
          ]),
        ]),
        ArcaneProgressBar(
          value: percent.toDouble(),
          size: ComponentSize.sm,
          variant: percent >= 80
              ? ProgressVariant.error
              : (percent >= 60
                    ? ProgressVariant.warning
                    : ProgressVariant.primary),
        ),
        dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            percent >= 60
                ? 'Storage is filling up. Images are kept in this browser '
                      'only, and a full store silently refuses to save. Export '
                      'what you need and delete unused images.'
                : 'Images live in this browser only. Keep them at or under '
                      '${huiRecommendedMaxImageDimension}x'
                      '$huiRecommendedMaxImageDimension pixels: Gloss draws '
                      'one text display per row and one character per pixel.',
          ),
        ]),
      ],
    );
  }

  Widget _empty() => dom.div(classes: 'hui-image-empty', <Widget>[
    ArcaneEmptyState(
      title: 'No images yet',
      description:
          'Upload PNG or GIF files to use them as textImage and '
          'animatedTextImage icons. They are stored in this browser and '
          'exported as $huiImageFolder in images.zip.',
      icon: ArcaneIcon.images(size: IconSize.lg),
      action: Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        loading: _busy,
        onPressed: _upload,
        icon: ArcaneIcon.upload(size: IconSize.sm),
        label: 'Upload images',
      ),
    ),
  ]);

  Widget _card(StoredImage image, bool inUse) {
    final String path = image.path;
    final String draft = _drafts[path] ?? path;
    final String? error = _errors[path];
    return dom.div(
      classes: classNames(<String?>[
        'hui-image-card',
        'hui-lift',
        inUse ? 'is-used' : null,
        image.isOversized ? 'is-oversized' : null,
      ]),
      <Widget>[
        dom.div(classes: 'hui-image-preview hui-checkerboard', <Widget>[
          dom.img(src: image.dataUri, alt: path, classes: 'hui-image-thumb'),
        ]),
        dom.div(classes: 'hui-image-meta', <Widget>[
          HuiField(
            label: 'Path',
            error: error,
            help:
                '${image.width}x${image.height} px · '
                '${huiFormatBytes(image.approximateBytes)}'
                '${image.isOversized ? ' · larger than recommended' : ''}',
            control: TextInput(
              value: draft,
              size: ComponentSize.sm,
              fullWidth: true,
              onInput: (String value) => setState(() => _drafts[path] = value),
              onBlur: () => _commitRename(path),
              onSubmit: (String _) => _commitRename(path),
              attributes: <String, String>{
                'aria-label': 'Path for $path',
                'autocomplete': 'off',
                'spellcheck': 'false',
              },
            ),
          ),
          dom.div(classes: 'hui-image-card-tools', <Widget>[
            if (inUse)
              const dom.span(classes: 'hui-chip is-accent', <Widget>[
                Text('used in this menu'),
              ]),
            Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.iconSm,
              onPressed: () => _downloadOne(image),
              attributes: <String, String>{'aria-label': 'Download $path'},
              child: ArcaneIcon.download(size: IconSize.sm),
            ),
            HuiTwoStepButton(
              label: 'Delete $path',
              confirmLabel: 'Delete',
              icon: ArcaneIcon.trash2(size: IconSize.sm),
              iconOnly: true,
              size: ButtonSize.iconSm,
              onConfirm: () => _remove(path),
            ),
          ]),
        ]),
      ],
    );
  }
}
