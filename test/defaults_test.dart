/// The factory defaults and the authoring tables that go with them.
library;

import 'package:holoui_editor/config/defaults.dart';
import 'package:holoui_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  group('createDefaultIcon', () {
    test('builds one icon per authorable type', () {
      for (final String type in huiIconTypes) {
        expect(createDefaultIcon(type).type, type, reason: type);
      }
    });

    test('a new custom item icon is auto-detect with an empty id', () {
      final HuiCustomItemIcon icon =
          createDefaultIcon('customItem') as HuiCustomItemIcon;
      expect(icon.provider, huiAutoItemProvider);
      expect(icon.item, isEmpty);
      expect(icon.count, 1);
    });
  });

  group('huiItemProviderInfo', () {
    test('describes every provider the format allows', () {
      for (final String provider in huiCustomItemProviders) {
        final HuiItemProviderInfo? info = huiItemProviderInfo[provider];
        expect(info, isNotNull, reason: provider);
        expect(info!.label, isNotEmpty, reason: provider);
        expect(info.idFormat, isNotEmpty, reason: provider);
        expect(info.example, isNotEmpty, reason: provider);
      }
    });

    test('describes nothing the format does not allow', () {
      expect(huiItemProviderInfo.keys, huiCustomItemProviders);
    });
  });

  group('huiIconTypeDescriptions', () {
    test('covers every authorable icon type', () {
      for (final String type in huiIconTypes) {
        expect(huiIconTypeDescriptions[type], isNotNull, reason: type);
      }
    });
  });
}
