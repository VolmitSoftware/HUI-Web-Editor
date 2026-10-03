import '../model/gloss_health_bar.dart';
import 'validation.dart';

List<HuiIssue> validateHealthBar(
  GlossHealthBar bar, {
  String path = r'$.healthBar',
}) => <HuiIssue>[
  for (final (String key, num value, num minimum, num maximum)
      in <(String, num, num, num)>[
        ('warningThreshold', bar.warningThreshold, 0, 1),
        ('criticalThreshold', bar.criticalThreshold, 0, 1),
        ('decimals', bar.decimals, 0, 6),
      ])
    if (runtimeRangeIssue('$path.$key', value, minimum, maximum)
        case final HuiIssue issue)
      issue,
  for (final (String key, String value) in <(String, String)>[
    ('glyph', bar.glyph),
    ('emptyGlyph', bar.emptyGlyph),
  ])
    if (value.length > 64)
      HuiIssue(
        severity: HuiSeverity.error,
        path: '$path.$key',
        message: 'Health bar glyphs must be at most 64 characters.',
      ),
];
