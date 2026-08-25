library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_real_drops.dart';

GlossRealDropPresentation glossResolveRealDropPresentation(
  GlossRealDropSettingsDoc doc,
  GlossConditionContext context,
) {
  final List<GlossRealDropVariant> matches = <GlossRealDropVariant>[
    for (final GlossRealDropVariant variant in doc.variants)
      if (glossConditionMatches(variant.when, context).matches) variant,
  ]..sort(_compareVariants);
  return matches.isEmpty ? doc.presentation : matches.first.presentation;
}

String? glossResolveRealDropVariantId(
  GlossRealDropSettingsDoc doc,
  GlossConditionContext context,
) {
  final List<GlossRealDropVariant> matches = <GlossRealDropVariant>[
    for (final GlossRealDropVariant variant in doc.variants)
      if (glossConditionMatches(variant.when, context).matches) variant,
  ]..sort(_compareVariants);
  return matches.isEmpty ? null : matches.first.id;
}

bool glossRealDropAudienceVisible(
  GlossRealDropSettingsDoc doc,
  GlossConditionContext context,
) => glossConditionMatches(doc.audience.when, context).matches;

int _compareVariants(
  GlossRealDropVariant first,
  GlossRealDropVariant second,
) {
  final int priority = second.priority.compareTo(first.priority);
  return priority != 0 ? priority : first.id.compareTo(second.id);
}
