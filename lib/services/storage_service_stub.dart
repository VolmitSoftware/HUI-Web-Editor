/// Off-web backend for `storage_service.dart`.
///
/// jaspr_builder analyses every library off-web for style extraction, so the
/// `package:web` backend must never be reachable from a plain VM import. Values
/// live in memory here, which also lets pure-Dart tests exercise the services.
library;

final Map<String, String> _memory = <String, String>{};

String? storageGetItem(String key) => _memory[key];

void storageSetItem(String key, String value) {
  _memory[key] = value;
}

void storageRemoveItem(String key) {
  _memory.remove(key);
}

int storageLength() => _memory.length;

String? storageKeyAt(int index) {
  if (index < 0 || index >= _memory.length) {
    return null;
  }
  return _memory.keys.elementAt(index);
}

/// False off-web: nothing written here survives a process restart.
bool storageIsPersistent() => false;
