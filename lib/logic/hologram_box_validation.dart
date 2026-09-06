library;

import '../model/gloss_hologram_box.dart';
import 'validation.dart';

List<HuiIssue> validateHologramBox(
  GlossHologramBox box, {
  String path = r'$.box',
}) => <HuiIssue>[
  for (final MapEntry<String, (int, int)> entry in <String, (int, int)>{
    'padding': (box.padding, 64),
    'borderWidth': (box.borderWidth, 16),
  }.entries)
    if (entry.value.$1 < 0 || entry.value.$1 > entry.value.$2)
      HuiIssue(
        severity: HuiSeverity.warning,
        path: '$path.${entry.key}',
        message: 'Gloss clamps this value to {minimum}..{maximum}.',
        messageArguments: <String, Object?>{
          'minimum': 0,
          'maximum': entry.value.$2,
        },
      ),
  for (final MapEntry<String, String> entry in <String, String>{
    'backgroundArgb': box.backgroundArgb,
    'borderArgb': box.borderArgb,
  }.entries)
    if (!RegExp(r'^#[a-fA-F0-9]{8}$').hasMatch(entry.value))
      HuiIssue(
        severity: HuiSeverity.error,
        path: '$path.${entry.key}',
        message: 'ARGB color must use exactly eight hexadecimal digits',
      ),
];
