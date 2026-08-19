/// Inspector body for a Gloss bubble-style document: the prefix and offset,
/// the three silently-clamped numbers (with their effective values), the
/// behavior switches, and the optional select rule.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import '../../logic/gloss_text.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

class BubbleInspector extends StatefulWidget {
  const BubbleInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<BubbleInspector> createState() => _BubbleInspectorState();
}

class _BubbleInspectorState extends State<BubbleInspector> {
  EditorStore get _store => component.store;

  GlossBubbleStyleDoc? get _doc => _store.bubbleStyleDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossBubbleStyleDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-bubble', <Widget>[
      _header(doc),
      _look(doc),
      _timing(doc),
      _behavior(doc),
      _selection(doc),
    ]);
  }

  Widget _header(GlossBubbleStyleDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-bubble', <Widget>[
          const HuiEyebrow('Bubble style'),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('bubble.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            'How chat bubbles look and move for players this style selects. '
            'Revision ${doc.revision} is server-owned and travels with the '
            'file.',
          ),
        ]),
      ]);

  Widget _look(GlossBubbleStyleDoc doc) => InspectorSection(
    title: 'Look',
    children: <Widget>[
      HuiField(
        label: 'Prefix',
        trailing: const HuiFieldHelp('bubble.prefix'),
        help:
            'Colour codes prepended to every bubble line. Leaving the key '
            'out of the file means &7; an explicit empty string stays '
            'empty.',
        control: dom.div(<Widget>[
          TextInput(
            value: doc.prefix,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: '&7',
            onInput: (String value) => _store.mutateBubbleStyle(
              'bubble prefix',
              (GlossBubbleStyleDoc edited) {
                edited.prefix = value;
                edited.absentKeys.remove('prefix');
              },
            ),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          dom.div(classes: 'hui-hologram-line-preview', <Widget>[
            GlossTextLine(
              render: renderGlossLine(
                '${doc.effectivePrefix}Like this bubble line',
              ),
            ),
          ]),
        ]),
      ),
      HuiField(
        label: 'Offset',
        trailing: const HuiFieldHelp('bubble.offset'),
        help:
            'Blocks added to the sender\'s eye location before stacking. '
            'The shipped default floats one block up.',
        control: dom.div(<Widget>[
          HuiVec3Field(
            value: Vec3(doc.offset[0], doc.offset[1], doc.offset[2]),
            onChanged: (Vec3 value) => _store.mutateBubbleStyle(
              'bubble offset',
              (GlossBubbleStyleDoc edited) =>
                  edited.setOffset(value.x, value.y, value.z),
            ),
          ),
          HuiInlineIssues(_issuesFor(r'$.offset')),
        ]),
      ),
    ],
  );

  Widget _timing(GlossBubbleStyleDoc doc) => InspectorSection(
    title: 'Wrap and timing',
    children: <Widget>[
      _clampedNumber(
        label: 'Word wrap',
        helpKey: 'bubble.wordWrapChars',
        help: 'Characters per bubble line before the soft wrap. 8..128.',
        value: doc.wordWrapChars,
        effective: doc.effectiveWordWrapChars,
        path: r'$.wordWrapChars',
        onChanged: (int value) => _store.mutateBubbleStyle(
          'bubble wrap',
          (GlossBubbleStyleDoc edited) {
            edited.wordWrapChars = value;
            edited.absentKeys.remove('wordWrapChars');
          },
        ),
      ),
      _clampedNumber(
        label: 'Line stagger',
        helpKey: 'bubble.lineStaggerTicks',
        help:
            'Ticks between the lines of one message appearing. 0..40 '
            '(a tick is 50 ms).',
        value: doc.lineStaggerTicks,
        effective: doc.effectiveLineStaggerTicks,
        path: r'$.lineStaggerTicks',
        onChanged: (int value) => _store.mutateBubbleStyle(
          'bubble stagger',
          (GlossBubbleStyleDoc edited) {
            edited.lineStaggerTicks = value;
            edited.absentKeys.remove('lineStaggerTicks');
          },
        ),
      ),
      _clampedNumber(
        label: 'Lifetime',
        helpKey: 'bubble.maxAliveMs',
        help:
            'Milliseconds a bubble lives; the fly-away launch eases through '
            'its last 2000. 500..60000.',
        value: doc.maxAliveMs,
        effective: doc.effectiveMaxAliveMs,
        path: r'$.maxAliveMs',
        onChanged: (int value) => _store.mutateBubbleStyle(
          'bubble lifetime',
          (GlossBubbleStyleDoc edited) {
            edited.maxAliveMs = value;
            edited.absentKeys.remove('maxAliveMs');
          },
        ),
      ),
    ],
  );

  Widget _clampedNumber({
    required String label,
    required String helpKey,
    required String help,
    required int value,
    required int effective,
    required String path,
    required void Function(int value) onChanged,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(helpKey),
    help: help,
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value.toDouble(),
        step: 1,
        decimals: 0,
        integer: true,
        onChanged: (double parsed) => onChanged(parsed.round()),
      ),
      if (value != effective)
        HuiNote('The server silently runs $effective.'),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _behavior(GlossBubbleStyleDoc doc) => InspectorSection(
    title: 'Behavior',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Fly away',
        help:
            'Bubbles launch upward through their last two seconds instead '
            'of vanishing in place.',
        trailing: const HuiFieldHelp('bubble.flyAway'),
        value: doc.flyAway,
        onChanged: (bool value) => _store.mutateBubbleStyle(
          'bubble flyAway',
          (GlossBubbleStyleDoc edited) {
            edited.flyAway = value;
            edited.absentKeys.remove('flyAway');
          },
        ),
      ),
      HuiSwitchRow(
        label: 'Follow player',
        help:
            'Bubbles track the sender\'s eyes as they move; off keeps them '
            'where the message was sent.',
        trailing: const HuiFieldHelp('bubble.followPlayer'),
        value: doc.followPlayer,
        onChanged: (bool value) => _store.mutateBubbleStyle(
          'bubble followPlayer',
          (GlossBubbleStyleDoc edited) {
            edited.followPlayer = value;
            edited.absentKeys.remove('followPlayer');
          },
        ),
      ),
      HuiSwitchRow(
        label: 'Hide own',
        help: 'The sender does not see their own bubbles.',
        trailing: const HuiFieldHelp('bubble.hideOwn'),
        value: doc.hideOwn,
        onChanged: (bool value) => _store.mutateBubbleStyle(
          'bubble hideOwn',
          (GlossBubbleStyleDoc edited) {
            edited.hideOwn = value;
            edited.absentKeys.remove('hideOwn');
          },
        ),
      ),
    ],
  );

  Widget _selection(GlossBubbleStyleDoc doc) {
    final GlossBubbleSelect? select = doc.select;
    return InspectorSection(
      title: 'Selection',
      children: <Widget>[
        if (select == null) ...<Widget>[
          const HuiNote(
            'No select rule: players reach this style only by explicit '
            'choice, or as the fallback when the document is named '
            '"default".',
          ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.plus(size: IconSize.sm),
            onPressed: () => _store.mutateBubbleStyle(
              'add select',
              (GlossBubbleStyleDoc edited) =>
                  edited.select = GlossBubbleSelect(),
            ),
            child: const Text('Add select rule'),
          ),
          HuiInlineIssues(_issuesFor(r'$.select')),
        ] else ...<Widget>[
          _selectStrings(
            label: 'World globs',
            helpKey: 'bubble.select.worlds',
            help:
                'World-name patterns with * and ? wildcards. Empty matches '
                'every world.',
            placeholder: 'world*',
            values: select.worlds,
            onEdit: (int index, String value) => _store.mutateBubbleStyle(
              'edit select world',
              (GlossBubbleStyleDoc edited) {
                final GlossBubbleSelect? live = edited.select;
                if (live != null && index < live.worlds.length) {
                  live.worlds[index] = value;
                }
              },
            ),
            onRemove: (int index) => _store.mutateBubbleStyle(
              'remove select world',
              (GlossBubbleStyleDoc edited) {
                final GlossBubbleSelect? live = edited.select;
                if (live != null && index < live.worlds.length) {
                  live.worlds.removeAt(index);
                }
              },
            ),
            onAdd: () => _store.mutateBubbleStyle(
              'add select world',
              (GlossBubbleStyleDoc edited) {
                final GlossBubbleSelect? live = edited.select;
                if (live != null) {
                  live.worlds.add('');
                  live.absentKeys.remove('worlds');
                }
              },
            ),
            issuesPath: r'$.select.worlds',
          ),
          _selectStrings(
            label: 'Groups',
            helpKey: 'bubble.select.groups',
            help:
                'Vault group names, lowercased by the server. Empty skips '
                'the group check.',
            placeholder: 'vip',
            values: select.groups,
            onEdit: (int index, String value) => _store.mutateBubbleStyle(
              'edit select group',
              (GlossBubbleStyleDoc edited) {
                final GlossBubbleSelect? live = edited.select;
                if (live != null && index < live.groups.length) {
                  live.groups[index] = value;
                }
              },
            ),
            onRemove: (int index) => _store.mutateBubbleStyle(
              'remove select group',
              (GlossBubbleStyleDoc edited) {
                final GlossBubbleSelect? live = edited.select;
                if (live != null && index < live.groups.length) {
                  live.groups.removeAt(index);
                }
              },
            ),
            onAdd: () => _store.mutateBubbleStyle(
              'add select group',
              (GlossBubbleStyleDoc edited) {
                final GlossBubbleSelect? live = edited.select;
                if (live != null) {
                  live.groups.add('');
                  live.absentKeys.remove('groups');
                }
              },
            ),
            issuesPath: r'$.select.groups',
          ),
          HuiField(
            label: 'Priority',
            trailing: const HuiFieldHelp('bubble.select.priority'),
            help:
                'Highest matching priority wins; ties go to the smaller '
                'style id.',
            control: dom.div(<Widget>[
              HuiNumberField(
                value: select.priority.toDouble(),
                step: 1,
                decimals: 0,
                integer: true,
                onChanged: (double parsed) => _store.mutateBubbleStyle(
                  'select priority',
                  (GlossBubbleStyleDoc edited) {
                    final GlossBubbleSelect? live = edited.select;
                    if (live != null) {
                      live.priority = parsed.round();
                      live.absentKeys.remove('priority');
                    }
                  },
                ),
              ),
            ]),
          ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.trash2(size: IconSize.sm),
            onPressed: () => _store.mutateBubbleStyle(
              'remove select',
              (GlossBubbleStyleDoc edited) => edited.select = null,
            ),
            child: const Text('Remove select rule'),
          ),
          HuiInlineIssues(_issuesFor(r'$.select')),
        ],
      ],
    );
  }

  Widget _selectStrings({
    required String label,
    required String helpKey,
    required String help,
    required String placeholder,
    required List<String> values,
    required void Function(int index, String value) onEdit,
    required void Function(int index) onRemove,
    required void Function() onAdd,
    required String issuesPath,
  }) => HuiField(
    label: label,
    trailing: HuiFieldHelp(helpKey),
    help: help,
    control: dom.div(<Widget>[
      for (int index = 0; index < values.length; index++)
        dom.div(classes: 'hui-scoreboard-group-row', <Widget>[
          TextInput(
            value: values[index],
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: placeholder,
            onInput: (String value) => onEdit(index, value),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
          HuiIconButton(
            label: 'Remove $label entry',
            icon: ArcaneIcon.trash2(size: IconSize.sm),
            onPressed: () => onRemove(index),
          ),
        ]),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: onAdd,
        child: Text('Add ${label.toLowerCase()} entry'),
      ),
      HuiInlineIssues(_issuesFor(issuesPath)),
    ]),
  );
}
