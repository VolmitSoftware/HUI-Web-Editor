/// Import dialog: file picker, paste box, and a preview before anything is
/// replaced.
///
/// The old editor replaced the whole document from a native `alert()` with no
/// preview and no undo. Here the document is only touched when the user presses
/// Replace, the parse result is shown first, and the replacement is a single
/// undo step.
///
/// The pasted or picked JSON is auto-detected across every transferable Gloss
/// document kind. Validation is shown before replacement but never blocks an
/// import; only malformed JSON or a document that its detected codec cannot
/// decode does.
library;

import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../doctype/document_type.dart';
import '../../doctype/document_type_registry.dart';
import '../../logic/canvas_scene.dart'
    show CanvasScene, ImageCharCache, McTextCache, buildCanvasScene;
import '../../logic/gloss_text.dart'
    show GlossAnimationResolver, GlossEmojiResolver;
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart' show HuiCatalogs;
import '../../services/file_transfer.dart';
import '../../services/image_library.dart' show ImageLibrary;
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'dialog_parts.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({
    required this.store,
    required this.isOpen,
    required this.onClose,
    super.key,
  });

  final EditorStore store;
  final bool isOpen;
  final VoidCallback onClose;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  String _text = '';
  String _sourceName = '';
  String? _parseError;
  Object? _parsedDocument;
  DocumentTypeAdapter? _parsedType;
  List<HuiIssue> _issues = const <HuiIssue>[];
  bool _picking = false;

  /// Bumped whenever the text is replaced from code; the textarea remounts so
  /// the browser shows the new value instead of the user's dirty one.
  int _generation = 0;

  /// Shared by every parse in this dialog: text and image measurement is
  /// re-run on each keystroke, and a menu import measures the whole document.
  final McTextCache _textCache = McTextCache();
  final ImageCharCache _charCache = ImageCharCache();

  EditorStore get _store => component.store;

  @override
  void didUpdateComponent(ImportDialog oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!oldComponent.isOpen && component.isOpen) {
      _reset();
    }
  }

  void _reset() {
    _text = '';
    _sourceName = '';
    _parseError = null;
    _parsedDocument = null;
    _parsedType = null;
    _issues = const <HuiIssue>[];
    _generation++;
  }

  void _parse(String raw) {
    _parseError = null;
    _parsedDocument = null;
    _parsedType = null;
    _issues = const <HuiIssue>[];
    if (raw.trim().isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      _parseError = 'That is not valid JSON.';
      return;
    }

    try {
      final DocumentTypeAdapter type = DocumentTypeRegistry.detectTransferable(
        decoded,
      );
      final Object document = type.decodeSnapshot(raw);
      _parsedType = type;
      _parsedDocument = document;
      _issues = _validate(type, document);
    } on HuiFormatException catch (e) {
      _parseError = '${e.message} (at ${e.path})';
    } catch (_) {
      _parseError = 'That JSON is not a supported Gloss runtime document.';
    }
  }

  /// Validates through the detected kind's adapter, so the import preview
  /// reports exactly what the document reports once it is open — one dispatch
  /// instead of a second per-kind switch that can drift from
  /// [DocumentTypeAdapter.validate].
  List<HuiIssue> _validate(DocumentTypeAdapter type, Object document) =>
      type.validate(
        _ImportedDocumentState(
          store: _store,
          document: document,
          textCache: _textCache,
          charCache: _charCache,
        ),
      );

  void _onText(String raw) {
    setState(() {
      _text = raw;
      _parse(raw);
    });
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    final (String, String)? picked = await pickJsonFile();
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (picked != null) {
        _sourceName = picked.$1;
        _text = picked.$2;
        _generation++;
        _parse(_text);
      }
    });
  }

  bool get _hasParsed => _parsedDocument != null && _parsedType != null;

  void _replace() {
    if (!_hasParsed) return;
    final String name = _sourceName.isEmpty ? _store.menuId : _sourceName;
    // The store re-runs the same auto-detection; the dialog's own parse above
    // exists only to preview the result before this commits.
    _store.importJson(name, _text);
    component.onClose();
  }

  String get _targetId =>
      _sourceName.isEmpty ? _store.menuId : menuIdFromFileName(_sourceName);

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-import-dialog',
    isOpen: component.isOpen,
    onClose: component.onClose,
    title: 'Import JSON',
    maxWidth: 720,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: component.onClose,
        label: 'Cancel',
      ),
      Button(
        variant: ButtonVariant.primary,
        disabled: !_hasParsed,
        onPressed: _hasParsed ? _replace : null,
        icon: ArcaneIcon.upload(size: IconSize.sm),
        label: 'Replace document',
      ),
    ],
    children: <Widget>[_body()],
  );

  Widget _body() => dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
    const ArcaneAlert.warning(
      message:
          'Importing replaces the document you are editing. It is a '
          'single undo step, so Ctrl+Z brings the old one back.',
    ),
    HuiDialogSection(
      title: 'From a file',
      description:
          'Menus, previews, holograms, animations, scoreboards, MOTD, emoji, '
          'bubble styles and tablists all work; the file shape decides which. '
          'Dropping JSON anywhere creates a new document. This dialog replaces '
          'the active document only after you confirm below.',
      children: <Widget>[
        dom.div(classes: 'hui-dialog-actions', <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.small,
            loading: _picking,
            onPressed: _pickFile,
            icon: ArcaneIcon.folderOpen(size: IconSize.sm),
            label: 'Choose a .json file',
          ),
          if (_sourceName.isNotEmpty)
            dom.span(classes: 'hui-dialog-filename', <Widget>[
              Text(_sourceName),
            ]),
        ]),
      ],
    ),
    HuiDialogSection(
      title: 'Or paste it',
      description:
          'Anything the plugin accepts: single-value lists and '
          'missing booleans are read the same way Gloss reads them.',
      children: <Widget>[
        TextArea(
          key: ValueKey<int>(_generation),
          value: _text,
          rows: 8,
          fullWidth: true,
          placeholder: '{ "offset": [0, 1.7, 2.5], "components": [] }',
          onInput: _onText,
        ),
      ],
    ),
    HuiDialogSection(
      title: 'Preview',
      description: 'Nothing is written until you press Replace.',
      children: <Widget>[_preview()],
    ),
  ]);

  Widget _preview() {
    // The picker is a real wait: the browser dialog, then a full file read.
    // Standing in for the summary that is about to appear keeps the section
    // from collapsing and reflowing everything under it.
    if (_picking) {
      return const HuiSkeleton(label: 'Reading the file', lines: 4);
    }
    final String? error = _parseError;
    if (error != null) {
      return ArcaneAlert.error(
        title: 'Could not read that file',
        message: error,
      );
    }
    final Object? document = _parsedDocument;
    if (document is HuiPreviewDoc) return _previewDocSummary(document);
    if (document is HuiMenu) return _menuSummary(document);
    if (document is GlossDoc) return _glossSummary(document);
    return ArcaneEmptyState(
      title: 'Nothing to import yet',
      description:
          'Choose a file or paste JSON above. Every runtime document kind is '
          'detected as you type, and validation issues are listed here before '
          'anything is replaced.',
      icon: ArcaneIcon.fileCode(size: IconSize.lg),
    );
  }

  Widget _menuSummary(HuiMenu menu) {
    final int errors = _issues
        .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
        .length;
    final int warnings = _issues
        .where((HuiIssue issue) => issue.severity == HuiSeverity.warning)
        .length;

    return dom.div(classes: 'hui-import-preview', <Widget>[
      HuiChips(
        labels: <String>[
          'menu document',
          'id $_targetId',
          '${menu.components.length} component'
              '${menu.components.length == 1 ? '' : 's'}',
          menu.followPlayer ? 'follows player' : 'fixed in place',
          if (menu.maxDistance != null)
            'maxDistance ${menu.maxDistance}'
          else
            'unlimited range',
          '$errors error${errors == 1 ? '' : 's'}',
          '$warnings warning${warnings == 1 ? '' : 's'}',
        ],
      ),
      _issueList(),
    ]);
  }

  Widget _previewDocSummary(HuiPreviewDoc doc) {
    final int errors = _issues.length;
    return dom.div(classes: 'hui-import-preview', <Widget>[
      HuiChips(
        labels: <String>[
          'container-preview document',
          'id $_targetId',
          '${doc.elements.length} element'
              '${doc.elements.length == 1 ? '' : 's'}',
          '${doc.variants.length} variant'
              '${doc.variants.length == 1 ? '' : 's'}',
          doc.card == null ? 'no card (bare content)' : 'has a card',
          '$errors expression error${errors == 1 ? '' : 's'}',
        ],
      ),
      if (errors > 0)
        const dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            'Expression errors are shown for reference and do not '
            'block importing — the document still replaces the current '
            'one when you press Replace.',
          ),
        ]),
      _issueList(),
    ]);
  }

  Widget _glossSummary(GlossDoc doc) {
    final int errors = _issues
        .where((HuiIssue issue) => issue.severity == HuiSeverity.error)
        .length;
    final int warnings = _issues
        .where((HuiIssue issue) => issue.severity == HuiSeverity.warning)
        .length;
    final String noun = _parsedType?.noun ?? 'runtime';
    return dom.div(classes: 'hui-import-preview', <Widget>[
      HuiChips(
        labels: <String>[
          '$noun document',
          'id $_targetId',
          'schema ${doc.schemaVersion}',
          'revision ${doc.revision}',
          ..._documentFacts(doc),
          '$errors error${errors == 1 ? '' : 's'}',
          '$warnings warning${warnings == 1 ? '' : 's'}',
        ],
      ),
      _issueList(),
    ]);
  }

  List<String> _documentFacts(GlossDoc doc) => switch (doc) {
    final GlossHologramDoc hologram => <String>[
      '${hologram.lines.length} line${hologram.lines.length == 1 ? '' : 's'}',
    ],
    final GlossAnimationDoc animation => <String>[
      '${animation.frames.length} frame${animation.frames.length == 1 ? '' : 's'}',
      animation.mode,
    ],
    final GlossScoreboardDoc scoreboard => <String>[
      '${scoreboard.lines.length} line${scoreboard.lines.length == 1 ? '' : 's'}',
      scoreboard.primary ? 'primary' : 'not primary',
    ],
    final GlossMotdDoc motd => <String>[
      '${motd.entries.length} entr${motd.entries.length == 1 ? 'y' : 'ies'}',
    ],
    final GlossEmojiDoc emoji => <String>[
      emoji.enabled ? 'enabled' : 'disabled',
    ],
    final GlossBubbleStyleDoc bubble => <String>[
      '${bubble.wordWrapChars} character wrap',
    ],
    final GlossTablistDoc tablist => <String>[
      '${tablist.nameFormats.length} name format${tablist.nameFormats.length == 1 ? '' : 's'}',
    ],
    _ => const <String>[],
  };

  Widget _issueList() {
    if (_issues.isEmpty) {
      return const dom.p(classes: 'hui-dialog-note', <Widget>[
        Text('No issues found in the imported document.'),
      ]);
    }
    return dom.ul(classes: 'hui-import-issues', <Widget>[
      for (final HuiIssue issue in _issues.take(12))
        dom.li(
          classes: classNames(<String?>[
            'hui-import-issue',
            switch (issue.severity) {
              HuiSeverity.error => 'is-error',
              HuiSeverity.warning => 'is-warning',
              HuiSeverity.info => 'is-info',
            },
          ]),
          <Widget>[
            dom.code(<Widget>[Text(issue.path)]),
            dom.span(<Widget>[Text(issue.message)]),
          ],
        ),
      if (_issues.length > 12)
        dom.li(classes: 'hui-import-issue', <Widget>[
          dom.span(<Widget>[Text('and ${_issues.length - 12} more…')]),
        ]),
    ]);
  }
}

/// The parsed-but-not-yet-adopted document, presented as the document state
/// its [DocumentTypeAdapter] expects.
///
/// The store still owns the catalogs, image library and workspace animation /
/// emoji resolvers — validation of an imported document resolves references
/// against the workspace it is about to join — but the document slots carry
/// the candidate, never the open document.
final class _ImportedDocumentState implements DocumentStateView {
  _ImportedDocumentState({
    required this.store,
    required this.document,
    required this.textCache,
    required this.charCache,
  });

  final EditorStore store;
  final Object document;
  final McTextCache textCache;
  final ImageCharCache charCache;

  CanvasScene? _scene;

  /// Only the menu adapter reads this, and only for a [HuiMenu] document; the
  /// store's menu is an unreachable fallback that keeps the getter total.
  @override
  HuiMenu get menu => document is HuiMenu ? document as HuiMenu : store.menu;

  @override
  HuiPreviewDoc? get previewDoc =>
      document is HuiPreviewDoc ? document as HuiPreviewDoc : null;

  @override
  GlossDoc? get glossDoc => document is GlossDoc ? document as GlossDoc : null;

  @override
  GlossAnimationResolver get workspaceAnimations => store.workspaceAnimations;

  @override
  GlossEmojiResolver get workspaceEmoji => store.workspaceEmoji;

  /// The candidate was decoded here, not read back from storage, so there is
  /// no byte-exact source to preserve.
  @override
  String? get preservedMenuSource => null;

  @override
  HuiCatalogs get catalogs => store.catalogs;

  @override
  ImageLibrary? get images => store.images;

  /// Overlap reporting needs the candidate's own scene, not the open
  /// document's. Cached because the adapter may ask more than once.
  @override
  CanvasScene resolveValidationScene() => _scene ??= buildCanvasScene(
    menu: menu,
    uiScale: 1,
    trueRender: false,
    togglePreview: store.togglePreviewFor,
    textCache: textCache,
    images: store.images,
    catalogs: store.catalogs,
    charCache: charCache,
    animations: store.workspaceAnimations,
    emoji: store.workspaceEmoji,
  );
}
