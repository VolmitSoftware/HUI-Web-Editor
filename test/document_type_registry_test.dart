import 'package:gloss_editor/doctype/document_type.dart';
import 'package:gloss_editor/doctype/document_type_registry.dart';
import 'package:test/test.dart';

void main() {
  test('detectTransferable routes every runtime document shape', () {
    final Map<String, Object> samples = <String, Object>{
      'menu': <String, Object>{'components': <Object>[]},
      'preview': <String, Object>{'elements': <Object>[]},
      'hologram': <String, Object>{
        'schemaVersion': 1,
        'anchor': <String, Object>{},
      },
      'animation': <String, Object>{'schemaVersion': 1, 'frames': <Object>[]},
      'scoreboard': <String, Object>{'schemaVersion': 1, 'title': 'Board'},
      'motd': <String, Object>{'schemaVersion': 1, 'entries': <Object>[]},
      'emoji': <String, Object>{'schemaVersion': 1, 'emoji': 'U+2764;'},
      'bubble-style': <String, Object>{'schemaVersion': 2, 'wordWrapChars': 32},
      'tablist': <String, Object>{
        'schemaVersion': 1,
        'nameFormats': <String, Object>{},
      },
      'damage-indicators': <String, Object>{
        'schemaVersion': 1,
        'limits': <String, Object>{},
        'damage': <String, Object>{},
        'healing': <String, Object>{},
        'filters': <String, Object>{},
      },
    };

    for (final MapEntry<String, Object> sample in samples.entries) {
      final DocumentTypeAdapter type = DocumentTypeRegistry.detectTransferable(
        sample.value,
      );
      final String expected = sample.key == 'preview'
          ? 'container-preview'
          : sample.key;
      expect(type.syncWireKind, expected, reason: sample.key);
    }
  });

  test('detectTransferable keeps malformed unmarked JSON on menu fallback', () {
    final DocumentTypeAdapter type = DocumentTypeRegistry.detectTransferable(
      <String, Object>{'unknown': true},
    );
    expect(type.syncWireKind, 'menu');
  });
}
