/// Cross-repo pins for the files this repo carries as verbatim copies of a
/// Gloss resource.
///
/// Gloss is the truth repo. Every file listed here exists twice on purpose —
/// once in `../Gloss` (or `GLOSS_REPOSITORY`) where the plugin's own suite
/// reads it, once here where `dart test` reads it — and the two copies must
/// stay identical. The shipped previews, baselines and defaults are already
/// pinned by `preview_templates_test.dart`, `templates_test.dart`,
/// `gloss_templates_test.dart` and `emoji_catalog_test.dart`; this file covers
/// the rest. `FIXTURES.md` is the full inventory.
///
/// A failure here is never fixed by editing the Gloss file or by hand-editing
/// the editor copy: refresh the copy FROM Gloss and re-run both suites.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/gloss_repository.dart';

/// One mirrored file: the path in this repo, and the Gloss path it is
/// refreshed from.
final class MirroredFixture {
  const MirroredFixture({
    required this.editorPath,
    required this.glossPath,
    required this.guards,
  });

  /// Path in this repository, relative to the package root.
  final String editorPath;

  /// Path inside the Gloss checkout, relative to its repository root.
  final String glossPath;

  /// What drifting would silently break — quoted in the failure message.
  final String guards;

  String get refreshCommand =>
      'cp "${glossRepositoryFilePath(glossPath)}" "$editorPath"';
}

const List<MirroredFixture> mirroredFixtures = <MirroredFixture>[
  MirroredFixture(
    editorPath: 'test/fixtures/expr_test_vectors.json',
    glossPath: 'src/test/resources/expr_test_vectors.json',
    guards:
        'the shared expression-language contract replayed by '
        'preview_expr_vectors_test.dart here and ExprVectorsTest there',
  ),
  MirroredFixture(
    editorPath: 'test/fixtures/editor-sync-canonical-v3.json',
    glossPath: 'src/test/resources/editor-sync-canonical-v3.json',
    guards:
        'the v3 canonical-JSON revision algorithm shared by the Gloss '
        'runtime, editor, and sync relay',
  ),
  MirroredFixture(
    editorPath: 'web/assets/catalog/preview-variables.json',
    glossPath: 'src/test/resources/preview-variables.json',
    guards:
        'the preview variable contract read by PreviewSim and catalogs.dart',
  ),
  MirroredFixture(
    editorPath: 'test/fixtures/golden/chest_27.json',
    glossPath: 'src/test/resources/golden/chest_27.json',
    guards:
        'the captured container-preview scene replayed by '
        'preview_card_scene_test.dart',
  ),
  MirroredFixture(
    editorPath: 'test/fixtures/golden/furnace_smelting.json',
    glossPath: 'src/test/resources/golden/furnace_smelting.json',
    guards:
        'the captured container-preview scene replayed by '
        'preview_card_scene_test.dart',
  ),
  MirroredFixture(
    editorPath: 'test/fixtures/golden/locked.json',
    glossPath: 'src/test/resources/golden/locked.json',
    guards:
        'the captured container-preview scene replayed by '
        'preview_card_scene_test.dart',
  ),
];

void main() {
  group('mirrored Gloss fixtures stay identical', () {
    for (final MirroredFixture fixture in mirroredFixtures) {
      test('${fixture.editorPath} matches Gloss', () {
        final File editor = File(fixture.editorPath);
        final File gloss = File(glossRepositoryFilePath(fixture.glossPath));
        expect(
          editor.existsSync(),
          isTrue,
          reason:
              'missing editor copy ${fixture.editorPath}; restore it with '
              '${fixture.refreshCommand}',
        );
        expect(
          gloss.existsSync(),
          isTrue,
          reason:
              'missing Gloss source ${gloss.path}; set GLOSS_REPOSITORY to a '
              'Gloss checkout',
        );

        final String editorText = editor.readAsStringSync();
        final String glossText = gloss.readAsStringSync();
        final String drift =
            '${fixture.editorPath} has drifted from ${fixture.glossPath}. '
            'It pins ${fixture.guards}. Gloss is the truth repo: refresh the '
            'editor copy FROM Gloss with `${fixture.refreshCommand}` and make '
            'the engine agree. Never edit the Gloss file and never hand-edit '
            'the copy to make this pass.';

        expect(
          jsonDecode(editorText),
          jsonDecode(glossText),
          reason: 'CONTENT: $drift',
        );
        expect(
          editorText.trim(),
          glossText.trim(),
          reason: 'FORMATTING: $drift',
        );
      });
    }
  });
}
