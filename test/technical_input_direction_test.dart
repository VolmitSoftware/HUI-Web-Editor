import 'dart:io';

import 'package:arcane_jaspr/arcane_jaspr.dart' show TextAlign;
import 'package:gloss_editor/components/common/hui_technical_input.dart';
import 'package:test/test.dart';

void main() {
  test('technical inputs are left-to-right bidi islands', () {
    expect(huiTechnicalInputAttributes['dir'], 'ltr');
    expect(huiTechnicalInputAttributes['autocomplete'], 'off');
    expect(huiTechnicalInputAttributes['spellcheck'], 'false');
    expect(huiTechnicalInputStyles.textAlign, TextAlign.left);
    final String shellStyles = File(
      'web/styles/02-shell.css',
    ).readAsStringSync();
    expect(shellStyles, contains('input[dir="ltr"]'));
    expect(shellStyles, contains('textarea[dir="ltr"]'));
    expect(shellStyles, contains('unicode-bidi: isolate'));
  });

  test('technical identifiers and player names use the shared bidi island', () {
    const Map<String, int> expectedUses = <String, int>{
      'lib/components/dialogs/export_dialog.dart': 1,
      'lib/components/dialogs/image_manager_dialog.dart': 1,
      'lib/components/panels/editor_rail.dart': 1,
      'lib/components/panels/components_rail.dart': 1,
      'lib/components/inspector/extras_editor.dart': 1,
      'lib/components/inspector/preview_match_editor.dart': 2,
      'lib/components/inspector/real_drop_inspector.dart': 1,
      'lib/components/inspector/component_inspector.dart': 1,
      'lib/components/inspector/scoreboard_inspector.dart': 2,
      'lib/components/inspector/player_head_picker.dart': 1,
      'lib/components/inspector/tablist_inspector.dart': 1,
      'lib/components/common/hui_color_field.dart': 1,
      'lib/components/inspector/real_drop_animation_inspector.dart': 1,
      'lib/components/inspector/bubble_inspector.dart': 1,
    };

    for (final MapEntry<String, int> entry in expectedUses.entries) {
      final String source = File(entry.key).readAsStringSync();
      expect(
        'styles: huiTechnicalInputStyles'.allMatches(source).length,
        greaterThanOrEqualTo(entry.value),
        reason: entry.key,
      );
      expect(
        'huiTechnicalInputAttributes'.allMatches(source).length,
        greaterThanOrEqualTo(entry.value),
        reason: entry.key,
      );
    }
  });

  test('pasted JSON uses the shared left-to-right styles', () {
    final String source = File(
      'lib/components/dialogs/import_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('styles: huiTechnicalInputStyles'));
  });
}
