/// Browser backend for `storage_service.dart`.
///
/// Every entry point may throw: `localStorage` is absent in some embedded
/// webviews and throws `SecurityError` when cookies are blocked, and `setItem`
/// throws `QuotaExceededError` once the ~5 MB origin budget is spent.
/// [StorageService] owns the try/catch; this layer stays a thin binding.
library;

import 'package:web/web.dart' as web;

String? storageGetItem(String key) => web.window.localStorage.getItem(key);

void storageSetItem(String key, String value) {
  web.window.localStorage.setItem(key, value);
}

void storageRemoveItem(String key) {
  web.window.localStorage.removeItem(key);
}

int storageLength() => web.window.localStorage.length;

String? storageKeyAt(int index) => web.window.localStorage.key(index);

bool storageIsPersistent() => true;
