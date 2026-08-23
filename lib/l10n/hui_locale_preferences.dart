library;

import '../services/storage_service.dart';
import 'hui_locale_platform.dart' as platform;
import 'hui_localizations.dart';

String resolveInitialHuiLocale({
  String? storedLocale,
  Iterable<String> browserLanguages = const <String>[],
}) {
  if (storedLocale != null) {
    try {
      return canonicalHuiLocale(storedLocale);
    } on ArgumentError {
      StorageService.remove(huiLocaleStorageKey);
    }
  }
  return matchHuiLocale(browserLanguages) ?? huiEnglishLocale;
}

String loadInitialHuiLocale() => resolveInitialHuiLocale(
  storedLocale: StorageService.read(huiLocaleStorageKey),
  browserLanguages: platform.huiBrowserLanguages(),
);

bool persistHuiLocale(String locale) =>
    StorageService.write(huiLocaleStorageKey, canonicalHuiLocale(locale));

String huiLocaleManifestPath(String locale) =>
    '/manifests/${canonicalHuiLocale(locale)}.webmanifest';

void stampHuiLocaleDocument(String locale) {
  final HuiLocale metadata = huiLocale(locale);
  platform.stampHuiDocument(
    locale: metadata,
    title: huiText(huiDocumentTitleSource),
    description: huiText(huiDocumentDescriptionSource),
    manifestPath: huiLocaleManifestPath(metadata.code),
  );
}
