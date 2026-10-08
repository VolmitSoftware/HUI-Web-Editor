import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../logic/validation.dart';
import '../../model/gloss_surface.dart';
import '../../model/gloss_surface_subscription.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class SurfaceSubscriptionsEditor extends StatelessWidget {
  const SurfaceSubscriptionsEditor({required this.store, super.key});
  final EditorStore store;

  void _edit(int index, void Function(GlossSurfaceSubscription entry) update) =>
      store.mutateSurface('surface subscription', (GlossSurfaceDoc next) {
        update(next.on![index]);
      });

  String _label(int index, String field) => huiText(
    'Subscription {index}: {field}',
    <String, Object?>{'index': index + 1, 'field': field},
  );

  Widget _number(
    int index,
    String label,
    int? value,
    void Function(GlossSurfaceSubscription entry, int? value) update,
  ) => HuiField(
    label: label,
    control: TextInput(
      value: value?.toString() ?? '',
      fullWidth: true,
      attributes: <String, String>{
        'aria-label': _label(index, label),
        'inputmode': 'numeric',
      },
      onChanged: (String source) {
        final int? parsed = int.tryParse(source);
        if (parsed != null || source.trim().isEmpty) {
          _edit(
            index,
            (GlossSurfaceSubscription entry) => update(entry, parsed),
          );
        }
      },
    ),
  );

  void _move(int from, int to) =>
      store.mutateSurface('move surface subscription', (GlossSurfaceDoc next) {
        final GlossSurfaceSubscription entry = next.on!.removeAt(from);
        next.on!.insert(to, entry);
      });

  @override
  Widget build(BuildContext context) {
    final GlossSurfaceDoc doc = store.surfaceDoc!;
    final List<GlossSurfaceSubscription> entries =
        doc.on ?? const <GlossSurfaceSubscription>[];
    return InspectorSection(
      title: huiText('Event subscriptions'),
      sectionKey: 'surface.subscriptions',
      children: <Widget>[
        HuiNote(
          huiText(
            'World changes run on the backend; server changes run on Velocity. Join and interval events work on both.',
          ),
        ),
        HuiInlineIssues(
          store.issues
              .where((HuiIssue issue) => issue.path.startsWith(r'$.on'))
              .toList(),
        ),
        if (doc.hasMalformedSubscriptions)
          HuiNote(
            huiText(
              'Repair event subscriptions in Code view to use these controls.',
            ),
          )
        else ...<Widget>[
          for (final (int index, GlossSurfaceSubscription entry)
              in entries.indexed)
            dom.div(
              classes: 'hui-inspector-subsection',
              attributes: <String, String>{
                'data-surface-subscription': '$index',
              },
              <Widget>[
                HuiEyebrow(
                  huiText('Subscription {index}', <String, Object?>{
                    'index': index + 1,
                  }),
                ),
                ArcaneSelect(
                  label: _label(index, huiText('Event')),
                  value: entry.trigger ?? '',
                  options: <ArcaneSelectOption>[
                    if (!glossSurfaceSubscriptionTriggers.contains(
                      entry.trigger,
                    ))
                      ArcaneSelectOption(
                        value: entry.trigger ?? '',
                        label: entry.trigger ?? huiText('Select event'),
                      ),
                    for (final String trigger
                        in glossSurfaceSubscriptionTriggers)
                      ArcaneSelectOption(value: trigger, label: trigger),
                  ],
                  onChanged: (String value) => _edit(
                    index,
                    (GlossSurfaceSubscription next) => next.setTrigger(value),
                  ),
                ),
                if (entry.trigger == 'interval' ||
                    entry.everyTicks != null) ...<Widget>[
                  _number(index, huiText('Interval'), entry.everyTicks, (
                    GlossSurfaceSubscription next,
                    int? value,
                  ) {
                    next.everyTicks = value;
                    next.extras.remove('everyTicks');
                  }),
                  HuiNote(
                    huiText('Required for interval events, 1–1728000 ticks.'),
                  ),
                ],
                _number(index, huiText('Delay'), entry.delayTicks, (
                  GlossSurfaceSubscription next,
                  int? value,
                ) {
                  next.delayTicks = value;
                  next.extras.remove('delayTicks');
                }),
                HuiNote(
                  huiText(
                    'Wait 0–72000 ticks after the event before submitting.',
                  ),
                ),
                HuiField(
                  label: huiText('Condition'),
                  control: TextInput(
                    value: entry.when ?? '',
                    placeholder: 'true',
                    fullWidth: true,
                    attributes: <String, String>{
                      'aria-label': _label(index, huiText('Condition')),
                    },
                    onChanged: (String value) =>
                        _edit(index, (GlossSurfaceSubscription next) {
                          next.when = value.isEmpty ? null : value;
                          next.extras.remove('when');
                        }),
                  ),
                ),
                HuiNote(
                  huiText('Viewer condition evaluated when this event fires.'),
                ),
                Wrap(
                  children: <Widget>[
                    Button(
                      label: huiText('Move up'),
                      variant: ButtonVariant.outline,
                      onPressed: index == 0
                          ? null
                          : () => _move(index, index - 1),
                    ),
                    Button(
                      label: huiText('Move down'),
                      variant: ButtonVariant.outline,
                      onPressed: index + 1 == entries.length
                          ? null
                          : () => _move(index, index + 1),
                    ),
                    Button(
                      label: huiText('Remove subscription'),
                      variant: ButtonVariant.outline,
                      onPressed: () => store.mutateSurface(
                        'remove surface subscription',
                        (GlossSurfaceDoc next) => next.on!.removeAt(index),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          Button(
            label: huiText('Add subscription'),
            variant: ButtonVariant.outline,
            onPressed: entries.length >= 64
                ? null
                : () => store.mutateSurface('add surface subscription', (
                    GlossSurfaceDoc next,
                  ) {
                    (next.on ??= <GlossSurfaceSubscription>[]).add(
                      GlossSurfaceSubscription(trigger: 'join'),
                    );
                    next.extras.remove('on');
                  }),
          ),
        ],
      ],
    );
  }
}
