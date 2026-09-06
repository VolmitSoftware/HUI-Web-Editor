library;

import 'json_codec.dart';
import 'hui_icons.dart';

HuiIconStyle defaultHologramDisplayStyle() =>
    HuiIconStyle(billboard: 'center', seeThrough: true);

final class GlossHologramBox {
  GlossHologramBox({
    this.enabled = false,
    this.padding = 4,
    this.borderWidth = 1,
    this.backgroundArgb = '#B31B1B22',
    this.borderArgb = '#FFAAAAAA',
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  bool enabled;
  int padding;
  int borderWidth;
  String backgroundArgb;
  String borderArgb;
  Map<String, Object?> extras;

  static GlossHologramBox fromJson(Object? raw) {
    if (raw == null) return GlossHologramBox();
    final Map<String, Object?> map = huiReadObject(raw, r'$.box');
    return GlossHologramBox(
      enabled: huiReadBool(map, 'enabled'),
      padding: huiReadInt(map, 'padding', fallback: 4),
      borderWidth: huiReadInt(map, 'borderWidth', fallback: 1),
      backgroundArgb: huiReadString(
        map,
        'backgroundArgb',
        fallback: '#B31B1B22',
      ),
      borderArgb: huiReadString(map, 'borderArgb', fallback: '#FFAAAAAA'),
      extras: huiCollectExtras(map, const <String>{
        'enabled',
        'padding',
        'borderWidth',
        'backgroundArgb',
        'borderArgb',
      }),
    );
  }

  GlossHologramBox copy() => GlossHologramBox.fromJson(toJson());

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'enabled': enabled,
    'padding': padding,
    'borderWidth': borderWidth,
    'backgroundArgb': backgroundArgb,
    'borderArgb': borderArgb,
  }, extras);
}
