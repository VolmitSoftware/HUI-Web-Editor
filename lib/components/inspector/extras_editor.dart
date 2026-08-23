/// Editor for the unknown keys the codec preserves.
///
/// `json_codec.dart:112-129` deep-copies every key Gloss does not recognise
/// and merges it back on export, which is what makes an import/export round
/// trip lossless. Until now the only way to see those keys was the code view.
///
/// The disclosure is hand-built rather than `ArcaneDisclosure`: that component
/// has no `on*` props at all, its open state is JS toggling `hidden`, and this
/// subtree rebuilds on every keystroke — which would revert it.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/json_value.dart';
import '../common/common.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ExtrasEditor extends StatefulWidget {
  const ExtrasEditor({
    required this.title,
    required this.extras,
    required this.onChanged,
    super.key,
  });

  /// Names the object the keys hang off — `Menu`, `Icon`, `Action`. Also the
  /// stem of the undo labels this editor commits.
  final String title;

  /// The live extras map. Insertion order is the export order, so edits keep it.
  final Map<String, dynamic> extras;

  final void Function(String label, Map<String, dynamic> next) onChanged;

  @override
  State<ExtrasEditor> createState() => _ExtrasEditorState();
}

class _ExtrasEditorState extends State<ExtrasEditor> {
  bool _open = false;

  /// Text the user is typing, per key. Held locally so an entry that does not
  /// parse yet stays on screen instead of being reverted by the next rebuild.
  final Map<String, String> _drafts = <String, String>{};
  final Map<String, JsonParseResult> _errors = <String, JsonParseResult>{};

  String _newKey = '';
  String Function()? _newKeyError;

  @override
  void didUpdateComponent(ExtrasEditor oldComponent) {
    super.didUpdateComponent(oldComponent);
    // Undo, redo and a document swap all rewrite extras behind us. Drop the
    // draft for any key whose committed value moved, and for keys that left.
    final Map<String, dynamic> next = component.extras;
    _drafts.removeWhere((String key, String draft) {
      if (!next.containsKey(key)) return true;
      final Object? was = oldComponent.extras[key];
      final Object? now = next[key];
      return formatJsonValue(was) != formatJsonValue(now);
    });
    _errors.removeWhere(
      (String key, JsonParseResult _) => !_drafts.containsKey(key),
    );
  }

  String _valueText(String key) =>
      _drafts[key] ?? formatJsonValue(component.extras[key]);

  void _commit(String label, Map<String, dynamic> next) =>
      component.onChanged('${component.title.toLowerCase()} $label', next);

  void _editValue(String key, String raw) {
    _drafts[key] = raw;
    final JsonParseResult parsed = parseJsonValue(raw);
    setState(() {
      if (parsed.ok) {
        _errors.remove(key);
      } else {
        _errors[key] = parsed;
      }
    });
    if (!parsed.ok) return;
    final Map<String, dynamic> next = Map<String, dynamic>.of(component.extras);
    next[key] = parsed.value;
    _commit('extra $key', next);
  }

  void _remove(String key) {
    _drafts.remove(key);
    _errors.remove(key);
    final Map<String, dynamic> next = Map<String, dynamic>.of(component.extras)
      ..remove(key);
    _commit('remove extra $key', next);
  }

  void _add() {
    final String key = _newKey.trim();
    if (key.isEmpty) {
      setState(() => _newKeyError = () => huiText('Give the key a name.'));
      return;
    }
    if (component.extras.containsKey(key)) {
      setState(
        () => _newKeyError = () =>
            huiText('{key} is already here.', <String, Object?>{'key': key}),
      );
      return;
    }
    setState(() {
      _newKey = '';
      _newKeyError = null;
    });
    final Map<String, dynamic> next = Map<String, dynamic>.of(component.extras);
    next[key] = '';
    _commit('add extra $key', next);
  }

  @override
  Widget build(BuildContext context) {
    final int count = component.extras.length;
    return dom.div(
      classes: classNames(<String?>[
        'hui-extras',
        _open ? 'is-open' : null,
        count == 0 ? 'is-empty' : null,
      ]),
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '8px',
          'min-width': '0',
        },
      ),
      <Widget>[_summary(count), if (_open) _body()],
    );
  }

  Widget _summary(int count) => Button(
    variant: ButtonVariant.ghost,
    size: ButtonSize.sm,
    fullWidth: true,
    onPressed: () => setState(() => _open = !_open),
    attributes: <String, String>{
      'aria-expanded': _open ? 'true' : 'false',
      'aria-label': component.title,
      // The legacy accordion binder claims every `button[aria-expanded]`
      // in a one-shot 100ms scan, then flips `aria-expanded` itself and
      // writes `display` onto the button's next sibling — this body, whose
      // visibility Dart owns. `data-arcane-interactive` is the binder's own
      // opt-out (accordion_scripts.dart:8), and unlike the CSS guard below
      // it also stops the attribute flip.
      'data-arcane-interactive': 'true',
    },
    icon: _open
        ? ArcaneIcon.chevronUp(size: IconSize.sm)
        : ArcaneIcon.chevronDown(size: IconSize.sm),
    child: dom.span(
      classes: 'hui-extras-summary',
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '6px',
          'min-width': '0',
        },
      ),
      <Widget>[
        Text(component.title),
        dom.span(classes: 'hui-count-chip', <Widget>[
          Text(huiText("{count}", <String, Object?>{'count': count})),
        ]),
      ],
    ),
  );

  Widget _body() => dom.div(
    classes: 'hui-extras-body',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '10px',
        'min-width': '0',
      },
    ),
    <Widget>[
      _note(),
      if (component.extras.isEmpty)
        _empty()
      else
        for (final String key in component.extras.keys.toList()) _row(key),
      const HuiDivider(),
      _addRow(),
    ],
  );

  /// The one thing a reader has to know before touching this section.
  Widget _note() => dom.p(
    classes: 'hui-extras-note',
    styles: const dom.Styles(
      raw: <String, String>{
        'margin': '0',
        'font-size': '0.72rem',
        'line-height': '1.45',
        'color': 'var(--muted-foreground)',
      },
    ),
    <Widget>[
      Text(
        huiText(
          'Gloss ignores keys it does not recognise, so nothing here changes '
          'anything in game. The editor keeps them and writes them back on '
          'export, which is why an imported file never loses what it arrived '
          'with.',
        ),
      ),
    ],
  );

  Widget _empty() => dom.p(
    classes: 'hui-extras-empty',
    styles: const dom.Styles(
      raw: <String, String>{
        'margin': '0',
        'font-size': '0.74rem',
        'color': 'var(--muted-foreground)',
      },
    ),
    <Widget>[Text(huiText('No extra keys on this object.'))],
  );

  Widget _row(String key) => HuiField(
    label: key,
    classes: 'hui-extras-row',
    error: _errors[key]?.error,
    help: huiText(
      'Bare text is a string; quote it to keep a literal like true or 7.',
    ),
    trailing: Button(
      variant: ButtonVariant.ghost,
      size: ButtonSize.iconSm,
      onPressed: () => _remove(key),
      attributes: <String, String>{
        'aria-label': huiText("Remove {key}", <String, Object?>{'key': key}),
      },
      child: ArcaneIcon.trash2(size: IconSize.sm),
    ),
    control: TextInput(
      value: _valueText(key),
      size: ComponentSize.sm,
      fullWidth: true,
      placeholder: huiText('value'),
      onInput: (String value) => _editValue(key, value),
      attributes: const <String, String>{
        'autocomplete': 'off',
        'spellcheck': 'false',
      },
    ),
  );

  Widget _addRow() => HuiField(
    label: huiText('Add a key'),
    error: _newKeyError?.call(),
    control: dom.div(
      classes: 'hui-extras-add',
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'grid',
          'grid-template-columns': 'minmax(0, 1fr) auto',
          'align-items': 'center',
          'gap': '8px',
          'min-width': '0',
        },
      ),
      <Widget>[
        TextInput(
          value: _newKey,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: huiText('myPluginKey'),
          onInput: (String value) {
            _newKey = value;
            if (_newKeyError != null) {
              setState(() => _newKeyError = null);
            }
          },
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: _add,
          child: Text(huiText('Add')),
        ),
      ],
    ),
  );
}
