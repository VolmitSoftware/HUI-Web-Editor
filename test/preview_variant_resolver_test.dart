/// [previewVarsForMaterial] / [previewMatchesGlob]: the variant resolution
/// lifted out of `preview_card_scene_test.dart`'s golden-parity harness (E4
/// left it test-local; E5 promotes it to `lib/logic/` so the import dialog and
/// the simulation panel can share it). The golden tests in
/// `preview_card_scene_test.dart` are the behavior-preservation gate for this
/// file — they must stay green unchanged.
library;

import 'package:gloss_editor/logic/preview_variant_resolver.dart';
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

void main() {
  group('previewMatchesGlob', () {
    test('an exact pattern matches only that name', () {
      expect(previewMatchesGlob('FURNACE', 'FURNACE'), isTrue);
      expect(previewMatchesGlob('FURNACE', 'BLAST_FURNACE'), isFalse);
    });

    test('pattern casing is normalized, name is not', () {
      expect(previewMatchesGlob('furnace', 'FURNACE'), isTrue);
      // The name side is expected already-uppercase (Bukkit enum casing); a
      // lowercase name simply fails to match, matching the plugin's own
      // `compileGlob` contract.
      expect(previewMatchesGlob('FURNACE', 'furnace'), isFalse);
    });

    test('a trailing wildcard matches any suffix', () {
      expect(previewMatchesGlob('*_SHULKER_BOX', 'RED_SHULKER_BOX'), isTrue);
      expect(previewMatchesGlob('*_SHULKER_BOX', 'SHULKER_BOX'), isFalse);
      expect(previewMatchesGlob('*_SHULKER_BOX', 'RED_SHULKER_BOX_X'), isFalse);
    });

    test('a bare wildcard matches everything', () {
      expect(previewMatchesGlob('*', 'ANYTHING'), isTrue);
      expect(previewMatchesGlob('*', ''), isTrue);
    });

    test('an interior wildcard matches only that shape', () {
      expect(previewMatchesGlob('A*B', 'AXXXB'), isTrue);
      expect(previewMatchesGlob('A*B', 'AB'), isTrue);
      expect(previewMatchesGlob('A*B', 'BA'), isFalse);
    });
  });

  group('previewVarsForMaterial', () {
    HuiPreviewDoc doc() => HuiPreviewDoc(
      match: HuiPreviewMatch(
        vars: <String, dynamic>{'style': 'base', 'accent': '#FFFFFFFF'},
      ),
      variants: <HuiPreviewVariant>[
        HuiPreviewVariant(
          blocks: <String>['BLAST_FURNACE'],
          vars: <String, dynamic>{'style': 'blast'},
        ),
        HuiPreviewVariant(
          blocks: <String>['*_SHULKER_BOX'],
          vars: <String, dynamic>{'style': 'shulker'},
        ),
      ],
    );

    test('null material keeps the document defaults untouched', () {
      final Map<String, dynamic> vars = previewVarsForMaterial(doc(), null);
      expect(vars, <String, dynamic>{'style': 'base', 'accent': '#FFFFFFFF'});
    });

    test('a material no variant claims keeps the document defaults', () {
      final Map<String, dynamic> vars = previewVarsForMaterial(doc(), 'CHEST');
      expect(vars, <String, dynamic>{'style': 'base', 'accent': '#FFFFFFFF'});
    });

    test('an exact-match variant overlays on top of the defaults', () {
      final Map<String, dynamic> vars = previewVarsForMaterial(
        doc(),
        'BLAST_FURNACE',
      );
      // Overridden key changes, untouched key survives from the base.
      expect(vars['style'], 'blast');
      expect(vars['accent'], '#FFFFFFFF');
    });

    test('a glob-matching variant overlays the same way', () {
      final Map<String, dynamic> vars = previewVarsForMaterial(
        doc(),
        'RED_SHULKER_BOX',
      );
      expect(vars['style'], 'shulker');
      expect(vars['accent'], '#FFFFFFFF');
    });

    test('the FIRST matching variant wins when more than one could match', () {
      final HuiPreviewDoc withOverlap = HuiPreviewDoc(
        match: HuiPreviewMatch(vars: <String, dynamic>{'style': 'base'}),
        variants: <HuiPreviewVariant>[
          HuiPreviewVariant(
            blocks: <String>['*_BOX'],
            vars: <String, dynamic>{'style': 'first'},
          ),
          HuiPreviewVariant(
            blocks: <String>['RED_BOX'],
            vars: <String, dynamic>{'style': 'second'},
          ),
        ],
      );
      expect(previewVarsForMaterial(withOverlap, 'RED_BOX')['style'], 'first');
    });

    test('mutating the result never mutates the document', () {
      final HuiPreviewDoc source = doc();
      final Map<String, dynamic> vars = previewVarsForMaterial(
        source,
        'BLAST_FURNACE',
      );
      vars['style'] = 'mutated-locally';
      expect(source.match.vars['style'], 'base');
      expect(source.variants.first.vars['style'], 'blast');
    });
  });
}
