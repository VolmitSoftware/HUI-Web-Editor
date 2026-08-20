import 'dart:io';

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

  group('mobile pane Escape', () {
    test('closes an open pane with an unmodified Escape press', () {
      expect(
        huiClosesMobilePane(
          const ShellKey(key: 'Escape'),
          mobilePaneOpen: true,
        ),
        isTrue,
      );
    });

    test('does not claim Escape without a pane or with modifiers', () {
      expect(
        huiClosesMobilePane(
          const ShellKey(key: 'Escape'),
          mobilePaneOpen: false,
        ),
        isFalse,
      );
      expect(
        huiClosesMobilePane(
          const ShellKey(key: 'Escape', ctrl: true),
          mobilePaneOpen: true,
        ),
        isFalse,
      );
    });

    test('both canvas stages defer Escape to the open pane', () {
      for (final String path in <String>[
        'lib/components/canvas/canvas_interactions.dart',
        'lib/components/preview_card/preview_card_interactions.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains("if (key.key == 'Escape' && huiMobilePaneOpen()) return;"),
          reason: path,
        );
      }
    });
  });
}
