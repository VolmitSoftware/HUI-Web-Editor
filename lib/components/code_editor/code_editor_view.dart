/// Raw JSON view, two-way synced with the store.
///
/// Sync rules, in order of importance:
///   1. Invalid JSON never touches the document. The text stays exactly as
///      typed and an error strip explains why nothing was committed.
///   2. Valid JSON commits through `EditorStore.applyCode`, which pushes one
///      undo entry labelled `code edit`.
///   3. The textarea is only re-serialized when the document changed somewhere
///      else (canvas drag, inspector edit, undo). While the user is typing, the
///      text is left alone — the old editor re-stringified on every keystroke
///      and destroyed both formatting and caret position.
///
/// Rule 3 is implemented with a remount key: browsers ignore writes to a
/// textarea's child text node once the value is dirty, so an external change
/// bumps `_syncGeneration` and the element is rebuilt from scratch. That remount
/// is expensive enough (it drops the pane's scroll position) that external
/// changes arriving in a burst — a canvas drag fires one per pointermove — are
/// coalesced; see [_CodeEditorViewState._onStoreChanged].
///
/// Highlighting is a `<pre>` of coloured spans laid out underneath a
/// transparent textarea. Both carry identical font metrics and padding and the
/// pre mirrors the textarea's scroll, so the two stay glued together.
library;

import 'dart:async';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component, ListenableBuilder, ValueKey;

import '../../logic/validation.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'code_dom.dart';
import 'json_highlight.dart';

class CodeEditorView extends StatefulWidget {
  const CodeEditorView({required this.store, super.key});

  final EditorStore store;

  @override
  State<CodeEditorView> createState() => _CodeEditorViewState();
}

/// Quiet period an external change burst has to settle for before the textarea
/// is rebuilt. A canvas drag notifies on every pointermove; without this the
/// pane is torn down and re-created sixty times a second for the whole gesture.
const Duration huiCodeAdoptQuiet = Duration(milliseconds: 250);

class _CodeEditorViewState extends State<CodeEditorView> {
  static int _instances = 0;

  late final String _uid = 'hui-code-${_instances++}';
  String get _areaId => '$_uid-area';
  String get _highlightId => '$_uid-highlight';

  late String _text;
  late String _lastStoreJson;
  late List<JsonToken> _tokens;
  int _syncGeneration = 0;
  String? _error;

  /// True while `applyCode` runs, so the notification it fires does not get
  /// mistaken for an external edit and overwrite the text being typed.
  bool _committing = false;

  Timer? _adoptTimer;
  DateTime? _lastExternalAt;
  void Function()? _unbindScroll;
  int _boundGeneration = -1;
  bool _postFramePending = false;

  EditorStore get _store => component.store;

  @override
  void initState() {
    super.initState();
    _lastStoreJson = _store.exportJson();
    _setText(_lastStoreJson);
    _store.addListener(_onStoreChanged);
    _schedulePostFrame();
  }

  @override
  void didUpdateComponent(CodeEditorView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
      _adoptStoreText();
    }
  }

  @override
  void dispose() {
    _adoptTimer?.cancel();
    _adoptTimer = null;
    _unbindScroll?.call();
    _unbindScroll = null;
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Leading and trailing edge both fire: the first change of a burst lands
  /// immediately so the pane is never stale, and one more lands once the burst
  /// stops. Everything between is dropped.
  void _onStoreChanged() {
    if (!mounted || _committing) return;
    final DateTime now = DateTime.now();
    final DateTime? previous = _lastExternalAt;
    _lastExternalAt = now;
    if (previous != null && now.difference(previous) < huiCodeAdoptQuiet) {
      _adoptTimer?.cancel();
      _adoptTimer = Timer(huiCodeAdoptQuiet, _adoptIfChanged);
      return;
    }
    _adoptIfChanged();
  }

  void _adoptIfChanged() {
    _adoptTimer?.cancel();
    _adoptTimer = null;
    if (!mounted || _committing) return;
    if (_store.exportJson() == _lastStoreJson) return;
    setState(_adoptStoreText);
  }

  void _adoptStoreText() {
    _lastStoreJson = _store.exportJson();
    _setText(_lastStoreJson);
    _error = null;
    _syncGeneration++;
  }

  /// The token list is derived state; recomputing it in `build` would re-scan
  /// the whole document on every unrelated rebuild.
  void _setText(String value) {
    _text = value;
    _tokens = tokenizeJson(value);
  }

  void _onInput(String raw) {
    _committing = true;
    final bool applied = _store.applyCode(raw);
    _committing = false;
    // Adopt the post-commit snapshot so the notification that just fired is not
    // replayed as an external change on the next store event.
    _lastStoreJson = _store.exportJson();
    setState(() {
      _setText(raw);
      _error = applied ? null : _store.codeError;
    });
  }

  void _reformat() {
    setState(_adoptStoreText);
  }

  /// The textarea is re-created whenever [_syncGeneration] changes, taking the
  /// scroll listener with it, so the mirror is re-bound after every such frame.
  void _schedulePostFrame() {
    if (_postFramePending) return;
    _postFramePending = true;
    context.binding.addPostFrameCallback(() {
      _postFramePending = false;
      if (!mounted || _boundGeneration == _syncGeneration) return;
      _unbindScroll?.call();
      _unbindScroll = bindScrollMirror(_areaId, _highlightId);
      if (_unbindScroll != null) _boundGeneration = _syncGeneration;
    });
  }

  int get _lineCount {
    int lines = 1;
    for (int i = 0; i < _text.length; i++) {
      if (_text.codeUnitAt(i) == 10) lines++;
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    _schedulePostFrame();
    return dom.div(
      classes: 'hui-code',
      <Widget>[
        _toolbar(),
        if (_error != null) _errorStrip(_error!),
        _editor(),
        ListenableBuilder(
          listenable: _store,
          builder: (BuildContext inner) => _issueList(),
        ),
      ],
    );
  }

  Widget _toolbar() => dom.div(
        classes: 'hui-code-toolbar',
        <Widget>[
          dom.div(
            classes: 'hui-code-toolbar-info',
            <Widget>[
              const HuiEyebrow('menu json'),
              dom.span(
                classes: 'hui-code-stat',
                <Widget>[Text('$_lineCount lines · ${_text.length} chars')],
              ),
            ],
          ),
          dom.div(
            classes: 'hui-code-toolbar-tools',
            <Widget>[
              ArcaneTooltip(
                text: 'Re-indent from the document',
                child: Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.small,
                  onPressed: _reformat,
                  icon: ArcaneIcon.wandSparkles(size: IconSize.sm),
                  label: 'Format',
                  attributes: const <String, String>{
                    'aria-label': 'Reformat the JSON from the document',
                  },
                ),
              ),
            ],
          ),
        ],
      );

  Widget _errorStrip(String message) => dom.div(
        classes: 'hui-code-error',
        attributes: const <String, String>{'role': 'alert'},
        <Widget>[
          ArcaneIcon.circleAlert(size: IconSize.sm),
          dom.span(
            classes: 'hui-code-error-text',
            <Widget>[Text('$message — not applied, your text is untouched.')],
          ),
        ],
      );

  Widget _editor() => dom.div(
        classes: 'hui-code-body',
        <Widget>[
          dom.div(
            classes: 'hui-code-gutter',
            attributes: const <String, String>{'aria-hidden': 'true'},
            <Widget>[
              for (int line = 1; line <= _lineCount; line++)
                dom.span(classes: 'hui-code-line', <Widget>[Text('$line')]),
            ],
          ),
          // The wrapper is what stretches; the pre inside it is in normal flow
          // and therefore what gives the pair its height, and the textarea is
          // laid over it. Both must agree on font, padding and wrapping or the
          // colours slide off the glyphs.
          dom.div(
            classes: 'hui-code-input',
            styles: const dom.Styles(
              raw: <String, String>{
                'position': 'relative',
                'flex': '1 1 auto',
                'min-width': '0',
                'align-self': 'stretch',
              },
            ),
            <Widget>[
              _highlightLayer(),
              dom.textarea(
                <Widget>[Component.text(_text)],
                key: ValueKey<int>(_syncGeneration),
                id: _areaId,
                classes: 'hui-code-area',
                rows: _lineCount,
                onInput: _onInput,
                styles: const dom.Styles(
                  raw: <String, String>{
                    'position': 'absolute',
                    'top': '0',
                    'left': '0',
                    'width': '100%',
                    'height': '100%',
                    'color': 'transparent',
                    'caret-color': 'var(--hui-text)',
                    'background': 'transparent',
                  },
                ),
                attributes: const <String, String>{
                  'wrap': 'off',
                  'spellcheck': 'false',
                  'autocapitalize': 'off',
                  'autocomplete': 'off',
                  'autocorrect': 'off',
                  'aria-label': 'Menu JSON',
                },
              ),
            ],
          ),
        ],
      );

  /// Painted underneath the textarea. Hidden from assistive tech: the textarea
  /// already carries the same text and is the thing you can interact with.
  Widget _highlightLayer() => dom.pre(
        <Widget>[
          for (final JsonToken token in _tokens)
            if (token.kind == JsonTokenKind.plain)
              Component.text(token.text)
            else
              dom.span(
                styles: dom.Styles(
                  raw: <String, String>{'color': _tokenColor(token.kind)},
                ),
                <Widget>[Component.text(token.text)],
              ),
          // Keeps a final line box alive when the document ends on a newline,
          // so the pre never comes up one line shorter than the textarea.
          const Component.text('\u200B'),
        ],
        id: _highlightId,
        classes: 'hui-code-highlight',
        attributes: const <String, String>{'aria-hidden': 'true'},
        styles: const dom.Styles(
          raw: <String, String>{
            'margin': '0',
            // The top and left padding must match `.hui-code-area` exactly or
            // the colours slide off the glyphs; the extra at the bottom is
            // room for the textarea's own horizontal scrollbar, which would
            // otherwise eat the last line.
            'padding': '12px 16px 26px',
            'font': 'inherit',
            'line-height': 'inherit',
            'white-space': 'pre',
            'tab-size': '2',
            'overflow': 'hidden',
            'pointer-events': 'none',
            'color': 'var(--hui-text)',
          },
        ),
      );

  static String _tokenColor(JsonTokenKind kind) => switch (kind) {
        JsonTokenKind.key => 'var(--hui-accent)',
        JsonTokenKind.string => 'var(--hui-success, #2e7d55)',
        JsonTokenKind.number => 'var(--hui-info, #007acc)',
        JsonTokenKind.literal => 'var(--hui-warning, #a06022)',
        JsonTokenKind.punctuation => 'var(--hui-muted)',
        JsonTokenKind.plain => 'var(--hui-text)',
      };

  Widget _issueList() {
    final List<HuiIssue> issues = _store.issues;
    return dom.div(
      classes: 'hui-code-issues',
      <Widget>[
        dom.div(
          classes: 'hui-code-issues-head',
          <Widget>[
            HuiEyebrow(
              issues.isEmpty ? 'no issues' : 'issues (${issues.length})',
            ),
          ],
        ),
        if (issues.isEmpty)
          const dom.p(
            classes: 'hui-code-issues-empty',
            <Widget>[
              Text('This document matches everything the plugin expects.'),
            ],
          )
        else
          dom.ul(
            classes: 'hui-code-issues-list',
            <Widget>[
              for (final HuiIssue issue in issues)
                dom.li(
                  classes: classNames(<String?>[
                    'hui-code-issue',
                    switch (issue.severity) {
                      HuiSeverity.error => 'is-error',
                      HuiSeverity.warning => 'is-warning',
                      HuiSeverity.info => 'is-info',
                    },
                  ]),
                  <Widget>[
                    dom.code(
                      classes: 'hui-code-issue-path',
                      <Widget>[Text(issue.path)],
                    ),
                    dom.span(
                      classes: 'hui-code-issue-message',
                      <Widget>[Text(issue.message)],
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
