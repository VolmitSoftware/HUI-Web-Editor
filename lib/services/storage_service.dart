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
  static const String keyPrefix = 'holoui.';

  /// Browsers do not expose the localStorage budget. 5 MB is the near-universal
  /// value and is only used to draw a usage meter.
  static const int approximateQuotaBytes = 5 * 1024 * 1024;

  static String? read(String key) {
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
    try {
      storageSetItem(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  static void remove(String key) {
    try {
      storageRemoveItem(key);
    } catch (_) {}
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

  /// Drops every key this app owns. Used by the "reset local data" action.
  static void clearAll({String prefix = keyPrefix}) {
    for (final String key in keys(prefix: prefix)) {
      remove(key);
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
