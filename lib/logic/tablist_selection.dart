/// Mirror of the static half of Gloss `TablistService.java`: which format a
/// player's list name uses, and how tokens substitute into it.
///
/// `chooseListName` (`TablistService.java`) resolves in this order: an
/// operator takes `_op` when it exists; a non-blank primary group takes its
/// own entry, looked up trimmed and lowercased the way `TablistDoc.copyFormats`
/// normalizes the keys; `default` catches the rest (keeping the player's
/// group name for `$group`); and with no `default` the literal `$player`
/// fallback applies. `substituteTokens` (`TablistService.java:46-52`) then replaces
/// `$player` and `$group`. A blank chosen template makes the plugin RESET
/// the list name to vanilla rather than applying an empty one
/// (`TablistService.applyListName`).
library;

import '../model/gloss_tablist.dart';

/// `TablistService.ListNameChoice`.
typedef GlossTablistChoice = ({String template, String groupName});

/// `TablistService.chooseListName`. [nameFormats] must already be the
/// EFFECTIVE map ([GlossTablistDoc.effectiveNameFormats]) — the service only
/// ever sees normalized keys.
GlossTablistChoice glossTablistChooseListName(
  bool op,
  String? primaryGroup,
  Map<String, String> nameFormats,
) {
  if (op && nameFormats.containsKey(glossTablistOpGroupKey)) {
    return (
      template: nameFormats[glossTablistOpGroupKey]!,
      groupName: glossTablistOpGroupKey,
    );
  }
  if (primaryGroup != null && primaryGroup.trim().isNotEmpty) {
    final String groupKey = primaryGroup.trim().toLowerCase();
    if (nameFormats.containsKey(groupKey)) {
      return (template: nameFormats[groupKey]!, groupName: primaryGroup);
    }
  }
  if (nameFormats.containsKey(glossTablistDefaultGroupKey)) {
    return (
      template: nameFormats[glossTablistDefaultGroupKey]!,
      groupName: primaryGroup ?? '',
    );
  }
  return (template: glossTablistFallbackFormat, groupName: primaryGroup ?? '');
}

/// `TablistService.substituteTokens`.
String glossTablistSubstituteTokens(
  String raw,
  String? playerName,
  String? groupName,
) => raw
    .replaceAll(r'$player', playerName ?? '')
    .replaceAll(r'$group', groupName ?? '');
