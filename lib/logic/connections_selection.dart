/// Which connection message a given reader actually sees.
///
/// `ConnectionsService.announce` gates on the document and section `show`
/// conditions and on `Section.active()`, then `ConnectionsService.render`
/// walks the variants in order and takes the first whose condition holds for
/// that reader. The runtime sorts variants by priority when it loads the file
/// (`Section.copyVariants`), so selection here sorts too rather than trusting
/// the authored order.
library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_connections.dart';
import 'gloss_show.dart';

/// The sampled reader the preview renders for. `viewer.name` in
/// [glossScopedSampleValues] is the same person.
const String glossConnectionsSampleViewerName = 'Builder';

/// True when [key]'s section would put a line in chat at [nowMs]: the block
/// exists, is on, and both show conditions hold.
bool glossConnectionsSectionBroadcasts(
  GlossConnectionsDoc doc,
  String key, {
  int nowMs = 0,
}) {
  final GlossConnectionsSection section = doc.section(key);
  if (!section.present || !section.enabled) return false;
  if (!glossShowMatches(doc.extras['show'], nowMs: nowMs)) return false;
  return glossShowMatches(section.extras['show'], nowMs: nowMs);
}

/// The presentation the sampled reader gets: the highest-priority variant
/// whose condition holds, else the section's own text.
GlossConnectionsPresentation glossResolveConnectionsPresentation(
  GlossConnectionsDoc doc,
  String key, {
  GlossConditionContext? context,
}) {
  final GlossConnectionsSection section = doc.section(key);
  final GlossConditionContext scope =
      context ??
      GlossConditionContext(
        variables: <String, Object?>{...glossScopedSampleValues},
        groups: <String>{'default'},
      );
  final List<GlossConnectionsVariant> matches =
      <GlossConnectionsVariant>[
        for (final GlossConnectionsVariant variant in section.variants)
          if (variant.when.trim().isNotEmpty &&
              glossConditionMatches(variant.when, scope).matches)
            variant,
      ]..sort(
        (GlossConnectionsVariant first, GlossConnectionsVariant second) =>
            second.priority.compareTo(first.priority),
      );
  return matches.isEmpty ? section.presentation : matches.first.presentation;
}
