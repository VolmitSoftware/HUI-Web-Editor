library;

import 'package:gloss_editor/logic/real_drop_labels.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('material names match DropNameFormatter.materialName', () {
    for (final (String material, String name) in <(String, String)>[
      ('DIAMOND_SWORD', 'Diamond Sword'),
      ('COBBLESTONE', 'Cobblestone'),
      ('OAK_LOG', 'Oak Log'),
      ('HEART_OF_THE_SEA', 'Heart of the Sea'),
      ('MUSIC_DISC_13', 'Music Disc 13'),
      ('LILY_OF_THE_VALLEY', 'Lily of the Valley'),
      ('JACK_O_LANTERN', "Jack o'Lantern"),
    ]) {
      test('$material is $name', () {
        expect(glossDropMaterialName(material), name);
      });
    }
  });

  test('an authored name overrides the material name, keyed without case', () {
    final GlossRealDropLabels labels = GlossRealDropLabels(
      names: <String, String>{' cobblestone ': '&7Cobble', 'STONE': '  '},
    );
    expect(glossDropTypeName(labels, 'COBBLESTONE'), '&7Cobble');
    expect(glossDropTypeName(labels, 'STONE'), 'Stone');
    expect(glossDropTypeName(labels, 'OAK_LOG'), 'Oak Log');
  });

  test('an item display name wins only when the labels opt in', () {
    final GlossRealDropLabels labels = GlossRealDropLabels(
      names: <String, String>{'DIAMOND_SWORD': 'Blade'},
    );
    expect(
      glossDropTypeName(labels, 'DIAMOND_SWORD', displayName: '&bExcalibur'),
      'Blade',
    );
    labels.useItemDisplayNames = true;
    expect(
      glossDropTypeName(labels, 'DIAMOND_SWORD', displayName: '&bExcalibur'),
      '&bExcalibur',
    );
    expect(
      glossDropTypeName(labels, 'DIAMOND_SWORD', displayName: ' '),
      'Blade',
    );
  });

  test('the label replaces every placeholder and always renders the count', () {
    final GlossRealDropLabels labels = GlossRealDropLabels();
    expect(
      glossDropLabel(labels, material: 'COBBLESTONE', count: 1),
      '&71x Cobblestone',
    );
    labels.format = '{count} {type} {count} {other}';
    expect(
      glossDropLabel(labels, material: 'OAK_LOG', count: 3),
      '3 Oak Log 3 {other}',
    );
  });

  test('a blank format renders the shipped default', () {
    final GlossRealDropLabels labels = GlossRealDropLabels(format: '  ');
    expect(
      glossDropLabel(labels, material: 'OAK_LOG', count: 32),
      '&732x Oak Log',
    );
  });
}
