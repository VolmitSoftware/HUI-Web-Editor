/// The editing affordance for one real-drops expression: a monospace input
/// that parses what is in it on every keystroke and puts the parser's own
/// complaint under the caret that caused it.
///
/// Deliberately not [PreviewExprField]. That widget holds a draft that does not
/// parse and never commits it, which is right for a container preview: a broken
/// expression there degrades one element and the document still loads. A
/// real-drops expression is not like that — a parse error refuses the *whole*
/// document at load (`RealDropSettingsDoc.Script`'s constructor calls
/// `RealDropScriptPlan.validate` before anything else), so the editor's job is
/// to keep the author's text and say loudly that the file will not load, not to
/// quietly discard the keystroke. So this commits every edit, and the same text
/// reaches `validateRealDropSettingsDoc`, which raises the server's own
/// sentence into the validation panel.
///
/// The inline error is the parse error only. Everything that needs the rest of
/// the document to know — an unknown variable, a `vars` name that shadows a
/// built-in, a field that type-checks to the wrong thing — is computed once
/// centrally in `real_drop_script.dart` and arrives here as [issues], so this
/// widget never has a second opinion about the same expression.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;

import '../../logic/preview_expr.dart';
import '../../logic/validation.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

/// Monospace, so a caret column in the error block lines up with the character
/// it points at. Kept in step with the `.hui-drop-expr input` rule in
/// `04-inspector.css`, which puts the same face on the input itself.
const String realDropExprFont = 'var(--font-mono, ui-monospace, monospace)';

class RealDropExprField extends StatefulWidget {
  const RealDropExprField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.docKey,
    this.placeholder,
    this.neutral,
    this.issues = const <HuiIssue>[],
    this.bare = false,
    this.trailing,
    super.key,
  });

  final String label;

  /// The expression source as the document carries it.
  final String value;

  /// Fires with the trimmed source on every keystroke, broken or not.
  final void Function(String next) onChanged;

  /// Key into the schema-derived help map, rendered as the row's popover.
  final String? docKey;

  final String? placeholder;

  /// The source an empty field falls back to, shown as the resettable default
  /// — `0` for offset and rotation, `1` for scale, `true` for visible.
  final String? neutral;

  /// Pre-filtered issues for this field's JSON path.
  final List<HuiIssue> issues;

  /// Renders the input alone, with no label row around it. The `vars` list
  /// uses it: the name field beside it already says which expression this is,
  /// and a second label there would be a column of blanks.
  final bool bare;

  final Widget? trailing;

  @override
  State<RealDropExprField> createState() => _RealDropExprFieldState();
}

class _RealDropExprFieldState extends State<RealDropExprField> {
  late String _text = component.value;

  /// The value this widget itself last committed, so an external change — undo,
  /// a code-view commit, the other pane editing the same field — resyncs the
  /// input while an echo of our own keystroke does not.
  late String _lastCommitted = component.value;

  String? _syntaxError;
  int _syntaxPosition = previewNoPosition;

  @override
  void initState() {
    super.initState();
    _revalidate(commit: false);
  }

  @override
  void didUpdateComponent(RealDropExprField oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.value == _lastCommitted) return;
    _lastCommitted = component.value;
    _text = component.value;
    _revalidate(commit: false);
  }

  void _onInput(String raw) {
    setState(() {
      _text = raw;
      _revalidate(commit: true);
    });
  }

  void _revalidate({required bool commit}) {
    final String trimmed = _text.trim();
    if (trimmed.isEmpty) {
      // Blank is not a parse error: the server reads a blank axis as the
      // block's neutral value, and a blank glow as the feature switched off.
      _syntaxError = null;
      _syntaxPosition = previewNoPosition;
    } else {
      try {
        parsePreviewExpr(trimmed);
        _syntaxError = null;
        _syntaxPosition = previewNoPosition;
      } on PExprException catch (e) {
        _syntaxError = e.position == previewNoPosition
            ? e.message
            : '${e.message} at position ${e.position}';
        _syntaxPosition = e.position;
      }
    }
    if (!commit) return;
    _lastCommitted = trimmed;
    component.onChanged(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final String? docKey = component.docKey;
    final Widget control = _control();
    if (component.bare) return control;
    return HuiField(
      label: component.label,
      defaultValue: component.neutral,
      onReset: component.neutral == null || _text == component.neutral
          ? null
          : () => _onInput(component.neutral!),
      trailing:
          component.trailing ?? (docKey == null ? null : HuiFieldHelp(docKey)),
      control: control,
    );
  }

  Widget _control() => dom.div(classes: 'hui-drop-expr', <Widget>[
    // The monospace face is a stylesheet rule on the wrapper rather than an
    // inline style: the framework's input takes typed style data, not raw
    // CSS, and the caret block below only lines up if the two share a font.
    TextInput(
      value: _text,
      size: ComponentSize.sm,
      fullWidth: true,
      placeholder: component.placeholder,
      error: _syntaxError,
      onInput: _onInput,
      attributes: const <String, String>{
        'autocomplete': 'off',
        'autocapitalize': 'off',
        'spellcheck': 'false',
      },
    ),
    if (_syntaxError != null) _errorBlock(),
    HuiInlineIssues(component.issues),
  ]);

  /// The parser's message and a caret under the character it stopped at. The
  /// caret is the whole reason the input is monospace.
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
              'font-family': realDropExprFont,
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
}
