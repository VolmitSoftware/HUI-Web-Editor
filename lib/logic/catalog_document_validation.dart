import '../model/model.dart';
import 'gloss_show.dart';
import 'validation.dart';

List<HuiIssue> validateStringsDoc(GlossStringsDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[?glossRevisionIssue(doc.revision)];
  final RegExp locale = RegExp(r'^[A-Za-z]{2}[_-][A-Za-z]{2}$');
  if (!locale.hasMatch(doc.locale)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.locale',
        message: 'Use a language_COUNTRY locale.',
      ),
    );
  }
  if (doc.fallback.isNotEmpty && !locale.hasMatch(doc.fallback)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.fallback',
        message: 'Use a language_COUNTRY locale.',
      ),
    );
  }
  if (doc.entries.length > 8192) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.entries',
        message: 'A strings catalog supports at most 8192 entries.',
      ),
    );
  }
  for (final MapEntry<String, String> entry in doc.entries.entries) {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(entry.key)) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '\$.entries.${entry.key}',
          message:
              'Use lowercase letters, digits, dots, underscores and hyphens for entry keys.',
        ),
      );
    }
    if (entry.value.length > 4096) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: '\$.entries.${entry.key}',
          message: 'Keep each string within 4096 characters.',
        ),
      );
    }
  }
  return issues;
}

List<HuiIssue> validateWaypointDoc(GlossWaypointDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[
    ?glossRevisionIssue(doc.revision),
    ...validateGlossShow(doc.show),
    ...validateGlossShow(doc.audience, path: r'$.audience.when'),
  ];
  final GlossMarkerAnchor anchor = doc.anchor;
  final bool position =
      anchor.world != null ||
      anchor.x != null ||
      anchor.y != null ||
      anchor.z != null;
  final int targets =
      (position ? 1 : 0) +
      ((anchor.entity?.isNotEmpty ?? false) ? 1 : 0) +
      ((anchor.player?.isNotEmpty ?? false) ? 1 : 0);
  if (targets != 1 ||
      (position &&
          ((anchor.world?.trim().isEmpty ?? true) ||
              anchor.x == null ||
              anchor.y == null ||
              anchor.z == null))) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.anchor',
        message:
            'Choose a complete world position, an entity UUID, or a player name.',
      ),
    );
  }
  if (anchor.entity case final String entity
      when !RegExp(
        r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
      ).hasMatch(entity)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.anchor.entity',
        message: 'Enter an entity UUID.',
      ),
    );
  }
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(doc.color)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.color',
        message: 'Use a #RRGGBB color.',
      ),
    );
  }
  if (!const <String>['default', 'bowtie'].contains(doc.style)) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.style',
        message: 'Choose default or bowtie.',
      ),
    );
  }
  if (!doc.range.isFinite || doc.range < 0) {
    issues.add(
      const HuiIssue(
        severity: HuiSeverity.error,
        path: r'$.range',
        message: 'Range must be zero or greater.',
      ),
    );
  }
  return issues;
}
