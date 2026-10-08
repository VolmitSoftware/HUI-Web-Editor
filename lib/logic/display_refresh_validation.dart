import '../model/gloss_display_refresh.dart';
import 'validation.dart';

List<HuiIssue> validateDisplayRefresh(GlossDisplayRefresh refresh, {String path = r'$.refresh'}) => <HuiIssue>[
  for (final MapEntry<String, int?> entry in <String, int?>{
    'contentTicks': refresh.contentTicks, 'visibilityTicks': refresh.visibilityTicks, 'motionTicks': refresh.motionTicks,
  }.entries)
    if (entry.value != null && (entry.value! < 1 || entry.value! > 1200))
      HuiIssue(severity: HuiSeverity.error, path: '$path.${entry.key}', message: 'Refresh intervals must be 1 through 1200 ticks, or absent.'),
];
