import 'dart:io';

import 'package:gloss_editor/config/templates.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

void main() {
  test(
    'every starter template builds a fresh menu without validation errors',
    () {
      for (final HuiTemplate template in huiTemplates) {
        final HuiMenu first = template.build();
        final HuiMenu second = template.build();
        expect(identical(first, second), isFalse, reason: template.id);
        expect(
          validateHuiMenu(
            first,
          ).where((HuiIssue issue) => issue.severity == HuiSeverity.error),
          isEmpty,
          reason: template.id,
        );
      }
    },
  );

  test('template ids and displayed component counts are accurate', () {
    final Set<String> ids = <String>{};
    for (final HuiTemplate template in huiTemplates) {
      expect(ids.add(template.id), isTrue, reason: template.id);
      final String count = '${template.build().components.length} components';
      expect(template.highlights, contains(count), reason: template.id);
    }
  });

  test('the blank hologram is the plugin baseline', () {
    final HuiMenu menu = buildBlankHologramTemplate();
    expect(menu.followPlayer, isFalse);
    expect(menu.components.map((HuiComponent c) => c.id), <String>[
      'title',
      'body',
      'close',
    ]);
    final String fixture = File(
      'test/fixtures/menus/blank-hologram.json',
    ).readAsStringSync();
    expect(kBlankHologramJson.trim(), fixture.trim());
    final File plugin = File(
      glossRepositoryFilePath('src/main/resources/baselines/menu-blank.json'),
    );
    expect(plugin.existsSync(), isTrue);
    expect(kBlankHologramJson.trim(), plugin.readAsStringSync().trim());
  });
}
