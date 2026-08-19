library;

import 'dart:math' as math;

import '../doctype/doctype.dart';
import '../state/editor_store.dart';

final class ShowcaseSelection {
  const ShowcaseSelection({required this.type, required this.template});

  final DocumentTypeAdapter type;
  final DocumentTemplate template;
}

List<ShowcaseSelection> glossShowcaseSelections() {
  final List<ShowcaseSelection> selections = <ShowcaseSelection>[];
  for (final DocumentTypeAdapter type in DocumentTypeRegistry.all) {
    for (final DocumentTemplateSection section in type.templateSections) {
      for (final DocumentTemplate template in section.templates) {
        if (template.id.toLowerCase().contains('blank')) continue;
        selections.add(ShowcaseSelection(type: type, template: template));
      }
    }
  }
  return List<ShowcaseSelection>.unmodifiable(selections);
}

ShowcaseSelection? createRandomGlossShowcase(
  EditorStore store, {
  math.Random? random,
  String? previousTemplateId,
}) {
  final List<ShowcaseSelection> selections = glossShowcaseSelections();
  if (selections.isEmpty) return null;
  final math.Random source = random ?? math.Random();
  List<ShowcaseSelection> candidates = selections;
  if (previousTemplateId != null && selections.length > 1) {
    candidates = selections
        .where(
          (ShowcaseSelection selection) =>
              selection.template.id != previousTemplateId,
        )
        .toList(growable: false);
  }
  final ShowcaseSelection selected =
      candidates[source.nextInt(candidates.length)];
  selected.template.create(store);
  return selected;
}
