/// The one control every expression-capable preview field uses: a text input
/// that stores a `num`/`bool` constant or an expression source string, shows a
/// live syntax error with a position caret while the draft does not parse, and
/// a simple hand-built autocomplete list sourced from the catalog, the
/// document's own `vars` and the current element's repeat scope — see
/// [previewSuggestExprTokens] for exactly when it fires.
///
/// Mirrors [ExtrasEditor]'s commit rule: a draft that fails to parse is held
/// locally and never written to the document (an editor keystroke should never
/// leave a document mid-edit worse off), so [component.onChanged] only ever
/// fires with a value [parsePreviewExpr] accepted. Variable-name problems
/// (unknown, reserved-namespace typo, unresolved provider namespace) are NOT
/// checked here — they are already computed centrally by
/// [validatePreviewDoc] and handed in as [issues], so this widget does not
/// duplicate that logic. The one thing only this widget can know is which
/// simulated category is currently previewing, which is why the "not
/// published by this category" nudge is computed locally from
/// [categoryVariableNames].
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;

import '../../logic/preview_doc_validation.dart';
import '../../logic/preview_expr.dart';
import '../../logic/validation.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

// previewSuggestExprTokens / previewTrailingExprToken live in
// preview_doc_validation.dart — DOM-free autocomplete-source logic, tested
// directly there rather than only through this widget's own rendering.

/// Which JSON shapes a bare (non-expression) draft is allowed to commit as.
/// The model pins this per field — `visible`/`framed` reject a JSON number on
/// decode, `text`/`title`/`accent` reject anything but a string — so getting
/// it wrong here does not just look untidy, it silently drops the value the
/// next time the document round-trips through the codec.
enum PreviewExprKind {
  /// `x`, `y`, `z`, `width`, `height`, `size`, `color`, `wellColor`, `index`,
  /// `background`, `repeat.count`: a bare number commits as a JSON number,
  /// anything else as an expression string.
  numeric,

  /// `visible`, `card.framed`: the bare words `true`/`false` commit as a JSON
  /// boolean, anything else as an expression string. Never a JSON number.
  boolean,

  /// `text`, `card.title`, `card.accent`: always a string, exactly as typed
  /// (or `null` for an empty draft). The format never accepts a JSON
  /// constant here at all — even a literal color has to be written as the
  /// expression `'#RRGGBB'`.
  string,
}

class PreviewExprField extends StatefulWidget {
  const PreviewExprField({
    required this.label,
    required this.raw,
    required this.onChanged,
    this.kind = PreviewExprKind.numeric,
    this.required = false,
    this.help,
    this.placeholder,
    this.trailing,
    this.issues = const <HuiIssue>[],
    this.declaredVars = const <String>{},
    this.scope = const <String>{},
    this.categoryVariableNames = const <String>[],
    super.key,
  });

  final String label;

  /// The field's current committed value: `num`, `bool`, `String` (an
  /// expression source), or `null` for absent (the compiler's own default
  /// applies). Which of these a bare draft may commit as is [kind].
  final Object? raw;

  final void Function(Object? next) onChanged;

  final PreviewExprKind kind;
  final bool required;
  final String? help;
  final String? placeholder;
  final Widget? trailing;

  /// Pre-filtered issues for this exact field path, straight from
  /// [validatePreviewDoc] via `EditorStore.issuesForPreviewElement` (or a
  /// `card.*`/`match.*` filter at the document level).
  final List<HuiIssue> issues;

  /// Names reachable as `vars.<name>` — offered by autocomplete, never
  /// validated here (the store already flags an unknown one).
  final Set<String> declaredVars;

  /// The active element's repeat variable, if any — offered by autocomplete
  /// the same way.
  final Set<String> scope;

  /// Every variable name the currently simulated category actually publishes.
  /// Empty means "unknown" (no live preview open), which skips the nudge
  /// entirely rather than flagging every cataloged name as unpublished.
  final List<String> categoryVariableNames;

  @override
  State<PreviewExprField> createState() => _PreviewExprFieldState();
}

class _PreviewExprFieldState extends State<PreviewExprField> {
  late String _text;

  /// The value this widget itself last committed, so an external change (undo,
  /// a code-view commit, another surface editing the same element) can be told
  /// apart from an echo of our own edit and only the former resyncs [_text].
  Object? _lastCommitted;

  String? _syntaxError;
  int _syntaxPosition = previewNoPosition;
  List<String> _categoryHints = const <String>[];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _lastCommitted = component.raw;
    _text = _format(component.raw);
  }

  @override
  void didUpdateComponent(PreviewExprField oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.raw == _lastCommitted) return;
    _lastCommitted = component.raw;
    _text = _format(component.raw);
    _syntaxError = null;
    _syntaxPosition = previewNoPosition;
    _categoryHints = const <String>[];
  }

  static String _format(Object? raw) {
    if (raw == null) return '';
    if (raw is bool) return raw ? 'true' : 'false';
    if (raw is num) return previewStringify(raw.toDouble());
    return raw as String;
  }

  Object? _encode(String trimmed) {
    if (trimmed.isEmpty) return null;
    switch (component.kind) {
      case PreviewExprKind.boolean:
        final String lower = trimmed.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
        return trimmed;
      case PreviewExprKind.numeric:
        return double.tryParse(trimmed) ?? trimmed;
      case PreviewExprKind.string:
        return trimmed;
    }
  }

  void _onInput(String raw) {
    setState(() {
      _text = raw;
      _showSuggestions = true;
      _revalidate();
    });
  }

  void _revalidate() {
    final String trimmed = _text.trim();
    if (trimmed.isEmpty) {
      _syntaxError = null;
      _syntaxPosition = previewNoPosition;
      _categoryHints = const <String>[];
      _commit(null);
      return;
    }
    final PExpr expr;
    try {
      expr = parsePreviewExpr(trimmed);
    } on PExprException catch (e) {
      // Held locally, never committed: a broken draft must not overwrite the
      // last value the document actually builds from.
      _syntaxError = e.message;
      _syntaxPosition = e.position;
      return;
    }
    _syntaxError = null;
    _syntaxPosition = previewNoPosition;
    _categoryHints = _computeCategoryHints(expr);
    _commit(_encode(trimmed));
  }

  List<String> _computeCategoryHints(PExpr expr) {
    final List<String> categoryNames = component.categoryVariableNames;
    if (categoryNames.isEmpty) return const <String>[];
    final Set<String> published = categoryNames.toSet();
    final Set<String> hints = <String>{};
    previewCollectVarRefs(expr, (String name) {
      if (previewFlatCatalog.contains(name) && !published.contains(name)) {
        hints.add(name);
      }
    });
    return hints.toList()..sort();
  }

  void _commit(Object? next) {
    _lastCommitted = next;
    component.onChanged(next);
  }

  void _onBlur() {
    // Delayed so a click on a suggestion (which blurs the input first) still
    // lands before the list unmounts.
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _showSuggestions = false);
    });
  }

  RegExpMatch? get _tokenMatch => previewTrailingExprToken.firstMatch(_text);

  List<String> _suggestions() => previewSuggestExprTokens(
    _text,
    declaredVars: component.declaredVars,
    scope: component.scope,
  );

  void _selectSuggestion(String suggestion) {
    final RegExpMatch? match = _tokenMatch;
    final String next = match == null
        ? '$_text$suggestion'
        : _text.substring(0, match.start) + suggestion;
    setState(() {
      _text = next;
      _showSuggestions = false;
      _revalidate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> suggestions = _showSuggestions
        ? _suggestions()
        : const <String>[];
    final List<HuiIssue> combined = <HuiIssue>[
      ...component.issues,
      for (final String name in _categoryHints)
        HuiIssue(
          severity: HuiSeverity.info,
          path: component.label,
          message:
              '$name is not published while previewing this category; '
              'it reads as unresolved there.',
        ),
    ];
    return HuiField(
      label: component.label,
      required: component.required,
      help: component.help,
      trailing: component.trailing,
      control: dom.div(
        styles: const dom.Styles(
          raw: <String, String>{'position': 'relative', 'min-width': '0'},
        ),
        <Widget>[
          TextInput(
            value: _text,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: component.placeholder,
            error: _syntaxError,
            onInput: _onInput,
            onBlur: _onBlur,
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          if (suggestions.isNotEmpty) _suggestionList(suggestions),
          if (_syntaxError != null) _errorBlock(),
          HuiInlineIssues(combined),
        ],
      ),
    );
  }

  Widget _errorBlock() => dom.div(
    classes: 'hui-expr-error',
    styles: const dom.Styles(
      raw: <String, String>{
        'margin-top': '4px',
        'font-size': '0.72rem',
        'color': 'var(--hui-danger, var(--destructive))',
      },
    ),
    <Widget>[
      Text(_syntaxError!),
      if (_syntaxPosition != previewNoPosition &&
          _syntaxPosition <= _text.length)
        dom.pre(
          styles: const dom.Styles(
            raw: <String, String>{
              'margin': '2px 0 0',
              'padding': '0',
              'font-family': 'var(--font-mono, ui-monospace, monospace)',
              'font-size': '0.7rem',
              'line-height': '1.2',
              'white-space': 'pre',
              'overflow-x': 'auto',
            },
          ),
          <Widget>[Component.text('${' ' * _syntaxPosition}^')],
        ),
    ],
  );

  Widget _suggestionList(List<String> suggestions) => dom.div(
    classes: 'hui-expr-suggestions',
    styles: const dom.Styles(
      raw: <String, String>{
        'position': 'absolute',
        'z-index': '30',
        'top': '100%',
        'left': '0',
        'right': '0',
        'margin-top': '2px',
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '1px',
        'padding': '4px',
        'border': '1px solid var(--hui-border)',
        'border-radius': 'var(--hui-radius)',
        'background': 'var(--hui-surface-raised)',
        'box-shadow': 'var(--hui-shadow-sm)',
        'max-height': '160px',
        'overflow-y': 'auto',
      },
    ),
    attributes: const <String, String>{'role': 'listbox'},
    <Widget>[
      for (final String suggestion in suggestions)
        dom.button(
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'block',
              'width': '100%',
              'padding': '4px 6px',
              'border': '0',
              'border-radius': '0',
              'background': 'transparent',
              'color': 'var(--hui-text)',
              'text-align': 'left',
              'font': 'inherit',
              'font-family': 'var(--font-mono, ui-monospace, monospace)',
              'font-size': '0.74rem',
              'cursor': 'pointer',
            },
          ),
          attributes: const <String, String>{'type': 'button'},
          events: <String, void Function(Object)>{
            'click': (Object _) => _selectSuggestion(suggestion),
          },
          <Widget>[Text(suggestion)],
        ),
    ],
  );
}
