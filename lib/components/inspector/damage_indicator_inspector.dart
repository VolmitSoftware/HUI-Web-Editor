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
import 'field_help.dart';
import 'inspector_widgets.dart';

class DamageIndicatorInspector extends StatelessWidget {
  const DamageIndicatorInspector({required this.store, super.key});

  final EditorStore store;

  List<HuiIssue> _issuesFor(String path) => store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossDamageIndicatorsDoc? doc = store.damageIndicatorsDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-damage-indicators', <Widget>[
      _header(doc),
      _limits(doc),
      _style(doc, doc.damage, healing: false),
      _style(doc, doc.healing, healing: true),
      _audience(doc),
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
          'Conditional floating combat numbers with complete damage and healing variants.',
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
        help: huiText('Global spawn budget. 1..1000.'),
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
        help: huiText('Visible lifetime. 250..30000 ms.'),
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
        help: huiText('Smaller changes do not spawn an indicator. 0..1000.'),
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
        help: huiText('Digits after the decimal point. 0..4.'),
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
        _condition(
          label: huiText('Event condition'),
          value: style.when,
          path: '$path.when',
          onInput: (String value) => _mutateStyle(
            healing,
            '${noun.toLowerCase()} condition',
            (GlossDamageIndicatorStyle edited) => edited.when = value,
          ),
        ),
        HuiEyebrow(huiText('Default presentation')),
        ..._presentationFields(
          doc,
          style.presentation,
          '$path.presentation',
          (
            String label,
            void Function(GlossDamageIndicatorPresentation) edit,
          ) => _mutateStyle(
            healing,
            label,
            (GlossDamageIndicatorStyle edited) => edit(edited.presentation),
          ),
        ),
        HuiEyebrow(huiText('Conditional variants')),
        for (int index = 0; index < style.variants.length; index++)
          _variant(doc, style, healing, index, path),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: () => _mutateStyle(
            healing,
            'add ${noun.toLowerCase()} variant',
            (GlossDamageIndicatorStyle edited) => edited.variants.add(
              GlossDamageIndicatorVariant(
                id: 'variant-${edited.variants.length + 1}',
                when: 'false',
                presentation: edited.presentation.copy(),
              ),
            ),
          ),
          child: Text(huiText('Add variant')),
        ),
      ],
    );
  }

  Widget _variant(
    GlossDamageIndicatorsDoc doc,
    GlossDamageIndicatorStyle style,
    bool healing,
    int index,
    String stylePath,
  ) {
    final GlossDamageIndicatorVariant variant = style.variants[index];
    final String path = '$stylePath.variants[$index]';
    return dom.div(classes: 'hui-damage-indicator-variant', <Widget>[
      dom.div(classes: 'hui-inspector-title-row', <Widget>[
        HuiEyebrow(
          huiText('Variant {id}', <String, Object?>{
            'id': variant.id.isEmpty ? index + 1 : variant.id,
          }),
        ),
        HuiIconButton(
          label: huiText('Delete variant'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onPressed: () => _mutateStyle(healing, 'delete indicator variant', (
            GlossDamageIndicatorStyle edited,
          ) {
            if (index < edited.variants.length) {
              edited.variants.removeAt(index);
            }
          }),
        ),
      ]),
      HuiField(
        label: huiText('Variant id'),
        control: dom.div(<Widget>[
          TextInput(
            value: variant.id,
            size: ComponentSize.sm,
            fullWidth: true,
            onInput: (String value) => _mutateVariant(
              healing,
              index,
              'indicator variant id',
              (GlossDamageIndicatorVariant edited) => edited.id = value,
            ),
          ),
          HuiInlineIssues(_issuesFor('$path.id')),
        ]),
      ),
      _integer(
        label: huiText('Priority'),
        help: huiText('Highest matching priority wins.'),
        path: '$path.priority',
        value: variant.priority,
        onChanged: (int value) => _mutateVariant(
          healing,
          index,
          'indicator variant priority',
          (GlossDamageIndicatorVariant edited) => edited.priority = value,
        ),
      ),
      _condition(
        label: huiText('Condition'),
        value: variant.when,
        path: '$path.when',
        onInput: (String value) => _mutateVariant(
          healing,
          index,
          'indicator variant condition',
          (GlossDamageIndicatorVariant edited) => edited.when = value,
        ),
      ),
      ..._presentationFields(
        doc,
        variant.presentation,
        '$path.presentation',
        (String label, void Function(GlossDamageIndicatorPresentation) edit) =>
            _mutateVariant(
              healing,
              index,
              label,
              (GlossDamageIndicatorVariant edited) => edit(edited.presentation),
            ),
      ),
    ]);
  }

  List<Widget> _presentationFields(
    GlossDamageIndicatorsDoc doc,
    GlossDamageIndicatorPresentation presentation,
    String path,
    void Function(
      String label,
      void Function(GlossDamageIndicatorPresentation presentation) edit,
    )
    mutate,
  ) => <Widget>[
    HuiField(
      label: huiText('Text format'),
      help: huiText('Minecraft text containing {amount}.'),
      control: dom.div(<Widget>[
        TextInput(
          value: presentation.format,
          size: ComponentSize.sm,
          fullWidth: true,
          onInput: (String value) => mutate(
            'indicator format',
            (GlossDamageIndicatorPresentation edited) => edited.format = value,
          ),
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
        dom.div(classes: 'hui-damage-indicator-format-preview', <Widget>[
          GlossTextLine(
            render: renderGlossLine(
              renderDamageIndicatorText(
                presentation,
                7.25,
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
      control: dom.div(<Widget>[
        HuiVec3Field(
          value: presentation.offset,
          labels: <String>[huiText('X'), huiText('Y'), huiText('Z')],
          onChanged: (Vec3 value) => mutate(
            'indicator offset',
            (GlossDamageIndicatorPresentation edited) => edited.offset = value,
          ),
        ),
        HuiInlineIssues(_issuesFor('$path.offset')),
      ]),
    ),
    _decimal(
      label: huiText('Horizontal speed'),
      help: huiText('Outward speed. 0..16.'),
      path: '$path.motion.horizontalSpeed',
      value: presentation.motion.horizontalSpeed,
      onChanged: (double value) => mutate(
        'indicator horizontal speed',
        (GlossDamageIndicatorPresentation edited) =>
            edited.motion.horizontalSpeed = value,
      ),
    ),
    _decimal(
      label: huiText('Vertical speed'),
      help: huiText('Initial vertical speed. -16..16.'),
      path: '$path.motion.verticalSpeed',
      value: presentation.motion.verticalSpeed,
      onChanged: (double value) => mutate(
        'indicator vertical speed',
        (GlossDamageIndicatorPresentation edited) =>
            edited.motion.verticalSpeed = value,
      ),
    ),
    _decimal(
      label: huiText('Vertical acceleration'),
      help: huiText('Vertical acceleration. -32..32.'),
      path: '$path.motion.verticalAcceleration',
      value: presentation.motion.verticalAcceleration,
      onChanged: (double value) => mutate(
        'indicator vertical acceleration',
        (GlossDamageIndicatorPresentation edited) =>
            edited.motion.verticalAcceleration = value,
      ),
    ),
    _decimal(
      label: huiText('Spin'),
      help: huiText('Degrees per second. -1440..1440.'),
      path: '$path.motion.spinDegreesPerSecond',
      value: presentation.motion.spinDegreesPerSecond,
      step: 5,
      onChanged: (double value) => mutate(
        'indicator spin',
        (GlossDamageIndicatorPresentation edited) =>
            edited.motion.spinDegreesPerSecond = value,
      ),
    ),
    _decimal(
      label: huiText('Start scale'),
      help: huiText('Scale at spawn. 0..16.'),
      path: '$path.transform.startScale',
      value: presentation.transform.startScale,
      onChanged: (double value) => mutate(
        'indicator start scale',
        (GlossDamageIndicatorPresentation edited) =>
            edited.transform.startScale = value,
      ),
    ),
    _decimal(
      label: huiText('End scale'),
      help: huiText('Scale at expiry. 0..16.'),
      path: '$path.transform.endScale',
      value: presentation.transform.endScale,
      onChanged: (double value) => mutate(
        'indicator end scale',
        (GlossDamageIndicatorPresentation edited) =>
            edited.transform.endScale = value,
      ),
    ),
    _decimal(
      label: huiText('Fade start'),
      help: huiText('Lifetime fraction where fading begins. 0..1.'),
      path: '$path.transform.fadeStartFraction',
      value: presentation.transform.fadeStartFraction,
      onChanged: (double value) => mutate(
        'indicator fade start',
        (GlossDamageIndicatorPresentation edited) =>
            edited.transform.fadeStartFraction = value,
      ),
    ),
  ];

  Widget _audience(GlossDamageIndicatorsDoc doc) => InspectorSection(
    title: huiText('Audience'),
    description: huiText('Evaluated independently for every viewer.'),
    children: <Widget>[
      _condition(
        label: huiText('Viewer condition'),
        value: doc.audience.when,
        path: r'$.audience.when',
        onInput: (String value) => _mutate(
          'indicator audience condition',
          (GlossDamageIndicatorsDoc edited) => edited.audience.when = value,
        ),
      ),
    ],
  );

  Widget _condition({
    required String label,
    required String value,
    required String path,
    required void Function(String value) onInput,
  }) => HuiField(
    label: label,
    trailing: const HuiFieldHelp('condition.when'),
    control: dom.div(<Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText("viewer.world == 'world'"),
        onInput: onInput,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
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

  void _mutateVariant(
    bool healing,
    int index,
    String label,
    void Function(GlossDamageIndicatorVariant variant) change,
  ) => _mutateStyle(healing, label, (GlossDamageIndicatorStyle style) {
    if (index < style.variants.length) change(style.variants[index]);
  });
}
