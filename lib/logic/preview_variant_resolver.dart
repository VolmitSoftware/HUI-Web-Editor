/// Variant `vars` resolution, ported from `CompiledPreviewDocument.varsForBlock`
/// by way of `PreviewDocumentRegistry`.
///
/// A container-preview document declares its own `vars` on [HuiPreviewMatch]
/// and may override a subset of them per variant. At runtime the plugin picks
/// the vars for a specific block or entity type by merging the FIRST variant
/// whose match names it over the document's own defaults; a name no variant
/// claims keeps the defaults untouched. This file is that same lookup, lifted
/// out of `preview_card_scene_test.dart` (E4 left it test-local) so the
/// simulation panel and the golden-parity tests can share one implementation.
///
/// DOM-free: pure logic, runs on the VM under `dart test`.
library;

import '../model/preview_doc.dart';

/// The vars a build against [material] would resolve to: [doc]'s own
/// `match.vars`, then the FIRST variant whose `blocks` names [material]
/// merged on top. `material` is `null` for the registry's static/no-target
/// path (a `special` document, or no simulated block at all), which always
/// keeps the document defaults untouched.
Map<String, dynamic> previewVarsForMaterial(
  HuiPreviewDoc doc,
  String? material,
) {
  final Map<String, dynamic> base = Map<String, dynamic>.of(doc.match.vars);
  if (material == null) return base;
  for (final HuiPreviewVariant variant in doc.variants) {
    for (final String pattern in variant.blocks) {
      if (previewMatchesGlob(pattern, material)) {
        return base..addAll(variant.vars);
      }
    }
  }
  return base;
}

/// `PreviewDocumentParser.compileGlob`: `*` is the only wildcard and every
/// segment between wildcards matches literally; a pattern with no `*` is an
/// exact match once uppercased. [name] is expected already in Bukkit's own
/// enum casing (`FURNACE`, `BLAST_FURNACE`, ...) — exactly what
/// `PreviewSim.blockType` carries and what every match/variant `blocks` entry
/// is written against — so, matching the plugin, only [pattern] is
/// case-normalized here.
bool previewMatchesGlob(String pattern, String name) {
  final String upper = pattern.toUpperCase();
  if (!upper.contains('*')) return upper == name;
  final String regex = upper.split('*').map(RegExp.escape).join('.*');
  return RegExp('^$regex\$').hasMatch(name);
}
