/// Raw JSON view: an explicit buffer over the document store.
///
/// The buffer is the whole design. Typing changes nothing but the text, and the
/// document only moves when the user says so — Ctrl/Cmd+S, or the Save button
/// in this pane's own toolbar. The old view committed on every keystroke, which
/// made `true` unwritable: the moment `f` replaced `t` the text parsed as
/// something else and the document took it.
///
/// Commit rules, in order of importance:
///   1. Nothing commits until Save. The pane shows whether the buffer is dirty
///      or clean, and a parse error is reported when Save is pressed, not
///      nagged on every keystroke — a muted hint in the toolbar is all a broken
///      buffer gets while it is being typed.
///   2. Invalid JSON never reaches the document. `EditorStore.applyCode`
///      refuses it and the text stays exactly as typed.
///   3. A valid Save commits through `applyCode`, which pushes one undo entry
///      labelled `code edit`, and leaves the user's own formatting alone.
///      Re-serializing on save would silently reflow a file the store preserves
///      byte for byte for menus; Format is the explicit way to ask for that.
///   4. The textarea is re-serialized only when the document changed somewhere
///      else (canvas drag, inspector edit, undo) AND the buffer is clean. A
///      dirty buffer is never overwritten: the incoming document is held to one
///      side and a notice offers the two honest choices — keep editing, in
///      which case a later Save wins, or reload and lose the unsaved text.
///   5. Leaving never discards. Switching document, switching view (the shell
///      unmounts this pane when the view is not Code or Split) or disposing
///      parks the dirty text in [HuiCodeDrafts] under the workspace document's
///      id, and coming back restores it with a notice saying so. A draft is
///      dropped only on a successful Save or an explicit Revert.
///
/// Rule 4's adoption is implemented with a remount key: browsers ignore writes
/// to a textarea's child text node once the value is dirty, so an external
/// change bumps `_syncGeneration` and the element is rebuilt from scratch. That
/// remount is expensive enough (a whole document's worth of DOM, and the caret
/// and selection go with it) that external changes arriving in a burst — a
/// canvas drag fires one per pointermove — are coalesced; see
/// [_CodeEditorViewState._onStoreChanged].
///
/// Highlighting is a `<pre>` of coloured spans laid out underneath a
/// transparent textarea. Both carry identical font metrics and padding, and
/// `.hui-code-input` is sized to the pre — as wide as the longest line and as
/// tall as the document — so the textarea over it covers every line and neither
/// layer can scroll on its own. All scrolling belongs to `.hui-code-body`,
/// which moves both layers and the gutter as one.
///
/// ## Completion
///
/// Ctrl+Space asks `json_caret.dart` where the caret is in JSON-path terms,
/// `logic/json_schema.dart` what the format allows there, and
/// `code_completion.dart` what accepting a candidate writes. All three are pure
/// and tested; this widget only moves text and paints a list. The popup owns
/// the arrows, Enter, Tab and Escape while it is open and lets every other key
/// through to the textarea, so typing filters the list instead of fighting it.
///
/// ## Hover
///
/// The transparent textarea sits ON TOP of the `<pre>`, so the coloured spans
/// never receive a pointer event and `:hover` on them is dead. Rather than
/// reorder the layers — which would cost the caret, the selection and every
/// keystroke — the hover is hit-tested from the textarea's own mousemove:
///
///   * every key span in the highlight layer carries `data-hui-key` with its
///     source offset;
///   * `huiCodeKeyBoxes` measures those spans once per document and returns
///     their real boxes relative to the pre's border box, which makes them
///     immune to scrolling;
///   * a mousemove converts its client point into that same space and asks
///     [huiCodeHoverHit] which box it is in.
///
/// Measured boxes rather than character arithmetic, because they come from the
/// browser's layout of the very glyphs on screen: a wide glyph, a ligature or a
/// fallback font cannot slide the answer onto the wrong key. The card itself
/// reuses the app's tooltip surface — the `gloss-tooltip-overlay-content`
/// classes from `11-tooltip-overlay.css` — rather than inventing a second
/// tooltip look. It cannot use the shared overlay's `data-gloss-tooltip-text`
/// trigger convention, because that script keys off `mouseover`, which fires
/// once when the pointer enters the textarea and never again as it moves from
/// key to key.
///
/// The one place this pane still does character arithmetic is the completion
/// popup's anchor, which needs a caret pixel and has no span to measure. The
/// font is monospace, so column times cell width is exact for the ASCII the
/// formats are written in; a wide glyph earlier on the same line shifts the
/// popup sideways and nothing else.
library;

import 'dart:async';
import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart'
    show Component, EventCallback, ListenableBuilder, ValueKey;

import '../../config/gloss_json_schema.dart';
import '../../logic/json_schema.dart';
import '../../model/json_codec.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../inspector/dom_bridge.dart';
import '../shell/key_listener.dart';
import '../shell/shell_keys.dart';
import 'code_completion.dart';
import 'code_dom.dart';
import 'code_editor_chrome.dart';
import 'code_drafts.dart';
import 'code_hover.dart';
import 'json_caret.dart';
import 'json_highlight.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class CodeEditorView extends StatefulWidget {
  const CodeEditorView({required this.store, this.drafts, super.key});

  final EditorStore store;

  /// Where unsaved text is parked across unmounts. Defaults to the shared
  /// store; injected in tests.
  final HuiCodeDrafts? drafts;

  @override
  State<CodeEditorView> createState() => _CodeEditorViewState();
}

/// Quiet period an external change burst has to settle for before the textarea
/// is rebuilt. A canvas drag notifies on every pointermove; without this the
/// pane is torn down and re-created sixty times a second for the whole gesture.
const Duration huiCodeAdoptQuiet = Duration(milliseconds: 250);

/// The highlight layer's padding, in px. `.hui-code-area` in
/// `05-panels-dialogs.css` must carry the same two numbers or the colours slide
/// off the glyphs; they are named here because the caret arithmetic measures
/// from them.
const int huiCodePadTop = 12;
const int huiCodePadLeft = 16;

/// Buffers past this are not syntax-hinted on every keystroke. Nothing the
/// editor ships comes close; the guard exists so a pasted monster cannot make
/// typing feel heavy.
const int huiCodeHintLimit = 400000;

class _CodeEditorViewState extends State<CodeEditorView> {
  late String _text;

  /// The text the buffer is clean against: what was last adopted from the
  /// document, or last committed to it.
  late String _baseText;

  /// The store serialization this pane has already seen, so its own commit is
  /// not replayed as somebody else's edit.
  late String _lastStoreJson;

  /// Workspace id of the document this buffer belongs to.
  String _documentId = '';

  late List<JsonSpan> _spans;
  int _syncGeneration = 0;

  /// Loud, and only ever set by an action the user took: a refused Save, or a
  /// Format that could not parse.
  String Function()? _actionError;

  /// Quiet, recomputed as the user types. Never blocks anything.
  String Function()? _syntaxHint;

  bool _saved = false;

  /// An external document held back because the buffer is dirty.
  String? _pendingExternal;

  /// True while the pane is showing text it recovered from a draft.
  bool _restoredDraft = false;

  /// True while `applyCode` runs, so the notification it fires does not get
  /// mistaken for an external edit and overwrite the text being typed.
  bool _committing = false;

  Timer? _adoptTimer;
  DateTime? _lastExternalAt;
  late String _renderedLocale;

  // --- completion ---
  bool _completionOpen = false;
  List<HuiCompletion> _completionItems = const <HuiCompletion>[];
  int _completionIndex = 0;
  JsonCaretContext _completionCaret = JsonCaretContext.none;
  double _completionX = 0;
  double _completionY = 0;

  // --- hover ---
  List<HuiCodeKeyBox> _keyBoxes = const <HuiCodeKeyBox>[];
  String? _keyBoxesFor;
  int? _hoverOffset;
  HuiCodeKeyDoc? _hoverDoc;
  double _hoverX = 0;
  double _hoverY = 0;

  late final int _seq = _nextSeq++;
  static int _nextSeq = 0;

  String get _areaId => 'hui-code-area-$_seq';

  String get _preId => 'hui-code-pre-$_seq';

  String get _measureId => 'hui-code-measure-$_seq';

  EditorStore get _store => component.store;

  HuiCodeDrafts get _drafts => component.drafts ?? HuiCodeDrafts.shared;

  bool get _dirty => _text != _baseText;

  GlossJsonObject? get _schema => glossJsonSchemaFor(_store.docKind.name);

  @override
  void initState() {
    super.initState();
    _renderedLocale = huiLocalizations.activeLocale;
    _bindDocument();
    _store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateComponent(CodeEditorView oldComponent) {
    super.didUpdateComponent(oldComponent);
    final String locale = huiLocalizations.activeLocale;
    if (_renderedLocale != locale) {
      _renderedLocale = locale;
      _closeCompletion();
      _clearHover();
    }
    if (!identical(oldComponent.store, component.store)) {
      oldComponent.store.removeListener(_onStoreChanged);
      component.store.addListener(_onStoreChanged);
      _parkDraft();
      _bindDocument();
    }
  }

  @override
  void dispose() {
    _adoptTimer?.cancel();
    _adoptTimer = null;
    _parkDraft();
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  // --- document binding -----------------------------------------------------

  /// Points the buffer at whatever document is active now, preferring that
  /// document's parked draft over the store's own serialization.
  void _bindDocument() {
    _documentId = _store.workspace.activeId ?? '';
    _lastStoreJson = _store.canTransferDocument ? _store.exportJson() : '';
    final String? draft = _documentId.isEmpty
        ? null
        : _drafts.peek(_documentId);
    final bool restore = draft != null && draft != _lastStoreJson;
    _setText(restore ? draft : _lastStoreJson);
    _baseText = _lastStoreJson;
    _restoredDraft = restore;
    _actionError = null;
    _syntaxHint = restore ? _hintFor(_text) : null;
    _saved = false;
    _pendingExternal = null;
    _closeCompletion();
    _clearHover();
    _syncGeneration++;
  }

  void _parkDraft() {
    if (_documentId.isEmpty) return;
    if (_dirty) {
      _drafts.park(_documentId, _text);
    } else {
      _drafts.drop(_documentId);
    }
  }

  /// Leading and trailing edge both fire: the first change of a burst lands
  /// immediately so the pane is never stale, and one more lands once the burst
  /// stops. Everything between is dropped.
  void _onStoreChanged() {
    if (!mounted || _committing) return;
    final String activeId = _store.workspace.activeId ?? '';
    if (activeId != _documentId) {
      _adoptTimer?.cancel();
      _adoptTimer = null;
      _parkDraft();
      setState(_bindDocument);
      return;
    }
    if (!_store.canTransferDocument) {
      _adoptTimer?.cancel();
      _adoptTimer = null;
      return;
    }
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
    if (!mounted || _committing || !_store.canTransferDocument) return;
    final String next = _store.exportJson();
    if (next == _lastStoreJson) return;
    if (_dirty) {
      // Rule 4: the unsaved text wins the screen, and the user is told what
      // happened rather than watching their typing vanish.
      setState(() {
        _lastStoreJson = next;
        _pendingExternal = next;
        _restoredDraft = false;
      });
      return;
    }
    setState(_adoptStoreText);
  }

  void _adoptStoreText() {
    if (!_store.canTransferDocument) return;
    _lastStoreJson = _store.exportJson();
    _setText(_lastStoreJson);
    _baseText = _lastStoreJson;
    _actionError = null;
    _syntaxHint = null;
    _pendingExternal = null;
    _restoredDraft = false;
    _saved = false;
    if (_documentId.isNotEmpty) _drafts.drop(_documentId);
    _closeCompletion();
    _clearHover();
    _syncGeneration++;
  }

  /// The span list is derived state; recomputing it in `build` would re-scan
  /// the whole document on every unrelated rebuild.
  void _setText(String value) {
    _text = value;
    _spans = jsonSpans(value);
    _keyBoxesFor = null;
  }

  // --- editing --------------------------------------------------------------

  void _onInput(String raw) {
    setState(() {
      _setText(raw);
      _actionError = null;
      _saved = false;
      _restoredDraft = false;
      _syntaxHint = _hintFor(raw);
      _clearHover();
    });
    if (_completionOpen) _refreshCompletion();
  }

  /// Passive syntax feedback. Never an alert, never a commit gate.
  ///
  /// The parser's own message is deliberately thrown away: on dart2js it is
  /// whatever `JSON.parse` threw, which is a paragraph of quoted source that
  /// says nothing useful about a buffer the user is still halfway through
  /// typing. The loud strip a refused Save raises still carries the real
  /// message, because by then the user has asked for it.
  String Function()? _hintFor(String text) {
    if (text.length > huiCodeHintLimit) return null;
    if (text.trim().isEmpty) return () => huiText('Empty buffer');
    try {
      jsonDecode(text);
      return null;
    } on FormatException catch (_) {
      return () => huiText('Not valid JSON yet');
    }
  }

  void _save() {
    if (!_store.canTransferDocument || !_dirty) return;
    _closeCompletion();
    _committing = true;
    final bool applied = _store.applyCode(_text);
    _committing = false;
    _lastStoreJson = _store.exportJson();
    setState(() {
      if (applied) {
        _baseText = _text;
        _actionError = null;
        _syntaxHint = null;
        _pendingExternal = null;
        _restoredDraft = false;
        _saved = true;
        if (_documentId.isNotEmpty) _drafts.drop(_documentId);
      } else {
        _saved = false;
        _actionError = () =>
            _store.codeError ?? huiText('That is not valid JSON.');
      }
    });
  }

  /// Throws the unsaved text away, on purpose and only when asked.
  void _revert() {
    setState(_adoptStoreText);
  }

  /// Re-indents the BUFFER, not the document: a Format that re-read the store
  /// would quietly discard unsaved edits, which is the whole thing this pane
  /// no longer does. The writer is the same one every model exports through,
  /// so a formatted buffer is byte-identical to what a save would produce.
  void _reformat() {
    final Object? decoded;
    try {
      decoded = jsonDecode(_text);
    } on FormatException catch (_) {
      setState(
        () =>
            _actionError = () =>
                huiText('Cannot format: the buffer is not valid JSON.'),
      );
      return;
    }
    final String formatted = huiWriteJson(decoded);
    setState(() {
      _setText(formatted);
      _actionError = null;
      _saved = false;
      _syntaxHint = null;
      _syncGeneration++;
    });
  }

  int get _lineCount {
    int lines = 1;
    for (int i = 0; i < _text.length; i++) {
      if (_text.codeUnitAt(i) == 10) lines++;
    }
    return lines;
  }

  // --- keyboard -------------------------------------------------------------

  /// One handler on the pane root; keydowns from the textarea bubble into it.
  ///
  /// Everything handled here is swallowed with `stopPropagation`, which is what
  /// keeps the shell's document-level binder from also running: `mod+S` there
  /// downloads the document, and inside this pane it has to mean Save. It is
  /// claimed even with nothing to save — a chord that exports on a clean buffer
  /// and commits on a dirty one would be worse than one that always means the
  /// same thing.
  void _onKeyDown(Object? event) {
    final String key = domEventKey(event);
    final ({bool ctrl, bool meta, bool shift, bool alt}) mods =
        huiCodeModifiers(event);
    final bool mod = mods.ctrl || mods.meta;

    if (_completionOpen) {
      switch (key) {
        case 'ArrowDown':
          _moveCompletion(1);
          return _swallow(event);
        case 'ArrowUp':
          _moveCompletion(-1);
          return _swallow(event);
        case 'Enter':
        case 'Tab':
          _acceptCompletion(_completionIndex);
          return _swallow(event);
        case 'Escape':
          setState(_closeCompletion);
          return _swallow(event);
      }
    }

    if (mod && !mods.alt && !mods.shift && key.toLowerCase() == 's') {
      _save();
      return _swallow(event);
    }
    if (mod && !mods.alt && (key == ' ' || key == 'Spacebar')) {
      _openCompletion();
      return _swallow(event);
    }
    if (key == 'Escape' && _hoverDoc != null) {
      setState(_clearHover);
      _swallow(event);
    }
  }

  void _swallow(Object? event) {
    domPreventDefault(event);
    domStopPropagation(event);
  }

  // --- completion -----------------------------------------------------------

  void _openCompletion() {
    final GlossJsonObject? root = _schema;
    if (root == null) {
      // The container-preview kind is the only editable one with no model.
      // A quiet line, not the red strip: the user asked for help and there is
      // none, which is not an error they made.
      setState(
        () => _syntaxHint = () => huiText('No completion model for this kind'),
      );
      return;
    }
    final (int, int)? selection = readTextSelection(_areaId);
    final int caret = selection?.$1 ?? _text.length;
    final JsonCaretContext context = jsonCaretContext(_text, caret);
    final List<HuiCompletion> items = huiCodeCompletions(
      root: root,
      caret: context,
    );
    if (items.isEmpty) {
      setState(() {
        _closeCompletion();
        _syntaxHint = () => huiText('Nothing to complete here');
      });
      return;
    }
    final ({double x, double y}) anchor = _caretPoint(context.replaceStart);
    setState(() {
      _completionOpen = true;
      _completionItems = items;
      _completionIndex = 0;
      _completionCaret = context;
      _completionX = anchor.x;
      _completionY = anchor.y;
      _clearHover();
    });
  }

  /// Re-runs the resolver against the text as it stands, so typing filters the
  /// list. An empty result closes the popup instead of leaving a dead box open.
  void _refreshCompletion() {
    final GlossJsonObject? root = _schema;
    if (root == null) return;
    final (int, int)? selection = readTextSelection(_areaId);
    final int caret = selection?.$1 ?? _text.length;
    final JsonCaretContext context = jsonCaretContext(_text, caret);
    final List<HuiCompletion> items = huiCodeCompletions(
      root: root,
      caret: context,
    );
    setState(() {
      if (items.isEmpty) {
        _closeCompletion();
        return;
      }
      _completionItems = items;
      _completionCaret = context;
      _completionIndex = _completionIndex.clamp(0, items.length - 1);
    });
  }

  void _moveCompletion(int delta) {
    if (_completionItems.isEmpty) return;
    final int count = _completionItems.length;
    setState(() {
      _completionIndex = (_completionIndex + delta + count) % count;
    });
  }

  void _acceptCompletion(int index) {
    if (index < 0 || index >= _completionItems.length) return;
    final HuiCompletion item = _completionItems[index];
    final HuiCompletionEdit edit = huiApplyCompletion(
      _text,
      _completionCaret,
      item,
    );
    // Written straight onto the element: jaspr renders the textarea's text as a
    // child node, which only feeds `defaultValue` once the field is user-dirty.
    writeTextValue(
      _areaId,
      edit.text,
      selectionStart: edit.caret,
      selectionEnd: edit.caret,
    );
    setState(() {
      _setText(edit.text);
      _closeCompletion();
      _saved = false;
      _restoredDraft = false;
      _syntaxHint = _hintFor(edit.text);
    });
  }

  void _closeCompletion() {
    _completionOpen = false;
    _completionItems = const <HuiCompletion>[];
    _completionIndex = 0;
    _completionCaret = JsonCaretContext.none;
  }

  /// Viewport point of the caret at [offset].
  ///
  /// Column arithmetic over a measured monospace cell; see the library comment
  /// for what that costs. Falls back to the pane's top-left when the measuring
  /// probe is not in the document yet.
  ({double x, double y}) _caretPoint(int offset) {
    final ({double left, double top, double width, double height})? pre =
        huiCodeRect(_preId);
    final ({double left, double top, double width, double height})? cell =
        huiCodeRect(_measureId);
    if (pre == null || cell == null || cell.width <= 0) {
      return (x: pre?.left ?? 0, y: pre?.top ?? 0);
    }
    final int safe = offset.clamp(0, _text.length);
    int line = 0;
    int lineStart = 0;
    for (int i = 0; i < safe; i++) {
      if (_text.codeUnitAt(i) == 10) {
        line++;
        lineStart = i + 1;
      }
    }
    final double column = (safe - lineStart).toDouble();
    return (
      x: pre.left + huiCodePadLeft + column * (cell.width / 10),
      y: pre.top + huiCodePadTop + (line + 1) * cell.height,
    );
  }

  // --- hover ----------------------------------------------------------------

  void _onPointerMove(Object? event) {
    if (_completionOpen) return;
    final ({double left, double top, double width, double height})? pre =
        huiCodeRect(_preId);
    if (pre == null) return;
    if (_keyBoxesFor != _text) {
      _keyBoxes = _readKeyBoxes();
      _keyBoxesFor = _text;
    }
    if (_keyBoxes.isEmpty) {
      if (_hoverOffset != null) setState(_clearHover);
      return;
    }
    final ({double x, double y}) point = huiCodePointerPoint(event);
    final HuiCodeKeyBox? box = huiCodeHoverBox(
      _keyBoxes,
      point.x - pre.left,
      point.y - pre.top,
    );
    if (box == null) {
      if (_hoverOffset != null) setState(_clearHover);
      return;
    }
    if (box.offset == _hoverOffset) return;
    final GlossJsonObject? root = _schema;
    if (root == null) return;
    final HuiCodeKeyDoc? doc = huiCodeKeyDoc(
      root: root,
      source: _text,
      offset: box.offset,
    );
    if (doc == null) {
      if (_hoverOffset != null) setState(_clearHover);
      return;
    }
    setState(() {
      _hoverOffset = box.offset;
      _hoverDoc = doc;
      _hoverX = pre.left + box.left;
      _hoverY = pre.top + box.bottom + 6;
    });
  }

  List<HuiCodeKeyBox> _readKeyBoxes() {
    final List<double> flat = huiCodeKeyBoxes(_preId);
    final List<HuiCodeKeyBox> boxes = <HuiCodeKeyBox>[];
    for (int i = 0; i + 4 < flat.length; i += 5) {
      boxes.add(
        HuiCodeKeyBox(
          offset: flat[i].toInt(),
          left: flat[i + 1],
          top: flat[i + 2],
          right: flat[i + 3],
          bottom: flat[i + 4],
        ),
      );
    }
    return boxes;
  }

  void _clearHover() {
    _hoverOffset = null;
    _hoverDoc = null;
  }

  void _onPointerLeave(Object? event) {
    if (_hoverOffset == null) return;
    setState(_clearHover);
  }

  /// A scroll moves both layers under a pointer that did not move, so every
  /// measured box and the caret anchor are stale the instant it happens.
  void _onScroll(Object? event) {
    if (_hoverOffset == null && !_completionOpen) return;
    setState(() {
      _clearHover();
      _closeCompletion();
    });
  }

  // --- render ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-code',
    events: <String, EventCallback>{'keydown': _onKeyDown},
    <Widget>[
      _toolbar(),
      if (_actionError != null) HuiCodeErrorStrip(_actionError!()),
      if (_pendingExternal != null) _externalNotice(),
      if (_restoredDraft) _draftNotice(),
      _editor(),
      if (_completionOpen)
        HuiCodeCompletionPopup(
          items: _completionItems,
          index: _completionIndex,
          x: _completionX,
          y: _completionY,
          onAccept: _acceptCompletion,
          onHover: (int index) {
            if (_completionIndex == index) return;
            setState(() => _completionIndex = index);
          },
        ),
      if (_hoverDoc != null)
        HuiCodeHoverCard(doc: _hoverDoc!, x: _hoverX, y: _hoverY),
      ListenableBuilder(
        listenable: _store,
        builder: (BuildContext inner) => HuiCodeIssueList(_store.issues),
      ),
    ],
  );

  Widget _toolbar() {
    final bool apple = isApplePlatform();
    final String saveKeys = shortcutLabel('mod+S', apple: apple);
    return dom.div(classes: 'hui-code-toolbar', <Widget>[
      dom.div(classes: 'hui-code-toolbar-info', <Widget>[
        // Every kind shares this view now, so the eyebrow names the open one
        // rather than claiming a scoreboard's JSON is a menu's.
        HuiEyebrow(
          huiText("{noun} JSON", <String, Object?>{
            'noun': _store.docType.noun,
          }),
        ),
        dom.span(classes: 'hui-code-stat', <Widget>[
          Text(
            huiText('{lines} · {characters}', <String, Object?>{
              'lines': huiPlural(
                'code_editor.line_count',
                _lineCount,
                oneEnglish: '{count} line',
                otherEnglish: '{count} lines',
              ),
              'characters': huiPlural(
                'code_editor.character_count',
                _text.length,
                oneEnglish: '{count} character',
                otherEnglish: '{count} characters',
              ),
            }),
          ),
        ]),
        HuiCodeStateChip(dirty: _dirty, saved: _saved),
      ]),
      dom.div(classes: 'hui-code-toolbar-tools', <Widget>[
        if (_syntaxHint != null)
          dom.span(
            classes: 'hui-code-syntax-hint',
            attributes: const <String, String>{'aria-live': 'polite'},
            <Widget>[Text(_syntaxHint!())],
          ),
        if (_dirty)
          ArcaneTooltip(
            text: huiText(
              'Throw the unsaved text away and re-read the document',
            ),
            child: Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.small,
              onPressed: _revert,
              icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
              label: huiText('Revert'),
              attributes: <String, String>{
                'aria-label': huiText('Discard the unsaved code edits'),
              },
            ),
          ),
        ArcaneTooltip(
          text: huiText('Re-indent this buffer'),
          child: Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.small,
            onPressed: _reformat,
            icon: ArcaneIcon.wand(size: IconSize.sm),
            label: huiText('Format'),
            attributes: <String, String>{
              'aria-label': huiText('Reformat the JSON in the buffer'),
            },
          ),
        ),
        dom.span(
          classes: classNames(<String?>[
            'hui-code-save',
            _dirty ? 'is-dirty' : null,
          ]),
          <Widget>[
            ArcaneTooltip(
              text: _dirty
                  ? huiText(
                      'Commit this buffer to the document ({keys})',
                      <String, Object?>{'keys': saveKeys},
                    )
                  : huiText('Nothing to save ({keys})', <String, Object?>{
                      'keys': saveKeys,
                    }),
              child: Button(
                variant: _dirty ? ButtonVariant.primary : ButtonVariant.ghost,
                size: ButtonSize.small,
                // Disabled rather than a no-op: a live control that reports
                // "Saved" without saving anything is a lie about what just
                // happened. The chord is disabled with it, in `_save`.
                disabled: !_dirty,
                onPressed: _save,
                icon: ArcaneIcon.save(size: IconSize.sm),
                label: huiText('Save'),
                attributes: <String, String>{
                  'aria-label': huiText('Save the JSON to the document'),
                },
              ),
            ),
          ],
        ),
      ]),
    ]);
  }

  Widget _externalNotice() => HuiCodeNotice(
    warning: true,
    message: huiText(
      'The document changed somewhere else while this buffer had unsaved '
      'edits. Your text is still here; saving it overwrites that change.',
    ),
    actions: <Widget>[
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.small,
        onPressed: () => setState(() => _pendingExternal = null),
        label: huiText('Keep editing'),
      ),
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.small,
        onPressed: _revert,
        label: huiText('Discard mine and reload'),
      ),
    ],
  );

  Widget _draftNotice() => HuiCodeNotice(
    message: huiText(
      'Unsaved code edits restored. They were kept when this pane closed '
      'and have not reached the document yet.',
    ),
    actions: <Widget>[
      Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.small,
        onPressed: () => setState(() => _restoredDraft = false),
        label: huiText('Got it'),
      ),
    ],
  );

  Widget _editor() => dom.div(
    classes: 'hui-code-body',
    events: <String, EventCallback>{'scroll': _onScroll},
    <Widget>[
      dom.div(
        classes: 'hui-code-gutter',
        attributes: const <String, String>{'aria-hidden': 'true'},
        <Widget>[
          for (int line = 1; line <= _lineCount; line++)
            dom.span(classes: 'hui-code-line', <Widget>[
              Text(huiText("{line}", <String, Object?>{'line': line})),
            ]),
        ],
      ),
      // The pre inside the wrapper is in normal flow and therefore what
      // gives the pair both its width and its height; the textarea is laid
      // over it at 100% x 100%. Both must agree on font, padding and
      // wrapping or the colours slide off the glyphs.
      dom.div(
        classes: 'hui-code-input',
        events: <String, EventCallback>{
          'mousemove': _onPointerMove,
          'mouseleave': _onPointerLeave,
        },
        <Widget>[
          _highlightLayer(),
          _measureProbe(),
          dom.textarea(
            <Widget>[Component.text(_text)],
            key: ValueKey<int>(_syncGeneration),
            classes: 'hui-code-area',
            rows: _lineCount,
            onInput: _onInput,
            id: _areaId,
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
            attributes: <String, String>{
              'wrap': 'off',
              'spellcheck': 'false',
              'autocapitalize': 'off',
              'autocomplete': 'off',
              'autocorrect': 'off',
              'aria-label': huiText("{noun} JSON", <String, Object?>{
                'noun': _store.docType.noun,
              }),
            },
          ),
        ],
      ),
    ],
  );

  /// Ten zeroes in the editor's own font, hidden and out of flow. Its box is
  /// one line high and ten cells wide, which is the whole of what the caret
  /// arithmetic needs and the only honest way to get it: the font stack resolves
  /// in the browser, not here.
  Widget _measureProbe() => dom.span(
    classes: 'hui-code-measure',
    attributes: <String, String>{'id': _measureId, 'aria-hidden': 'true'},
    const <Widget>[Text('0000000000')],
  );

  /// Painted underneath the textarea. Hidden from assistive tech: the textarea
  /// already carries the same text and is the thing you can interact with.
  ///
  /// Key spans carry `data-hui-key` with their source offset. That attribute is
  /// the hover's whole index: `huiCodeKeyBoxes` finds the spans by it and reads
  /// their measured boxes.
  Widget _highlightLayer() => dom.pre(
    <Widget>[
      for (final JsonSpan span in _spans)
        if (span.token.kind == JsonTokenKind.plain)
          Component.text(span.token.text)
        else
          dom.span(
            attributes: span.token.kind == JsonTokenKind.key
                ? <String, String>{'data-hui-key': '${span.start}'}
                : const <String, String>{},
            styles: dom.Styles(
              raw: <String, String>{'color': _tokenColor(span.token.kind)},
            ),
            <Widget>[Component.text(span.token.text)],
          ),
      // Keeps a final line box alive when the document ends on a newline,
      // so the pre never comes up one line shorter than the textarea.
      const Component.text('\u200B'),
    ],
    classes: 'hui-code-highlight',
    id: _preId,
    attributes: const <String, String>{'aria-hidden': 'true'},
    styles: const dom.Styles(
      raw: <String, String>{
        'margin': '0',
        // Must match `.hui-code-area` exactly or the colours slide off the
        // glyphs — and it is this padding that the wrapper, and through it
        // the textarea, is measured from.
        'padding': '${huiCodePadTop}px ${huiCodePadLeft}px',
        'font': 'inherit',
        'line-height': 'inherit',
        'white-space': 'pre',
        'tab-size': '2',
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
}
