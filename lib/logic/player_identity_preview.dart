library;

import '../components/scoreboard/scoreboard_selection.dart';
import '../model/model.dart';
import 'gloss_show.dart';
import 'gloss_text.dart';

const Map<String, String> glossTeamColors = <String, String>{
  'black': '&0',
  'dark_blue': '&1',
  'dark_green': '&2',
  'dark_aqua': '&3',
  'dark_red': '&4',
  'dark_purple': '&5',
  'gold': '&6',
  'gray': '&7',
  'dark_gray': '&8',
  'blue': '&9',
  'green': '&a',
  'aqua': '&b',
  'red': '&c',
  'light_purple': '&d',
  'yellow': '&e',
  'white': '&f',
};

GlossConditionContext identityPreviewContext(
  String name,
  Set<String> permissions, {
  bool sneaking = false,
}) => GlossConditionContext(
  variables: <String, Object?>{
    ...glossScopedSampleValues,
    'subject.name': name,
    'subject.username': name,
    'subject.displayName': name,
    'subject.group': 'default',
    'subject.health': 18.0,
    'subject.maxHealth': 20.0,
    'subject.sneaking': sneaking,
    'subject.level': 27.0,
  },
  permissionsByRole: <String, Set<String>>{'subject': permissions},
  groupsByRole: <String, Set<String>>{
    'subject': <String>{'default'},
  },
);

bool identityRuleMatches(
  String permission,
  Object? when,
  GlossConditionContext context,
) =>
    (permission.isEmpty ||
        (context.permissionsByRole['subject']?.contains(permission) ??
            false)) &&
    glossShowMatches(when, scope: context);

GlossNametagPresentation? resolveNametagPreview(
  GlossNametagDoc doc,
  GlossConditionContext context,
) {
  if (!glossShowMatches(doc.extras['show'], scope: context) ||
      !identityRuleMatches(doc.select.permission, doc.select.when, context)) {
    return null;
  }
  GlossNametagVariant? selected;
  for (final GlossNametagVariant variant in doc.variants) {
    if (identityRuleMatches(variant.permission, variant.when, context) &&
        (selected == null || variant.priority > selected.priority ||
            variant.priority == selected.priority && variant.id.compareTo(selected.id) < 0)) {
      selected = variant;
    }
  }
  return selected?.presentation ?? doc.presentation;
}

GlossNameplatePresentation? resolveNameplatePreview(
  GlossNameplateDoc doc,
  GlossConditionContext context,
) {
  if (!glossShowMatches(doc.extras['show'], scope: context) ||
      !identityRuleMatches(doc.select.permission, doc.select.when, context)) {
    return null;
  }
  GlossNameplateVariant? selected;
  for (final GlossNameplateVariant variant in doc.variants) {
    if (identityRuleMatches(variant.permission, variant.when, context) &&
        (selected == null || variant.priority > selected.priority ||
            variant.priority == selected.priority && variant.id.compareTo(selected.id) < 0)) {
      selected = variant;
    }
  }
  return selected?.presentation ?? doc.presentation;
}

String nametagPreviewText(GlossNametagPresentation presentation) =>
    '${presentation.prefix}&r${glossTeamColors[presentation.color] ?? '&f'}{{ subject.name }}${presentation.suffix}&r';

String resolveIdentityPreviewName(
  Iterable<({String id, GlossNametagDoc doc})> documents,
  GlossConditionContext context, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
}) {
  ({String id, GlossNametagDoc doc})? selected;
  GlossNametagPresentation? presentation;
  for (final ({String id, GlossNametagDoc doc}) entry in documents) {
    final GlossNametagPresentation? candidate = resolveNametagPreview(entry.doc, context);
    if (candidate != null && (selected == null ||
        entry.doc.select.priority > selected.doc.select.priority ||
        entry.doc.select.priority == selected.doc.select.priority &&
            entry.id.compareTo(selected.id) < 0)) {
      selected = entry;
      presentation = candidate;
    }
  }
  if (presentation == null) return context.variable('subject.name') as String;
  return renderGlossLine(nametagPreviewText(presentation),
    animations: animations, emoji: emoji, nowMs: nowMs, richText: true,
    expressionSamples: GlossTextExpressionSamples(values: <String, Object>{
      for (final MapEntry<String, Object?> entry in context.variables.entries)
        if (entry.value != null) entry.key: entry.value!,
    }),
  ).renderedText;
}
