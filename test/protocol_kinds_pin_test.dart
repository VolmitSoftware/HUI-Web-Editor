import 'dart:io';

import 'package:test/test.dart';

/// `sync-relay/protocol.md` states the document kinds the transport carries.
/// Gloss is the truth repo for that list, so the table is derived from
/// `EditorSyncDocumentKind` in the paired checkout rather than maintained by
/// hand: a kind a lane adds shows up in the protocol or this test fails.
void main() {
  test('the protocol kind table matches the paired Gloss checkout', () {
    final File source = File(
      '../Gloss/src/main/java/art/arcane/gloss/editor/sync/'
      'EditorSyncDocumentKind.java',
    );
    if (!source.existsSync()) {
      markTestSkipped('no paired Gloss checkout beside this repository');
      return;
    }

    final String table = protocolKindTable(source.readAsStringSync());
    final String protocol = File('sync-relay/protocol.md').readAsStringSync();

    expect(
      protocol.contains(table),
      isTrue,
      reason:
          'sync-relay/protocol.md is missing the generated kind table:\n$table',
    );
  });

  test('every kind in the table is a transport slug', () {
    final File source = File(
      '../Gloss/src/main/java/art/arcane/gloss/editor/sync/'
      'EditorSyncDocumentKind.java',
    );
    if (!source.existsSync()) {
      markTestSkipped('no paired Gloss checkout beside this repository');
      return;
    }

    final List<ProtocolKind> kinds = protocolKinds(source.readAsStringSync());
    final RegExp slug = RegExp(r'^[a-z][a-z0-9-]{0,31}$');

    expect(kinds, isNotEmpty);
    for (final ProtocolKind kind in kinds) {
      expect(slug.hasMatch(kind.wireName), isTrue, reason: kind.wireName);
    }
  });
}

/// One row of the protocol's kind table.
final class ProtocolKind {
  const ProtocolKind({
    required this.wireName,
    required this.storageName,
    required this.layout,
    required this.versioned,
    required this.singletonId,
  });

  final String wireName;
  final String storageName;
  final String layout;
  final bool versioned;
  final String singletonId;

  String get row =>
      '| `$wireName` | `$storageName` | $layout | ${versioned ? 'yes' : 'no'} '
      '| ${singletonId.isEmpty ? '-' : '`$singletonId`'} |';
}

List<ProtocolKind> protocolKinds(String java) {
  final RegExp constant = RegExp(
    r'\n  [A-Z_]+\(\s*"([a-z0-9-]+)"\s*,\s*"([^"]+)"\s*,\s*'
    r'Layout\.([A-Z_]+)\s*,\s*(true|false)\s*,\s*([^,]+?)\s*,',
  );
  final List<ProtocolKind> kinds = <ProtocolKind>[];
  for (final RegExpMatch match in constant.allMatches(java)) {
    final String rawSingleton = match.group(5)!.trim();
    final String singletonId;
    if (rawSingleton == 'null') {
      singletonId = '';
    } else if (rawSingleton.startsWith('"')) {
      singletonId = rawSingleton.substring(1, rawSingleton.length - 1);
    } else if (rawSingleton.endsWith('DEFAULT_ID')) {
      singletonId = 'default';
    } else {
      singletonId = rawSingleton;
    }
    kinds.add(
      ProtocolKind(
        wireName: match.group(1)!,
        storageName: match.group(2)!,
        layout: match.group(3)!,
        versioned: match.group(4) == 'true',
        singletonId: singletonId,
      ),
    );
  }
  kinds.sort(
    (ProtocolKind left, ProtocolKind right) =>
        left.wireName.compareTo(right.wireName),
  );
  return kinds;
}

String protocolKindTable(String java) => <String>[
  '| Wire kind | Storage | Layout | Versioned | Singleton id |',
  '|---|---|---|---|---|',
  for (final ProtocolKind kind in protocolKinds(java)) kind.row,
].join('\n');
