library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/model.dart';
import '../../logic/player_identity_preview.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class IdentityRulesEditor extends StatelessWidget {
  const IdentityRulesEditor({required this.store, super.key});

  final EditorStore store;

  void _change(String label, void Function() change) =>
      store.mutateGloss(label, (GlossDoc doc) => change());

  Widget _text(
    String label,
    String value,
    void Function(String) changed, {
    String? help,
  }) => HuiField(
    label: label,
    help: help,
    control: TextInput(
      value: value,
      size: ComponentSize.sm,
      fullWidth: true,
      attributes: <String, String>{'aria-label': label},
      onChanged: (String value) => _change(label, () => changed(value)),
    ),
  );

  Widget _priority(int value, void Function(int) changed) => HuiField(
    label: 'Priority',
    help: 'Higher matching priorities win.',
    control: HuiNumberField(
      value: value.toDouble(),
      min: -1000,
      max: 1000,
      onChanged: (double value) =>
          _change('priority', () => changed(value.round())),
    ),
  );

  List<Widget> _nametag(GlossNametagPresentation value) => <Widget>[
    _text('Prefix', value.prefix, (String next) => value.prefix = next),
    _text('Suffix', value.suffix, (String next) => value.suffix = next),
    HuiField(
      label: 'Name color',
      control: ArcaneSelect(
        value: value.color,
        size: ComponentSize.sm,
        options: <ArcaneSelectOption>[
          for (final String color in glossTeamColors.keys)
            ArcaneSelectOption(value: color, label: color),
        ],
        onChanged: (String next) =>
            _change('name color', () => value.color = next),
      ),
    ),
    HuiField(
      label: 'Name visibility',
      control: ArcaneSelect(
        value: value.nameTagVisibility,
        size: ComponentSize.sm,
        options: <ArcaneSelectOption>[
          for (final String option in glossNametagVisibilities)
            ArcaneSelectOption(value: option, label: option),
        ],
        onChanged: (String next) =>
            _change('visibility', () => value.nameTagVisibility = next),
      ),
    ),
    HuiField(
      label: 'Collision',
      control: ArcaneSelect(
        value: value.collision,
        size: ComponentSize.sm,
        options: <ArcaneSelectOption>[
          for (final String option in glossNametagCollisions)
            ArcaneSelectOption(value: option, label: option),
        ],
        onChanged: (String next) =>
            _change('collision', () => value.collision = next),
      ),
    ),
  ];

  List<Widget> _nameplate(GlossNameplatePresentation value) => <Widget>[
    for (int index = 0; index < value.lines.length; index++) ...<Widget>[
      _text(
        'Line ${index + 1}',
        value.lines[index].text,
        (String next) => value.lines[index].text = next,
      ),
      _text(
        'Line ${index + 1} condition',
        '${value.lines[index].show ?? 'true'}',
        (String next) => value.lines[index].show = next,
      ),
      Button(
        label: 'Remove line ${index + 1}',
        variant: ButtonVariant.ghost,
        onPressed: () =>
            _change('remove line', () => value.lines.removeAt(index)),
      ),
    ],
    Button(
      label: 'Add line',
      variant: ButtonVariant.outline,
      onPressed: () => _change(
        'add line',
        () => value.lines.add(GlossNameplateLine(text: '&f{{ subject.name }}')),
      ),
    ),
    HuiField(
      label: 'Offset',
      control: HuiNumberField(
        value: value.offset,
        min: -2,
        max: 8,
        onChanged: (double next) =>
            _change('offset', () => value.offset = next),
      ),
    ),
    HuiSwitchRow(
      label: 'Hide while sneaking',
      value: value.hideSneaking,
      onChanged: (bool next) =>
          _change('hide sneaking', () => value.hideSneaking = next),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final GlossNametagDoc? nametag = store.nametagDoc;
    final GlossNameplateDoc? nameplate = store.nameplateDoc;
    final GlossPrioritySelect? select = nametag?.select ?? nameplate?.select;
    if (select == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-identity-rules', <Widget>[
      const dom.h3(<Widget>[Text('Assignment')]),
      _text(
        'Required permission',
        select.permission,
        (String value) => select.permission = value,
        help:
            'Granted to the player wearing this style. Blank allows everyone.',
      ),
      _priority(select.priority, (int value) => select.priority = value),
      _text(
        'Condition',
        select.when,
        (String value) => select.when = value,
        help: 'The permission and this condition must both match.',
      ),
      const dom.h3(<Widget>[Text('Permission variants')]),
      if (nametag != null)
        for (int index = 0; index < nametag.variants.length; index++)
          _nametagVariant(nametag, index),
      if (nameplate != null)
        for (int index = 0; index < nameplate.variants.length; index++)
          _nameplateVariant(nameplate, index),
      Button(
        label: 'Add permission variant',
        variant: ButtonVariant.outline,
        onPressed: () => _change('add permission variant', () {
          if (nametag != null) {
            int number = nametag.variants.length + 1;
            while (nametag.variants.any(
              (GlossNametagVariant entry) => entry.id == 'rank-$number',
            )) {
              number++;
            }
            nametag.variants.add(
              GlossNametagVariant(
                id: 'rank-$number',
                priority: 10,
                presentation: nametag.presentation.copy(),
              )..permission = 'gloss.nametag.rank$number',
            );
          } else if (nameplate != null) {
            int number = nameplate.variants.length + 1;
            while (nameplate.variants.any(
              (GlossNameplateVariant entry) => entry.id == 'rank-$number',
            )) {
              number++;
            }
            nameplate.variants.add(
              GlossNameplateVariant(
                id: 'rank-$number',
                priority: 10,
                presentation: nameplate.presentation.copy(),
              )..permission = 'gloss.nameplate.rank$number',
            );
          }
        }),
      ),
    ]);
  }

  Widget _nametagVariant(GlossNametagDoc doc, int index) {
    final GlossNametagVariant variant = doc.variants[index];
    return dom.div(classes: 'hui-identity-variant', <Widget>[
      _text('Variant id', variant.id, (String value) => variant.id = value),
      _text(
        'Variant permission',
        variant.permission,
        (String value) => variant.permission = value,
      ),
      _priority(variant.priority, (int value) => variant.priority = value),
      _text(
        'Variant condition',
        variant.when,
        (String value) => variant.when = value,
      ),
      ..._nametag(variant.presentation),
      Button(
        label: 'Remove variant',
        variant: ButtonVariant.ghost,
        onPressed: () =>
            _change('remove variant', () => doc.variants.removeAt(index)),
      ),
    ]);
  }

  Widget _nameplateVariant(GlossNameplateDoc doc, int index) {
    final GlossNameplateVariant variant = doc.variants[index];
    return dom.div(classes: 'hui-identity-variant', <Widget>[
      _text('Variant id', variant.id, (String value) => variant.id = value),
      _text(
        'Variant permission',
        variant.permission,
        (String value) => variant.permission = value,
      ),
      _priority(variant.priority, (int value) => variant.priority = value),
      _text(
        'Variant condition',
        variant.when,
        (String value) => variant.when = value,
      ),
      ..._nameplate(variant.presentation),
      Button(
        label: 'Remove variant',
        variant: ButtonVariant.ghost,
        onPressed: () =>
            _change('remove variant', () => doc.variants.removeAt(index)),
      ),
    ]);
  }
}
