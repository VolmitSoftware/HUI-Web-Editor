/// Which surface presentation a given viewer actually gets.
///
/// `SurfaceRuntime` gates a document on its `show` condition and on
/// `select.when`, then takes the highest-priority variant whose condition
/// holds for that viewer and falls back to the document's own presentation.
/// Priority ties break on the variant id, the same deterministic rule the
/// scoreboard uses, so a preview never flickers between two equal candidates.
///
/// What comes back is the AUTHORED presentation; run it through
/// `glossSurfaceEffective` to see what survives `Presentation.forKind`.
library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_surface.dart';
import 'gloss_show.dart';
import 'preview_expr.dart';

/// Why a surface draws nothing for the sampled viewer.
enum GlossSurfaceSilence {
  /// The document `show` condition is false right now.
  documentHidden,

  /// `select.when` is false for this viewer.
  notSelected,

  /// The condition does not compile, and a broken condition fails closed.
  brokenCondition,
}

/// The sampled viewer every surface preview renders for — the same person
/// `glossScopedSampleValues` describes.
const String glossSurfaceSampleViewerName = 'Builder';

/// The scope a surface preview evaluates conditions in when the caller has no
/// simulator of its own.
GlossConditionContext glossSurfaceSampleContext() => GlossConditionContext(
  variables: <String, Object?>{...glossScopedSampleValues},
  groups: <String>{'default'},
);

/// Null when the sampled viewer would see this surface, otherwise the reason
/// they would not.
GlossSurfaceSilence? glossSurfaceSilence(
  GlossSurfaceDoc doc, {
  GlossConditionContext? context,
  int nowMs = 0,
}) {
  final GlossConditionContext scope = context ?? glossSurfaceSampleContext();
  if (!glossShowMatches(doc.extras['show'], scope: scope, nowMs: nowMs)) {
    return GlossSurfaceSilence.documentHidden;
  }
  final ({bool matches, String? error}) selected = glossConditionMatches(
    doc.select.when,
    scope,
  );
  if (selected.error != null) return GlossSurfaceSilence.brokenCondition;
  return selected.matches ? null : GlossSurfaceSilence.notSelected;
}

/// The id of the variant the sampled viewer resolves to, or null when the
/// document's own presentation wins.
String? glossResolveSurfaceVariantId(
  GlossSurfaceDoc doc, {
  GlossConditionContext? context,
}) {
  final List<GlossSurfaceVariant> matches = _matchingVariants(doc, context);
  return matches.isEmpty ? null : matches.first.id;
}

/// The authored presentation the sampled viewer resolves to.
GlossSurfacePresentation glossResolveSurfacePresentation(
  GlossSurfaceDoc doc, {
  GlossConditionContext? context,
}) {
  final List<GlossSurfaceVariant> matches = _matchingVariants(doc, context);
  return matches.isEmpty ? doc.presentation : matches.first.presentation;
}

/// The presentation the client is handed: the resolved variant put through
/// `Presentation.forKind`, so foreign fields are gone and the omitted ones
/// carry their runtime defaults.
GlossSurfacePresentation glossResolveEffectiveSurfacePresentation(
  GlossSurfaceDoc doc, {
  GlossConditionContext? context,
}) => glossSurfaceEffective(
  doc.resolvedSurface,
  glossResolveSurfacePresentation(doc, context: context),
);

List<GlossSurfaceVariant> _matchingVariants(
  GlossSurfaceDoc doc,
  GlossConditionContext? context,
) {
  final GlossConditionContext scope = context ?? glossSurfaceSampleContext();
  return <GlossSurfaceVariant>[
    for (final GlossSurfaceVariant variant in doc.variants)
      if (variant.when.trim().isNotEmpty &&
          glossConditionMatches(variant.when, scope).matches)
        variant,
  ]..sort((GlossSurfaceVariant first, GlossSurfaceVariant second) {
    final int priority = second.priority.compareTo(first.priority);
    return priority != 0 ? priority : first.id.compareTo(second.id);
  });
}

/// The boss-bar fill the client draws, in 0..1. A progress expression that
/// cannot be evaluated here reports as a full bar, which is what the runtime
/// falls back to.
double glossSurfaceProgressValue(
  String? progress, {
  GlossConditionContext? context,
}) {
  final String? source = glossSurfaceProgressSource(progress);
  if (source == null || source.isEmpty) return 1;
  final GlossConditionContext scope = context ?? glossSurfaceSampleContext();
  try {
    final Object value = evalPreviewExpr(parsePreviewExpr(source), scope);
    if (value is! num) return 1;
    final double resolved = value.toDouble();
    if (resolved.isNaN) return 1;
    return resolved.clamp(0, 1).toDouble();
  } on PExprException {
    return 1;
  }
}

/// How many notches the chosen boss-bar style cuts the bar into; 0 for the
/// solid bar that has none.
int glossSurfaceStyleSegments(String? style) => switch (style) {
  'segmented_6' => 6,
  'segmented_10' => 10,
  'segmented_12' => 12,
  'segmented_20' => 20,
  _ => 0,
};
