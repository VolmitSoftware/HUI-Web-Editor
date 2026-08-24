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
import 'package:gloss_editor/l10n/hui_localizations.dart';

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
  String Function()? _parseError;
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
      _parseError = () => huiText('That is not valid JSON.');
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
      _parseError = () => huiText('{message} (at {path})', <String, Object?>{
        'message': e.message,
        'path': e.path,
      });
    } catch (_) {
      _parseError = () =>
          huiText('That JSON is not a supported Gloss runtime document.');
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
    title: huiText('Import JSON'),
    maxWidth: 720,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: component.onClose,
        label: huiText('Cancel'),
      ),
      Button(
        variant: ButtonVariant.primary,
        disabled: !_hasParsed,
        onPressed: _hasParsed ? _replace : null,
        icon: ArcaneIcon.upload(size: IconSize.sm),
        label: huiText('Replace document'),
      ),
    ],
    children: <Widget>[_body()],
  );

  Widget _body() => dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
    ArcaneAlert.warning(
      message: huiText(
        'Importing replaces the document you are editing. It is a single undo step, so Ctrl+Z brings the old one back.',
      ),
    ),
    HuiDialogSection(
      title: huiText('From a file'),
      description: huiText(
        'Menus, previews, holograms, animations, scoreboards, MOTD, emoji, '
        'bubble styles and tablists all work; the file shape decides which. '
        'Dropping JSON anywhere creates a new document. This dialog replaces '
        'the active document only after you confirm below.',
      ),
      children: <Widget>[
        dom.div(classes: 'hui-dialog-actions', <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.small,
            loading: _picking,
            onPressed: _pickFile,
            icon: ArcaneIcon.folderOpen(size: IconSize.sm),
            label: huiText('Choose a .json file'),
          ),
          if (_sourceName.isNotEmpty)
            dom.span(classes: 'hui-dialog-filename', <Widget>[
              Text(_sourceName),
            ]),
        ]),
      ],
    ),
    HuiDialogSection(
      title: huiText('Or paste it'),
      description: huiText(
        'Anything the plugin accepts: single-value lists and '
        'missing booleans are read the same way Gloss reads them.',
      ),
      children: <Widget>[
        TextArea(
          key: ValueKey<int>(_generation),
          value: _text,
          rows: 8,
          fullWidth: true,
          styles: huiTechnicalInputStyles,
          placeholder: huiText('{ "offset": [0, 1.7, 2.5], "components": [] }'),
          onInput: _onText,
        ),
      ],
    ),
    HuiDialogSection(
      title: huiText('Preview'),
      description: huiText('Nothing is written until you press Replace.'),
      children: <Widget>[_preview()],
    ),
  ]);

  Widget _preview() {
    // The picker is a real wait: the browser dialog, then a full file read.
    // Standing in for the summary that is about to appear keeps the section
    // from collapsing and reflowing everything under it.
    if (_picking) {
      return HuiSkeleton(label: huiText('Reading the file'), lines: 4);
    }
    final String? error = _parseError?.call();
    if (error != null) {
      return ArcaneAlert.error(
        title: huiText('Could not read that file'),
        message: error,
      );
    }
    final Object? document = _parsedDocument;
    if (document is HuiPreviewDoc) return _previewDocSummary(document);
    if (document is HuiMenu) return _menuSummary(document);
    if (document is GlossDoc) return _glossSummary(document);
    return ArcaneEmptyState(
      title: huiText('Nothing to import yet'),
      description: huiText(
        'Choose a file or paste JSON above. Every runtime document kind is '
        'detected as you type, and validation issues are listed here before '
        'anything is replaced.',
      ),
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
          huiText('menu document'),
          huiText('id {id}', <String, Object?>{'id': _targetId}),
          huiPlural(
            'import.components.count',
            menu.components.length,
            oneEnglish: '{count} component',
            otherEnglish: '{count} components',
          ),
          menu.followPlayer
              ? huiText('follows player')
              : huiText('fixed in place'),
          if (menu.maxDistance != null)
            huiText('maxDistance {distance}', <String, Object?>{
              'distance': menu.maxDistance,
            })
          else
            huiText('unlimited range'),
          _errorCountLabel(errors),
          _warningCountLabel(warnings),
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
          huiText('container-preview document'),
          huiText('id {id}', <String, Object?>{'id': _targetId}),
          huiPlural(
            'import.elements.count',
            doc.elements.length,
            oneEnglish: '{count} element',
            otherEnglish: '{count} elements',
          ),
          huiPlural(
            'import.variants.count',
            doc.variants.length,
            oneEnglish: '{count} variant',
            otherEnglish: '{count} variants',
          ),
          doc.card == null
              ? huiText('no card (bare content)')
              : huiText('has a card'),
          huiPlural(
            'import.expression_errors.count',
            errors,
            oneEnglish: '{count} expression error',
            otherEnglish: '{count} expression errors',
          ),
        ],
      ),
      if (errors > 0)
        dom.p(classes: 'hui-dialog-note', <Widget>[
          Text(
            huiText(
              'Expression errors are shown for reference and do not '
              'block importing — the document still replaces the current '
              'one when you press Replace.',
            ),
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
    return dom.div(classes: 'hui-import-preview', <Widget>[
      HuiChips(
        labels: <String>[
          _glossDocumentKindLabel(doc),
          huiText('id {id}', <String, Object?>{'id': _targetId}),
          huiText('schema {version}', <String, Object?>{
            'version': doc.schemaVersion,
          }),
          huiText('revision {revision}', <String, Object?>{
            'revision': doc.revision,
          }),
          ..._documentFacts(doc),
          _errorCountLabel(errors),
          _warningCountLabel(warnings),
        ],
      ),
      _issueList(),
    ]);
  }

  List<String> _documentFacts(GlossDoc doc) => switch (doc) {
    final GlossHologramDoc hologram => <String>[
      _lineCountLabel(hologram.lines.length),
    ],
    final GlossAnimationDoc animation => <String>[
      _frameCountLabel(animation.frames.length),
      _animationModeLabel(animation.mode),
    ],
    final GlossScoreboardDoc scoreboard => <String>[
      _lineCountLabel(scoreboard.lines.length),
      scoreboard.primary ? huiText('primary') : huiText('not primary'),
    ],
    final GlossMotdDoc motd => <String>[
      huiPlural(
        'import.entries.count',
        motd.entries.length,
        oneEnglish: '{count} entry',
        otherEnglish: '{count} entries',
      ),
    ],
    final GlossEmojiDoc emoji => <String>[
      emoji.enabled ? huiText('enabled') : huiText('disabled'),
    ],
    final GlossBubbleStyleDoc bubble => <String>[
      huiPlural(
        'import.character_wrap.count',
        bubble.wordWrapChars,
        oneEnglish: '{count} character wrap',
        otherEnglish: '{count} character wrap',
      ),
    ],
    final GlossTablistDoc tablist => <String>[
      huiPlural(
        'import.name_formats.count',
        tablist.nameFormats.length,
        oneEnglish: '{count} name format',
        otherEnglish: '{count} name formats',
      ),
    ],
    final GlossRealDropSettingsDoc realDrops => <String>[
      huiText('{speed}x tumble speed', <String, Object?>{
        'speed': realDrops.motion.speedMultiplier.toStringAsFixed(2),
      }),
      huiPlural(
        'import.models_per_stack.count',
        realDrops.limits.maxVisualsPerStack,
        oneEnglish: '{count} model per stack',
        otherEnglish: '{count} models per stack',
      ),
    ],
    final GlossDamageIndicatorsDoc indicators => <String>[
      huiText('{rate}/s global cap', <String, Object?>{
        'rate': indicators.limits.maxPerSecond,
      }),
      huiText('{duration} ms lifetime', <String, Object?>{
        'duration': indicators.limits.lifetimeMs,
      }),
    ],
    _ => const <String>[],
  };

  String _glossDocumentKindLabel(GlossDoc doc) => switch (doc) {
    GlossHologramDoc() => huiText('hologram document'),
    GlossAnimationDoc() => huiText('animation document'),
    GlossScoreboardDoc() => huiText('scoreboard document'),
    GlossMotdDoc() => huiText('MOTD document'),
    GlossEmojiDoc() => huiText('emoji document'),
    GlossBubbleStyleDoc() => huiText('bubble-style document'),
    GlossTablistDoc() => huiText('tablist document'),
    GlossRealDropSettingsDoc() => huiText('real-drop settings document'),
    GlossDamageIndicatorsDoc() => huiText('damage-indicator settings document'),
    _ => huiText('runtime document'),
  };

  String _animationModeLabel(String mode) => switch (mode) {
    'ascend' => huiText('ascend'),
    'descend' => huiText('descend'),
    'ascend_descend' => huiText('ascend then descend'),
    'random' => huiText('random'),
    _ => mode,
  };

  String _lineCountLabel(int count) => huiPlural(
    'import.lines.count',
    count,
    oneEnglish: '{count} line',
    otherEnglish: '{count} lines',
  );

  String _frameCountLabel(int count) => huiPlural(
    'import.frames.count',
    count,
    oneEnglish: '{count} frame',
    otherEnglish: '{count} frames',
  );

  String _errorCountLabel(int count) => huiPlural(
    'import.errors.count',
    count,
    oneEnglish: '{count} error',
    otherEnglish: '{count} errors',
  );

  String _warningCountLabel(int count) => huiPlural(
    'import.warnings.count',
    count,
    oneEnglish: '{count} warning',
    otherEnglish: '{count} warnings',
  );

  Widget _issueList() {
    if (_issues.isEmpty) {
      return dom.p(classes: 'hui-dialog-note', <Widget>[
        Text(huiText('No issues found in the imported document.')),
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
          dom.span(<Widget>[
            Text(
              huiText("and {value} more…", <String, Object?>{
                'value': _issues.length - 12,
              }),
            ),
          ]),
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
