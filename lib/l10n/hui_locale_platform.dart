library;

import 'hui_locale_platform_stub.dart'
    if (dart.library.js_interop) 'hui_locale_platform_web.dart'
    as platform;
import 'hui_localizations.dart';

List<String> huiBrowserLanguages() => platform.huiBrowserLanguages();

void stampHuiDocument({
  required HuiLocale locale,
  required String title,
  required String description,
  required String manifestPath,
}) => platform.stampHuiDocument(
  locale: locale,
  title: title,
  description: description,
  manifestPath: manifestPath,
);
