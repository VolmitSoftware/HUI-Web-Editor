library;

import 'package:holoui_editor/components/dialogs/editor_sync_dialog.dart';
import 'package:test/test.dart';

void main() {
  test(
    'fresh sync capability opens approval before the first relay request',
    () {
      expect(
        editorSyncImportDialogShouldOpen(
          relayEndpoint: Uri.parse('https://relay.example/v1'),
          loading: false,
          error: null,
          session: null,
        ),
        isTrue,
      );
      expect(
        editorSyncImportDialogShouldOpen(
          relayEndpoint: null,
          loading: false,
          error: null,
          session: null,
        ),
        isFalse,
      );
    },
  );
}
