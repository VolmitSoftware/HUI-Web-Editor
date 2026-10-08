library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/gloss_channel.dart';
import '../../model/json_codec.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class ChannelFieldsEditor extends StatelessWidget {
  const ChannelFieldsEditor({
    required this.value,
    required this.onChanged,
    this.fallback = const <String, Object?>{},
    this.inherited = false,
    this.mentions = true,
    super.key,
  });
  final Map<String, Object?> value;
  final Map<String, Object?> fallback;
  final bool inherited;
  final bool mentions;
  final void Function(Map<String, Object?>) onChanged;

  void _set(String key, Object? next) =>
      onChanged(<String, Object?>{...value, key: next});
  void _remove(String key) =>
      onChanged(Map<String, Object?>.of(value)..remove(key));
  Map<String, Object?> _defaults(String key) => switch (key) {
    'items' => GlossChannelItems().toJson(),
    'links' => GlossChannelLinks().toJson(),
    'mentions' => GlossChannelMentions().toJson(),
    'throttle' => GlossChannelThrottle().toJson(),
    'filtering' => GlossChannelFiltering().toJson(),
    _ => <String, Object?>{},
  };
  Map<String, Object?> _map(String key) => value[key] is Map
      ? huiReadObject(value[key], key)
      : fallback[key] is Map
      ? huiReadObject(fallback[key], key)
      : _defaults(key);

  Widget _text(String label, String text, void Function(String) change) =>
      HuiField(
        label: huiText(label),
        control: TextInput(
          value: text,
          size: ComponentSize.sm,
          fullWidth: true,
          onChanged: change,
          attributes: <String, String>{
            'aria-label': huiText(label),
            'spellcheck': 'false',
          },
        ),
      );

  Widget _block(
    String key,
    String title,
    List<Widget> Function(Map<String, Object?>) fields,
  ) {
    final bool present = value.containsKey(key);
    return InspectorSection(
      title: huiText(title),
      sectionKey: 'channel.fields.$inherited.$key',
      children: <Widget>[
        if (inherited)
          HuiSwitchRow(
            label: huiText('Override {field}', <String, Object?>{
              'field': huiText(title),
            }),
            value: present,
            onChanged: (bool enabled) =>
                enabled ? _set(key, _map(key)) : _remove(key),
          ),
        if (!inherited || present) ...fields(_map(key)),
      ],
    );
  }

  Widget _string(
    String key,
    Map<String, Object?> block,
    String field,
    String label,
  ) => _text(
    label,
    '${block[field] ?? ''}',
    (String text) => _set(key, <String, Object?>{...block, field: text}),
  );
  Widget _enabled(String key, Map<String, Object?> block) => HuiSwitchRow(
    label: huiText('Enabled'),
    value: block['enabled'] != false,
    onChanged: (bool enabled) =>
        _set(key, <String, Object?>{...block, 'enabled': enabled}),
  );

  @override
  Widget build(BuildContext context) {
    final List<Object?> cards = huiReadList(value['card'] ?? fallback['card']);
    final List<Object?> filters = huiReadList(
      value['filters'] ?? fallback['filters'],
    );
    return dom.div(<Widget>[
      if (inherited)
        InspectorSection(
          title: huiText('Message format'),
          children: <Widget>[
            HuiSwitchRow(
              label: huiText('Override format'),
              value: value.containsKey('format'),
              onChanged: (bool enabled) => enabled
                  ? _set('format', fallback['format'] ?? '{{ message }}')
                  : _remove('format'),
            ),
            if (value.containsKey('format'))
              _text(
                'Format',
                '${value['format']}',
                (String text) => _set('format', text),
              ),
          ],
        ),
      InspectorSection(
        title: huiText('Hover card'),
        children: <Widget>[
          if (inherited)
            HuiSwitchRow(
              label: huiText('Override hover card'),
              value: value.containsKey('card'),
              onChanged: (bool enabled) =>
                  enabled ? _set('card', cards) : _remove('card'),
            ),
          if (!inherited || value.containsKey('card'))
            HuiField(
              label: huiText('Card lines'),
              control: TextArea(
                value: cards.join('\n'),
                onChanged: (String text) =>
                    _set('card', text.isEmpty ? <String>[] : text.split('\n')),
              ),
            ),
        ],
      ),
      _block(
        'items',
        'Item links',
        (Map<String, Object?> block) => <Widget>[
          _enabled('items', block),
          _string('items', block, 'token', 'Item token'),
          _string('items', block, 'permission', 'Item permission'),
          _string('items', block, 'render', 'Item text'),
        ],
      ),
      _block(
        'links',
        'Web links',
        (Map<String, Object?> block) => <Widget>[
          _enabled('links', block),
          _string('links', block, 'render', 'Link text'),
        ],
      ),
      if (mentions)
        _block(
          'mentions',
          'Mentions',
          (Map<String, Object?> block) => <Widget>[
            _enabled('mentions', block),
            for (final MapEntry<String, String> field in const <String, String>{
              'pattern': 'Mention pattern',
              'render': 'Tagged name',
              'messageFormat': 'Tagged message',
              'sound': 'Mention sound',
              'permission': 'Mention permission',
            }.entries)
              _string('mentions', block, field.key, field.value),
          ],
        ),
      _block(
        'throttle',
        'Message limits',
        (Map<String, Object?> block) => <Widget>[
          for (final MapEntry<String, String> field in const <String, String>{
            'minIntervalTicks': 'Minimum interval ticks',
            'repeatWindowTicks': 'Repeat window ticks',
            'maxRepeats': 'Maximum repeats',
          }.entries)
            _text(field.value, '${block[field.key] ?? 0}', (String text) {
              final int? number = int.tryParse(text);
              if (number != null) {
                _set('throttle', <String, Object?>{
                  ...block,
                  field.key: number,
                });
              }
            }),
        ],
      ),
      _block('filtering', 'Filter policy', (Map<String, Object?> raw) {
        final Map<String, Object?> block = <String, Object?>{
          ...GlossChannelFiltering().toJson(),
          ...raw,
        };
        return <Widget>[
          HuiField(
            label: huiText('Pattern syntax'),
            help: huiText(
              'RE2 expressions. Lookaround and backreferences are unsupported. Replacements are literal.',
            ),
            control: dom.span(<Widget>[Text('${block['syntax']}')]),
          ),
          for (final MapEntry<String, String> field in const <String, String>{
            'maxInputCharacters': 'Maximum input characters',
            'maxOutputCharacters': 'Maximum output characters',
            'maxPatternCharacters': 'Maximum pattern characters',
            'maxReplacementCharacters': 'Maximum replacement characters',
            'maxFilters': 'Maximum filters',
            'maxMatches': 'Maximum matches',
            'maxProgramSize': 'Maximum expression program size',
            'maxNestingDepth': 'Maximum expression nesting',
            'maxWorkUnits': 'Maximum search work units',
            'budgetMicros': 'Elapsed target in microseconds',
          }.entries)
            _text(field.value, '${block[field.key]}', (String text) {
              final int? number = int.tryParse(text);
              if (number != null) {
                _set('filtering', <String, Object?>{
                  ...block,
                  field.key: number,
                });
              }
            }),
          HuiField(
            label: huiText('When a filter limit is reached'),
            help: huiText(
              'Drop requires all filters to finish. Keep completed may deliver text that later filters would remove. Oversized input always drops.',
            ),
            control: HuiSegmented(
              value: '${block['onLimit']}',
              segments: <HuiSegment>[
                HuiSegment(value: 'drop', label: huiText('Drop message')),
                HuiSegment(
                  value: 'keep-completed',
                  label: huiText('Keep completed'),
                ),
              ],
              onChanged: (String policy) => _set('filtering', <String, Object?>{
                ...block,
                'onLimit': policy,
              }),
            ),
          ),
        ];
      }),
      InspectorSection(
        title: huiText('Message filters'),
        children: <Widget>[
          if (inherited)
            HuiSwitchRow(
              label: huiText('Override filters'),
              value: value.containsKey('filters'),
              onChanged: (bool enabled) =>
                  enabled ? _set('filters', filters) : _remove('filters'),
            ),
          if (!inherited || value.containsKey('filters')) ...<Widget>[
            for (int index = 0; index < filters.length; index++) ...<Widget>[
              for (final String key in <String>['match', 'replace'])
                _text(
                  key == 'match' ? 'RE2 pattern' : 'Literal replacement',
                  '${huiReadObject(filters[index], 'filter')[key] ?? ''}',
                  (String text) {
                    final List<Object?> next = List<Object?>.of(filters);
                    next[index] = <String, Object?>{
                      ...huiReadObject(next[index], 'filter'),
                      key: text,
                    };
                    _set('filters', next);
                  },
                ),
              Button(
                label: huiText('Remove filter'),
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                onPressed: () =>
                    _set('filters', List<Object?>.of(filters)..removeAt(index)),
              ),
            ],
            Button(
              label: huiText('Add filter'),
              variant: ButtonVariant.outline,
              size: ButtonSize.sm,
              onPressed: () => _set('filters', <Object?>[
                ...filters,
                <String, Object?>{'match': 'pattern', 'replace': ''},
              ]),
            ),
          ],
        ],
      ),
    ]);
  }
}
