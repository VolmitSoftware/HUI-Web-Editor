library;

import '../state/editor_store.dart';
import '../l10n/hui_localizations.dart';
import 'storage_service.dart';

const String _themeStorageKey = 'gloss.theme';

final class LocalDataResetResult {
  const LocalDataResetResult({required this.success, required this.message});

  final bool success;
  final String message;
}

Future<LocalDataResetResult> resetAllLocalEditorData(
  EditorStore store, {
  required bool isDarkMode,
}) async {
  store.flushAutosave();
  final bool reset = await store.workspace.reset();
  if (!reset) {
    return LocalDataResetResult(
      success: false,
      message:
          store.workspace.lastError ??
          huiText('Browser storage refused the reset.'),
    );
  }
  final bool imagesCleared = store.images?.clear() ?? true;
  final bool localStorageCleared = StorageService.clearAll();
  final bool themeSaved = StorageService.write(
    _themeStorageKey,
    isDarkMode ? 'dark' : 'light',
  );
  final bool localeSaved = StorageService.write(
    huiLocaleStorageKey,
    huiLocalizations.activeLocale,
  );
  store.images?.load();
  store.resetLocalPreferences();
  store.adoptEmptyWorkspace();
  await store.workspace.writesSettled;
  final bool workspaceReady =
      store.workspace.docs.isEmpty &&
      store.workspace.folders.isEmpty &&
      !store.workspace.hasUnsavedChanges;
  if (imagesCleared &&
      localStorageCleared &&
      themeSaved &&
      localeSaved &&
      workspaceReady) {
    return LocalDataResetResult(
      success: true,
      message: huiText('Local data cleared. The workspace is empty.'),
    );
  }
  return LocalDataResetResult(
    success: false,
    message: huiText(
      'The workspace was reset, but some browser data could not be cleared or the empty workspace could not be saved. Reload and verify local data before continuing.',
    ),
  );
}
