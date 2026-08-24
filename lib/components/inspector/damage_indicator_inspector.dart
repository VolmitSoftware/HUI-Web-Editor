library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/damage_indicator_preview.dart';
import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'inspector_widgets.dart';

class DamageIndicatorInspector extends StatelessWidget {
  const DamageIndicatorInspector({required this.store, super.key});

  final EditorStore store;

  GlossDamageIndicatorsDoc? get _doc => store.damageIndicatorsDoc;

  List<HuiIssue> _issuesFor(String path) => store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossDamageIndicatorsDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-damage-indicators', <Widget>[
      _header(doc),
      _limits(doc),
      _style(doc, doc.damage, healing: false),
      _style(doc, doc.healing, healing: true),
      _filters(doc),
    ]);
  }

  Widget _header(
    GlossDamageIndicatorsDoc doc,
  ) => dom.div(classes: 'hui-inspector-headgroup', <Widget>[
    dom.div(classes: 'hui-inspector-header is-damage-indicators', <Widget>[
      HuiEyebrow(huiText('Damage indicators')),
      dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
        Text(store.menuId),
      ]),
    ]),
    dom.p(classes: 'hui-inspector-lede', <Widget>[
      Text(
        huiText(
          'Floating combat numbers with independent damage and healing motion.',
        ),
      ),
    ]),
    HuiRevisionRow(revision: doc.revision),
  ]);

  Widget _limits(GlossDamageIndicatorsDoc doc) => InspectorSection(
    title: huiText('Admission and formatting'),
    children: <Widget>[
      _integer(
        label: huiText('Maximum per second'),
        help: huiText(
          'Global spawn budget before new combat numbers are dropped. 1..1000.',
        ),
        path: r'$.limits.maxPerSecond',
        value: doc.limits.maxPerSecond,
        onChanged: (int value) => _mutate(
          'indicator spawn budget',
          (GlossDamageIndicatorsDoc edited) =>
              edited.limits.maxPerSecond = value,
        ),
      ),
      HuiField(
        label: huiText('Lifetime'),
        help: huiText('How long one indicator remains visible. 250..30000 ms.'),
        control: dom.div(<Widget>[
          HuiDurationField(
            value: doc.limits.lifetimeMs.toDouble(),
            unit: HuiDurationUnit.milliseconds,
            onChanged: (double value) => _mutate(
              'indicator lifetime',
              (GlossDamageIndicatorsDoc edited) =>
                  edited.limits.lifetimeMs = value.round(),
            ),
          ),
          HuiInlineIssues(_issuesFor(r'$.limits.lifetimeMs')),
        ]),
      ),
      _decimal(
        label: huiText('Minimum health change'),
        help: huiText(
          'Smaller measured health changes do not spawn an indicator. 0..1000.',
        ),
        path: r'$.limits.minimumDelta',
        value: doc.limits.minimumDelta,
        step: 0.001,
        decimals: 3,
        onChanged: (double value) => _mutate(
          'indicator minimum delta',
          (GlossDamageIndicatorsDoc edited) =>
              edited.limits.minimumDelta = value,
        ),
      ),
      _integer(
        label: huiText('Decimal places'),
        help: huiText('Digits after the decimal point in {amount}. 0..4.'),
        path: r'$.limits.decimals',
        value: doc.limits.decimals,
        onChanged: (int value) => _mutate(
          'indicator decimals',
          (GlossDamageIndicatorsDoc edited) => edited.limits.decimals = value,
        ),
      ),
    ],
  );

  Widget _style(
    GlossDamageIndicatorsDoc doc,
    GlossDamageIndicatorStyle style, {
    required bool healing,
  }) {
    final String path = healing ? r'$.healing' : r'$.damage';
    final String noun = healing ? huiText('Healing') : huiText('Damage');
    return InspectorSection(
      title: noun,
      sectionKey: healing
          ? 'damage-indicators.healing'
          : 'damage-indicators.damage',
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Show {noun} indicators', <String, Object?>{
            'noun': noun.toLowerCase(),
          }),
          value: style.enabled,
          onChanged: (bool value) => _mutateStyle(
            healing,
            '${noun.toLowerCase()} indicator visibility',
            (GlossDamageIndicatorStyle edited) => edited.enabled = value,
          ),
        ),
        HuiField(
          label: huiText('Text format'),
          help: huiText(
            'Minecraft text containing {amount}, replaced by the formatted health change.',
          ),
          control: dom.div(<Widget>[
            TextInput(
              value: style.format,
              size: ComponentSize.sm,
              fullWidth: true,
              onInput: (String value) => _mutateStyle(
                healing,
                '${noun.toLowerCase()} indicator format',
                (GlossDamageIndicatorStyle edited) => edited.format = value,
              ),
              styles: huiTechnicalInputStyles,
              attributes: huiTechnicalInputAttributes,
            ),
            dom.div(classes: 'hui-damage-indicator-format-preview', <Widget>[
              GlossTextLine(
                render: renderGlossLine(
                  renderDamageIndicatorText(
                    style,
                    healing ? 4.5 : 7.25,
                    doc.limits.decimals,
                  ),
                  animations: store.workspaceAnimations,
                  emoji: store.workspaceEmoji,
                ),
              ),
            ]),
            HuiInlineIssues(_issuesFor('$path.format')),
          ]),
        ),
        HuiField(
          label: huiText('Spawn offset'),
          help: huiText('Blocks from the damaged or healed entity.'),
          control: dom.div(<Widget>[
            HuiVec3Field(
              value: style.offset,
              labels: <String>[huiText('X'), huiText('Y'), huiText('Z')],
              axisHints: <String>[
                huiText('Sideways from the entity'),
                huiText('Above the entity origin'),
                huiText('Forward from the entity'),
              ],
              onChanged: (Vec3 value) => _mutateStyle(
                healing,
                '${noun.toLowerCase()} indicator offset',
                (GlossDamageIndicatorStyle edited) => edited.offset = value,
              ),
            ),
            HuiInlineIssues(_issuesFor('$path.offset')),
          ]),
        ),
        _decimal(
          label: huiText('Horizontal speed'),
          help: huiText('Outward travel in blocks per second. 0..16.'),
          path: '$path.motion.horizontalSpeed',
          value: style.motion.horizontalSpeed,
          onChanged: (double value) => _mutateMotion(
            healing,
            '${noun.toLowerCase()} horizontal speed',
            (GlossDamageIndicatorMotion edited) =>
                edited.horizontalSpeed = value,
          ),
        ),
        _decimal(
          label: huiText('Vertical speed'),
          help: huiText(
            'Initial vertical travel in blocks per second. -16..16.',
          ),
          path: '$path.motion.verticalSpeed',
          value: style.motion.verticalSpeed,
          onChanged: (double value) => _mutateMotion(
            healing,
            '${noun.toLowerCase()} vertical speed',
            (GlossDamageIndicatorMotion edited) => edited.verticalSpeed = value,
          ),
        ),
        _decimal(
          label: huiText('Vertical acceleration'),
          help: huiText(
            'Curve acceleration in blocks per second squared. -32..32.',
          ),
          path: '$path.motion.verticalAcceleration',
          value: style.motion.verticalAcceleration,
          onChanged: (double value) => _mutateMotion(
            healing,
            '${noun.toLowerCase()} vertical acceleration',
            (GlossDamageIndicatorMotion edited) =>
                edited.verticalAcceleration = value,
          ),
        ),
        _decimal(
          label: huiText('Spin'),
          help: huiText(
            'Screen-plane roll in degrees per second. -1440..1440.',
          ),
          path: '$path.motion.spinDegreesPerSecond',
          value: style.motion.spinDegreesPerSecond,
          step: 5,
          onChanged: (double value) => _mutateMotion(
            healing,
            '${noun.toLowerCase()} indicator spin',
            (GlossDamageIndicatorMotion edited) =>
                edited.spinDegreesPerSecond = value,
          ),
        ),
        _decimal(
          label: huiText('Start scale'),
          help: huiText('TextDisplay scale at spawn. 0..16.'),
          path: '$path.presentation.startScale',
          value: style.presentation.startScale,
          onChanged: (double value) => _mutatePresentation(
            healing,
            '${noun.toLowerCase()} start scale',
            (GlossDamageIndicatorPresentation edited) =>
                edited.startScale = value,
          ),
        ),
        _decimal(
          label: huiText('End scale'),
          help: huiText('TextDisplay scale at expiry. 0..16.'),
          path: '$path.presentation.endScale',
          value: style.presentation.endScale,
          onChanged: (double value) => _mutatePresentation(
            healing,
            '${noun.toLowerCase()} end scale',
            (GlossDamageIndicatorPresentation edited) =>
                edited.endScale = value,
          ),
        ),
        _decimal(
          label: huiText('Fade start'),
          help: huiText(
            'Lifetime fraction where opacity begins falling to zero. 0..1.',
          ),
          path: '$path.presentation.fadeStartFraction',
          value: style.presentation.fadeStartFraction,
          onChanged: (double value) => _mutatePresentation(
            healing,
            '${noun.toLowerCase()} fade start',
            (GlossDamageIndicatorPresentation edited) =>
                edited.fadeStartFraction = value,
          ),
        ),
      ],
    );
  }

  Widget _filters(GlossDamageIndicatorsDoc doc) => InspectorSection(
    title: huiText('World filters'),
    description: huiText(
      'Indicators never spawn in these exact world folder names.',
    ),
    children: <Widget>[
      for (int index = 0; index < doc.filters.disabledWorlds.length; index++)
        dom.div(classes: 'hui-damage-indicator-world-row', <Widget>[
          TextInput(
            value: doc.filters.disabledWorlds[index],
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: huiText('world_nether'),
            onInput: (String value) => _mutate(
              'edit disabled indicator world',
              (GlossDamageIndicatorsDoc edited) {
                if (index < edited.filters.disabledWorlds.length) {
                  edited.filters.disabledWorlds[index] = value;
                }
              },
            ),
          ),
          HuiIconButton(
            label: huiText('Remove world'),
            icon: ArcaneIcon.trash2(size: IconSize.sm),
            onPressed: () => _mutate('remove disabled indicator world', (
              GlossDamageIndicatorsDoc edited,
            ) {
              if (index < edited.filters.disabledWorlds.length) {
                edited.filters.disabledWorlds.removeAt(index);
              }
            }),
          ),
        ]),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: () => _mutate(
          'add disabled indicator world',
          (GlossDamageIndicatorsDoc edited) =>
              edited.filters.disabledWorlds.add(''),
        ),
        child: Text(huiText('Add world')),
      ),
      HuiInlineIssues(_issuesFor(r'$.filters.disabledWorlds')),
    ],
  );

  Widget _integer({
    required String label,
    required String help,
    required String path,
    required int value,
    required void Function(int value) onChanged,
  }) => HuiField(
    label: label,
    help: help,
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value.toDouble(),
        step: 1,
        decimals: 0,
        integer: true,
        onChanged: (double parsed) => onChanged(parsed.round()),
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _decimal({
    required String label,
    required String help,
    required String path,
    required double value,
    required void Function(double value) onChanged,
    double step = 0.05,
    int decimals = 2,
  }) => HuiField(
    label: label,
    help: help,
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value,
        step: step,
        decimals: decimals,
        onChanged: onChanged,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  void _mutate(
    String label,
    void Function(GlossDamageIndicatorsDoc doc) change,
  ) => store.mutateDamageIndicators(label, change);

  void _mutateStyle(
    bool healing,
    String label,
    void Function(GlossDamageIndicatorStyle style) change,
  ) => _mutate(
    label,
    (GlossDamageIndicatorsDoc doc) =>
        change(healing ? doc.healing : doc.damage),
  );

  void _mutateMotion(
    bool healing,
    String label,
    void Function(GlossDamageIndicatorMotion motion) change,
  ) => _mutateStyle(
    healing,
    label,
    (GlossDamageIndicatorStyle style) => change(style.motion),
  );

  void _mutatePresentation(
    bool healing,
    String label,
    void Function(GlossDamageIndicatorPresentation presentation) change,
  ) => _mutateStyle(
    healing,
    label,
    (GlossDamageIndicatorStyle style) => change(style.presentation),
  );
}
