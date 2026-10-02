/// The stack label text, ported from Gloss `DropNameFormatter.java` and the
/// `RealDropSettingsDoc.Labels` normalization the server applies at load.
library;

import '../model/gloss_real_drops.dart';
import '../model/gloss_names.dart';

String glossDropMaterialName(String materialKey, {GlossNamesCatalog names = const GlossNamesCatalog()}) =>
    names.name(GlossNameCategory.materials, materialKey);

/// `RealDropSettingsDoc.cleanNames`: keys trimmed and upper-cased, entries
/// with a blank key or a blank name dropped, file order kept.
Map<String, String> glossDropLabelNames(Map<String, String> names) =>
    <String, String>{
      for (final MapEntry<String, String> entry in names.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim().toUpperCase(): entry.value,
    };

/// The `{type}` a stack of [material] renders with: the item's own
/// [displayName] when [GlossRealDropLabels.useItemDisplayNames] is on and it
/// has one, otherwise the authored per-material name, otherwise the Title Case
/// material name.
String glossDropTypeName(
  GlossRealDropLabels labels,
  String material, {
  String? displayName,
  GlossNamesCatalog names = const GlossNamesCatalog(),
}) {
  if (labels.useItemDisplayNames &&
      displayName != null &&
      displayName.trim().isNotEmpty) {
    return displayName;
  }
  final String key = material.toUpperCase();
  return glossDropLabelNames(labels.names)[key] ?? glossDropMaterialName(key, names: names);
}

/// The raw label the server renders for a stack: [GlossRealDropLabels.format],
/// or the shipped default when it is blank, with every `{count}` replaced by
/// [count] — one included — and every `{type}` by [glossDropTypeName].
String glossDropLabel(
  GlossRealDropLabels labels, {
  required String material,
  required int count,
  String? displayName,
  GlossNamesCatalog names = const GlossNamesCatalog(),
}) {
  final String format = labels.format.trim().isEmpty
      ? glossRealDropLabelFormatDefault
      : labels.format;
  return format
      .replaceAll('{count}', '$count')
      .replaceAll(
        '{type}',
        glossDropTypeName(labels, material, displayName: displayName, names: names),
      );
}
