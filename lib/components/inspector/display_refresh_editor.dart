import 'package:arcane_jaspr/arcane_jaspr.dart';

import '../../l10n/hui_localizations.dart';
import '../../model/gloss_display_refresh.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class DisplayRefreshEditor extends StatelessWidget {
  const DisplayRefreshEditor({
    required this.refresh,
    required this.onChanged,
    super.key,
  });
  final GlossDisplayRefresh refresh;
  final void Function(String, GlossDisplayRefresh) onChanged;

  void _edit(String label, void Function(GlossDisplayRefresh) edit) {
    final GlossDisplayRefresh next = refresh.copy();
    edit(next);
    onChanged(label, next);
  }

  List<Widget> _interval(
    String label,
    int? value,
    void Function(GlossDisplayRefresh, int?) edit,
  ) => <Widget>[
    HuiSwitchRow(
      label: huiText('Override {label} interval', <String, Object?>{
        'label': huiText(label),
      }),
      value: value != null,
      onChanged: (bool enabled) => _edit(
        'refresh $label',
        (GlossDisplayRefresh next) => edit(next, enabled ? 2 : null),
      ),
    ),
    if (value != null)
      HuiField(
        label: huiText('{label} ticks', <String, Object?>{
          'label': huiText(label),
        }),
        control: HuiNumberField(
          value: value.toDouble(),
          integer: true,
          step: 1,
          decimals: 0,
          ariaLabel: '$label ticks',
          onChanged: (double value) => _edit(
            'refresh $label',
            (GlossDisplayRefresh next) => edit(next, value.toInt()),
          ),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: huiText('Display refresh'),
    description: huiText(
      'Omitted intervals use the existing surface cadence. Animation and particle clocks remain independent.',
    ),
    children: <Widget>[
      ..._interval(
        'Content',
        refresh.contentTicks,
        (GlossDisplayRefresh next, int? value) => next.contentTicks = value,
      ),
      ..._interval(
        'Visibility',
        refresh.visibilityTicks,
        (GlossDisplayRefresh next, int? value) => next.visibilityTicks = value,
      ),
      ..._interval(
        'Motion',
        refresh.motionTicks,
        (GlossDisplayRefresh next, int? value) => next.motionTicks = value,
      ),
    ],
  );
}
