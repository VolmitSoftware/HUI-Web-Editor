import 'package:gloss_editor/components/shell/shell_keys.dart';
import 'package:test/test.dart';

void main() {
  group('overlay Escape precedence', () {
    test('an armed delete confirm is closed before the app overlays', () {
      expect(
        huiOverlayEscapeTarget(confirmDeleteOpen: true),
        HuiOverlayEscape.confirmDelete,
      );
    });

    test('with nothing armed the app closes its own dialogs and sheet', () {
      expect(
        huiOverlayEscapeTarget(confirmDeleteOpen: false),
        HuiOverlayEscape.appOverlay,
      );
    });
  });
}
