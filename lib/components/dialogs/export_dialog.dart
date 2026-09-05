/// Export dialog: canonical runtime file name, downloads and install location
/// for every transferable Gloss document kind.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../config/defaults.dart';
import '../../config/links.dart';
import '../../services/clipboard.dart';
import '../../services/file_transfer.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    required this.store,
    required this.isOpen,
    required this.onClose,
    this.images,
    super.key,
  });

  final EditorStore store;

  /// Defaults to the library the store already holds.
  final ImageLibrary? images;
  final bool isOpen;
  final VoidCallback onClose;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  late String _name;
  bool _zipping = false;

  EditorStore get _store => component.store;

  ImageLibrary? get _images => component.images ?? _store.images;

  @override
  void initState() {
    super.initState();
    _name = _store.menuId;
  }

  @override
  void didUpdateComponent(ExportDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    // Reopening always shows the document's current id, never a stale edit.
    if (!oldComponent.isOpen && component.isOpen) {
      _name = _store.menuId;
    }
  }

  String get _documentId => sanitizeMenuId(_name);

  String? get _wireKind => _store.docType.syncWireKind;

  bool get _fixedFileName =>
      _wireKind == 'motd' ||
      _wireKind == 'tablist' ||
      _wireKind == 'real-drops' ||
      _wireKind == 'entity-overlays' ||
      _wireKind == 'damage-indicators';

  String get _fileName => switch (_wireKind) {
    'motd' => 'motd.json',
    'tablist' => 'tablist.json',
    'real-drops' => 'default.json',
    'damage-indicators' => 'default.json',
    'entity-overlays' => 'default.json',
    _ => '$_documentId.json',
  };

  String get _installPath => switch (_wireKind) {
    'menu' => '$huiMenuFolder$_fileName',
    'hologram' => '$huiHologramFolder$_fileName',
    'animation' => '$huiAnimationFolder$_fileName',
    'scoreboard' => '$huiScoreboardFolder$_fileName',
    'motd' => huiMotdFile,
    'emoji' => '$huiEmojiFolder$_fileName',
    'bubble-style' => '$huiBubbleFolder$_fileName',
    'tablist' => huiTablistFile,
    'real-drops' => huiRealDropsFile,
    'damage-indicators' => huiDamageIndicatorsFile,
    'entity-overlays' => huiEntityOverlaysFile,
    _ => '$huiPreviewFolder$_fileName',
  };

  void _commitName() {
    if (_fixedFileName) return;
    if (_store.menuId != _documentId) _store.setMenuId(_documentId);
  }

  void _downloadJson() {
    _commitName();
    downloadText(_fileName, _store.exportJson());
    toast.success(
      huiText("Saved {fileName}", <String, Object?>{'fileName': _fileName}),
    );
  }

  Future<void> _copyJson() async {
    _commitName();
    final bool copied = await copyText(_store.exportJson());
    if (!mounted) return;
    if (copied) {
      toast.success(
        huiText("{noun} JSON copied to the clipboard", <String, Object?>{
          'noun': _store.docType.noun,
        }),
      );
    } else {
      toast.error(
        huiText('The browser refused clipboard access. Use Download instead.'),
      );
    }
  }

  Future<void> _downloadImages() async {
    final ImageLibrary? library = _images;
    if (library == null || library.images.isEmpty) return;
    setState(() => _zipping = true);
    final List<int> bytes = await library.exportZipBytes();
    if (!mounted) return;
    setState(() => _zipping = false);
    downloadBytes('images.zip', bytes, mime: 'application/zip');
    toast.success(
      huiText("Saved images.zip ({huiFormatBytes})", <String, Object?>{
        'huiFormatBytes': huiFormatBytes(bytes.length),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.canTransferDocument) return const dom.div(<Widget>[]);
    return ArcaneDialog(
      id: 'hui-export-dialog',
      isOpen: component.isOpen,
      onClose: component.onClose,
      title: huiText("Export {noun}", <String, Object?>{
        'noun': _store.docType.noun,
      }),
      maxWidth: 720,
      actions: <Widget>[
        Button(
          variant: ButtonVariant.outline,
          onPressed: component.onClose,
          label: huiText('Close'),
        ),
      ],
      children: <Widget>[
        ListenableBuilder(
          listenable: _store,
          builder: (BuildContext inner) {
            if (!_store.canTransferDocument) {
              return const dom.div(<Widget>[]);
            }
            if (_store.isMenuDoc) return _menuBody();
            if (_store.isPreviewDoc) return _previewBody();
            return _runtimeBody();
          },
        ),
      ],
    );
  }

  Widget _menuBody() {
    final ImageLibrary? library = _images;
    final Set<String> used = huiUsedImagePaths(_store.menu);
    final int missing = library == null
        ? used.length
        : used.where((String path) => !library.contains(path)).length;
    final String json = _store.exportJson();

    return dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
      if (_store.hasErrors)
        ArcaneAlert.error(
          title: huiPlural(
            'export.menu_error_count',
            _store.errorCount,
            oneEnglish: '{count} error in this menu',
            otherEnglish: '{count} errors in this menu',
          ),
          message: huiText(
            'The file will still export, but Gloss may refuse to open '
            'it. Check the validation panel before you ship it.',
          ),
        ),
      HuiDialogSection(
        title: huiText('File name'),
        description: huiText(
          'The name becomes the menu id, the open command and the '
          'permission node.',
        ),
        children: <Widget>[
          HuiField(
            label: huiText('Menu id'),
            help: huiText(
              'Lowercase letters, digits, underscore and hyphen. '
              'Anything else is replaced.',
            ),
            control: TextInput(
              value: _name,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: huiDefaultMenuId,
              onInput: (String value) => setState(() => _name = value),
              onBlur: _commitName,
              attributes: <String, String>{
                'aria-label': huiText('Menu id'),
                'autocomplete': 'off',
                'spellcheck': 'false',
                'dir': 'ltr',
              },
            ),
          ),
          HuiCodeBlock(text: '$huiMenuFolder$_fileName'),
        ],
      ),
      HuiDialogSection(
        title: huiText('Download'),
        description: huiText(
          'Everything the server needs, in the layout it expects.',
        ),
        children: <Widget>[
          dom.div(classes: 'hui-dialog-actions', <Widget>[
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              onPressed: _downloadJson,
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: huiText("Download {fileName}", <String, Object?>{
                'fileName': _fileName,
              }),
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: _copyJson,
              icon: ArcaneIcon.clipboardCopy(size: IconSize.sm),
              label: huiText('Copy JSON'),
            ),
            if (used.isNotEmpty)
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.small,
                loading: _zipping,
                disabled: library == null || library.images.isEmpty,
                onPressed: _downloadImages,
                icon: ArcaneIcon.fileArchive(size: IconSize.sm),
                label: huiText('Download images.zip'),
              ),
          ]),
          if (used.isNotEmpty)
            dom.p(classes: 'hui-dialog-note', <Widget>[
              Text(
                huiPlural(
                  'export.menu_image_count',
                  used.length,
                  oneEnglish:
                      'This menu uses {count} image. Unzip images.zip into '
                      '{folder}, keeping the folder structure.',
                  otherEnglish:
                      'This menu uses {count} images. Unzip images.zip into '
                      '{folder}, keeping the folder structure.',
                  arguments: <String, Object?>{'folder': huiImageFolder},
                ),
              ),
            ]),
          if (missing > 0)
            ArcaneAlert.warning(
              message: huiPlural(
                'export.missing_image_count',
                missing,
                oneEnglish:
                    '{count} referenced image is not in the local library, '
                    'so it will not be in the zip. Upload the file or copy it '
                    'to the server by hand.',
                otherEnglish:
                    '{count} referenced images are not in the local library, '
                    'so they will not be in the zip. Upload the files or copy '
                    'them to the server by hand.',
              ),
            ),
        ],
      ),
      HuiDialogSection(
        title: huiText('Install on your server'),
        description: huiText(
          'Gloss watches the folder, so no restart is needed.',
        ),
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              huiText(
                'Drop {fileName} under {menuFolder}. Slash-separated menu '
                'ids use matching subfolders and stay part of the runtime id.',
                <String, Object?>{
                  'fileName': _fileName,
                  'menuFolder': huiMenuFolder,
                },
              ),
              if (used.isNotEmpty)
                huiText(
                  'Unzip images.zip into {imageFolder} so every icon path '
                  'resolves.',
                  <String, Object?>{'imageFolder': huiImageFolder},
                ),
              huiText(
                'Changed menus re-register within about 5 ticks and any open '
                'session of that id is closed with DEFINITION_RELOADED. '
                'New and deleted files are noticed within about 20 ticks.',
              ),
              huiText(
                'Grant gloss.menus.open, gloss.menus.move and '
                'gloss.open.{documentId} — the per-menu node is not declared '
                'in plugin.yml, so it has to be granted explicitly.',
                <String, Object?>{'documentId': _documentId},
              ),
              huiText(
                'Test it with /gloss menu open {documentId} '
                '(aliases: gl, glo, gg).',
                <String, Object?>{'documentId': _documentId},
              ),
              huiText(
                'To re-anchor the open session, stand at its new origin and '
                'run /gloss menu move. This keeps the configured offset and '
                'does not rewrite {fileName}.',
                <String, Object?>{'fileName': _fileName},
              ),
            ],
          ),
          HuiCodeBlock(text: '/gloss menu open $_documentId\n/gloss menu move'),
        ],
      ),
      HuiDialogSection(
        title: huiText('Preview'),
        description: huiText('{characters}, {components}.', <String, Object?>{
          'characters': huiPlural(
            'export.character_count',
            json.length,
            oneEnglish: '{count} character',
            otherEnglish: '{count} characters',
          ),
          'components': huiPlural(
            'export.component_count',
            _store.menu.components.length,
            oneEnglish: '{count} component',
            otherEnglish: '{count} components',
          ),
        }),
        children: <Widget>[HuiCodeBlock(text: json, scroll: true)],
      ),
    ]);
  }

  Widget _previewBody() {
    final String json = _store.exportJson();
    final int elementCount = _store.previewDoc?.elements.length ?? 0;

    return dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
      HuiDialogSection(
        title: huiText('File name'),
        description: huiText(
          'Only used to name the file on disk and in error logs '
          '— unlike a menu, a container-preview document carries no id of '
          'its own.',
        ),
        children: <Widget>[
          HuiField(
            label: huiText('File name'),
            help: huiText(
              'Lowercase letters, digits, underscore and hyphen. '
              'Anything else is replaced.',
            ),
            control: TextInput(
              value: _name,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: huiDefaultMenuId,
              onInput: (String value) => setState(() => _name = value),
              onBlur: _commitName,
              styles: huiTechnicalInputStyles,
              attributes: <String, String>{
                ...huiTechnicalInputAttributes,
                'aria-label': huiText('File name'),
              },
            ),
          ),
          HuiCodeBlock(text: '$huiPreviewFolder$_fileName'),
        ],
      ),
      HuiDialogSection(
        title: huiText('Download'),
        description: huiText(
          "The document, ready to drop into {huiPreviewFolder}. There is no images zip: the preview format has no image icons.",
          <String, Object?>{'huiPreviewFolder': huiPreviewFolder},
        ),
        children: <Widget>[
          dom.div(classes: 'hui-dialog-actions', <Widget>[
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              onPressed: _downloadJson,
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: huiText("Download {fileName}", <String, Object?>{
                'fileName': _fileName,
              }),
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: _copyJson,
              icon: ArcaneIcon.clipboardCopy(size: IconSize.sm),
              label: huiText('Copy JSON'),
            ),
          ]),
        ],
      ),
      HuiDialogSection(
        title: huiText('Install on your server'),
        description: huiText(
          'Previews are not menus: they draw automatically, with '
          'no open command.',
        ),
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              huiText(
                'Drop {fileName} into {previewFolder} — the folder is flat, '
                'files in subfolders are never registered.',
                <String, Object?>{
                  'fileName': _fileName,
                  'previewFolder': huiPreviewFolder,
                },
              ),
              huiText(
                'Editing, adding or deleting a file there takes effect within '
                'a few ticks: no reload command and no restart.',
              ),
              huiText(
                'Grant gloss.preview to whoever should see it (operators '
                'have it by default); a viewer without it sees the locked '
                'document instead.',
              ),
              huiText(
                'It draws automatically over any block or entity its `match` '
                'names — there is no open command for a preview.',
              ),
            ],
          ),
        ],
      ),
      HuiDialogSection(
        title: huiText('Preview'),
        description: huiText('{characters}; {elements}.', <String, Object?>{
          'characters': huiPlural(
            'export.character_count',
            json.length,
            oneEnglish: '{count} character',
            otherEnglish: '{count} characters',
          ),
          'elements': huiPlural(
            'export.element_count',
            elementCount,
            oneEnglish: '{count} element',
            otherEnglish: '{count} elements',
          ),
        }),
        children: <Widget>[HuiCodeBlock(text: json, scroll: true)],
      ),
    ]);
  }

  Widget _runtimeBody() {
    final String json = _store.exportJson();
    final String noun = _store.docType.noun;

    return dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
      if (_store.hasErrors)
        ArcaneAlert.error(
          title: huiPlural(
            'export.document_error_count',
            _store.errorCount,
            oneEnglish: '{count} error in this {document}',
            otherEnglish: '{count} errors in this {document}',
            arguments: <String, Object?>{'document': noun},
          ),
          message: huiText(
            'The file will still export, but Gloss may refuse to load it. '
            'Check the validation panel before installing it.',
          ),
        ),
      HuiDialogSection(
        title: _fixedFileName ? huiText('Runtime file') : huiText('File name'),
        description: _fixedFileName
            ? huiText(
                'Gloss uses a fixed runtime file name for this document type.',
              )
            : huiText('The file name becomes this document\'s runtime id.'),
        children: <Widget>[
          if (!_fixedFileName)
            HuiField(
              label: huiText('Document id'),
              help: huiText(
                'Lowercase letters, digits, underscore, hyphen and nested '
                'path segments. Anything else is replaced.',
              ),
              control: TextInput(
                value: _name,
                size: ComponentSize.sm,
                fullWidth: true,
                onInput: (String value) => setState(() => _name = value),
                onBlur: _commitName,
                attributes: <String, String>{
                  'aria-label': huiText('Document id'),
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                  'dir': 'ltr',
                },
              ),
            ),
          HuiCodeBlock(text: _installPath),
        ],
      ),
      HuiDialogSection(
        title: huiText('Download'),
        description: huiText('Canonical JSON ready for the Gloss runtime.'),
        children: <Widget>[
          dom.div(classes: 'hui-dialog-actions', <Widget>[
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              onPressed: _downloadJson,
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: huiText("Download {fileName}", <String, Object?>{
                'fileName': _fileName,
              }),
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: _copyJson,
              icon: ArcaneIcon.clipboardCopy(size: IconSize.sm),
              label: huiText('Copy JSON'),
            ),
          ]),
        ],
      ),
      HuiDialogSection(
        title: huiText('Install on your server'),
        description: huiText(
          'Gloss watches runtime JSON and applies valid changes.',
        ),
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              huiText('Drop {fileName} at {installPath}.', <String, Object?>{
                'fileName': _fileName,
                'installPath': _installPath,
              }),
              huiText(
                'Keep the schema version and server-owned revision valid; the validation panel reports anything Gloss will reject.',
              ),
              huiText(
                'Check the server console after replacing the file. A parse failure leaves the last working {document} active.',
                <String, Object?>{'document': noun},
              ),
            ],
          ),
        ],
      ),
      HuiDialogSection(
        title: huiText('Preview'),
        description: huiPlural(
          'export.json_character_count',
          json.length,
          oneEnglish: '{count} character in the exported {noun} JSON.',
          otherEnglish: '{count} characters in the exported {noun} JSON.',
          arguments: <String, Object?>{'noun': noun},
        ),
        children: <Widget>[HuiCodeBlock(text: json, scroll: true)],
      ),
    ]);
  }
}
