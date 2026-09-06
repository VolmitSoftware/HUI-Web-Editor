/// Conditional header/footer and list-name presentation selection.
library;

import 'gloss_show.dart';
import '../components/scoreboard/scoreboard_selection.dart';
import '../model/gloss_tablist.dart';

GlossTablistHeaderFooterPresentation glossResolveTablistHeaderFooter(
  GlossTablistDoc doc,
  GlossConditionContext context,
) {
  final List<GlossTablistHeaderFooterVariant> matches =
      <GlossTablistHeaderFooterVariant>[
        for (final GlossTablistHeaderFooterVariant variant
            in doc.headerFooter.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort(_compareVariants);
  return matches.isEmpty
      ? doc.headerFooter.presentation
      : matches.first.presentation;
}

GlossTablistListNamePresentation glossResolveTablistListName(
  GlossTablistDoc doc,
  GlossConditionContext context,
) {
  final List<GlossTablistListNameVariant> matches =
      <GlossTablistListNameVariant>[
        for (final GlossTablistListNameVariant variant
            in doc.listNames.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort(_compareVariants);
  return matches.isEmpty
      ? doc.listNames.presentation
      : matches.first.presentation;
}

String? glossResolveTablistHeaderFooterVariantId(
  GlossTablistDoc doc,
  GlossConditionContext context,
) {
  final List<GlossTablistHeaderFooterVariant> matches =
      <GlossTablistHeaderFooterVariant>[
        for (final GlossTablistHeaderFooterVariant variant
            in doc.headerFooter.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort(_compareVariants);
  return matches.isEmpty ? null : matches.first.id;
}

String? glossResolveTablistListNameVariantId(
  GlossTablistDoc doc,
  GlossConditionContext context,
) {
  final List<GlossTablistListNameVariant> matches =
      <GlossTablistListNameVariant>[
        for (final GlossTablistListNameVariant variant
            in doc.listNames.variants)
          if (glossConditionMatches(variant.when, context).matches) variant,
      ]..sort(_compareVariants);
  return matches.isEmpty ? null : matches.first.id;
}

int _compareVariants(
  GlossConditionalVariant first,
  GlossConditionalVariant second,
) {
  final int priority = second.priority.compareTo(first.priority);
  return priority != 0 ? priority : first.id.compareTo(second.id);
}

String glossTablistSubstituteTokens(
  String raw,
  String? playerName,
  String? groupName,
) => raw
    .replaceAll(r'$player', playerName ?? '')
    .replaceAll(r'$group', groupName ?? '');

bool glossTablistHeaderFooterVisible(
  GlossTablistDoc doc,
  GlossConditionContext context, {
  int nowMs = 0,
}) =>
    doc.headerFooter.enabled &&
    glossShowMatches(doc.extras['show'], scope: context, nowMs: nowMs) &&
    glossShowMatches(
      doc.headerFooter.extras['show'],
      scope: context,
      nowMs: nowMs,
    );

bool glossTablistListNamesVisible(
  GlossTablistDoc doc,
  GlossConditionContext context, {
  int nowMs = 0,
}) =>
    doc.listNames.enabled &&
    glossShowMatches(doc.extras['show'], scope: context, nowMs: nowMs) &&
    glossShowMatches(
      doc.listNames.extras['show'],
      scope: context,
      nowMs: nowMs,
    );
