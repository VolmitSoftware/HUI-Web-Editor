/// Light/dark theme persistence and document stamping.
///
/// The pre-paint IIFE in `web/index.html` mirrors [stampDocumentTheme] so the
/// page never flashes the wrong brightness before the bundle boots. Keep the
/// two in sync.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:web/web.dart' as web;

const String _themeStorageKey = 'gloss.theme';

Brightness loadStoredBrightness() {
  try {
    final String? stored = web.window.localStorage.getItem(_themeStorageKey);
    if (stored == 'light') return Brightness.light;
    if (stored == 'dark') return Brightness.dark;
  } catch (_) {
    // Private mode or storage disabled; fall through to default.
  }
  return Brightness.dark;
}

void persistBrightness(Brightness brightness) {
  try {
    web.window.localStorage.setItem(
      _themeStorageKey,
      brightness == Brightness.light ? 'light' : 'dark',
    );
  } catch (_) {}
}

void stampDocumentTheme(Brightness brightness) {
  final web.Element root = web.document.documentElement!;
  root.classList.remove('light');
  root.classList.remove('dark');
  root.classList.add(brightness == Brightness.light ? 'light' : 'dark');
}
