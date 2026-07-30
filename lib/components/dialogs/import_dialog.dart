/// Import dialog: file picker, paste box, and a preview before anything is
/// replaced.
///
/// The old editor replaced the whole document from a native `alert()` with no
/// preview and no undo. Here the document is only touched when the user presses
/// Replace, the parse result is shown first, and the replacement is a single
/// undo step.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
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
  HuiMenu? _parsed;
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
    _parsed = null;
    _issues = const <HuiIssue>[];
    _generation++;
  }

  void _parse(String raw) {
    if (raw.trim().isEmpty) {
      _parseError = null;
      _parsed = null;
      _issues = const <HuiIssue>[];
      return;
    }
    try {
      final HuiMenu menu = decodeHuiMenu(raw);
      _parsed = menu;
      _parseError = null;
      _issues = validateHuiMenu(
        menu,
        knownImagePaths: _store.images?.paths,
        knownMaterials:
            _store.catalogs.loaded ? _store.catalogs.materialKeys : null,
        knownSounds: _store.catalogs.loaded ? _store.catalogs.soundKeys : null,
      );
    } on HuiFormatException catch (e) {
      _parsed = null;
      _issues = const <HuiIssue>[];
      _parseError = '${e.message} (at ${e.path})';
    } catch (_) {
      _parsed = null;
      _issues = const <HuiIssue>[];
      _parseError = 'That is not valid JSON.';
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

  void _replace() {
    if (_parsed == null) return;
    final String name = _sourceName.isEmpty ? _store.menuId : _sourceName;
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
        title: 'Import menu JSON',
        maxWidth: 720,
        actions: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            onPressed: component.onClose,
            label: 'Cancel',
          ),
          Button(
            variant: ButtonVariant.primary,
            disabled: _parsed == null,
            onPressed: _parsed == null ? null : _replace,
            icon: ArcaneIcon.upload(size: IconSize.sm),
            label: 'Replace document',
          ),
        ],
        children: <Widget>[_body()],
      );

  Widget _body() => dom.div(
        classes: 'hui-dialog-body',
        <Widget>[
          const ArcaneAlert.warning(
            message: 'Importing replaces the document you are editing. It is a '
                'single undo step, so Ctrl+Z brings the old menu back.',
          ),
          HuiDialogSection(
            title: 'From a file',
            description:
                'Dropping a .json file anywhere in the editor does the same '
                'thing.',
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
    final String? error = _parseError;
    if (error != null) {
      return ArcaneAlert.error(
        title: 'Could not read that menu',
        message: error,
      );
    }
    final HuiMenu? menu = _parsed;
    if (menu == null) {
      return const dom.p(
        classes: 'hui-dialog-note',
        <Widget>[
          Text('Choose a file or paste JSON to see what will be imported.'),
        ],
      );
    }

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
        if (_issues.isEmpty)
          const dom.p(
            classes: 'hui-dialog-note',
            <Widget>[Text('No issues found in the imported menu.')],
          )
        else
          dom.ul(
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
                    dom.span(
                      <Widget>[Text('and ${_issues.length - 12} more…')],
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
