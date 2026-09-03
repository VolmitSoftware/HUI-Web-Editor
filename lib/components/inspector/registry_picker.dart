/// Searchable registry-key picker shared by the item icon and the sound action.
///
/// DELIBERATE DEVIATION from the brief's "use `ArcaneCombobox`": that widget
/// keeps its filter query in private state and renders every option it is
/// given. The shipped catalogues hold 1691 materials (1151 of them carrying a
/// base64 sprite) and 1968 sounds, so handing it the full list would mount
/// thousands of nodes and megabytes of decoded data URIs on open. This picker
/// owns the query, so it can search the whole catalogue while only ever
/// rendering [maxResults] rows. The free-text field is always present and is
/// the source of truth, which also covers keys the catalogue does not know.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show EventCallback;

import '../common/common.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// One row in the browse list. [texture] is a data URI or null, [detail] a
/// muted second line (a display name, the owning plugin, ...).
class RegistryOption {
  const RegistryOption(this.key, [this.texture, this.detail]);

  final String key;
  final String? texture;
  final String? detail;
}

class RegistryPicker extends StatefulWidget {
  const RegistryPicker({
    required this.value,
    required this.onChanged,
    required this.search,
    this.textureFor,
    this.placeholder,
    this.browseLabel,
    this.searchPlaceholder,
    this.emptyMessage,
    this.catalogAvailable = true,
    this.maxResults = 60,
    this.showThumbnail = true,
    this.lowercase = true,
    super.key,
  });

  /// The raw registry key. Trimmed, and lowercased unless [lowercase] is off.
  final String value;
  final void Function(String value) onChanged;

  /// Catalogue query. Called with the browse query and [maxResults].
  final List<RegistryOption> Function(String query, int limit) search;

  /// Sprite for the current value, when the catalogue has one.
  final String? Function(String key)? textureFor;
  final String? placeholder;
  final String? browseLabel;
  final String? searchPlaceholder;
  final String? emptyMessage;

  /// False while the catalogue assets are missing: the browse button hides and
  /// the field degrades to plain free text.
  final bool catalogAvailable;
  final int maxResults;
  final bool showThumbnail;

  /// Vanilla registry keys must be lowercase or they resolve to null. Custom
  /// item ids must not be touched: several providers use case-sensitive maps
  /// and MMOItems ids are conventionally uppercase.
  final bool lowercase;

  @override
  State<RegistryPicker> createState() => _RegistryPickerState();
}

class _RegistryPickerState extends State<RegistryPicker> {
  bool _browsing = false;
  String _query = '';

  void _pick(String key) {
    setState(() {
      _browsing = false;
      _query = '';
    });
    component.onChanged(key);
  }

  Widget? _thumbnail() {
    if (!component.showThumbnail) return null;
    final String? texture = component.textureFor?.call(component.value);
    if (texture == null) return null;
    return dom.img(
      src: texture,
      alt: '',
      classes: 'hui-registry-thumb',
      styles: const dom.Styles(
        raw: <String, String>{
          'width': '18px',
          'height': '18px',
          'image-rendering': 'pixelated',
          'display': 'block',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String browseLabel =
        component.browseLabel ?? huiText('Browse catalog');
    final String searchPlaceholder =
        component.searchPlaceholder ?? huiText('Search catalog');
    final String emptyMessage =
        component.emptyMessage ?? huiText('No matches in the shipped catalog.');
    final List<RegistryOption> results = _browsing
        ? component.search(_query, component.maxResults)
        : const <RegistryOption>[];
    return dom.div(
      classes: classNames(<String?>[
        'hui-registry-picker',
        _browsing ? 'is-browsing' : null,
      ]),
      <Widget>[
        dom.div(
          classes: 'hui-registry-field',
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'flex',
              'align-items': 'center',
              'gap': '6px',
              'min-width': '0',
            },
          ),
          <Widget>[
            dom.div(
              styles: const dom.Styles(
                raw: <String, String>{'flex': '1 1 auto', 'min-width': '0'},
              ),
              <Widget>[
                TextInput(
                  value: component.value,
                  size: ComponentSize.sm,
                  fullWidth: true,
                  placeholder: component.placeholder,
                  prefix: _thumbnail(),
                  onInput: (String raw) => component.onChanged(
                    component.lowercase ? raw.trim().toLowerCase() : raw.trim(),
                  ),
                  attributes: const <String, String>{
                    'autocomplete': 'off',
                    'autocapitalize': 'off',
                    'spellcheck': 'false',
                    'dir': 'ltr',
                  },
                ),
              ],
            ),
            if (component.catalogAvailable)
              Button(
                variant: _browsing
                    ? ButtonVariant.secondary
                    : ButtonVariant.outline,
                size: ButtonSize.sm,
                onPressed: () => setState(() {
                  _browsing = !_browsing;
                  _query = '';
                }),
                attributes: <String, String>{
                  'aria-label': browseLabel,
                  'aria-expanded': _browsing ? 'true' : 'false',
                  // Opt out of the legacy accordion binder, which claims every
                  // `button[aria-expanded]` and would flip the attribute Dart
                  // owns (accordion_scripts.dart:8).
                  'data-arcane-interactive': 'true',
                },
                label: browseLabel,
              ),
          ],
        ),
        if (_browsing)
          dom.div(classes: 'hui-registry-browser', <Widget>[
            TextInput(
              value: _query,
              size: ComponentSize.sm,
              fullWidth: true,
              placeholder: searchPlaceholder,
              onInput: (String raw) => setState(() => _query = raw),
              attributes: const <String, String>{
                'autocomplete': 'off',
                'spellcheck': 'false',
              },
            ),
            if (results.isEmpty)
              dom.p(classes: 'hui-registry-empty', <Widget>[Text(emptyMessage)])
            else
              dom.div(classes: 'hui-registry-results', <Widget>[
                for (final RegistryOption option in results) _resultRow(option),
              ]),
            if (results.length >= component.maxResults)
              dom.p(classes: 'hui-registry-more', <Widget>[
                Text(
                  huiText(
                    "Showing the first {maxResults} matches. Keep typing to narrow it down.",
                    <String, Object?>{'maxResults': component.maxResults},
                  ),
                ),
              ]),
          ]),
      ],
    );
  }

  Widget _resultRow(RegistryOption option) {
    final bool selected = option.key == component.value;
    return dom.button(
      classes: classNames(<String?>[
        'hui-registry-result',
        selected ? 'is-selected' : null,
      ]),
      attributes: <String, String>{
        'type': 'button',
        'aria-label': option.key,
        if (selected) 'aria-current': 'true',
      },
      // The callback parameter is jaspr's `EventCallback`, whose argument type
      // comes from `package:web`; it is left to inference so this file never
      // imports `package:web` (which would break off-web style extraction).
      events: <String, EventCallback>{'click': (_) => _pick(option.key)},
      <Widget>[
        if (option.texture != null)
          dom.img(
            src: option.texture!,
            alt: '',
            classes: 'hui-registry-result-icon',
            styles: const dom.Styles(
              raw: <String, String>{
                'width': '18px',
                'height': '18px',
                'image-rendering': 'pixelated',
                'flex': '0 0 auto',
              },
            ),
          )
        else
          const dom.span(
            classes: 'hui-registry-result-icon is-blank',
            <Widget>[],
          ),
        dom.span(classes: 'hui-registry-result-text', <Widget>[
          dom.span(classes: 'hui-registry-result-key', <Widget>[
            Text(option.key),
          ]),
          if (option.detail != null)
            dom.span(classes: 'hui-registry-result-detail', <Widget>[
              Text(option.detail!),
            ]),
        ]),
      ],
    );
  }
}
