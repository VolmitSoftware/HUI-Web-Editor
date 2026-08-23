import 'dart:convert';
import 'dart:io';

import 'package:gloss_editor/l10n/hui_localizations.dart';

import 'localization_catalog.dart';

void main(List<String> arguments) {
  final bool check = arguments.contains('--check');
  if (arguments.any((String argument) => argument != '--check')) {
    stderr.writeln('Usage: dart run tool/update_localizations.dart [--check]');
    exitCode = 64;
    return;
  }

  final Directory root = _findRoot();
  final LocalizationSource source = collectLocalizationSource(root);
  final Map<String, Map<String, String>> glossPreview =
      readGlossPreviewTranslations(root, source.previewMessages.keys.toSet());
  final Directory directory = Directory('${root.path}/l10n');
  final Directory deployDirectory = Directory('${root.path}/web/languages');
  final Directory manifestDirectory = Directory('${root.path}/web/manifests');
  if (!directory.existsSync() && !check) directory.createSync(recursive: true);
  if (!deployDirectory.existsSync() && !check) {
    deployDirectory.createSync(recursive: true);
  }
  if (!manifestDirectory.existsSync() && !check) {
    manifestDirectory.createSync(recursive: true);
  }

  final List<String> stale = <String>[];
  final List<String> validationErrors = <String>[];
  if (check) {
    final Set<String> expectedNames = <String>{
      for (final String locale in localizationLocaleCodes) '$locale.json',
    };
    _validateGeneratedNames(
      directory,
      expectedNames,
      '.json',
      validationErrors,
    );
    _validateGeneratedNames(
      deployDirectory,
      expectedNames,
      '.json',
      validationErrors,
    );
    final Set<String> expectedManifestNames = <String>{
      for (final String locale in localizationLocaleCodes)
        '$locale.webmanifest',
    };
    _validateGeneratedNames(
      manifestDirectory,
      expectedManifestNames,
      '.webmanifest',
      validationErrors,
    );
  }
  for (final String locale in localizationLocaleCodes) {
    final File file = File('${directory.path}/$locale.json');
    final File deployFile = File('${deployDirectory.path}/$locale.json');
    final File manifestFile = File(
      '${manifestDirectory.path}/$locale.webmanifest',
    );
    final LocalizationCatalog? existing = file.existsSync()
        ? readLocalizationCatalog(file)
        : null;
    if (check && existing != null) {
      for (final String error in validateLocalizationCatalog(
        existing,
        source,
      )) {
        validationErrors.add('$locale canonical: $error');
      }
      final Map<String, String>? runtimePreview = glossPreview[locale];
      if (runtimePreview != null) {
        for (final MapEntry<String, String> entry in runtimePreview.entries) {
          if (existing.previewMessages[entry.key] != entry.value) {
            validationErrors.add(
              '$locale canonical: previewMessages[${jsonEncode(entry.key)}] '
              'differs from the Gloss runtime catalog.',
            );
          }
        }
      }
    }
    final LocalizationCatalog updated = _updatedCatalog(
      locale,
      source,
      existing,
      glossPreview[locale],
    );
    final String output = encodeLocalizationCatalog(updated);
    final String manifestOutput = _encodeInstallManifest(locale, updated);
    for (final String error in validateLocalizationCatalog(updated, source)) {
      validationErrors.add('$locale generated: $error');
    }
    if (check) {
      if (!file.existsSync() || file.readAsStringSync() != output) {
        stale.add(file.path);
      }
      if (!deployFile.existsSync() || deployFile.readAsStringSync() != output) {
        stale.add(deployFile.path);
      }
      if (!manifestFile.existsSync() ||
          manifestFile.readAsStringSync() != manifestOutput) {
        stale.add(manifestFile.path);
      }
      if (deployFile.existsSync() &&
          (!file.existsSync() ||
              deployFile.readAsStringSync() != file.readAsStringSync())) {
        final LocalizationCatalog deploy = readLocalizationCatalog(deployFile);
        for (final String error in validateLocalizationCatalog(
          deploy,
          source,
        )) {
          validationErrors.add('$locale deploy: $error');
        }
      }
    } else {
      file.writeAsStringSync(output);
      deployFile.writeAsStringSync(output);
      manifestFile.writeAsStringSync(manifestOutput);
    }
  }

  if (validationErrors.isNotEmpty) {
    stderr.writeln('Invalid localization catalogs:');
    for (final String error in validationErrors) {
      stderr.writeln('  $error');
    }
    exitCode = 1;
    return;
  }

  if (check && stale.isNotEmpty) {
    stderr.writeln('Localization catalogs need regeneration:');
    for (final String path in stale) {
      stderr.writeln('  $path');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    '${check ? 'Validated' : 'Updated'} ${localizationLocaleCodes.length} '
    'catalogs and install manifests (${source.messages.length} messages, '
    '${source.contexts.length} contexts, '
    '${source.plurals.length} plurals, '
    '${source.previewMessages.length} preview messages).',
  );
}

void _validateGeneratedNames(
  Directory directory,
  Set<String> expected,
  String extension,
  List<String> errors,
) {
  final Set<String> actual = directory.existsSync()
      ? directory
            .listSync()
            .whereType<File>()
            .map((File file) => file.uri.pathSegments.last)
            .where((String name) => name.endsWith(extension))
            .toSet()
      : <String>{};
  final List<String> missing = expected.difference(actual).toList()..sort();
  final List<String> extra = actual.difference(expected).toList()..sort();
  if (missing.isNotEmpty) {
    errors.add('${directory.path} is missing ${missing.join(', ')}.');
  }
  if (extra.isNotEmpty) {
    errors.add('${directory.path} has extra ${extra.join(', ')}.');
  }
}

String _encodeInstallManifest(String locale, LocalizationCatalog catalog) {
  final HuiLocale metadata = huiLocale(locale);
  final Map<String, Object> manifest = <String, Object>{
    'name': catalog.messages[huiDocumentTitleSource]!,
    'short_name': 'Gloss',
    'description': catalog.messages[huiDocumentDescriptionSource]!,
    'lang': metadata.htmlLanguage,
    'dir': metadata.rightToLeft ? 'rtl' : 'ltr',
    'start_url': '/',
    'display': 'standalone',
    'background_color': '#050505',
    'theme_color': '#050505',
    'icons': <Map<String, String>>[
      <String, String>{
        'src': '../assets/brand/icon-192x192.png',
        'sizes': '192x192',
        'type': 'image/png',
      },
      <String, String>{
        'src': '../assets/brand/icon-512x512.png',
        'sizes': '512x512',
        'type': 'image/png',
      },
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
}

LocalizationCatalog _updatedCatalog(
  String locale,
  LocalizationSource source,
  LocalizationCatalog? existing,
  Map<String, String>? glossPreview,
) {
  final Map<String, String> messages = <String, String>{};
  for (final String key in source.messages.keys) {
    messages[key] = locale == 'en_US' ? key : existing?.messages[key] ?? key;
  }
  final Map<String, String> contexts = <String, String>{};
  for (final MapEntry<String, String> entry in source.contexts.entries) {
    contexts[entry.key] = locale == 'en_US'
        ? entry.value
        : existing?.contexts[entry.key] ?? entry.value;
  }

  final List<String> requiredForms = localizationPluralForms[locale]!;
  final Map<String, Map<String, String>> plurals =
      <String, Map<String, String>>{};
  for (final MapEntry<String, Map<String, String>> entry
      in source.plurals.entries) {
    final Map<String, String> english = entry.value;
    final Map<String, String> previous =
        existing?.plurals[entry.key] ?? const <String, String>{};
    plurals[entry.key] = <String, String>{
      for (final String form in requiredForms)
        form: locale == 'en_US'
            ? english[form] ?? english['other']!
            : previous[form] ?? english[form] ?? english['other']!,
    };
  }

  final Map<String, String> previewMessages = <String, String>{};
  for (final MapEntry<String, String> entry in source.previewMessages.entries) {
    previewMessages[entry.key] = locale == 'en_US'
        ? entry.value
        : glossPreview?[entry.key] ??
              existing?.previewMessages[entry.key] ??
              entry.value;
  }
  return applyLockedLocalizationGlossary(
    LocalizationCatalog(
      locale: locale,
      messages: messages,
      contexts: contexts,
      plurals: plurals,
      previewMessages: previewMessages,
    ),
    source,
  );
}

Map<String, Map<String, String>> readGlossPreviewTranslations(
  Directory root,
  Set<String> requiredKeys,
) {
  final Directory languageDirectory = Directory(
    '${root.parent.path}/Gloss/src/main/resources/languages',
  );
  if (!languageDirectory.existsSync()) return <String, Map<String, String>>{};
  final Map<String, Map<String, String>> locales =
      <String, Map<String, String>>{};
  for (final String locale in localizationLocaleCodes.skip(1)) {
    final File file = File('${languageDirectory.path}/$locale.yml');
    if (!file.existsSync()) continue;
    final Map<String, String> flattened = _flattenQuotedYaml(file);
    final Map<String, String> preview = <String, String>{
      for (final String key in requiredKeys)
        if (flattened.containsKey('messages.$key'))
          key: flattened['messages.$key']!,
    };
    if (preview.keys.toSet().containsAll(requiredKeys) &&
        requiredKeys.containsAll(preview.keys)) {
      locales[locale] = preview;
    }
  }
  return locales;
}

Map<String, String> _flattenQuotedYaml(File file) {
  final RegExp linePattern = RegExp(
    r'^(\s*)"((?:\\.|[^"])*)"\s*:\s*(?:"((?:\\.|[^"])*)")?\s*$',
  );
  final List<_YamlLevel> levels = <_YamlLevel>[];
  final Map<String, String> values = <String, String>{};
  for (final String line in file.readAsLinesSync()) {
    final RegExpMatch? match = linePattern.firstMatch(line);
    if (match == null) continue;
    final int indent = match.group(1)!.length;
    final String key = jsonDecode('"${match.group(2)!}"') as String;
    while (levels.isNotEmpty && levels.last.indent >= indent) {
      levels.removeLast();
    }
    final String? encodedValue = match.group(3);
    if (encodedValue == null) {
      levels.add(_YamlLevel(indent, key));
      continue;
    }
    final String value = jsonDecode('"$encodedValue"') as String;
    final String path = <String>[
      for (final _YamlLevel level in levels) level.key,
      key,
    ].join('.');
    values[path] = value;
  }
  return values;
}

Directory _findRoot() {
  Directory current = Directory.current.absolute;
  while (true) {
    if (File('${current.path}/pubspec.yaml').existsSync() &&
        Directory('${current.path}/lib').existsSync()) {
      return current;
    }
    if (current.parent.path == current.path) {
      throw StateError('Run this tool from inside HUI-Web-Editor.');
    }
    current = current.parent;
  }
}

final class _YamlLevel {
  const _YamlLevel(this.indent, this.key);

  final int indent;
  final String key;
}
