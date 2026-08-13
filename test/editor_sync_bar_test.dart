import 'package:holoui_editor/components/shell/editor_sync_bar.dart';
import 'package:holoui_editor/services/editor_sync.dart';
import 'package:test/test.dart';

void main() {
  group('editor sync publish controls', () {
    test('connected and applied projects can publish', () {
      expect(_controls(EditorSyncStatus.connected).canPublish, isTrue);
      expect(_controls(EditorSyncStatus.applied).canPublish, isTrue);
    });

    test('busy and pending projects cannot publish', () {
      expect(
        _controls(EditorSyncStatus.connected, busy: true).canPublish,
        isFalse,
      );
      expect(_controls(EditorSyncStatus.pending).canPublish, isFalse);
    });

    test('rejected projects explain that publishing can be retried', () {
      final EditorSyncControls controls = _controls(EditorSyncStatus.rejected);

      expect(controls.canPublish, isTrue);
      expect(controls.publishLabel, 'Publish to Server');
      expect(controls.publishHint, contains('publish again'));
    });
  });
}

EditorSyncControls _controls(EditorSyncStatus status, {bool busy = false}) =>
    EditorSyncControls(
      status: status,
      subjectId: 'lobby-board',
      busy: busy,
      onPublish: _noop,
      onCopyLink: _noop,
      onDisconnect: _noop,
    );

void _noop() {}
