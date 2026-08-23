import 'dart:io';

import 'package:test/test.dart';

import '../tool/localization_catalog.dart';
import '../tool/semantic_audit_glossary.dart';
import '../tool/update_localizations.dart' as updater;

void main() {
  final Directory root = Directory.current.absolute;
  late LocalizationSource source;

  setUpAll(() {
    source = collectLocalizationSource(root);
  });

  test('all source and deploy catalogs are complete and byte-identical', () {
    final Directory sourceDirectory = Directory('${root.path}/l10n');
    final Directory deployDirectory = Directory('${root.path}/web/languages');
    final List<String> sourceNames =
        sourceDirectory
            .listSync()
            .whereType<File>()
            .map((File file) => file.uri.pathSegments.last)
            .where((String name) => name.endsWith('.json'))
            .toList()
          ..sort();
    final List<String> expectedNames = <String>[
      for (final String locale in localizationLocaleCodes) '$locale.json',
    ]..sort();
    expect(sourceNames, expectedNames);
    final List<String> deployNames =
        deployDirectory
            .listSync()
            .whereType<File>()
            .map((File file) => file.uri.pathSegments.last)
            .where((String name) => name.endsWith('.json'))
            .toList()
          ..sort();
    expect(deployNames, expectedNames);

    for (final String locale in localizationLocaleCodes) {
      final File sourceFile = File('${sourceDirectory.path}/$locale.json');
      final File deployFile = File('${deployDirectory.path}/$locale.json');
      expect(deployFile.existsSync(), isTrue, reason: locale);
      expect(deployFile.readAsBytesSync(), sourceFile.readAsBytesSync());

      final LocalizationCatalog catalog = readLocalizationCatalog(sourceFile);
      expect(catalog.locale, locale);
      expect(
        validateLocalizationCatalog(catalog, source),
        isEmpty,
        reason: locale,
      );
    }
  });

  test('Gloss preview contract has exactly 55 translated keys', () {
    expect(source.previewMessages, hasLength(55));
    expect(
      source.previewMessages.keys,
      contains('gloss.preview.theme.title.furnace'),
    );
    expect(
      source.previewMessages.keys,
      contains('gloss.preview.state.smelting_item'),
    );
  });

  test('semantic audit corrections remain complete and locked', () {
    for (final MapEntry<String, Map<String, String>> localeEntry
        in semanticAuditGlossary.entries) {
      final LocalizationCatalog catalog = readLocalizationCatalog(
        File('${root.path}/l10n/${localeEntry.key}.json'),
      );
      for (final MapEntry<String, String> messageEntry
          in localeEntry.value.entries) {
        expect(source.messages, contains(messageEntry.key));
        expect(
          catalog.messages[messageEntry.key],
          messageEntry.value,
          reason: '${localeEntry.key}: ${messageEntry.key}',
        );
      }

      final MapEntry<String, String> first = localeEntry.value.entries.first;
      catalog.messages[first.key] = '${first.value} drift';
      expect(
        validateLocalizationCatalog(catalog, source),
        contains(contains('semantic audit glossary')),
        reason: localeEntry.key,
      );
    }

    final Map<String, String> simplifiedChinese =
        semanticAuditGlossary['zh_CN']!;
    final String protocolRange = simplifiedChinese.entries.firstWhere((
      MapEntry<String, String> entry,
    ) {
      return entry.key.startsWith('"{trimmed}" can never resolve');
    }).value;
    expect(protocolRange, contains('A-Z'));
    expect(protocolRange, isNot(contains('A–Z')));
    final String numericRange = simplifiedChinese.entries.firstWhere((
      MapEntry<String, String> entry,
    ) {
      return entry.key.startsWith(
        'Upper bound on the number of display models',
      );
    }).value;
    expect(numericRange, contains('1-5'));
    expect(numericRange, isNot(contains('1–5')));
  });

  test('preview messages match the sibling Gloss runtime catalogs', () {
    final Map<String, Map<String, String>> runtime = updater
        .readGlossPreviewTranslations(
          root,
          source.previewMessages.keys.toSet(),
        );
    if (runtime.isEmpty) return;
    for (final String locale in localizationLocaleCodes.skip(1)) {
      expect(runtime, contains(locale));
      final LocalizationCatalog catalog = readLocalizationCatalog(
        File('${root.path}/l10n/$locale.json'),
      );
      expect(catalog.previewMessages, runtime[locale], reason: locale);
    }
  });

  test('every locale has exactly its required plural forms', () {
    expect(source.plurals, contains('validation.integration_metrics'));
    expect(
      source.plurals,
      contains('validation.real_drop_script.variable_count'),
    );
    expect(localizationPluralForms['he_IL'], <String>['one', 'two', 'other']);
    for (final String locale in localizationLocaleCodes) {
      final LocalizationCatalog catalog = readLocalizationCatalog(
        File('${root.path}/l10n/$locale.json'),
      );
      for (final Map<String, String> forms in catalog.plurals.values) {
        expect(
          forms.keys.toSet(),
          localizationPluralForms[locale]!.toSet(),
          reason: locale,
        );
      }
    }

    final LocalizationCatalog hebrew = readLocalizationCatalog(
      File('${root.path}/l10n/he_IL.json'),
    );
    hebrew.plurals.values.first['many'] = 'אסור';
    expect(
      validateLocalizationCatalog(hebrew, source),
      contains(contains('has extra many')),
    );
  });

  test('validator rejects placeholder, token, and delimiter drift', () {
    final String placeholderKey = source.messages.keys.firstWhere(
      (String key) => localizationPlaceholders(key).isNotEmpty,
    );
    LocalizationCatalog catalog = readLocalizationCatalog(
      File('${root.path}/l10n/en_US.json'),
    );
    final String placeholder = RegExp(
      r'\{[a-z][a-zA-Z0-9_]*\}',
    ).firstMatch(placeholderKey)!.group(0)!;
    catalog.messages[placeholderKey] = placeholderKey.replaceFirst(
      placeholder,
      '',
    );
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('different placeholders')),
    );

    const String tokenKey = 'Pick a material such as diamond_sword';
    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages[tokenKey] = 'Pick a material such as gold_sword';
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a protocol or code token')),
    );

    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages['Gloss Editor'] = 'Glanz Editor';
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a protocol or code token')),
    );

    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages['Menu JSON'] = 'Menu Jason';
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a protocol or code token')),
    );

    final String platformKey = source.messages.keys.firstWhere(
      (String key) => key.contains('Paper teleport path'),
    );
    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages[platformKey] = platformKey.replaceFirst('Paper', 'Papier');
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a protocol or code token')),
    );

    const String acceptedValuesKey =
        'Accepted values: center, left, right. Omitted, this is center.';
    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages[acceptedValuesKey] = acceptedValuesKey.replaceAll(
      'center',
      'middle',
    );
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a contextual code identifier')),
    );

    final String dropScriptKey = source.messages.keys.firstWhere(
      (String key) => key.contains('DROP_SCRIPT_FORMAT.md'),
    );
    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages[dropScriptKey] = dropScriptKey.replaceFirst(
      'impactSpeed',
      'impactVelocity',
    );
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a contextual code identifier')),
    );

    final String functionKey = source.messages.keys.firstWhere(
      (String key) => key.contains('Functions: clamp, lerp'),
    );
    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages[functionKey] = functionKey.replaceFirst('clamp', 'limit');
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed a contextual code identifier')),
    );

    final String delimiterKey = source.messages.keys.firstWhere(
      (String key) => key.contains('['),
    );
    catalog = readLocalizationCatalog(File('${root.path}/l10n/en_US.json'));
    catalog.messages[delimiterKey] = delimiterKey.replaceFirst('[', '');
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('changed structural delimiters')),
    );
  });

  test('validation and format errors are localization source messages', () {
    expect(source.messages, contains('Expected a JSON object'));
    expect(source.messages, contains('Missing type'));
    expect(
      source.messages,
      contains('Correct the expression syntax, function, variable, or type.'),
    );
    expect(source.messages, contains('The workspace state is unreadable.'));
    expect(
      source.messages,
      contains('The stored image library was unreadable and was ignored.'),
    );
    expect(
      source.messages,
      contains(
        'IndexedDB could not be opened. Existing localStorage data was left '
        'untouched.',
      ),
    );
    expect(
      source.messages,
      contains('Panel metadata was unreadable and defaults are being shown.'),
    );
    expect(source.messages, contains('The relay timed out.'));
    expect(source.messages, contains('delete line'));
    expect(
      source.messages,
      contains('Menu format reference, commands and permissions.'),
    );
    expect(
      source.messages,
      contains('namespace:id, or a bare id searched across namespaces'),
    );
    expect(
      source.messages,
      contains(
        'Clickable. Runs its ordered action list when a player clicks it.',
      ),
    );
    expect(source.messages, contains('Occupied inventory slots'));
    expect(
      source.messages,
      contains('Drag to move - one undo step per gesture'),
    );
    expect(source.messages, contains('The editor link is malformed.'));
    expect(source.messages, contains('That file is not valid JSON.'));
    expect(source.messages, contains('Not valid JSON.'));
    expect(source.messages, contains('Unknown variable: {name}'));
    expect(
      source.messages,
      contains(
        '{name} references provider namespace "{prefix}", which nothing '
        'currently cataloged publishes. It may be supplied by another plugin '
        'at runtime, or it may be a typo.',
      ),
    );
    expect(
      source.messages,
      contains(
        'No background: a menu has no panel, colour or image behind its components.',
      ),
    );
    expect(source.plurals, contains('workspace.repaired_entries.count'));
    expect(source.plurals, contains('workspace.legacy_damaged.count'));
    expect(
      source.messages,
      contains('Navigation mode "{mode}" is not recognized'),
    );
    expect(
      source.messages,
      contains('Push and replace navigation require a target menu'),
    );
  });

  test('contextual labels keep distinct stable ids', () {
    expect(source.contexts['field.pitch.sound'], 'Pitch');
    expect(source.contexts['field.pitch.orientation'], 'Pitch');
    expect(source.contexts['action.open'], 'Open');
    expect(source.contexts['state.open'], 'Open');
    expect(source.contexts['sound_category.master'], 'Master');
    expect(source.contexts['sound_category.block'], 'Blocks');
    expect(source.contexts['sound_category.player'], 'Players');
    expect(source.contexts['billboard.center'], 'Center');
    expect(source.contexts['alignment.center'], 'Center');
    expect(source.contexts['animation_blend.add'], 'Add');
    expect(source.contexts['animation_blend.replace'], 'Replace');
    expect(source.contexts['animation_blend.multiply'], 'Multiply');
  });

  test('validator rejects known Minecraft and UI false friends', () {
    final LocalizationCatalog catalog = readLocalizationCatalog(
      File('${root.path}/l10n/de_DE.json'),
    );
    catalog.messages['Ticks to enter or leave the hovered pose. 0 is instant.'] =
        'Zecken für die schwebende Pose.';
    catalog.messages['Blocks the icon leans toward the viewer while hovered.'] =
        'Blockiert das Symbol beim Schweben.';
    catalog.messages['Ticks required to finish the current smelt.'] =
        'Zecken, bis der Ofen riecht.';
    catalog.messages['Custom item'] = 'Benutzerdefinierter Artikel';
    catalog.messages['Scoreboard'] = 'Anzeigetafel';
    catalog.messages['Tablist'] = 'Spielerliste';
    catalog.messages['Menu'] = 'Speisekarte';
    catalog.messages['Panel'] = 'Schild';
    catalog.messages['Billboard'] = 'Werbetafel';
    catalog.messages['Yaw'] = 'Jaaa';
    catalog.messages['Roll'] = 'Rolle';
    catalog.messages['Scale'] = 'Umfang';
    catalog.messages['Offset'] = 'Ausgleich';
    catalog.messages['Light'] = 'Leicht';
    catalog.messages['Light level'] = 'Leichtigkeit';
    catalog.messages['Line'] = 'Leine';
    catalog.messages['Right'] = 'Correct';
    catalog.messages['centred'] = 'zentriert';
    catalog.messages['Furnace'] = 'Backofen';
    catalog.messages['Chest'] = 'Brust';
    catalog.messages['Ender chest'] = 'Endkiste';
    catalog.plurals['duration.tick_count'] = <String, String>{
      'one': '{count} Zecke',
      'other': '{count} Zecken',
    };
    catalog.plurals['toast.aligned_components'] = <String, String>{
      'one': '{count} ausgerichtete Komponente {alignment}.',
      'other': '{count} ausgerichtete Komponenten {alignment}.',
    };
    catalog.plurals['export.missing_image_count'] = <String, String>{
      'one': '{count} Bild fehlt im Reißverschluss.',
      'other': '{count} Bilder fehlen im Reißverschluss.',
    };
    catalog.contexts['action.open'] = 'Offen';
    catalog.contexts['field.pitch.sound'] = 'Neigung';
    catalog.contexts['sound_category.block'] = 'Bausteine';
    catalog.contexts['billboard.center'] = 'Werbemitte';
    catalog.contexts['animation_blend.add'] = 'Hinzufügen';
    final List<String> errors = validateLocalizationCatalog(catalog, source);
    expect(errors, contains(contains('Minecraft game ticks')));
    expect(
      errors,
      contains(contains('plurals["duration.tick_count"].one mistranslates')),
    );
    expect(errors, contains(contains('pointer or gaze hover')));
    expect(errors, contains(contains('distance unit')));
    expect(errors, contains(contains('furnace smelting')));
    expect(errors, contains(contains('custom items')));
    expect(errors, contains(contains('messages["Scoreboard"] must be')));
    expect(errors, contains(contains('messages["Tablist"] must be')));
    expect(errors, contains(contains('messages["Menu"] must be')));
    expect(errors, contains(contains('messages["Panel"] must be')));
    expect(errors, contains(contains('messages["Billboard"] must be')));
    expect(errors, contains(contains('messages["Yaw"] must be')));
    expect(errors, contains(contains('messages["Roll"] must be')));
    expect(errors, contains(contains('messages["Scale"] must be')));
    expect(errors, contains(contains('messages["Offset"] must be')));
    expect(errors, contains(contains('messages["Light"] must be')));
    expect(errors, contains(contains('messages["Light level"] must be')));
    expect(errors, contains(contains('messages["Line"] must be')));
    expect(errors, contains(contains('messages["Right"] must be')));
    expect(errors, contains(contains('messages["centred"] must be')));
    expect(
      errors,
      contains(contains('plurals["toast.aligned_components"].one must be')),
    );
    expect(
      errors,
      contains(contains('mistranslates a ZIP archive as a clothing zipper')),
    );
    expect(errors, contains(contains('messages["Ender chest"] must be')));
    expect(
      errors,
      contains(contains('messages["Furnace"] must match the Gloss runtime')),
    );
    expect(
      errors,
      contains(contains('messages["Chest"] must match the Gloss runtime')),
    );
    expect(errors, contains(contains('contexts["action.open"] must be')));
    expect(errors, contains(contains('contexts["field.pitch.sound"] must be')));
    expect(
      errors,
      contains(contains('contexts["sound_category.block"] must be')),
    );
    expect(errors, contains(contains('contexts["billboard.center"] must be')));
    expect(
      errors,
      contains(contains('contexts["animation_blend.add"] must be')),
    );

    final LocalizationCatalog artifactCatalog = readLocalizationCatalog(
      File('${root.path}/l10n/de_DE.json'),
    );
    artifactCatalog.messages['Defines the type of item displayed.'] =
        'In-game in-game item';
    artifactCatalog.messages['Loading language'] = 'Wort, Wort, Wort';
    final List<String> artifactErrors = validateLocalizationCatalog(
      artifactCatalog,
      source,
    );
    expect(
      artifactErrors,
      contains(contains('contains an untranslated domain marker')),
    );
    expect(
      artifactErrors,
      contains(contains('contains a doubled domain marker')),
    );
    expect(
      artifactErrors,
      contains(contains('contains pathological repetition')),
    );

    final LocalizationCatalog portuguese = readLocalizationCatalog(
      File('${root.path}/l10n/pt_PT.json'),
    );
    portuguese.messages['Roll'] = 'Rolagem';
    expect(
      validateLocalizationCatalog(portuguese, source),
      contains(contains('messages["Roll"] must be "Rolamento"')),
    );

    final LocalizationCatalog japanese = readLocalizationCatalog(
      File('${root.path}/l10n/ja-JP.json'),
    );
    japanese.messages['Play'] = '遊ぶ';
    japanese.messages['centred'] = '中央';
    japanese.plurals['toast.aligned_components'] = <String, String>{
      'other': '{count} コンポーネントを整列しました。',
    };
    final List<String> japaneseErrors = validateLocalizationCatalog(
      japanese,
      source,
    );
    expect(japaneseErrors, contains(contains('messages["Play"] must be "再生"')));
    expect(japaneseErrors, contains(contains('messages["centred"] must be')));
    expect(
      japaneseErrors,
      contains(contains('plurals["toast.aligned_components"].other must be')),
    );

    final LocalizationCatalog simplifiedChinese = readLocalizationCatalog(
      File('${root.path}/l10n/zh_CN.json'),
    );
    simplifiedChinese.messages['Action'] = '行动';
    simplifiedChinese.messages['Drop stage'] = '下降阶段';
    expect(
      validateLocalizationCatalog(simplifiedChinese, source),
      allOf(
        contains(contains('messages["Action"] must be "操作"')),
        contains(contains('messages["Drop stage"] must be "掉落物舞台"')),
      ),
    );

    final LocalizationCatalog hebrew = readLocalizationCatalog(
      File('${root.path}/l10n/he_IL.json'),
    );
    hebrew.messages['Clear'] = 'ברור';
    expect(
      validateLocalizationCatalog(hebrew, source),
      contains(contains('messages["Clear"] must be "נקה"')),
    );

    final LocalizationCatalog spanish = readLocalizationCatalog(
      File('${root.path}/l10n/es_ES.json'),
    );
    spanish.plurals['workspace.folder_count'] = <String, String>{
      'one': '{count} folder',
      'many': '{count} folders',
      'other': '{count} folders',
    };
    expect(
      validateLocalizationCatalog(spanish, source),
      contains(contains('plurals["workspace.folder_count"].one must be')),
    );

    final LocalizationCatalog lithuanian = readLocalizationCatalog(
      File('${root.path}/l10n/lt_LT.json'),
    );
    lithuanian.plurals['export.missing_image_count'] = <String, String>{
      'one': '{count} vaizdo trūksta ZIP faile.',
      'few': '{count} vaizdų trūksta ZIP faile.',
      'other': '{count} vaizdų trūksta ZIP faile.',
    };
    expect(
      validateLocalizationCatalog(lithuanian, source),
      contains(contains('must use "ZIP archyve" for the ZIP archive')),
    );
  });

  test('source and translations preserve intentional edge whitespace', () {
    final List<String> edgeWhitespaceKeys = source.messages.keys
        .where((String key) => key.trim() != key)
        .toList();
    expect(edgeWhitespaceKeys, isNotEmpty);
    for (final String locale in localizationLocaleCodes) {
      final LocalizationCatalog catalog = readLocalizationCatalog(
        File('${root.path}/l10n/$locale.json'),
      );
      for (final String key in edgeWhitespaceKeys) {
        final String translated = catalog.messages[key]!;
        expect(
          _leadingWhitespace(translated),
          _leadingWhitespace(key),
          reason: '$locale: $key',
        );
        expect(
          _trailingWhitespace(translated),
          _trailingWhitespace(key),
          reason: '$locale: $key',
        );
      }
    }
  });

  test('validator rejects complete and partial English fallback', () {
    LocalizationCatalog catalog = readLocalizationCatalog(
      File('${root.path}/l10n/de_DE.json'),
    );
    const String fullKey =
        'A menu needs at least one component to render. Start with a text '
        'decoration or a button.';
    catalog.messages[fullKey] = fullKey;
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('retains untranslated English prose')),
    );

    catalog = readLocalizationCatalog(File('${root.path}/l10n/de_DE.json'));
    const String partialKey =
        'Blocks the icon leans toward the viewer while hovered.';
    catalog.messages[partialKey] =
        'Abstand: the icon leans toward the viewer while hovered.';
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('retains a long untranslated English fragment')),
    );

    catalog = readLocalizationCatalog(File('${root.path}/l10n/de_DE.json'));
    catalog.messages['Color'] = 'Color';
    expect(
      validateLocalizationCatalog(catalog, source),
      contains(contains('without an allowlist entry')),
    );

    catalog = readLocalizationCatalog(File('${root.path}/l10n/de_DE.json'));
    catalog.messages['Scoreboard'] = 'Scoreboard';
    final List<String> allowedCognateErrors =
        validateLocalizationCatalog(catalog, source).where((String error) {
          return error.contains(
            'messages["Scoreboard"] retains an English term without an '
            'allowlist entry',
          );
        }).toList();
    expect(allowedCognateErrors, isEmpty);
  });
}

String _leadingWhitespace(String value) =>
    RegExp(r'^\s*').firstMatch(value)!.group(0)!;

String _trailingWhitespace(String value) =>
    RegExp(r'\s*$').firstMatch(value)!.group(0)!;
