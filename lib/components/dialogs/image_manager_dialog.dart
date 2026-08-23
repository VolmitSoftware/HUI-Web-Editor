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
import '../../services/player_skin_source.dart';
import '../../services/storage_service.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../panels/two_step_button.dart';
import 'dialog_parts.dart';
import 'image_picker.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ImageManagerDialog extends StatefulWidget {
  const ImageManagerDialog({
    required this.store,
    required this.images,
    required this.isOpen,
    required this.onClose,
    this.onUseImage,
    this.onUseAnimation,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;
  final bool isOpen;
  final VoidCallback onClose;
  final void Function(StoredImage image)? onUseImage;
  final void Function(List<StoredImage> frames)? onUseAnimation;

  @override
  State<ImageManagerDialog> createState() => _ImageManagerDialogState();
}

class _ImageManagerDialogState extends State<ImageManagerDialog> {
  final Map<String, String> _drafts = <String, String>{};
  final Map<String, ImageLocalizedMessage> _errors =
      <String, ImageLocalizedMessage>{};
  final PlayerSkinSource _skins = PlayerSkinSource();
  String _username = '';
  bool _busy = false;
  bool _fetching = false;

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

  @override
  void dispose() {
    _skins.close();
    super.dispose();
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

  Future<void> _uploadPlayerHeads() async {
    setState(() => _busy = true);
    final List<Object> files = await pickImageFiles();
    if (!mounted) return;
    if (files.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final ImageAddOutcome outcome = await _library.addPlayerHeadsFromFiles(
      files,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _reportOutcome(outcome);
  }

  /// Fetches a skin by name and stores the head it composes to.
  ///
  /// Every failure path ends here with a message and an untouched workspace:
  /// the fetch either returns bytes or a sentence saying which host said what,
  /// and the library only writes once the skin has actually composed.
  Future<void> _fetchHeadByName() async {
    final String username = _username.trim();
    if (_fetching) return;
    setState(() => _fetching = true);
    final PlayerSkinFetch fetched = await _skins.fetch(username);
    if (!mounted) return;
    if (!fetched.isSuccess) {
      setState(() => _fetching = false);
      toast.error(fetched.message!);
      return;
    }
    final ImageAddOutcome outcome = _library.addPlayerHeadFromSkin(
      username: fetched.username,
      skinPngDataUri: fetched.pngDataUri!,
    );
    if (!mounted) return;
    setState(() {
      _fetching = false;
      if (outcome.isSuccess) _username = '';
    });
    if (outcome.isSuccess) {
      toast.success(
        huiText("Added {path} from {host}", <String, Object?>{
          'path': outcome.added.single.path,
          'host': fetched.host,
        }),
      );
      return;
    }
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
        huiPlural(
          'images.added_count_short',
          outcome.added.length,
          oneEnglish: 'Added {count} image',
          otherEnglish: 'Added {count} images',
        ),
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
      setState(
        () =>
            _errors[path] = () =>
                validateImagePath(next) ?? huiText('Rename failed.'),
      );
      return;
    }
    final bool renamed = _library.rename(path, next);
    if (!renamed) {
      final ImageLocalizedMessage failure =
          _library.lastErrorMessage ?? () => huiText('Rename failed.');
      setState(() => _errors[path] = failure);
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
      toast.error(huiText('That image could not be decoded.'));
      return;
    }
    final int slash = image.path.lastIndexOf('/');
    final String name = slash >= 0
        ? image.path.substring(slash + 1)
        : image.path;
    downloadBytes(name, bytes, mime: 'image/png');
  }

  void _useImage(StoredImage image) {
    component.onUseImage?.call(image);
    component.onClose();
  }

  void _useAnimation(List<StoredImage> frames) {
    component.onUseAnimation?.call(frames);
    component.onClose();
  }

  Future<void> _downloadZip() async {
    setState(() => _busy = true);
    final List<int> bytes = await _library.exportZipBytes();
    if (!mounted) return;
    setState(() => _busy = false);
    downloadBytes('images.zip', bytes, mime: 'application/zip');
    toast.success(
      huiText("Saved images.zip ({huiFormatBytes})", <String, Object?>{
        'huiFormatBytes': huiFormatBytes(bytes.length),
      }),
    );
  }

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-image-dialog',
    isOpen: component.isOpen,
    onClose: component.onClose,
    title: huiText('Images'),
    maxWidth: 860,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: component.onClose,
        label: huiText('Close'),
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
            _card(
              image,
              used.contains(image.path),
              _library.animationFramesFor(image.path),
            ),
          if (_busy)
            HuiSkeleton(
              label: huiText('Reading images'),
              block: true,
              lines: 2,
              classes: 'hui-skeleton-card',
            ),
        ]),
    ]);
  }

  Widget _toolbar(
    bool hasImages,
  ) => dom.div(classes: 'hui-image-toolbar', <Widget>[
    dom.div(classes: 'hui-dialog-actions', <Widget>[
      Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        loading: _busy,
        onPressed: _upload,
        icon: ArcaneIcon.upload(size: IconSize.sm),
        label: huiText('Upload images'),
      ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.small,
        loading: _busy,
        onPressed: _uploadPlayerHeads,
        icon: ArcaneIcon.userRound(size: IconSize.sm),
        label: huiText('Import Minecraft player heads from skins'),
      ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.small,
        disabled: !hasImages || _busy,
        onPressed: hasImages ? _downloadZip : null,
        icon: ArcaneIcon.fileArchive(size: IconSize.sm),
        label: huiText('Download images.zip'),
      ),
    ]),
    dom.div(classes: 'hui-dialog-actions', <Widget>[
      HuiField(
        label: huiText('Head by username'),
        help: huiText('Fetches that player\'s skin from minotar.net'),
        control: TextInput(
          value: _username,
          size: ComponentSize.sm,
          placeholder: 'Notch',
          disabled: _fetching,
          onInput: (String value) => setState(() => _username = value),
          onSubmit: (String _) => _fetchHeadByName(),
          styles: huiTechnicalInputStyles,
          attributes: <String, String>{
            ...huiTechnicalInputAttributes,
            'aria-label': huiText('Minecraft username'),
            'maxlength': '16',
          },
        ),
      ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.small,
        loading: _fetching,
        disabled: _busy,
        onPressed: _fetchHeadByName,
        icon: ArcaneIcon.download(size: IconSize.sm),
        label: huiText('Fetch head'),
      ),
    ]),
    dom.p(classes: 'hui-dialog-note', <Widget>[
      Text(
        huiText(
          'Image-icon uploads are automatically resized to fit 16x16. Skin head import '
          'extracts the 8x8 face and hat layer from a Minecraft skin PNG, '
          'either from a file you pick or from a username fetched from '
          'minotar.net (mc-heads.net if that is down) — the username is all '
          'that is sent. A name those hosts do not know comes back as one '
          'of the vanilla default skins rather than as an error, so a head '
          'that is plainly not that player means the name was probably '
          'wrong. You can also drop images anywhere in '
          'the editor. Unzip images.zip into plugins/Gloss/images/ and the '
          'paths resolve unchanged.',
        ),
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
          HuiEyebrow(huiText('browser storage')),
          dom.span(classes: 'hui-quota-value', <Widget>[
            Text(
              huiText(
                "{huiFormatBytes} of about {huiFormatBytes2} ({percent}%)",
                <String, Object?>{
                  'huiFormatBytes': huiFormatBytes(used),
                  'huiFormatBytes2': huiFormatBytes(quota),
                  'percent': percent,
                },
              ),
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
                ? huiText(
                    'Storage is filling up. Images are kept in this browser only, and a full store silently refuses to save. Export what you need and delete unused images.',
                  )
                : huiText(
                    'Images live in this browser only. Keep them at or under {dimension}x{dimension} pixels: Gloss draws one text display per row and one character per pixel.',
                    <String, Object?>{
                      'dimension': huiRecommendedMaxImageDimension,
                    },
                  ),
          ),
        ]),
      ],
    );
  }

  Widget _empty() => dom.div(classes: 'hui-image-empty', <Widget>[
    ArcaneEmptyState(
      title: huiText('No images yet'),
      description: huiText(
        "Upload PNG or GIF files to use them as textImage and animatedTextImage icons, or import an uploaded Minecraft skin as an 8x8 player head. Oversized uploads are resized automatically. Assets are exported as {huiImageFolder} in images.zip.",
        <String, Object?>{'huiImageFolder': huiImageFolder},
      ),
      icon: ArcaneIcon.images(size: IconSize.lg),
      action: Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        loading: _busy,
        onPressed: _upload,
        icon: ArcaneIcon.upload(size: IconSize.sm),
        label: huiText('Upload images'),
      ),
    ),
  ]);

  Widget _card(
    StoredImage image,
    bool inUse,
    List<StoredImage> animationFrames,
  ) {
    final String path = image.path;
    final String draft = _drafts[path] ?? path;
    final String? error = _errors[path]?.call();
    final bool firstAnimationFrame =
        animationFrames.isNotEmpty && animationFrames.first.path == path;
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
            label: huiText('Path'),
            error: error,
            help: image.isOversized
                ? huiText(
                    '{dimensions} px · {size} · larger than recommended',
                    <String, Object?>{
                      'dimensions': '${image.width}x${image.height}',
                      'size': huiFormatBytes(image.approximateBytes),
                    },
                  )
                : huiText('{dimensions} px · {size}', <String, Object?>{
                    'dimensions': '${image.width}x${image.height}',
                    'size': huiFormatBytes(image.approximateBytes),
                  }),
            control: TextInput(
              value: draft,
              size: ComponentSize.sm,
              fullWidth: true,
              onInput: (String value) => setState(() => _drafts[path] = value),
              onBlur: () => _commitRename(path),
              onSubmit: (String _) => _commitRename(path),
              attributes: <String, String>{
                'aria-label': huiText("Path for {path}", <String, Object?>{
                  'path': path,
                }),
                'autocomplete': 'off',
                'spellcheck': 'false',
                'dir': 'ltr',
              },
            ),
          ),
          dom.div(classes: 'hui-image-card-tools', <Widget>[
            if (inUse)
              dom.span(classes: 'hui-chip is-accent', <Widget>[
                Text(huiText('used in this menu')),
              ]),
            if (component.onUseImage != null)
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.sm,
                onPressed: () => _useImage(image),
                icon: ArcaneIcon.plus(size: IconSize.sm),
                label: huiText('Use image'),
              ),
            if (component.onUseAnimation != null && firstAnimationFrame)
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.sm,
                onPressed: () => _useAnimation(animationFrames),
                icon: ArcaneIcon.play(size: IconSize.sm),
                label: huiPlural(
                  'image_manager.use_frames',
                  animationFrames.length,
                  oneEnglish: 'Use {count} frame',
                  otherEnglish: 'Use {count} frames',
                ),
              ),
            Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.iconSm,
              onPressed: () => _downloadOne(image),
              attributes: <String, String>{
                'aria-label': huiText("Download {path}", <String, Object?>{
                  'path': path,
                }),
              },
              child: ArcaneIcon.download(size: IconSize.sm),
            ),
            HuiTwoStepButton(
              label: huiText("Delete {path}", <String, Object?>{'path': path}),
              confirmLabel: huiText('Delete'),
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
