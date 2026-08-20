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
import '../../logic/bubble_motion.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'preview_expr_field.dart';

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
      _motion(doc),
      _shimmer(doc),
      _behavior(doc),
      _selection(doc),
    ]);
  }

  Widget _header(GlossBubbleStyleDoc doc) => dom.div(
    classes: 'hui-inspector-headgroup',
    <Widget>[
      dom.div(classes: 'hui-inspector-header is-bubble', <Widget>[
        const HuiEyebrow('Bubble style'),
        dom.div(classes: 'hui-inspector-title-row', <Widget>[
          dom.h2(classes: 'hui-inspector-title', <Widget>[Text(_store.menuId)]),
          const HuiFieldHelp('bubble.id'),
        ]),
      ]),
      const dom.p(classes: 'hui-inspector-lede', <Widget>[
        Text('How chat bubbles look and move for players this style selects.'),
      ]),
      HuiRevisionRow(revision: doc.revision),
    ],
  );

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
    sectionKey: 'bubble.timing',
    children: <Widget>[
      _clampedNumber(
        label: 'Word wrap',
        helpKey: 'bubble.wordWrapChars',
        help: 'Characters per bubble line before the soft wrap. 8..128.',
        value: doc.wordWrapChars,
        effective: doc.effectiveWordWrapChars,
        path: r'$.wordWrapChars',
        onChanged: (int value) => _store.mutateBubbleStyle('bubble wrap', (
          GlossBubbleStyleDoc edited,
        ) {
          edited.wordWrapChars = value;
          edited.absentKeys.remove('wordWrapChars');
        }),
      ),
      _clampedNumber(
        label: 'Lifetime',
        helpKey: 'bubble.maxAliveMs',
        help: 'Milliseconds a bubble block lives. 500..60000.',
        value: doc.maxAliveMs,
        effective: doc.effectiveMaxAliveMs,
        path: r'$.maxAliveMs',
        unit: HuiDurationUnit.milliseconds,
        step: 500,
        onChanged: (int value) => _store.mutateBubbleStyle('bubble lifetime', (
          GlossBubbleStyleDoc edited,
        ) {
          edited.maxAliveMs = value;
          edited.absentKeys.remove('maxAliveMs');
        }),
      ),
    ],
  );

  Widget _motion(GlossBubbleStyleDoc doc) => InspectorSection(
    title: 'Motion',
    sectionKey: 'bubble.motion',
    children: <Widget>[
      const HuiNote(
        'Every field is a live expression. Use t (0..1), remaining, ageMs, '
        'lifetimeMs, stackIndex, stackCount, lineCount, stackY, seed and pi.',
      ),
      dom.div(classes: 'hui-bubble-motion-presets', <Widget>[
        _motionPreset('Static', GlossBubbleMotion.identity),
        _motionPreset('Legacy fly-away', GlossBubbleMotion.legacyFlyAway),
        _motionPreset('Fly up', _flyUpMotion),
        _motionPreset('Fade away', _fadeMotion),
        _motionPreset('Shrink away', _shrinkMotion),
        _motionPreset('Arc + fall', _arcMotion),
      ]),
      _motionVector(
        title: 'Translation (blocks)',
        path: r'$.motion.translation',
        vector: doc.motion.translation,
        onEdit: (GlossBubbleMotion edited) => edited.translation,
      ),
      _motionVector(
        title: 'Scale',
        path: r'$.motion.scale',
        vector: doc.motion.scale,
        onEdit: (GlossBubbleMotion edited) => edited.scale,
      ),
      _motionVector(
        title: 'Rotation (degrees)',
        path: r'$.motion.rotation',
        vector: doc.motion.rotation,
        onEdit: (GlossBubbleMotion edited) => edited.rotation,
      ),
      PreviewExprField(
        label: 'Opacity',
        raw: doc.motion.opacity,
        kind: PreviewExprKind.string,
        required: true,
        placeholder: '1 - smoothstep(0.7, 1, t)',
        help: 'Runtime clamps the result to 0..1.',
        scope: glossBubbleMotionVariables,
        issues: _issuesFor(r'$.motion.opacity'),
        onChanged: (Object? value) => _store.mutateBubbleStyle(
          'bubble motion opacity',
          (GlossBubbleStyleDoc edited) =>
              edited.motion.opacity = value as String? ?? '1',
        ),
      ),
    ],
  );

  Widget _motionPreset(String label, GlossBubbleMotion Function() create) =>
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: () => _store.mutateBubbleStyle(
          'bubble motion preset',
          (GlossBubbleStyleDoc edited) => edited.motion = create(),
        ),
        child: Text(label),
      );

  Widget _motionVector({
    required String title,
    required String path,
    required GlossBubbleMotionVector vector,
    required GlossBubbleMotionVector Function(GlossBubbleMotion motion) onEdit,
  }) => dom.div(<Widget>[
    const dom.div(classes: 'hui-field-separator', <Widget>[]),
    const HuiEyebrow('Vector'),
    dom.div(classes: 'hui-bubble-motion-grid', <Widget>[
      for (final (String, String) axis in <(String, String)>[
        ('X', vector.x),
        ('Y', vector.y),
        ('Z', vector.z),
      ])
        PreviewExprField(
          label: '$title ${axis.$1}',
          raw: axis.$2,
          kind: PreviewExprKind.string,
          required: true,
          placeholder: axis.$1 == 'Y' ? '8 * t' : '0',
          scope: glossBubbleMotionVariables,
          issues: _issuesFor('$path.${axis.$1.toLowerCase()}'),
          onChanged: (Object? value) => _store.mutateBubbleStyle(
            'bubble motion ${axis.$1.toLowerCase()}',
            (GlossBubbleStyleDoc edited) {
              final GlossBubbleMotionVector target = onEdit(edited.motion);
              final String next =
                  value as String? ?? (path.endsWith('scale') ? '1' : '0');
              switch (axis.$1) {
                case 'X':
                  target.x = next;
                case 'Y':
                  target.y = next;
                case 'Z':
                  target.z = next;
              }
            },
          ),
        ),
    ]),
  ]);

  static GlossBubbleMotion _flyUpMotion() => GlossBubbleMotion(
    translation: GlossBubbleMotionVector(
      x: '0',
      y: '8 * smoothstep(0, 1, t)',
      z: '0',
    ),
    scale: GlossBubbleMotionVector.scaleDefaults(),
    rotation: GlossBubbleMotionVector.rotationDefaults(),
    opacity: '1',
  );

  static GlossBubbleMotion _fadeMotion() => GlossBubbleMotion(
    translation: GlossBubbleMotionVector(x: '0', y: '1.5 * t', z: '0'),
    scale: GlossBubbleMotionVector.scaleDefaults(),
    rotation: GlossBubbleMotionVector.rotationDefaults(),
    opacity: '1 - smoothstep(0.65, 1, t)',
  );

  static GlossBubbleMotion _shrinkMotion() => GlossBubbleMotion(
    translation: GlossBubbleMotionVector(x: '0', y: '2 * t', z: '0'),
    scale: GlossBubbleMotionVector(
      x: '1 - smoothstep(0.45, 1, t)',
      y: '1 - smoothstep(0.45, 1, t)',
      z: '1 - smoothstep(0.45, 1, t)',
    ),
    rotation: GlossBubbleMotionVector.rotationDefaults(),
    opacity: '1',
  );

  static GlossBubbleMotion _arcMotion() => GlossBubbleMotion(
    translation: GlossBubbleMotionVector(
      x: '4 * t',
      y: '5 * sin(pi * t) - 6 * t',
      z: '2 * sin(pi * 2 * t)',
    ),
    scale: GlossBubbleMotionVector(
      x: '1 - 0.35 * t',
      y: '1 - 0.35 * t',
      z: '1 - 0.35 * t',
    ),
    rotation: GlossBubbleMotionVector(x: '45 * t', y: '90 * t', z: '180 * t'),
    opacity: '1 - smoothstep(0.8, 1, t)',
  );

  Widget _shimmer(GlossBubbleStyleDoc doc) => InspectorSection(
    title: 'Shimmer',
    sectionKey: 'bubble.shimmer',
    children: <Widget>[
      const HuiNote(
        'Original Gloss shine: a solid white three-glyph wave moves left to '
        'right at exactly 30 glyphs a second. Each wrapped row restarts at its '
        'left edge. With the default five-second lifetime it returns after '
        '4.234 seconds while the bubble is flying away.',
      ),
      dom.div(classes: 'hui-bubble-motion-presets', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _store.mutateBubbleStyle(
            'original Gloss shimmer preset',
            (GlossBubbleStyleDoc edited) =>
                edited.shimmer = GlossBubbleShimmer(),
          ),
          child: const Text('Original Gloss'),
        ),
      ]),
      HuiSwitchRow(
        label: 'At spawn',
        help:
            'Anchor the free-running cycle at the bubble\'s birth, after the '
            'configured spawn delay. This is the shine itself, not a one-off '
            'pass.',
        value: doc.shimmer.spawn,
        onChanged: (bool value) => _store.mutateBubbleStyle(
          'bubble spawn shimmer',
          (GlossBubbleStyleDoc edited) => edited.shimmer.spawn = value,
        ),
      ),
      HuiSwitchRow(
        label: 'At fly-away',
        trailing: const HuiFieldHelp('bubble.shimmer.flyAway'),
        help:
            'Adds an EXTRA cycle anchored flyAwayLeadMs before expiry, '
            'alongside whatever motion expressions are active then. Off by '
            'default: the free-running cycle already produces a departure '
            'pass on its own.',
        value: doc.shimmer.flyAway,
        onChanged: (bool value) => _store.mutateBubbleStyle(
          'bubble fly-away shimmer',
          (GlossBubbleStyleDoc edited) => edited.shimmer.flyAway = value,
        ),
      ),
      HuiField(
        label: 'Band color',
        trailing: const HuiFieldHelp('bubble.shimmer.color'),
        help:
            'Every lit glyph in the wave. Exactly six RGB digits in #RRGGBB form.',
        defaultValue: glossBubbleShimmerDefaultColor,
        onReset: doc.shimmer.color == glossBubbleShimmerDefaultColor
            ? null
            : () => _editShimmer(
                'color',
                (GlossBubbleShimmer shimmer) =>
                    shimmer.color = glossBubbleShimmerDefaultColor,
              ),
        control: dom.div(<Widget>[
          HuiColorField(
            value: doc.shimmer.color,
            format: HuiColorFormat.rgb,
            label: 'shimmer band colour',
            placeholder: glossBubbleShimmerDefaultColor,
            onChanged: (String value) => _store.mutateBubbleStyle(
              'bubble shimmer color',
              (GlossBubbleStyleDoc edited) => edited.shimmer.color = value,
            ),
          ),
          HuiInlineIssues(_issuesFor(r'$.shimmer.color')),
        ]),
      ),
      _clampedNumber(
        label: 'Band width',
        help:
            'Visible characters lit at once. The original Gloss width is 3. 1..16.',
        value: doc.shimmer.width,
        effective: doc.shimmer.effectiveWidth,
        path: r'$.shimmer.width',
        defaultValue: '3',
        onReset: doc.shimmer.width == 3
            ? null
            : () => _editShimmer(
                'band width',
                (GlossBubbleShimmer shimmer) => shimmer.width = 3,
              ),
        onChanged: (int value) => _editShimmer(
          'band width',
          (GlossBubbleShimmer shimmer) => shimmer.width = value,
        ),
      ),
      _clampedNumber(
        label: 'Cycle duration',
        helpKey: 'bubble.shimmer.durationMs',
        help:
            'Milliseconds for one full 127-glyph cycle, not for one pass over '
            'the text: the band travels 127 / duration glyphs a second '
            'whatever the line length. 100..10000.',
        value: doc.shimmer.durationMs,
        effective: doc.shimmer.effectiveDurationMs,
        path: r'$.shimmer.durationMs',
        unit: HuiDurationUnit.milliseconds,
        step: 50,
        defaultValue: '$glossBubbleShimmerDefaultDurationMs ms',
        onReset: doc.shimmer.durationMs == glossBubbleShimmerDefaultDurationMs
            ? null
            : () => _editShimmer(
                'cycle duration',
                (GlossBubbleShimmer shimmer) =>
                    shimmer.durationMs = glossBubbleShimmerDefaultDurationMs,
              ),
        onChanged: (int value) => _editShimmer(
          'cycle duration',
          (GlossBubbleShimmer shimmer) => shimmer.durationMs = value,
        ),
      ),
      _clampedNumber(
        label: 'Spawn delay',
        help: 'Milliseconds after the bubble appears before the cycle starts.',
        value: doc.shimmer.spawnDelayMs,
        effective: doc.shimmer.effectiveSpawnDelayMs,
        path: r'$.shimmer.spawnDelayMs',
        unit: HuiDurationUnit.milliseconds,
        step: 50,
        onChanged: (int value) => _editShimmer(
          'spawn delay',
          (GlossBubbleShimmer shimmer) => shimmer.spawnDelayMs = value,
        ),
      ),
      _clampedNumber(
        label: 'Fly-away lead',
        help:
            'Milliseconds before expiry when the extra cycle restarts from '
            'the left edge. Match or exceed the cycle duration to show a '
            'complete pass.',
        value: doc.shimmer.flyAwayLeadMs,
        effective: doc.shimmer.effectiveFlyAwayLeadMs,
        path: r'$.shimmer.flyAwayLeadMs',
        unit: HuiDurationUnit.milliseconds,
        step: 50,
        onChanged: (int value) => _editShimmer(
          'fly-away lead',
          (GlossBubbleShimmer shimmer) => shimmer.flyAwayLeadMs = value,
        ),
      ),
    ],
  );

  void _editShimmer(String label, void Function(GlossBubbleShimmer s) edit) =>
      _store.mutateBubbleStyle(
        'bubble shimmer $label',
        (GlossBubbleStyleDoc edited) => edit(edited.shimmer),
      );

  /// Every silently-clamped integer in this document, in one shape: the value,
  /// what the server will actually run, and the field help when there is one.
  /// Time-valued ones read back in seconds.
  ///
  /// The shimmer group used to have its own near-identical copy of this, which
  /// differed only in never mounting field help and never showing a unit.
  Widget _clampedNumber({
    required String label,
    required String help,
    required int value,
    required int effective,
    required String path,
    required void Function(int value) onChanged,
    String? helpKey,
    String? defaultValue,
    void Function()? onReset,
    HuiDurationUnit? unit,
    double step = 1,
  }) => HuiField(
    label: label,
    trailing: helpKey == null ? null : HuiFieldHelp(helpKey),
    help: help,
    defaultValue: defaultValue,
    onReset: onReset,
    control: dom.div(<Widget>[
      if (unit == null)
        HuiNumberField(
          value: value.toDouble(),
          step: step,
          decimals: 0,
          integer: true,
          onChanged: (double parsed) => onChanged(parsed.round()),
        )
      else
        HuiDurationField(
          value: value.toDouble(),
          unit: unit,
          step: step,
          onChanged: (double parsed) => onChanged(parsed.round()),
        ),
      if (value != effective) HuiNote('The server silently runs $effective.'),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _behavior(GlossBubbleStyleDoc doc) => InspectorSection(
    title: 'Behavior',
    children: <Widget>[
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
        onChanged: (bool value) => _store.mutateBubbleStyle('bubble hideOwn', (
          GlossBubbleStyleDoc edited,
        ) {
          edited.hideOwn = value;
          edited.absentKeys.remove('hideOwn');
        }),
      ),
    ],
  );

  Widget _selection(GlossBubbleStyleDoc doc) {
    final GlossBubbleSelect? select = doc.select;
    return InspectorSection(
      title: 'Selection',
      sectionKey: 'bubble.selection',
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
            onAdd: () => _store.mutateBubbleStyle('add select world', (
              GlossBubbleStyleDoc edited,
            ) {
              final GlossBubbleSelect? live = edited.select;
              if (live != null) {
                live.worlds.add('');
                live.absentKeys.remove('worlds');
              }
            }),
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
            onAdd: () => _store.mutateBubbleStyle('add select group', (
              GlossBubbleStyleDoc edited,
            ) {
              final GlossBubbleSelect? live = edited.select;
              if (live != null) {
                live.groups.add('');
                live.absentKeys.remove('groups');
              }
            }),
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
