library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:holoui_editor/config/defaults.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:holoui_editor/state/editor_store.dart';
import 'package:holoui_editor/state/workspace.dart';
import 'package:holoui_editor/state/workspace_route.dart';
import 'package:test/test.dart';

String _payload(Map<String, dynamic> envelope) {
  final List<int> bytes = const GZipEncoder().encodeBytes(
    utf8.encode(jsonEncode(envelope)),
  );
  return base64Url.encode(bytes).replaceAll('=', '');
}

void main() {
  test('document hash round-trips stable workspace and document UUIDs', () {
    const String workspaceId = '00000000-0000-4000-8000-000000000001';
    const String documentId = '00000000-0000-4000-8000-000000000002';
    final WorkspaceRouteResult parsed = parseWorkspaceRoute(
      workspaceDocumentHash(workspaceId, documentId),
    );
    final WorkspaceDocumentRoute route =
        parsed.route! as WorkspaceDocumentRoute;
    expect(parsed.error, isNull);
    expect(route.workspaceId, workspaceId);
    expect(route.documentId, documentId);
  });

  test('menu handoff uses base64url gzip envelope v1 and nested ids', () {
    final String json = encodeHuiMenu(createDefaultMenu());
    final String hash = workspaceMenuImportHash(
      WorkspaceMenuImportEnvelope(runtimeId: 'shops/tools/Confirm', json: json),
    );
    expect(hash, startsWith('#/import/menu/'));
    expect(hash, isNot(contains('=')));

    final WorkspaceRouteResult parsed = parseWorkspaceRoute(hash);
    final WorkspaceMenuImportRoute route =
        parsed.route! as WorkspaceMenuImportRoute;
    expect(parsed.error, isNull);
    expect(route.envelope.runtimeId, 'shops/tools/Confirm');
    expect(route.envelope.json, json);
  });

  test('handoff rejects noncanonical runtime ids before import preview', () {
    final String payload = _payload(<String, dynamic>{
      'version': 1,
      'kind': 'menu',
      'runtimeId': 'shops/../secret',
      'json': encodeHuiMenu(createDefaultMenu()),
    });
    final WorkspaceRouteResult parsed = parseWorkspaceRoute(
      '#/import/menu/$payload',
    );
    expect(parsed.route, isNull);
    expect(parsed.error, contains('runtime id'));
  });

  test('handoff rejects wrong versions and invalid menu JSON', () {
    final String wrongVersion = _payload(<String, dynamic>{
      'version': 2,
      'kind': 'menu',
      'runtimeId': 'shop',
      'json': '{}',
    });
    expect(
      parseWorkspaceRoute('#/import/menu/$wrongVersion').error,
      contains('unsupported'),
    );

    final String badMenu = _payload(<String, dynamic>{
      'version': 1,
      'kind': 'menu',
      'runtimeId': 'shop',
      'json': '[]',
    });
    expect(
      parseWorkspaceRoute('#/import/menu/$badMenu').error,
      contains('valid HoloUI menu JSON'),
    );
  });

  test('unsupported and malformed hashes fail without throwing', () {
    expect(parseWorkspaceRoute('#/future/route').error, isNotNull);
    expect(parseWorkspaceRoute('#/import/menu/not-gzip').error, isNotNull);
    expect(parseWorkspaceRoute('').route, isNull);
  });

  test('gzip advertised size is rejected before envelope inflation', () {
    final List<int> compressed = const GZipEncoder().encodeBytes(
      utf8.encode('{}'),
    );
    final int footer = compressed.length - 4;
    const int oversized = 2 * 1024 * 1024 + 1;
    compressed[footer] = oversized & 0xff;
    compressed[footer + 1] = (oversized >> 8) & 0xff;
    compressed[footer + 2] = (oversized >> 16) & 0xff;
    compressed[footer + 3] = (oversized >> 24) & 0xff;
    final String payload = base64Url.encode(compressed).replaceAll('=', '');
    expect(
      parseWorkspaceRoute('#/import/menu/$payload').error,
      contains('too large'),
    );
  });

  test('gzip inflation is bounded when the footer size is forged', () {
    final List<int> compressed = const GZipEncoder().encodeBytes(
      List<int>.filled(2 * 1024 * 1024 + 1, 65),
    );
    final int footer = compressed.length - 4;
    compressed[footer] = 0;
    compressed[footer + 1] = 0;
    compressed[footer + 2] = 0;
    compressed[footer + 3] = 0;
    final String payload = base64Url.encode(compressed).replaceAll('=', '');

    expect(
      parseWorkspaceRoute('#/import/menu/$payload').error,
      contains('too large'),
    );
  });

  test('concatenated gzip members and trailing bytes are rejected', () {
    final List<int> first = const GZipEncoder().encodeBytes(utf8.encode('{}'));
    final List<int> second = const GZipEncoder().encodeBytes(utf8.encode('{}'));
    final String concatenated = base64Url
        .encode(<int>[...first, ...second])
        .replaceAll('=', '');
    final String trailing = base64Url
        .encode(<int>[...first, 0])
        .replaceAll('=', '');

    expect(
      parseWorkspaceRoute('#/import/menu/$concatenated').error,
      contains('not valid gzip'),
    );
    expect(
      parseWorkspaceRoute('#/import/menu/$trailing').error,
      contains('not valid gzip'),
    );
  });

  test('raw handoff creation preserves the exact validated JSON bytes', () {
    final Map<String, String> storage = <String, String>{};
    int nextId = 1;
    final Workspace workspace = Workspace(
      read: (String key) => storage[key],
      write: (String key, String value) {
        storage[key] = value;
        return true;
      },
      idFactory: () {
        final String tail = '${nextId++}'.padLeft(12, '0');
        return '00000000-0000-4000-8000-$tail';
      },
    );
    final EditorStore store = EditorStore(
      workspace: workspace,
      autosaveDelay: const Duration(days: 1),
    );
    const String source =
        '{\n  "id": "server-owned",\n  "components": [],\n'
        '  "extension": {"value": 7},\n  "offset": [0.0, 1, 2]\n}';

    expect(
      store.newMenuDocumentFromJson(
        name: 'Shop',
        runtimeId: 'shops/Shop',
        json: source,
      ),
      isTrue,
    );
    expect(workspace.active?.json, source);
    expect(workspace.active?.runtimeId, 'shops/Shop');
    expect(store.exportJson(), source);
    expect(store.menu.extras['extension'], <String, dynamic>{'value': 7});

    store.dispose();
    final Workspace reloadedWorkspace = Workspace(
      read: (String key) => storage[key],
      write: (String key, String value) {
        storage[key] = value;
        return true;
      },
      idFactory: () {
        final String tail = '${nextId++}'.padLeft(12, '0');
        return '00000000-0000-4000-8000-$tail';
      },
    );
    final EditorStore reloaded = EditorStore(
      workspace: reloadedWorkspace,
      autosaveDelay: const Duration(days: 1),
    );
    expect(reloaded.exportJson(), source);

    reloaded.mutate('turn follow on', (HuiMenu menu) {
      menu.followPlayer = true;
    });
    expect(reloaded.exportJson(), isNot(source));
    expect(jsonDecode(reloaded.exportJson()), contains('closeOnDeath'));

    reloaded.dispose();
    reloadedWorkspace.dispose();
    workspace.dispose();
  });
}
