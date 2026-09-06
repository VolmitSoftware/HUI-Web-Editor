library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import '../../l10n/hui_localizations.dart';
import '../../logic/validation.dart';
import '../../model/gloss_hologram_box.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class HologramBoxEditor extends StatelessWidget {
  const HologramBoxEditor({
    required this.box,
    required this.mutate,
    this.issues = const <HuiIssue>[],
    this.sectionKey,
    super.key,
  });
  final GlossHologramBox box;
  final void Function(String, void Function(GlossHologramBox)) mutate;
  final List<HuiIssue> issues;
  final String? sectionKey;

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: huiText('Box decoration'),
    sectionKey: sectionKey,
    children: <Widget>[
      HuiSwitchRow(
        label: huiText('Show box'),
        value: box.enabled,
        onChanged: (bool value) => mutate(
          'show box',
          (GlossHologramBox edited) => edited.enabled = value,
        ),
      ),
      if (box.enabled) ...<Widget>[
        HuiField(
          label: huiText('Padding'),
          help: huiText('Space around the text in font pixels. 0..64.'),
          control: HuiNumberField(
            value: box.padding.toDouble(),
            min: 0,
            max: 64,
            step: 1,
            decimals: 0,
            onChanged: (double value) => mutate(
              'box padding',
              (GlossHologramBox edited) => edited.padding = value.round(),
            ),
          ),
        ),
        HuiField(
          label: huiText('Border width'),
          help: huiText('Uniform border width in font pixels. 0..16.'),
          control: HuiNumberField(
            value: box.borderWidth.toDouble(),
            min: 0,
            max: 16,
            step: 1,
            decimals: 0,
            onChanged: (double value) => mutate(
              'box border width',
              (GlossHologramBox edited) => edited.borderWidth = value.round(),
            ),
          ),
        ),
        HuiField(
          label: huiText('Background'),
          control: HuiColorField(
            value: box.backgroundArgb,
            label: huiText('box background'),
            onChanged: (String value) => mutate(
              'box background',
              (GlossHologramBox edited) => edited.backgroundArgb = value,
            ),
          ),
        ),
        HuiField(
          label: huiText('Border color'),
          control: HuiColorField(
            value: box.borderArgb,
            label: huiText('box border'),
            onChanged: (String value) => mutate(
              'box border',
              (GlossHologramBox edited) => edited.borderArgb = value,
            ),
          ),
        ),
      ],
      HuiInlineIssues(issues),
    ],
  );
}
