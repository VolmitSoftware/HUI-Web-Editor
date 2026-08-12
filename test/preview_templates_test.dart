/// Every starter in [huiPreviewTemplates] must parse clean and build clean
/// against the simulated category it targets: a template is what a brand new
/// user's first document looks like, so it can never open with a hidden
/// `onError` the author never caused.
library;

import 'package:holoui_editor/config/preview_templates.dart';
import 'package:holoui_editor/logic/preview_card_scene.dart';
import 'package:holoui_editor/logic/preview_sim.dart';
import 'package:holoui_editor/logic/preview_variant_resolver.dart';
import 'package:holoui_editor/model/preview_doc.dart';
import 'package:test/test.dart';

void main() {
  group('every preview template', () {
    for (final HuiPreviewTemplate template in huiPreviewTemplates) {
      test(
        '${template.id} parses and builds clean against "${template.category}"',
        () {
          final HuiPreviewDoc doc = template.build();

          // "Parses clean": round-tripping through the JSON codec never throws.
          final String json = encodeHuiPreviewDoc(doc);
          final HuiPreviewDoc reparsed = decodeHuiPreviewDoc(json);
          expect(reparsed.elements.length, doc.elements.length);

          // "Builds clean": zero onError output against the declared category,
          // with the document's own vars resolved exactly as the plugin's
          // registry would (no specific material — the template's own defaults).
          final PreviewSim sim = PreviewSim(template.category);
          sim.vars = PreviewSim.parseVars(previewVarsForMaterial(doc, null));
          final List<String> errors = <String>[];
          final PreviewCardScene scene = buildCardScene(
            doc,
            sim,
            onError: errors.add,
          );
          expect(
            errors,
            isEmpty,
            reason: '${template.id} must build without any onError output',
          );
          expect(scene.items, isNotEmpty);
        },
      );
    }

    test('every template has a unique, non-empty id', () {
      final Set<String> ids = huiPreviewTemplates
          .map((HuiPreviewTemplate template) => template.id)
          .toSet();
      expect(ids.length, huiPreviewTemplates.length);
      expect(ids.every((String id) => id.isNotEmpty), isTrue);
    });

    test('build() never returns a shared instance', () {
      final HuiPreviewTemplate template = huiPreviewTemplates.first;
      final HuiPreviewDoc a = template.build();
      final HuiPreviewDoc b = template.build();
      expect(identical(a, b), isFalse);
      a.elements.clear();
      expect(template.build().elements, isNotEmpty);
    });
  });

  group('huiPreviewTemplateById', () {
    test('finds a known id', () {
      expect(huiPreviewTemplateById('furnace-dashboard'), isNotNull);
    });

    test('misses an unknown id', () {
      expect(huiPreviewTemplateById('does-not-exist'), isNull);
    });
  });

  group('specific template shapes', () {
    test('the furnace dashboard is the real shipped document', () {
      final HuiPreviewDoc doc = buildFurnaceDashboardTemplate();
      expect(doc.match.blocks, <String>['FURNACE', 'BLAST_FURNACE', 'SMOKER']);
      expect(doc.variants.length, 2);
      expect(doc.card, isNotNull);
    });

    test('the minimal chest is a 9-slot framed grid', () {
      final HuiPreviewDoc doc = buildMinimalChestTemplate();
      expect(doc.card, isNotNull);
      expect(doc.card!.framed, isNull); // absent = parser default (framed).
      final PreviewSim sim = PreviewSim('chest');
      final PreviewCardScene scene = buildCardScene(doc, sim);
      expect(scene.items.whereType<CardSlot>().length, 9);
    });

    test('the custom stat card is bare content with no chrome', () {
      final HuiPreviewDoc doc = buildCustomStatCardTemplate();
      expect(doc.card, isNotNull);
      expect(doc.card!.framed, false);
      final PreviewSim sim = PreviewSim('statics');
      final PreviewCardScene scene = buildCardScene(doc, sim);
      // No CardPanel at all: framed:false skips the whole frame() wrap.
      expect(scene.items.whereType<CardPanel>(), isEmpty);
    });
  });
}
