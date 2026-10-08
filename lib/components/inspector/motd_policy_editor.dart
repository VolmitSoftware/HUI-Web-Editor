import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../../model/gloss_motd.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class MotdDocumentPolicies extends StatelessWidget {
  const MotdDocumentPolicies({required this.store, super.key});
  final EditorStore store;
  void _edit(String label, void Function(GlossMotdDoc) edit) =>
      store.mutateMotd(label, edit);
  @override
  Widget build(BuildContext context) {
    final GlossMotdDoc doc = store.motdDoc!;
    final GlossMotdServerLinks? links = doc.serverLinks;
    return dom.div(<Widget>[
      InspectorSection(
        title: huiText('Response policy'),
        sectionKey: 'motd.policy',
        children: <Widget>[
          _choice(
            huiText('Rotation mode'),
            doc.rotation?.effectiveMode ?? 'weighted',
            const <String>['weighted', 'sequence', 'time', 'first'],
            (String value) => _edit(
              'rotation mode',
              (GlossMotdDoc next) =>
                  (next.rotation ??= GlossMotdRotation()).mode = value,
            ),
          ),
          _number(
            huiText('Rotation interval seconds'),
            doc.rotation?.intervalSeconds,
            (int? value) => _edit(
              'rotation interval',
              (GlossMotdDoc next) =>
                  (next.rotation ??= GlossMotdRotation()).intervalSeconds =
                      value,
            ),
            placeholder: '60',
          ),
          HuiNote(
            huiText(
              'Sequence advances on each handled status request. Time rotation uses the epoch and interval; weighted rotation uses entry weights.',
            ),
          ),
          _text(
            huiText('Server state'),
            doc.state ?? '',
            (String value) => _edit(
              'server state',
              (GlossMotdDoc next) => next.state = value.isEmpty ? null : value,
            ),
            placeholder: 'normal',
          ),
          _text(
            huiText('Document icon set'),
            doc.icons?.join('\n') ?? '',
            (String value) => _edit(
              'document icons',
              (GlossMotdDoc next) => next.icons = _lines(value),
            ),
            multiline: true,
          ),
          HuiNote(
            huiText(
              'One 64×64 PNG path per line. Entry icon sets override entry icons, then document icon sets and document icons.',
            ),
          ),
          HuiInlineIssues(
            store.issues
                .where(
                  (issue) =>
                      issue.path.startsWith(r'$.rotation') ||
                      issue.path == r'$.state' ||
                      issue.path.startsWith(r'$.icons'),
                )
                .toList(),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Independent server links'),
        sectionKey: 'motd.serverLinks',
        children: <Widget>[
          HuiSwitchRow(
            label: huiText('Manage links independently'),
            value: links != null,
            onChanged: (bool enabled) => _edit(
              'independent links',
              (GlossMotdDoc next) => next.serverLinks = enabled
                  ? GlossMotdServerLinks(
                      links: <GlossMotdLink>[
                        for (final GlossMotdLink link in next.links)
                          link.copy(),
                      ],
                    )
                  : null,
            ),
          ),
          HuiNote(
            huiText(
              'Independent links do not depend on the MOTD feature switch or entry selection. The original link list remains available when this override is removed.',
            ),
          ),
          if (links != null) ...<Widget>[
            HuiSwitchRow(
              label: huiText('Publish server links'),
              value: links.enabled != false,
              onChanged: (bool enabled) => _edit(
                'publish links',
                (GlossMotdDoc next) => next.serverLinks!.enabled = enabled,
              ),
            ),
            for (int index = 0; index < (links.links?.length ?? 0); index++)
              _link(links.links![index], index),
            if ((links.links?.length ?? 0) < glossMotdMaxLinks)
              Button(
                label: huiText('Add independent link'),
                variant: ButtonVariant.outline,
                onPressed: () => _edit(
                  'add independent link',
                  (GlossMotdDoc next) =>
                      (next.serverLinks!.links ??= <GlossMotdLink>[]).add(
                        GlossMotdLink(type: 'website'),
                      ),
                ),
              ),
            HuiInlineIssues(
              store.issues
                  .where((issue) => issue.path.startsWith(r'$.serverLinks'))
                  .toList(),
            ),
          ],
        ],
      ),
    ]);
  }

  Widget _link(GlossMotdLink link, int index) {
    void change(void Function(GlossMotdLink) edit) => _edit(
      'independent link',
      (GlossMotdDoc next) => edit(next.serverLinks!.links![index]),
    );
    String label(String field) => huiText(
      'Link {index}: {field}',
      <String, Object?>{'index': index + 1, 'field': field},
    );
    return InspectorSection(
      title: huiText('Independent link {index}', <String, Object?>{
        'index': index + 1,
      }),
      children: <Widget>[
        _choice(
          label(huiText('Type')),
          link.type ?? '',
          <String>['', ...glossMotdLinkTypes],
          (String value) => change(
            (GlossMotdLink next) => next.type = value.isEmpty ? null : value,
          ),
        ),
        _text(
          label(huiText('Label')),
          link.label ?? '',
          (String value) => change(
            (GlossMotdLink next) => next.label = value.isEmpty ? null : value,
          ),
        ),
        _text(
          label(huiText('Address')),
          link.url,
          (String value) => change((GlossMotdLink next) => next.url = value),
        ),
        if (index > 0)
          Button(
            label: huiText('Move link up'),
            variant: ButtonVariant.ghost,
            onPressed: () =>
                _edit('reorder independent links', (GlossMotdDoc next) {
                  final List<GlossMotdLink> entries = next.serverLinks!.links!;
                  entries.insert(index - 1, entries.removeAt(index));
                }),
          ),
        Button(
          label: huiText('Delete independent link'),
          variant: ButtonVariant.ghost,
          onPressed: () => _edit(
            'delete independent link',
            (GlossMotdDoc next) => next.serverLinks!.links!.removeAt(index),
          ),
        ),
      ],
    );
  }
}

class MotdEntryPolicies extends StatelessWidget {
  const MotdEntryPolicies({
    required this.store,
    required this.index,
    super.key,
  });
  final EditorStore store;
  final int index;
  void _edit(String label, void Function(GlossMotdEntry) edit) =>
      store.mutateMotd(label, (GlossMotdDoc doc) => edit(doc.entries[index]));
  void _selector(String label, void Function(GlossMotdSelector) edit) => _edit(
    label,
    (GlossMotdEntry entry) => edit(entry.select ??= GlossMotdSelector()),
  );
  void _counts(String label, void Function(GlossMotdCounts) edit) => _edit(
    label,
    (GlossMotdEntry entry) => edit(entry.counts ??= GlossMotdCounts()),
  );
  String _label(String field) => huiText(
    'Entry {index}: {field}',
    <String, Object?>{'index': index + 1, 'field': field},
  );

  @override
  Widget build(BuildContext context) {
    final GlossMotdEntry entry = store.motdDoc!.entries[index];
    final GlossMotdSelector selector = entry.select ?? GlossMotdSelector();
    final GlossMotdCounts counts = entry.counts ?? GlossMotdCounts();
    return dom.div(<Widget>[
      InspectorSection(
        title: huiText('Request selection'),
        sectionKey: 'motd.entry.$index.selection',
        children: <Widget>[
          HuiNote(
            huiText(
              'Status requests have no authenticated player. Match client-supplied host and protocol metadata, calendar time, state and real online counts.',
            ),
          ),
          _text(
            _label(huiText('Hostnames')),
            selector.hostnames?.join('\n') ?? '',
            (String value) => _selector(
              'hostnames',
              (GlossMotdSelector next) => next.hostnames = _lines(value),
            ),
            multiline: true,
          ),
          _number(
            _label(huiText('Minimum protocol')),
            selector.minProtocol,
            (int? value) => _selector(
              'minimum protocol',
              (GlossMotdSelector next) => next.minProtocol = value,
            ),
          ),
          _number(
            _label(huiText('Maximum protocol')),
            selector.maxProtocol,
            (int? value) => _selector(
              'maximum protocol',
              (GlossMotdSelector next) => next.maxProtocol = value,
            ),
          ),
          _text(
            _label(huiText('Time zone')),
            selector.zone ?? '',
            (String value) => _selector(
              'time zone',
              (GlossMotdSelector next) =>
                  next.zone = value.isEmpty ? null : value,
            ),
            placeholder: 'UTC',
          ),
          _text(
            _label(huiText('Start time')),
            selector.startTime ?? '',
            (String value) => _selector(
              'start time',
              (GlossMotdSelector next) =>
                  next.startTime = value.isEmpty ? null : value,
            ),
            placeholder: '18:00',
          ),
          _text(
            _label(huiText('End time')),
            selector.endTime ?? '',
            (String value) => _selector(
              'end time',
              (GlossMotdSelector next) =>
                  next.endTime = value.isEmpty ? null : value,
            ),
            placeholder: '23:00',
          ),
          HuiNote(
            huiText(
              'Start is inclusive and end is exclusive. Equal times cover the full day. Overnight windows use the weekday after midnight. No selected weekdays means every day.',
            ),
          ),
          for (final (int day, String label) in <(int, String)>[
            (1, huiText('Monday')),
            (2, huiText('Tuesday')),
            (3, huiText('Wednesday')),
            (4, huiText('Thursday')),
            (5, huiText('Friday')),
            (6, huiText('Saturday')),
            (7, huiText('Sunday')),
          ])
            HuiSwitchRow(
              label: _label(label),
              value: selector.days?.contains(day) ?? false,
              onChanged: (bool enabled) => _selector('weekdays', (
                GlossMotdSelector next,
              ) {
                final List<int> days = List<int>.of(next.days ?? const <int>[]);
                if (enabled) {
                  if (!days.contains(day)) days.add(day);
                } else {
                  days.removeWhere((int value) => value == day);
                }
                next.days = days..sort();
              }),
            ),
          _text(
            _label(huiText('Matching states')),
            selector.states?.join('\n') ?? '',
            (String value) => _selector(
              'matching states',
              (GlossMotdSelector next) => next.states = _lines(value),
            ),
            multiline: true,
          ),
          _number(
            _label(huiText('Minimum real online')),
            selector.minOnline,
            (int? value) => _selector(
              'minimum online',
              (GlossMotdSelector next) => next.minOnline = value,
            ),
          ),
          _number(
            _label(huiText('Maximum real online')),
            selector.maxOnline,
            (int? value) => _selector(
              'maximum online',
              (GlossMotdSelector next) => next.maxOnline = value,
            ),
          ),
          HuiInlineIssues(
            store.issues
                .where(
                  (issue) => issue.path.startsWith('entries[$index].select'),
                )
                .toList(),
          ),
        ],
      ),
      InspectorSection(
        title: huiText('Ping presentation policy'),
        sectionKey: 'motd.entry.$index.policy',
        children: <Widget>[
          _text(
            _label(huiText('Icon set')),
            entry.icons?.join('\n') ?? '',
            (String value) => _edit(
              'entry icons',
              (GlossMotdEntry next) => next.icons = _lines(value),
            ),
            multiline: true,
          ),
          _choice(
            _label(huiText('Sample mode')),
            entry.sampleMode ?? '',
            const <String>['', 'inherit', 'replace', 'hide'],
            (String value) => _edit(
              'sample mode',
              (GlossMotdEntry next) =>
                  next.sampleMode = value.isEmpty ? null : value,
            ),
          ),
          _choice(
            _label(huiText('Online count mode')),
            counts.onlineMode ?? 'inherit',
            const <String>['inherit', 'fixed', 'offset'],
            (String value) => _counts(
              'online count mode',
              (GlossMotdCounts next) => next.onlineMode = value,
            ),
          ),
          _number(
            _label(huiText('Online count value')),
            counts.onlineValue,
            (int? value) => _counts(
              'online count value',
              (GlossMotdCounts next) => next.onlineValue = value,
            ),
            placeholder: '0',
          ),
          _choice(
            _label(huiText('Maximum count mode')),
            counts.maximumMode ?? 'inherit',
            const <String>['inherit', 'fixed', 'offset'],
            (String value) => _counts(
              'maximum count mode',
              (GlossMotdCounts next) => next.maximumMode = value,
            ),
          ),
          _number(
            _label(huiText('Maximum count value')),
            counts.maximumValue,
            (int? value) => _counts(
              'maximum count value',
              (GlossMotdCounts next) => next.maximumValue = value,
            ),
            placeholder: '0',
          ),
          HuiSwitchRow(
            label: _label(huiText('Hide player counts')),
            value: counts.hide == true,
            onChanged: (bool value) => _counts(
              'hide counts',
              (GlossMotdCounts next) => next.hide = value,
            ),
          ),
          HuiNote(
            huiText(
              'Fixed and offset policies override count expressions. Hidden counts and sample controls require Paper or Velocity. These fields do not change admission limits.',
            ),
          ),
          HuiInlineIssues(
            store.issues
                .where(
                  (issue) =>
                      issue.path.startsWith('entries[$index].counts') ||
                      issue.path.startsWith('entries[$index].icons') ||
                      issue.path == 'entries[$index].sampleMode',
                )
                .toList(),
          ),
        ],
      ),
    ]);
  }
}

Widget _text(
  String label,
  String value,
  void Function(String) changed, {
  bool multiline = false,
  String? placeholder,
}) => multiline
    ? TextArea(
        label: label,
        value: value,
        onChanged: changed,
        placeholder: placeholder,
        fullWidth: true,
      )
    : HuiField(
        label: label,
        control: TextInput(
          value: value,
          onChanged: changed,
          placeholder: placeholder,
          fullWidth: true,
          attributes: <String, String>{'aria-label': label},
        ),
      );

Widget _number(
  String label,
  int? value,
  void Function(int?) changed, {
  String? placeholder,
}) => _text(label, value?.toString() ?? '', (String text) {
  if (text.trim().isEmpty) {
    changed(null);
    return;
  }
  final int? number = int.tryParse(text);
  if (number != null) changed(number);
}, placeholder: placeholder);

Widget _choice(
  String label,
  String value,
  List<String> options,
  void Function(String) changed,
) => ArcaneSelect(
  label: label,
  value: value,
  fullWidth: true,
  options: <ArcaneSelectOption>[
    for (final String option in options)
      ArcaneSelectOption(
        value: option,
        label: option.isEmpty ? huiText('Automatic') : option,
      ),
  ],
  onChanged: changed,
);

List<String>? _lines(String value) => value.isEmpty
    ? null
    : value.split('\n').map((String line) => line.trim()).toList();
