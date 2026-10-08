import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../l10n/hui_localizations.dart';
import '../../logic/behavior_validation.dart';
import '../../model/gloss_behavior.dart';
import '../../model/gloss_doc.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'extras_editor.dart';
import 'actions_editor.dart';
import 'behavior_state_editor.dart';
import 'inspector_session.dart';
import '../../model/behavior_authoring.dart';
import '../../model/hui_actions.dart';
import 'inspector_widgets.dart';

class BehaviorInspector extends StatefulWidget {
  const BehaviorInspector({required this.store, super.key});
  final EditorStore store;
  @override
  State<BehaviorInspector> createState() => _BehaviorInspectorState();
}

class _BehaviorInspectorState extends State<BehaviorInspector> {
  EditorStore get store => component.store;
  final InspectorSession session = InspectorSession();

  void _edit(String label, void Function(GlossBehaviorDoc doc) update) => store
      .mutateGloss(label, (GlossDoc doc) => update(doc as GlossBehaviorDoc));

  Widget _text(
    String label,
    String value,
    void Function(GlossBehaviorDoc doc, String value) update,
  ) => HuiField(
    label: huiText(label),
    control: TextInput(
      value: value,
      attributes: <String, String>{'aria-label': label},
      onChanged: (String next) =>
          _edit(label, (GlossBehaviorDoc doc) => update(doc, next)),
    ),
  );

  Widget _limit(
    String name,
    int value,
    void Function(GlossBehaviorMatching matching, int value) update,
  ) => HuiField(
    label: name,
    control: TextInput(
      value: '$value',
      attributes: <String, String>{'aria-label': name, 'inputmode': 'numeric'},
      onChanged: (String next) {
        final int? parsed = int.tryParse(next);
        if (parsed != null) {
          _edit(name, (GlossBehaviorDoc doc) => update(doc.matching, parsed));
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final GlossBehaviorDoc doc = store.glossDoc! as GlossBehaviorDoc;
    return dom.div(classes: 'hui-inspector-body is-behavior', <Widget>[
      InspectorSection(
        title: huiText('Behavior'),
        children: <Widget>[
          HuiSwitchRow(
            label: huiText('Enabled'),
            value: doc.enabled,
            onChanged: (bool value) => _edit(
              'enabled',
              (GlossBehaviorDoc next) => next.enabled = value,
            ),
          ),
          HuiSwitchRow(
            label: huiText('Allow server commands'),
            value: doc.allowServerCommands,
            onChanged: (bool value) => _edit(
              'server commands',
              (GlossBehaviorDoc next) => next.allowServerCommands = value,
            ),
          ),
          HuiNote(
            huiText(
              'Events run on the server. The browser validates matching rules without executing actions.',
            ),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Chat matching'),
        children: <Widget>[
          HuiNote(
            huiText(
              'RE2 patterns support bounded matching. Lookaround and backreferences are unsupported. Exhausted matching budgets skip behaviors and retain ordinary chat.',
            ),
          ),
          _limit(
            'maxInputCharacters',
            doc.matching.maxInputCharacters,
            (GlossBehaviorMatching limits, int value) =>
                limits.maxInputCharacters = value,
          ),
          _limit(
            'maxPatternCharacters',
            doc.matching.maxPatternCharacters,
            (GlossBehaviorMatching limits, int value) =>
                limits.maxPatternCharacters = value,
          ),
          _limit(
            'maxProgramSize',
            doc.matching.maxProgramSize,
            (GlossBehaviorMatching limits, int value) =>
                limits.maxProgramSize = value,
          ),
          _limit(
            'maxNestingDepth',
            doc.matching.maxNestingDepth,
            (GlossBehaviorMatching limits, int value) =>
                limits.maxNestingDepth = value,
          ),
          _limit(
            'maxWorkUnits',
            doc.matching.maxWorkUnits,
            (GlossBehaviorMatching limits, int value) =>
                limits.maxWorkUnits = value,
          ),
        ],
      ),
      for (int index = 0; index < doc.on.length; index++)
        _entry(doc.on[index], index),
      Button(
        label: huiText('Add trigger'),
        variant: ButtonVariant.outline,
        onPressed: () => _edit(
          'add trigger',
          (GlossBehaviorDoc next) => next.on.add(GlossBehaviorEntry()),
        ),
      ),
      BehaviorStateEditor(store: store),
    ]);
  }

  Widget _actions(GlossBehaviorEntry entry, int index) {
    final HuiActionSourceList? source = HuiActionSourceList.read(entry.actions);
    if (source == null) {
      return HuiNote(
        huiText('Repair actions in Code view to use these controls.'),
      );
    }
    return ActionsEditor(
      store: store,
      catalogs: store.catalogs,
      session: session,
      sessionKey: '${store.menuId}/on/$index/do',
      slot: ActionSlot.actions,
      actions: source.actions,
      clickContext: false,
      title: huiText('Actions {index}', <String, Object?>{'index': index + 1}),
      path: '\$.on[$index].do',
      issues: store.issues,
      onEdit: (String label, void Function(List<HuiAction>) edit) =>
          _edit(label, (GlossBehaviorDoc next) {
            final HuiActionSourceList? current = HuiActionSourceList.read(
              next.on[index].actions,
            );
            if (current != null) next.on[index].actions = current.edit(edit);
          }),
    );
  }

  Widget _entry(GlossBehaviorEntry entry, int index) {
    final Set<String> accepted =
        behaviorTriggerOptions[entry.trigger] ?? const <String>{};
    final Map<String, Object?> options = entry.toJson()
      ..removeWhere(
        (String key, Object? _) =>
            const <String>{
              'trigger',
              'pattern',
              'when',
              'permission',
              'do',
            }.contains(key) ||
            accepted.contains(key),
      );
    return InspectorSection(
      title: '${index + 1}. ${entry.trigger}',
      children: <Widget>[
        HuiField(
          label: huiText('Trigger'),
          control: ArcaneSelect(
            value: entry.trigger,
            options: <ArcaneSelectOption>[
              for (final String trigger in behaviorTriggerOptions.keys)
                ArcaneSelectOption(value: trigger, label: trigger),
            ],
            onChanged: (String value) => _edit(
              'trigger',
              (GlossBehaviorDoc doc) => doc.on[index].trigger = value,
            ),
          ),
        ),
        if (entry.trigger == 'chat' || entry.pattern != null)
          _text(
            huiText('Chat pattern {index}', <String, Object?>{
              'index': index + 1,
            }),
            entry.pattern ?? '',
            (GlossBehaviorDoc doc, String value) =>
                doc.on[index].pattern = value.isEmpty ? null : value,
          ),
        _text(
          huiText('Condition {index}', <String, Object?>{'index': index + 1}),
          entry.when ?? '',
          (GlossBehaviorDoc doc, String value) =>
              doc.on[index].when = value.isEmpty ? null : value,
        ),
        _text(
          huiText('Permission {index}', <String, Object?>{'index': index + 1}),
          entry.permission ?? '',
          (GlossBehaviorDoc doc, String value) =>
              doc.on[index].permission = value.isEmpty ? null : value,
        ),
        for (final String key in accepted.where(
          (String key) => key != 'pattern',
        ))
          _text('$key ${index + 1}', '${entry.toJson()[key] ?? ''}', (
            GlossBehaviorDoc doc,
            String value,
          ) {
            final Map<String, Object?> source = doc.on[index].toJson();
            if (value.isEmpty) {
              source.remove(key);
            } else if (key == 'everyTicks') {
              final int? ticks = int.tryParse(value);
              if (ticks == null) return;
              source[key] = ticks;
            } else {
              source[key] = value;
            }
            doc.on[index] = GlossBehaviorEntry.fromJson(source);
          }),
        ExtrasEditor(
          title: huiText('Trigger options {index}', <String, Object?>{
            'index': index + 1,
          }),
          extensionKeys: false,
          extras: options,
          onChanged: (String label, Map<String, Object?> values) =>
              _edit(label, (GlossBehaviorDoc doc) {
                final Map<String, Object?> source = doc.on[index].toJson()
                  ..removeWhere(
                    (String key, Object? _) =>
                        !const <String>{
                          'trigger',
                          'pattern',
                          'when',
                          'permission',
                          'do',
                        }.contains(key) &&
                        !accepted.contains(key),
                  );
                doc.on[index] = GlossBehaviorEntry.fromJson(<String, Object?>{
                  ...source,
                  ...values,
                });
              }),
        ),
        _actions(entry, index),
        Button(
          label: huiText('Remove trigger'),
          variant: ButtonVariant.ghost,
          onPressed: () => _edit(
            'remove trigger',
            (GlossBehaviorDoc doc) => doc.on.removeAt(index),
          ),
        ),
      ],
    );
  }
}

class BehaviorView extends StatelessWidget {
  const BehaviorView({required this.store, super.key});
  final EditorStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (BuildContext context) {
      final GlossBehaviorDoc? doc = store.glossDoc is GlossBehaviorDoc
          ? store.glossDoc! as GlossBehaviorDoc
          : null;
      return dom.div(classes: 'hui-catalog-view', <Widget>[
        dom.h2(<Widget>[Text(huiText('Behavior triggers'))]),
        dom.p(<Widget>[
          Text(
            huiText(
              'Configure events, conditions and actions in the inspector. Runtime actions require a connected Minecraft server.',
            ),
          ),
        ]),
        if (doc != null && doc.on.isEmpty)
          dom.p(<Widget>[
            Text(huiText('No triggers. Add a trigger in the inspector.')),
          ]),
        if (doc != null)
          dom.ol(<Widget>[
            for (final GlossBehaviorEntry entry in doc.on)
              dom.li(<Widget>[
                Text(
                  huiText('{trigger} ({count} actions)', <String, Object?>{
                    'trigger':
                        '${entry.trigger}${entry.pattern == null ? '' : ': ${entry.pattern}'}',
                    'count': entry.actions.length,
                  }),
                ),
              ]),
          ]),
      ]);
    },
  );
}
