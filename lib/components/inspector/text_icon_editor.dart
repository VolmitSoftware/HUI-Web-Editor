/// `text` icon editor: the multiline field, the formatting palette and the live
/// preview.
///
/// The palette splices tags around the current selection. Because jaspr renders
/// a textarea's value as a child text node — which the browser stops mirroring
/// once the field is user-dirty — every splice writes the DOM `value` property
/// directly and restores the caret before notifying the store.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/jaspr.dart' show Component, EventCallback;

import '../../logic/validation.dart';
import '../common/common.dart';
import 'dom_bridge.dart';
import 'inspector_widgets.dart';
import 'mc_text_preview.dart';

/// One formatting button. [close] null means "insert at the caret" rather than
/// "wrap the selection".
class _TagAction {
  const _TagAction({
    required this.label,
    required this.open,
    required this.hint,
    this.close,
  });

  final String label;
  final String open;
  final String? close;
  final String hint;
}

class TextIconEditor extends StatefulWidget {
  const TextIconEditor({
    required this.fieldId,
    required this.text,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    this.label = 'Text',
    super.key,
  });

  /// DOM id of the textarea. Must be unique per slot.
  final String fieldId;
  final String text;

  /// Called with a mutation label and the new text.
  final void Function(String label, String text) onChanged;
  final List<HuiIssue> issues;
  final String label;

  @override
  State<TextIconEditor> createState() => _TextIconEditorState();
}

class _TextIconEditorState extends State<TextIconEditor> {
  /// The last value this editor is known to have pushed into the DOM. When the
  /// document moves for another reason (undo, redo, the code view) the textarea
  /// is force-synced, because jaspr can only render the value as a child text
  /// node and the browser ignores that once the field is user-dirty.
  late String _known;

  @override
  void initState() {
    super.initState();
    _known = component.text;
  }

  @override
  void didUpdateComponent(TextIconEditor oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.fieldId != component.fieldId) {
      // Callers key this editor by field id, so the id only moves under a
      // reused state when one of them forgets. This runs before the DOM is
      // patched, so the new id does not exist yet and a write would be dropped:
      // adopt the value instead and let the field render it.
      _known = component.text;
      return;
    }
    if (component.text != _known) {
      _known = component.text;
      writeTextValue(component.fieldId, component.text, focus: false);
    }
  }

  String get _text => component.text;

  String get _fieldId => component.fieldId;

  void _push(String label, String next) {
    _known = next;
    component.onChanged(label, next);
  }

  static const List<_TagAction> _tags = <_TagAction>[
    _TagAction(
      label: 'Bold',
      open: '<bold>',
      close: '</bold>',
      hint: 'MiniMessage <bold>. The legacy code &l does the same thing.',
    ),
    _TagAction(
      label: 'Italic',
      open: '<italic>',
      close: '</italic>',
      hint: 'MiniMessage <italic>. Legacy &o.',
    ),
    _TagAction(
      label: 'Underlined',
      open: '<underlined>',
      close: '</underlined>',
      hint: 'MiniMessage <underlined>. Legacy &n.',
    ),
    _TagAction(
      label: 'Strikethrough',
      open: '<strikethrough>',
      close: '</strikethrough>',
      hint: 'MiniMessage <strikethrough>. Legacy &m.',
    ),
    _TagAction(
      label: 'Obfuscated',
      open: '<obfuscated>',
      close: '</obfuscated>',
      hint: 'Scrambling text. Legacy &k.',
    ),
    _TagAction(
      label: 'Gradient',
      open: '<gradient:#ffffff:#5599ff>',
      close: '</gradient>',
      hint:
          'Interpolates colour across the wrapped characters. Add more '
          'colours by appending :#rrggbb.',
    ),
    _TagAction(
      label: 'Reset',
      open: '<reset>',
      hint: 'Drops all colour and formatting from this point on. Legacy &r.',
    ),
  ];

  /// Splices [open]/[close] around the current selection, or inserts [open] at
  /// the caret when [close] is null.
  void _apply(_TagAction tag) {
    final String text = _text;
    final (int, int)? selection = readTextSelection(_fieldId);
    final int length = text.length;
    final int start = (selection?.$1 ?? length).clamp(0, length);
    final int end = (selection?.$2 ?? start).clamp(start, length);
    final String selected = text.substring(start, end);
    final String close = tag.close ?? '';
    final String replacement = '${tag.open}$selected$close';
    final String next = text.replaceRange(start, end, replacement);
    // Caret lands inside the wrap so the selection survives, or right after the
    // tag when nothing was selected.
    final int caretStart = start + tag.open.length;
    final int caretEnd = caretStart + selected.length;
    writeTextValue(
      _fieldId,
      next,
      selectionStart: caretStart,
      selectionEnd: caretEnd,
    );
    _push('text ${tag.label.toLowerCase()}', next);
  }

  /// Colour tags are inserted, never wrapped: MiniMessage colours run until the
  /// next colour tag or a reset, which is how authors expect them to behave.
  void _insertColor(String hex) {
    final String normalized = _normalizeHex(hex);
    if (normalized.isEmpty) return;
    final String text = _text;
    final (int, int)? selection = readTextSelection(_fieldId);
    final int length = text.length;
    final int start = (selection?.$1 ?? length).clamp(0, length);
    final String tag = '<$normalized>';
    final String next = text.replaceRange(start, start, tag);
    final int caret = start + tag.length;
    writeTextValue(_fieldId, next, selectionStart: caret, selectionEnd: caret);
    _push('text colour', next);
  }

  static String _normalizeHex(String raw) {
    final String trimmed = raw.trim().toLowerCase();
    final String body = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;
    if (body.length != 6) return '';
    for (int i = 0; i < body.length; i++) {
      if (!'0123456789abcdef'.contains(body[i])) return '';
    }
    return '#$body';
  }

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-text-editor', <Widget>[
        HuiField(
          label: component.label,
          help: 'One stacked line per line break; each is parsed on its own.',
          control: dom.div(classes: 'hui-text-editor-control', <Widget>[
            _toolbar(),
            TextArea(
              id: _fieldId,
              value: _text,
              rows: 4,
              fullWidth: true,
              resize: TextAreaResize.vertical,
              placeholder: '&6&lShop\n&7Click to browse',
              onInput: (String raw) => _push('text', raw),
            ),
            HuiInlineIssues(component.issues),
          ]),
        ),
        dom.div(classes: 'hui-text-preview-block', <Widget>[
          const HuiEyebrow('In-game preview'),
          McTextPreview(raw: _text),
        ]),
        const HuiMore(
          summary: 'Legacy formatting codes',
          children: <Widget>[
            HuiNote(
              'Legacy codes work too: &0-&f for colour, &k obfuscated, '
              '&l bold, &m strikethrough, &n underlined, &o italic, '
              '&r reset.',
            ),
          ],
        ),
      ]);

  Widget _toolbar() => dom.div(classes: 'hui-text-toolbar', <Widget>[
    _colorControl(),
    for (final _TagAction tag in _tags)
      ArcaneTooltip(
        text: tag.hint,
        child: dom.button(
          classes: 'hui-text-tag',
          attributes: <String, String>{
            'type': 'button',
            'aria-label': 'Insert ${tag.label}',
          },
          events: <String, EventCallback>{'click': (_) => _apply(tag)},
          <Widget>[Text(tag.label)],
        ),
      ),
  ]);

  Widget _colorControl() => ArcaneTooltip(
    text:
        'Insert a <#rrggbb> colour tag at the caret. Everything after it '
        'takes that colour until the next colour tag or <reset>.',
    child: dom.label(classes: 'hui-text-color', <Widget>[
      ArcaneIcon.palette(size: IconSize.sm),
      Component.element(
        tag: 'input',
        classes: 'hui-text-color-input',
        attributes: const <String, String>{
          'type': 'color',
          'value': '#ffaa00',
          'aria-label': 'Insert a colour tag',
        },
        // `event` is jaspr's `EventCallback` argument; its type is left to
        // inference so this file never imports `package:web`.
        events: <String, EventCallback>{
          'input': (event) => _insertColor(domInputValue(event.target)),
        },
      ),
    ]),
  );
}
