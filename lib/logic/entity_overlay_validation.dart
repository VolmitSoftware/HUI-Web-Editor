library;

import '../model/gloss_doc.dart';
import '../model/gloss_entity_overlays.dart';
import 'particle_layer_validation.dart';
import 'gloss_show.dart';
import 'validation.dart';

List<HuiIssue> validateEntityOverlaysDoc(GlossEntityOverlaysDoc doc) {
  final HuiIssue? revision = glossRevisionIssue(doc.revision);
  final List<HuiIssue> issues = <HuiIssue>[
    ?revision,
    ...validateIconDisplayStyle(doc.style, path: r'$.style'),
    ...validateParticleLayers(doc.particleLayers, path: r'$.particleLayers'),
  ];
  final Map<String, (num, num, num)> ranges = <String, (num, num, num)>{
    'range': (doc.range, 1, 64),
    'updateIntervalTicks': (doc.updateIntervalTicks, 1, 40),
    'maxEntitiesPerViewer': (doc.maxEntitiesPerViewer, 1, 256),
    'maxActiveOverlays': (doc.maxActiveOverlays, 16, 16384),
    'verticalOffset': (doc.verticalOffset, -2, 8),
    'healthSegments': (doc.healthSegments, 1, 40),
    'hitHighlightMs': (doc.hitHighlightMs, 0, 10000),
    'box.padding': (doc.box.padding, 0, 64),
    'box.borderWidth': (doc.box.borderWidth, 0, 16),
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
  issues.addAll(validateGlossShow(doc.show));
  if (doc.lines.length > 64) {
    _error(issues, r'$.lines', 'An entity pane accepts at most 64 lines.');
  }
  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.lines.length; index++) {
    final GlossEntityOverlayLine line = doc.lines[index];
    final String path = '\$.lines[$index]';
    if (line.id.isEmpty ||
        line.id.length > 64 ||
        !RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(line.id)) {
      _error(
        issues,
        '$path.id',
        'Line ids must match [a-z0-9][a-z0-9._-]* and be at most 64 characters.',
      );
    } else if (!ids.add(line.id)) {
      _error(issues, '$path.id', 'Each line needs a unique id.');
    }
    if (!glossEntityOverlayLineTypes.contains(line.type)) {
      _error(issues, '$path.type', 'Choose text, insight or spacer.');
    }
    if (line.text.length > 4096) {
      _error(
        issues,
        '$path.text',
        'Line text must be at most 4096 characters.',
      );
    }
    issues.addAll(validateGlossShow(line.show, path: '$path.show'));
  }
  for (final MapEntry<String, String> color in <String, String>{
    'backgroundArgb': doc.box.backgroundArgb,
    'borderArgb': doc.box.borderArgb,
  }.entries) {
    if (!RegExp(r'^#[a-fA-F0-9]{8}$').hasMatch(color.value)) {
      _error(
        issues,
        '\$.box.${color.key}',
        'ARGB color must use exactly eight hexadecimal digits',
      );
    }
  }
  return issues;
}

void _error(List<HuiIssue> issues, String path, String message) => issues.add(
  HuiIssue(severity: HuiSeverity.error, path: path, message: message),
);
