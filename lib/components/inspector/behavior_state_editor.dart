import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../model/behavior_authoring.dart';
import '../../model/gloss_behavior.dart';
import '../../model/gloss_doc.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class BehaviorStateEditor extends StatelessWidget {
  const BehaviorStateEditor({required this.store, super.key});
  final EditorStore store;

  void _change(String key, void Function(BehaviorStateDeclaration) edit) =>
      store.mutateGloss('state declaration', (GlossDoc raw) {
        final GlossBehaviorDoc doc = raw as GlossBehaviorDoc;
        final BehaviorStateDeclaration? state = BehaviorStateDeclaration.read(
          doc.state[key],
        );
        if (state == null) return;
        edit(state);
        doc.state[key] = state.toJson();
      });

  @override
  Widget build(BuildContext context) {
    final GlossBehaviorDoc doc = store.glossDoc! as GlossBehaviorDoc;
    return InspectorSection(
      title: huiText('State declarations'),
      children: <Widget>[
        for (final MapEntry<String, Object?> entry in doc.state.entries)
          _row(entry.key, BehaviorStateDeclaration.read(entry.value)),
        Button(
          label: huiText('Add state'),
          variant: ButtonVariant.outline,
          onPressed: () => store.mutateGloss('add state', (GlossDoc raw) {
            final GlossBehaviorDoc next = raw as GlossBehaviorDoc;
            int index = 1;
            while (next.state.containsKey('state$index')) {
              index++;
            }
            next.state['state$index'] = BehaviorStateDeclaration(
              scope: 'player',
              type: 'number',
            ).toJson();
          }),
        ),
      ],
    );
  }

  Widget _row(String key, BehaviorStateDeclaration? state) => dom.div(
    attributes: <String, String>{'data-behavior-state': key},
    <Widget>[
      HuiField(
        label: huiText('State key'),
        control: TextInput(
          value: key,
          attributes: <String, String>{'aria-label': 'state/$key/key'},
          onChanged: (String value) => store.mutateGloss('rename state', (
            GlossDoc raw,
          ) {
            final GlossBehaviorDoc next = raw as GlossBehaviorDoc;
            if (value == key || next.state.containsKey(value)) return;
            next.state = <String, Object?>{
              for (final MapEntry<String, Object?> entry in next.state.entries)
                entry.key == key ? value : entry.key: entry.value,
            };
          }),
        ),
      ),
      if (state == null)
        HuiNote(
          huiText(
            'Repair state declarations in Code view to use these controls.',
          ),
        )
      else ...<Widget>[
        ArcaneSelect(
          label: huiText('Scope'),
          value: state.scope,
          options: <ArcaneSelectOption>[
            for (final String scope in <String>{
              'player',
              'world',
              'global',
              state.scope,
            })
              ArcaneSelectOption(value: scope, label: scope),
          ],
          onChanged: (String value) => _change(
            key,
            (BehaviorStateDeclaration next) => next.scope = value,
          ),
        ),
        ArcaneSelect(
          label: huiText('Type'),
          value: state.type,
          options: <ArcaneSelectOption>[
            for (final String type in <String>{
              'number',
              'string',
              'boolean',
              state.type,
            })
              ArcaneSelectOption(value: type, label: type),
          ],
          onChanged: (String value) => _change(
            key,
            (BehaviorStateDeclaration next) => next.type = value,
          ),
        ),
        HuiSwitchRow(
          label: huiText('Override'),
          value: state.hasDefault,
          onChanged: (bool value) =>
              _change(key, (BehaviorStateDeclaration next) {
                next.hasDefault = value;
                if (value && next.defaultValue == null) {
                  next.defaultValue = next.resolvedDefault;
                }
              }),
        ),
        if (state.hasDefault && state.type == 'boolean')
          HuiSwitchRow(
            label: huiText('Value'),
            value: state.resolvedDefault == true,
            onChanged: (bool value) => _change(
              key,
              (BehaviorStateDeclaration next) => next.defaultValue = value,
            ),
          )
        else if (state.hasDefault)
          HuiField(
            label: huiText('Value'),
            control: TextInput(
              value: '${state.defaultValue ?? ''}',
              attributes: <String, String>{'aria-label': 'state/$key/default'},
              onChanged: (String value) {
                final Object? parsed = state.type == 'number'
                    ? double.tryParse(value)
                    : value;
                if (parsed != null && (parsed is! num || parsed.isFinite)) {
                  _change(
                    key,
                    (BehaviorStateDeclaration next) =>
                        next.defaultValue = parsed,
                  );
                }
              },
            ),
          ),
      ],
      HuiInlineIssues(
        store.issues
            .where((issue) => issue.path.startsWith('\$.state.$key'))
            .toList(),
      ),
      Button(
        label: huiText('Remove state'),
        variant: ButtonVariant.outline,
        onPressed: () => store.mutateGloss(
          'remove state',
          (GlossDoc raw) => (raw as GlossBehaviorDoc).state.remove(key),
        ),
      ),
    ],
  );
}
