library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'hui_localizations.dart';

List<String> huiBrowserLanguages() {
  final List<String> languages = web.window.navigator.languages.toDart
      .map((JSString language) => language.toDart)
      .where((String language) => language.isNotEmpty)
      .toList(growable: false);
  if (languages.isNotEmpty) return languages;
  final String fallback = web.window.navigator.language;
  return fallback.isEmpty ? const <String>[] : <String>[fallback];
}

void stampHuiDocument({
  required HuiLocale locale,
  required String title,
  required String description,
  required String manifestPath,
}) {
  final web.Element? root = web.document.documentElement;
  root?.setAttribute('lang', locale.htmlLanguage);
  root?.setAttribute('dir', locale.rightToLeft ? 'rtl' : 'ltr');
  web.document.title = title;
  _setMeta('meta[name="description"]', 'content', description);
  _setMeta('meta[property="og:title"]', 'content', title);
  _setMeta('meta[property="og:description"]', 'content', description);
  _setAttribute('link[rel="manifest"]', 'href', manifestPath);
}

void _setMeta(String selector, String attribute, String value) {
  _setAttribute(selector, attribute, value);
}

void _setAttribute(String selector, String attribute, String value) {
  web.document.querySelector(selector)?.setAttribute(attribute, value);
}
