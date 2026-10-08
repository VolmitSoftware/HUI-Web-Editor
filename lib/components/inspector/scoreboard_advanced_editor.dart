import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../model/gloss_scoreboard.dart';
import '../../model/gloss_scoreboard_advanced.dart';
import '../../model/json_codec.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

typedef ScoreboardRowsBuilder =
    Widget Function(
      List<GlossScoreboardLine> rows,
      String path,
      void Function(void Function(List<GlossScoreboardLine>)) mutate,
    );

class ScoreboardLayoutEditor extends StatefulWidget {
  const ScoreboardLayoutEditor({
    required this.presentation,
    required this.path,
    required this.mutate,
    required this.rowsBuilder,
    super.key,
  });
  final GlossScoreboardPresentation presentation;
  final String path;
  final void Function(void Function(GlossScoreboardPresentation)) mutate;
  final ScoreboardRowsBuilder rowsBuilder;

  @override
  State<ScoreboardLayoutEditor> createState() => _ScoreboardLayoutEditorState();
}

class _ScoreboardLayoutEditorState extends State<ScoreboardLayoutEditor> {
  final Map<String, String> _names = <String, String>{};
  static final RegExp _id = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$');

  void _edit(void Function(GlossScoreboardLayout) change) =>
      component.mutate((GlossScoreboardPresentation edited) {
        final GlossScoreboardLayout layout = GlossScoreboardLayout.fromJson(
          edited.extras['layout'],
        );
        change(layout);
        edited.extras['layout'] = layout.toJson();
      });

  @override
  Widget build(BuildContext context) {
    final GlossScoreboardLayout layout;
    try {
      layout = GlossScoreboardLayout.fromJson(
        component.presentation.extras['layout'],
      );
    } on HuiFormatException {
      return HuiNote(
        huiText('Repair the layout in Code view to use these controls.'),
      );
    }
    return dom.div(classes: 'hui-scoreboard-layout', <Widget>[
      InspectorSection(
        title: huiText('Reusable sections'),
        children: <Widget>[
          for (final String name in layout.sections.keys)
            _section(layout, name),
          _button(
            huiText('Add section'),
            layout.sections.length >= 64
                ? null
                : () => _edit(
                    (GlossScoreboardLayout next) =>
                        next.sections[_nextId('section', next.sections.keys)] =
                            <GlossScoreboardLine>[],
                  ),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Rotating pages'),
        description: huiText(
          'Eligible pages rotate in list order. Durations use ticks; 20 ticks is one second. With no eligible pages, the base lines remain visible.',
        ),
        children: <Widget>[
          for (int index = 0; index < layout.pages.length; index++)
            _page(layout, index),
          _button(
            huiText('Add page'),
            layout.pages.length >= 64
                ? null
                : () => _edit(
                    (GlossScoreboardLayout next) => next.pages.add(
                      GlossScoreboardPage(
                        id: _nextId(
                          'page',
                          next.pages.map((GlossScoreboardPage page) => page.id),
                        ),
                        durationTicks: 100,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Layout policy'),
        children: <Widget>[
          _choice(
            huiText('Overflow'),
            layout.overflow ?? 'truncate',
            <String, String>{
              'truncate': huiText('Truncate'),
              'error': huiText('Reject overflow'),
            },
            (String value) =>
                _edit((GlossScoreboardLayout next) => next.overflow = value),
          ),
          HuiNote(
            huiText(
              'Minecraft displays at most 15 sidebar rows. Reject overflow checks expanded rows before conditions.',
            ),
          ),
          ..._interval(
            huiText('Title'),
            layout.refresh.titleTicks,
            (GlossScoreboardRefresh next, int? value) =>
                next.titleTicks = value,
          ),
          ..._interval(
            huiText('Text'),
            layout.refresh.textTicks,
            (GlossScoreboardRefresh next, int? value) => next.textTicks = value,
          ),
          ..._interval(
            huiText('Value'),
            layout.refresh.valueTicks,
            (GlossScoreboardRefresh next, int? value) =>
                next.valueTicks = value,
          ),
          HuiNote(
            huiText(
              'Omitted intervals use automatic refresh. Explicit intervals accept 1–72000 ticks.',
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _section(GlossScoreboardLayout layout, String name) {
    final String proposed = _names[name] ?? name;
    final bool canRename =
        proposed != name &&
        _id.hasMatch(proposed) &&
        !layout.sections.containsKey(proposed);
    return dom.div(classes: 'hui-scoreboard-section', styles: _groupStyles, <
      Widget
    >[
      _text(
        huiText('Section name'),
        proposed,
        (String value) => setState(() => _names[name] = value),
      ),
      _button(
        huiText('Rename section'),
        !canRename
            ? null
            : () {
                component.mutate((GlossScoreboardPresentation edited) {
                  final GlossScoreboardLayout next =
                      GlossScoreboardLayout.fromJson(edited.extras['layout']);
                  next.renameSection(name, proposed, edited.lines);
                  edited.extras['layout'] = next.toJson();
                });
                setState(() => _names.remove(name));
              },
      ),
      _button(
        huiText('Delete section'),
        () => _edit((GlossScoreboardLayout next) => next.sections.remove(name)),
      ),
      component.rowsBuilder(
        layout.sections[name]!,
        '${component.path}.layout.sections.$name',
        (void Function(List<GlossScoreboardLine>) change) =>
            _edit((GlossScoreboardLayout next) => change(next.sections[name]!)),
      ),
    ]);
  }

  Widget _page(GlossScoreboardLayout layout, int index) {
    final GlossScoreboardPage page = layout.pages[index];
    void edit(void Function(GlossScoreboardPage) change) =>
        _edit((GlossScoreboardLayout next) => change(next.pages[index]));
    return dom.div(
      classes: 'hui-scoreboard-page',
      styles: _groupStyles,
      <Widget>[
        _text(
          huiText('Page ID'),
          page.id,
          (String value) => edit((GlossScoreboardPage next) => next.id = value),
        ),
        _button(
          huiText('Move page up'),
          index == 0 ? null : () => _movePage(index, index - 1),
        ),
        _button(
          huiText('Move page down'),
          index == layout.pages.length - 1
              ? null
              : () => _movePage(index, index + 1),
        ),
        _button(
          huiText('Delete page'),
          () =>
              _edit((GlossScoreboardLayout next) => next.pages.removeAt(index)),
        ),
        HuiSwitchRow(
          label: huiText('Inherit presentation title'),
          value: page.title == null,
          onChanged: (bool value) => edit(
            (GlossScoreboardPage next) =>
                next.title = value ? null : component.presentation.title,
          ),
        ),
        if (page.title != null)
          _text(
            huiText('Page title'),
            page.title!,
            (String value) =>
                edit((GlossScoreboardPage next) => next.title = value),
          ),
        _text(
          huiText('Page condition'),
          _conditionText(page.show),
          (String value) =>
              edit((GlossScoreboardPage next) => next.show = _condition(value)),
        ),
        _ticks(
          huiText('Page duration ticks'),
          page.durationTicks ?? 100,
          (int value) =>
              edit((GlossScoreboardPage next) => next.durationTicks = value),
        ),
        component.rowsBuilder(
          page.lines,
          '${component.path}.layout.pages[$index]',
          (void Function(List<GlossScoreboardLine>) change) =>
              edit((GlossScoreboardPage next) => change(next.lines)),
        ),
      ],
    );
  }

  void _movePage(int from, int to) => _edit((GlossScoreboardLayout next) {
    next.pages.insert(to, next.pages.removeAt(from));
  });

  List<Widget> _interval(
    String label,
    int? value,
    void Function(GlossScoreboardRefresh, int?) change,
  ) => <Widget>[
    HuiSwitchRow(
      label: huiText('Override {label} interval', <String, Object?>{
        'label': label,
      }),
      value: value != null,
      onChanged: (bool enabled) => _edit(
        (GlossScoreboardLayout next) =>
            change(next.refresh, enabled ? 20 : null),
      ),
    ),
    if (value != null)
      _ticks(
        huiText('{label} ticks', <String, Object?>{'label': label}),
        value,
        (int ticks) =>
            _edit((GlossScoreboardLayout next) => change(next.refresh, ticks)),
      ),
  ];
}

class ScoreboardObjectivesEditor extends StatelessWidget {
  const ScoreboardObjectivesEditor({
    required this.raw,
    required this.onChanged,
    super.key,
  });
  final Object? raw;
  final void Function(Map<String, Object?>) onChanged;

  void _edit(void Function(GlossScoreboardObjectives) change) {
    final GlossScoreboardObjectives next = GlossScoreboardObjectives.fromJson(
      raw,
    );
    change(next);
    onChanged(next.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final GlossScoreboardObjectives objectives;
    try {
      objectives = GlossScoreboardObjectives.fromJson(raw);
    } on HuiFormatException {
      return HuiNote(
        huiText('Repair native objectives in Code view to use these controls.'),
      );
    }
    return InspectorSection(
      title: huiText('Native objectives'),
      description: huiText(
        'Player-list and below-name objectives are independent of sidebar variants. Preview their client appearance and slot conflicts in Minecraft.',
      ),
      children: <Widget>[
        _slot(huiText('Player list'), objectives.playerList, true),
        _slot(huiText('Below name'), objectives.belowName, false),
      ],
    );
  }

  Widget _slot(String label, GlossScoreboardObjective? slot, bool playerList) {
    void edit(void Function(GlossScoreboardObjective) change) =>
        _edit((GlossScoreboardObjectives next) {
          change((playerList ? next.playerList : next.belowName)!);
        });
    String field(String name) => '$label: $name';
    return dom.div(classes: 'hui-scoreboard-objective', styles: _groupStyles, <
      Widget
    >[
      HuiSwitchRow(
        label: label,
        value: slot != null,
        onChanged: (bool enabled) => _edit((GlossScoreboardObjectives next) {
          final GlossScoreboardObjective? value = enabled
              ? GlossScoreboardObjective()
              : null;
          if (playerList) {
            next.playerList = value;
          } else {
            next.belowName = value;
          }
        }),
      ),
      if (slot != null) ...<Widget>[
        _text(
          field(huiText('Title')),
          slot.title ?? '',
          (String value) =>
              edit((GlossScoreboardObjective next) => next.title = value),
        ),
        _text(
          field(huiText('Numeric value')),
          slot.value ?? 'subject.health',
          (String value) =>
              edit((GlossScoreboardObjective next) => next.value = value),
        ),
        _choice(
          field(huiText('Render type')),
          slot.renderType?.toLowerCase() ?? 'integer',
          <String, String>{
            'integer': huiText('Integer'),
            'hearts': huiText('Hearts'),
          },
          (String value) =>
              edit((GlossScoreboardObjective next) => next.renderType = value),
        ),
        _choice(
          field(huiText('Score format')),
          slot.format?.trim().toLowerCase() ?? 'number',
          <String, String>{
            'number': huiText('Number'),
            'blank': huiText('Blank'),
            'fixed': huiText('Fixed'),
            'styled': huiText('Styled'),
          },
          (String value) =>
              edit((GlossScoreboardObjective next) => next.format = value),
        ),
        _text(
          field(huiText('Formatted value')),
          slot.valueText ?? '',
          (String value) =>
              edit((GlossScoreboardObjective next) => next.valueText = value),
        ),
        _text(
          field(huiText('Viewer condition')),
          _conditionText(slot.show),
          (String value) => edit(
            (GlossScoreboardObjective next) => next.show = _condition(value),
          ),
        ),
        _text(
          field(huiText('Subject condition')),
          _conditionText(slot.subjects),
          (String value) => edit(
            (GlossScoreboardObjective next) =>
                next.subjects = _condition(value),
          ),
        ),
        _ticks(
          field(huiText('Refresh ticks')),
          slot.refreshTicks ?? 20,
          (int value) => edit(
            (GlossScoreboardObjective next) => next.refreshTicks = value,
          ),
        ),
        _choice(
          field(huiText('Slot conflict')),
          slot.conflict?.toLowerCase() ?? 'yield',
          <String, String>{
            'yield': huiText('Yield'),
            'override': huiText('Override'),
          },
          (String value) =>
              edit((GlossScoreboardObjective next) => next.conflict = value),
        ),
        HuiNote(
          huiText(
            'Yield preserves another plugin’s objective. Override takes this display slot.',
          ),
        ),
      ],
    ]);
  }
}

Widget _text(String label, String value, void Function(String) change) =>
    HuiField(
      label: label,
      control: TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        onChanged: change,
        attributes: <String, String>{
          'aria-label': label,
          'autocomplete': 'off',
          'spellcheck': 'false',
        },
      ),
    );
Widget _ticks(String label, int value, void Function(int) change) => HuiField(
  label: label,
  control: HuiNumberField(
    value: value.toDouble(),
    integer: true,
    min: 1,
    max: 72000,
    step: 1,
    decimals: 0,
    ariaLabel: label,
    onChanged: (double value) => change(value.toInt()),
  ),
);
Widget _choice(
  String label,
  String value,
  Map<String, String> options,
  void Function(String) change,
) => HuiField(
  label: label,
  control: ArcaneSelect(
    label: label,
    value: value,
    size: ComponentSize.sm,
    fullWidth: true,
    options: <ArcaneSelectOption>[
      for (final MapEntry<String, String> entry in options.entries)
        ArcaneSelectOption(value: entry.key, label: entry.value),
    ],
    onChanged: change,
  ),
);
Widget _button(String label, void Function()? action) => Button(
  label: label,
  onPressed: action,
  disabled: action == null,
  variant: ButtonVariant.outline,
  size: ButtonSize.sm,
);
String _nextId(String prefix, Iterable<String> ids) {
  int number = 1;
  while (ids.contains('$prefix-$number')) {
    number++;
  }
  return '$prefix-$number';
}

String _conditionText(Object? value) => value?.toString() ?? '';
Object? _condition(String value) => switch (value.trim()) {
  '' => null,
  'true' => true,
  'false' => false,
  _ => value,
};

const dom.Styles _groupStyles = dom.Styles(
  raw: <String, String>{
    'display': 'grid',
    'gap': '8px',
    'min-width': '0',
    'margin-bottom': '16px',
  },
);
