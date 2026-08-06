/// Import dialog: file picker, paste box, and a preview before anything is
/// replaced.
///
/// The old editor replaced the whole document from a native `alert()` with no
/// preview and no undo. Here the document is only touched when the user presses
/// Replace, the parse result is shown first, and the replacement is a single
/// undo step.
///
/// The pasted or picked JSON is auto-detected as either a HoloUI menu or a
/// container-preview document via [looksLikePreviewDoc] — the same detection
/// [EditorStore.importJson] itself runs, so the dialog's preview and the
/// actual replacement always agree on what they are looking at. A preview
/// document also runs [parseCheckPreviewDoc]: a syntax error in one of its
/// expression fields is shown, but — like every menu validation issue already
/// shown here — it never blocks Replace. Only JSON that does not parse at all
/// does.
library;

import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/preview_doc_validation.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/file_transfer.dart';
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
  HuiMenu? _parsedMenu;
  HuiPreviewDoc? _parsedPreview;
  List<HuiIssue> _issues = const <HuiIssue>[];
  bool _picking = false;

  /// Bumped whenever the text is replaced from code; the textarea remounts so
  /// the browser shows the new value instead of the user's dirty one.
  int _generation = 0;

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
    _parsedMenu = null;
    _parsedPreview = null;
    _issues = const <HuiIssue>[];
    _generation++;
  }

  void _parse(String raw) {
    _parseError = null;
    _parsedMenu = null;
    _parsedPreview = null;
    _issues = const <HuiIssue>[];
    if (raw.trim().isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      _parseError = 'That is not valid JSON.';
      return;
    }

    if (looksLikePreviewDoc(decoded)) {
      try {
        final HuiPreviewDoc doc = HuiPreviewDoc.fromJson(decoded);
        _parsedPreview = doc;
        _issues = parseCheckPreviewDoc(doc);
      } on HuiFormatException catch (e) {
        _parseError = '${e.message} (at ${e.path})';
      }
      return;
    }

    try {
      final HuiMenu menu = HuiMenu.fromJson(decoded);
      _parsedMenu = menu;
      _issues = validateHuiMenu(
        menu,
        knownImagePaths: _store.images?.paths,
        knownMaterials:
            _store.catalogs.loaded ? _store.catalogs.materialKeys : null,
        knownSounds: _store.catalogs.loaded ? _store.catalogs.soundKeys : null,
        customItems: _store.catalogs.customItems,
      );
    } on HuiFormatException catch (e) {
      _parseError = '${e.message} (at ${e.path})';
    }
  }

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

  bool get _hasParsed => _parsedMenu != null || _parsedPreview != null;

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

  Widget _body() => dom.div(
        classes: 'hui-dialog-body hui-stagger',
        <Widget>[
          const ArcaneAlert.warning(
            message: 'Importing replaces the document you are editing. It is a '
                'single undo step, so Ctrl+Z brings the old one back.',
          ),
          HuiDialogSection(
            title: 'From a file',
            description:
                'Dropping a .json file anywhere in the editor does the same '
                'thing. A menu or a container-preview document both work — '
                'the shape of the file decides which.',
            children: <Widget>[
              dom.div(
                classes: 'hui-dialog-actions',
                <Widget>[
                  Button(
                    variant: ButtonVariant.outline,
                    size: ButtonSize.small,
                    loading: _picking,
                    onPressed: _pickFile,
                    icon: ArcaneIcon.folderOpen(size: IconSize.sm),
                    label: 'Choose a .json file',
                  ),
                  if (_sourceName.isNotEmpty)
                    dom.span(
                      classes: 'hui-dialog-filename',
                      <Widget>[Text(_sourceName)],
                    ),
                ],
              ),
            ],
          ),
          HuiDialogSection(
            title: 'Or paste it',
            description: 'Anything the plugin accepts: single-value lists and '
                'missing booleans are read the same way HoloUI reads them.',
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
        ],
      );

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
    final HuiPreviewDoc? previewDoc = _parsedPreview;
    if (previewDoc != null) return _previewDocSummary(previewDoc);
    final HuiMenu? menu = _parsedMenu;
    if (menu != null) return _menuSummary(menu);
    return ArcaneEmptyState(
      title: 'Nothing to import yet',
      description: 'Choose a file or paste JSON above. Both a menu and a '
          'container-preview document are parsed as you type, and everything '
          'the plugin would complain about is listed here before anything is '
          'replaced.',
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

    return dom.div(
      classes: 'hui-import-preview',
      <Widget>[
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
      ],
    );
  }

  Widget _previewDocSummary(HuiPreviewDoc doc) {
    final int errors = _issues.length;
    return dom.div(
      classes: 'hui-import-preview',
      <Widget>[
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
          const dom.p(
            classes: 'hui-dialog-note',
            <Widget>[
              Text('Expression errors are shown for reference and do not '
                  'block importing — the document still replaces the current '
                  'one when you press Replace.'),
            ],
          ),
        _issueList(),
      ],
    );
  }

  Widget _issueList() {
    if (_issues.isEmpty) {
      return const dom.p(
        classes: 'hui-dialog-note',
        <Widget>[Text('No issues found in the imported document.')],
      );
    }
    return dom.ul(
      classes: 'hui-import-issues',
      <Widget>[
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
          dom.li(
            classes: 'hui-import-issue',
            <Widget>[
              dom.span(<Widget>[Text('and ${_issues.length - 12} more…')]),
            ],
          ),
      ],
    );
  }
}
