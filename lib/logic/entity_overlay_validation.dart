library;

import '../model/gloss_doc.dart';
import '../model/gloss_entity_overlays.dart';
import 'validation.dart';

List<HuiIssue> validateEntityOverlaysDoc(GlossEntityOverlaysDoc doc) {
  final HuiIssue? revision = glossRevisionIssue(doc.revision);
  final List<HuiIssue> issues = <HuiIssue>[?revision];
  final Map<String, (num, num, num)> ranges = <String, (num, num, num)>{
    'range': (doc.range, 1, 64),
    'updateIntervalTicks': (doc.updateIntervalTicks, 1, 40),
    'maxEntitiesPerViewer': (doc.maxEntitiesPerViewer, 1, 256),
    'verticalOffset': (doc.verticalOffset, -2, 8),
    'scale': (doc.scale, 0.1, 4),
    'healthSegments': (doc.healthSegments, 1, 40),
    'hitHighlightMs': (doc.hitHighlightMs, 0, 10000),
  };
  for (final MapEntry<String, (num, num, num)> entry in ranges.entries) {
    final (num value, num minimum, num maximum) = entry.value;
    if (!value.isFinite || value < minimum || value > maximum) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.warning,
          path: '\$.${entry.key}',
          message: 'Gloss clamps this value to {minimum}..{maximum}.',
          messageArguments: <String, Object?>{
            'minimum': minimum,
            'maximum': maximum,
          },
          fix: 'Choose a value inside the runtime range.',
        ),
      );
    }
  }
  return issues;
}
