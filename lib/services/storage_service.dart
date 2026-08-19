/// Guarded `localStorage` access.
///
/// The previous editor wrote base64 images straight into `localStorage` and
/// never checked the result, so a `QuotaExceededError` silently destroyed the
/// whole document. Every call here is wrapped: reads degrade to null, writes
/// report failure, and callers are expected to roll their state back.
library;

import 'storage_service_stub.dart'
    if (dart.library.js_interop) 'storage_service_web.dart';

class StorageService {
  const StorageService._();

  /// Every key this app owns starts with it; used for usage accounting and for
  /// the "reset local data" action.
  static const String keyPrefix = 'gloss.';

  /// The pre-rebrand prefix. [_ensureMigrated] copies data written under it to
  /// [keyPrefix] once, and [clearAll] still clears it so "reset local data"
  /// cannot resurrect old values.
  static const String legacyKeyPrefix = 'holoui.';

  /// Present once the one-time `holoui.*` -> `gloss.*` copy has run. Lives
  /// under [keyPrefix] so a full reset re-arms the (then no-op) migration.
  static const String migrationMarkerKey = '${keyPrefix}migrated.v1';

  /// One-time, non-destructive `holoui.*` -> `gloss.*` copy. Old keys are kept
  /// so an older deployed editor still finds its data; copy-if-absent keeps a
  /// rerun (marker write failed) harmless. Uses the raw backend so it cannot
  /// recurse through the public API.
  static void _ensureMigrated() {
    try {
      if (storageGetItem(migrationMarkerKey) != null) return;
      final List<String> legacyKeys = <String>[];
      final int count = storageLength();
      for (int i = 0; i < count; i++) {
        final String? key = storageKeyAt(i);
        if (key != null && key.startsWith(legacyKeyPrefix)) {
          legacyKeys.add(key);
        }
      }
      for (final String legacyKey in legacyKeys) {
        final String newKey =
            keyPrefix + legacyKey.substring(legacyKeyPrefix.length);
        if (storageGetItem(newKey) != null) continue;
        final String? value = storageGetItem(legacyKey);
        if (value != null) storageSetItem(newKey, value);
      }
      storageSetItem(migrationMarkerKey, '1');
    } catch (_) {
      // Storage unavailable or full: the next access retries; readers then
      // simply miss and fall back exactly as before the migration existed.
    }
  }

  /// Browsers do not expose the localStorage budget. 5 MB is the near-universal
  /// value and is only used to draw a usage meter.
  static const int approximateQuotaBytes = 5 * 1024 * 1024;

  static String? read(String key) {
    _ensureMigrated();
    try {
      return storageGetItem(key);
    } catch (_) {
      return null;
    }
  }

  /// Returns false when the value could not be persisted (quota exceeded,
  /// storage disabled, private mode). Callers must treat false as "the previous
  /// persisted state is still what is on disk".
  static bool write(String key, String value) {
    _ensureMigrated();
    try {
      storageSetItem(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool remove(String key) {
    _ensureMigrated();
    try {
      storageRemoveItem(key);
      return true;
    } catch (_) {}
    return false;
  }

  static bool get isPersistent {
    try {
      return storageIsPersistent();
    } catch (_) {
      return false;
    }
  }

  /// All keys under [prefix], in whatever order the browser reports them.
  static List<String> keys({String prefix = keyPrefix}) {
    _ensureMigrated();
    final List<String> found = <String>[];
    try {
      final int count = storageLength();
      for (int i = 0; i < count; i++) {
        final String? key = storageKeyAt(i);
        if (key != null && key.startsWith(prefix)) {
          found.add(key);
        }
      }
    } catch (_) {
      return found;
    }
    return found;
  }

  /// Approximate bytes held by this app's keys. localStorage stores UTF-16, and
  /// browsers charge for both key and value, hence the x2.
  static int estimateUsageBytes({String prefix = keyPrefix}) {
    int total = 0;
    for (final String key in keys(prefix: prefix)) {
      final String? value = read(key);
      total += (key.length + (value?.length ?? 0)) * 2;
    }
    return total;
  }

  /// Drops every key this app owns, including keys still under the pre-rebrand
  /// [legacyKeyPrefix] so a reset cannot be undone by re-migration. Used by the
  /// "reset local data" action.
  static bool clearAll({String prefix = keyPrefix}) {
    try {
      final List<String> found = <String>[];
      final int count = storageLength();
      for (int i = 0; i < count; i++) {
        final String? key = storageKeyAt(i);
        if (key != null &&
            (key.startsWith(prefix) || key.startsWith(legacyKeyPrefix))) {
          found.add(key);
        }
      }
      for (final String key in found) {
        storageRemoveItem(key);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Round-trips a probe key so the UI can warn before the user loses work.
  static bool get isWritable {
    const String probeKey = '${keyPrefix}probe';
    if (!write(probeKey, '1')) {
      return false;
    }
    remove(probeKey);
    return true;
  }
}
