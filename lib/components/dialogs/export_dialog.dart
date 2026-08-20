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
      _wireKind == 'real-drops';

  String get _fileName => switch (_wireKind) {
    'motd' => 'motd.json',
    'tablist' => 'tablist.json',
    'real-drops' => 'default.json',
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
    _ => '$huiPreviewFolder$_fileName',
  };

  void _commitName() {
    if (_fixedFileName) return;
    if (_store.menuId != _documentId) _store.setMenuId(_documentId);
  }

  void _downloadJson() {
    _commitName();
    downloadText(_fileName, _store.exportJson());
    toast.success('Saved $_fileName');
  }

  Future<void> _copyJson() async {
    _commitName();
    final bool copied = await copyText(_store.exportJson());
    if (!mounted) return;
    if (copied) {
      toast.success('${_store.docType.noun} JSON copied to the clipboard');
    } else {
      toast.error(
        'The browser refused clipboard access. Use Download instead.',
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
    toast.success('Saved images.zip (${huiFormatBytes(bytes.length)})');
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.canTransferDocument) return const dom.div(<Widget>[]);
    return ArcaneDialog(
      id: 'hui-export-dialog',
      isOpen: component.isOpen,
      onClose: component.onClose,
      title: 'Export ${_store.docType.noun}',
      maxWidth: 720,
      actions: <Widget>[
        Button(
          variant: ButtonVariant.outline,
          onPressed: component.onClose,
          label: 'Close',
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
          title:
              '${_store.errorCount} error'
              '${_store.errorCount == 1 ? '' : 's'} in this menu',
          message:
              'The file will still export, but Gloss may refuse to open '
              'it. Check the validation panel before you ship it.',
        ),
      HuiDialogSection(
        title: 'File name',
        description:
            'The name becomes the menu id, the open command and the '
            'permission node.',
        children: <Widget>[
          HuiField(
            label: 'Menu id',
            help:
                'Lowercase letters, digits, underscore and hyphen. '
                'Anything else is replaced.',
            control: TextInput(
              value: _name,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: huiDefaultMenuId,
              onInput: (String value) => setState(() => _name = value),
              onBlur: _commitName,
              attributes: const <String, String>{
                'aria-label': 'Menu id',
                'autocomplete': 'off',
                'spellcheck': 'false',
              },
            ),
          ),
          HuiCodeBlock(text: '$huiMenuFolder$_fileName'),
        ],
      ),
      HuiDialogSection(
        title: 'Download',
        description: 'Everything the server needs, in the layout it expects.',
        children: <Widget>[
          dom.div(classes: 'hui-dialog-actions', <Widget>[
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              onPressed: _downloadJson,
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: 'Download $_fileName',
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: _copyJson,
              icon: ArcaneIcon.clipboardCopy(size: IconSize.sm),
              label: 'Copy JSON',
            ),
            if (used.isNotEmpty)
              Button(
                variant: ButtonVariant.outline,
                size: ButtonSize.small,
                loading: _zipping,
                disabled: library == null || library.images.isEmpty,
                onPressed: _downloadImages,
                icon: ArcaneIcon.fileArchive(size: IconSize.sm),
                label: 'Download images.zip',
              ),
          ]),
          if (used.isNotEmpty)
            dom.p(classes: 'hui-dialog-note', <Widget>[
              Text(
                'This menu uses ${used.length} image'
                '${used.length == 1 ? '' : 's'}. Unzip images.zip into '
                '$huiImageFolder keeping the folder structure.',
              ),
            ]),
          if (missing > 0)
            ArcaneAlert.warning(
              message:
                  '$missing referenced image'
                  '${missing == 1 ? ' is' : 's are'} not in the local library, '
                  'so ${missing == 1 ? 'it' : 'they'} will not be in the zip. '
                  'Upload the file${missing == 1 ? '' : 's'} or copy '
                  '${missing == 1 ? 'it' : 'them'} to the server by hand.',
            ),
        ],
      ),
      HuiDialogSection(
        title: 'Install on your server',
        description: 'Gloss watches the folder, so no restart is needed.',
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              'Drop $_fileName under $huiMenuFolder. Slash-separated menu '
                  'ids use matching subfolders and stay part of the runtime id.',
              if (used.isNotEmpty)
                'Unzip images.zip into $huiImageFolder so every icon path '
                    'resolves.',
              'Changed menus re-register within about 5 ticks and any open '
                  'session of that id is closed with DEFINITION_RELOADED. '
                  'New and deleted files are noticed within about 20 ticks.',
              'Grant gloss.menus.open, gloss.menus.move and '
                  'gloss.open.$_documentId — the '
                  'per-menu node is not declared in plugin.yml, so it has '
                  'to be granted explicitly.',
              'Test it with /gloss menu open $_documentId '
                  '(aliases: gl, glo, gg).',
              'To re-anchor the open session, stand at its new origin and '
                  'run /gloss menu move. This keeps the configured offset and '
                  'does not rewrite $_fileName.',
            ],
          ),
          HuiCodeBlock(text: '/gloss menu open $_documentId\n/gloss menu move'),
        ],
      ),
      HuiDialogSection(
        title: 'Preview',
        description:
            '${json.length} characters, '
            '${_store.menu.components.length} components.',
        children: <Widget>[HuiCodeBlock(text: json, scroll: true)],
      ),
    ]);
  }

  Widget _previewBody() {
    final String json = _store.exportJson();
    final int elementCount = _store.previewDoc?.elements.length ?? 0;

    return dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
      HuiDialogSection(
        title: 'File name',
        description:
            'Only used to name the file on disk and in error logs '
            '— unlike a menu, a container-preview document carries no id of '
            'its own.',
        children: <Widget>[
          HuiField(
            label: 'File name',
            help:
                'Lowercase letters, digits, underscore and hyphen. '
                'Anything else is replaced.',
            control: TextInput(
              value: _name,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: huiDefaultMenuId,
              onInput: (String value) => setState(() => _name = value),
              onBlur: _commitName,
              attributes: const <String, String>{
                'aria-label': 'File name',
                'autocomplete': 'off',
                'spellcheck': 'false',
              },
            ),
          ),
          HuiCodeBlock(text: '$huiPreviewFolder$_fileName'),
        ],
      ),
      HuiDialogSection(
        title: 'Download',
        description:
            'The document, ready to drop into $huiPreviewFolder. '
            'There is no images zip: the preview format has no image icons.',
        children: <Widget>[
          dom.div(classes: 'hui-dialog-actions', <Widget>[
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              onPressed: _downloadJson,
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: 'Download $_fileName',
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: _copyJson,
              icon: ArcaneIcon.clipboardCopy(size: IconSize.sm),
              label: 'Copy JSON',
            ),
          ]),
        ],
      ),
      HuiDialogSection(
        title: 'Install on your server',
        description:
            'Previews are not menus: they draw automatically, with '
            'no open command.',
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              'Drop $_fileName into $huiPreviewFolder — the folder is flat, '
                  'files in subfolders are never registered.',
              'Editing, adding or deleting a file there takes effect within '
                  'a few ticks: no reload command and no restart.',
              'Grant gloss.preview to whoever should see it (operators '
                  'have it by default); a viewer without it sees the locked '
                  'document instead.',
              'It draws automatically over any block or entity its `match` '
                  'names — there is no open command for a preview.',
            ],
          ),
        ],
      ),
      HuiDialogSection(
        title: 'Preview',
        description:
            '${json.length} characters, $elementCount element'
            '${elementCount == 1 ? '' : 's'}.',
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
          title:
              '${_store.errorCount} error'
              '${_store.errorCount == 1 ? '' : 's'} in this $noun',
          message:
              'The file will still export, but Gloss may refuse to load it. '
              'Check the validation panel before installing it.',
        ),
      HuiDialogSection(
        title: _fixedFileName ? 'Runtime file' : 'File name',
        description: _fixedFileName
            ? 'Gloss has exactly one $noun document, so its runtime file name '
                  'is fixed.'
            : 'The file name becomes this $noun document\'s runtime id.',
        children: <Widget>[
          if (!_fixedFileName)
            HuiField(
              label: 'Document id',
              help:
                  'Lowercase letters, digits, underscore, hyphen and nested '
                  'path segments. Anything else is replaced.',
              control: TextInput(
                value: _name,
                size: ComponentSize.sm,
                fullWidth: true,
                onInput: (String value) => setState(() => _name = value),
                onBlur: _commitName,
                attributes: const <String, String>{
                  'aria-label': 'Document id',
                  'autocomplete': 'off',
                  'spellcheck': 'false',
                },
              ),
            ),
          HuiCodeBlock(text: _installPath),
        ],
      ),
      HuiDialogSection(
        title: 'Download',
        description: 'Canonical JSON ready for the Gloss runtime.',
        children: <Widget>[
          dom.div(classes: 'hui-dialog-actions', <Widget>[
            Button(
              variant: ButtonVariant.primary,
              size: ButtonSize.small,
              onPressed: _downloadJson,
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: 'Download $_fileName',
            ),
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.small,
              onPressed: _copyJson,
              icon: ArcaneIcon.clipboardCopy(size: IconSize.sm),
              label: 'Copy JSON',
            ),
          ]),
        ],
      ),
      HuiDialogSection(
        title: 'Install on your server',
        description: 'Gloss watches runtime JSON and applies valid changes.',
        children: <Widget>[
          HuiSteps(
            steps: <String>[
              'Drop $_fileName at $_installPath.',
              'Keep the schema version and server-owned revision valid; the '
                  'validation panel reports anything Gloss will reject.',
              'Check the server console after replacing the file. A parse '
                  'failure leaves the last working $noun active.',
            ],
          ),
        ],
      ),
      HuiDialogSection(
        title: 'Preview',
        description: '${json.length} characters in the exported $noun JSON.',
        children: <Widget>[HuiCodeBlock(text: json, scroll: true)],
      ),
    ]);
  }
}
