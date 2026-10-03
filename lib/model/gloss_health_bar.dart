import 'dart:math' as math;

import 'json_codec.dart';
import '../logic/preview_expr_functions.dart';

final class GlossHealthBar {
  GlossHealthBar({
    this.glyph = '|',
    String? emptyGlyph,
    this.healthyColor = '&a',
    this.warningColor = '&e',
    this.criticalColor = '&c',
    this.damageColor = '&c',
    this.emptyColor = '&8',
    this.warningThreshold = 0.5,
    this.criticalThreshold = 0.25,
    this.decimals = 1,
    Map<String, Object?>? extras,
  }) : emptyGlyph = emptyGlyph ?? glyph,
       extras = extras ?? <String, Object?>{};

  String glyph;
  String emptyGlyph;
  String healthyColor;
  String warningColor;
  String criticalColor;
  String damageColor;
  String emptyColor;
  double warningThreshold;
  double criticalThreshold;
  int decimals;
  Map<String, Object?> extras;

  static GlossHealthBar fromJson(Object? raw, {String path = 'healthBar'}) {
    final Map<String, Object?> map = huiReadObject(
      raw ?? <String, Object?>{},
      path,
    );
    return GlossHealthBar(
      glyph: huiReadString(map, 'glyph', fallback: '|'),
      emptyGlyph: map['emptyGlyph'] == null
          ? null
          : huiReadString(map, 'emptyGlyph'),
      healthyColor: huiReadString(map, 'healthyColor', fallback: '&a'),
      warningColor: huiReadString(map, 'warningColor', fallback: '&e'),
      criticalColor: huiReadString(map, 'criticalColor', fallback: '&c'),
      damageColor: huiReadString(map, 'damageColor', fallback: '&c'),
      emptyColor: huiReadString(map, 'emptyColor', fallback: '&8'),
      warningThreshold: huiReadDouble(map, 'warningThreshold', fallback: 0.5),
      criticalThreshold: huiReadDouble(
        map,
        'criticalThreshold',
        fallback: 0.25,
      ),
      decimals: huiReadInt(map, 'decimals', fallback: 1),
      extras: huiCollectExtras(map, <String>{
        ...GlossHealthBar().toJson().keys,
      }),
    );
  }

  Map<String, Object?> toJson() => huiMergeExtras(<String, Object?>{
    'glyph': glyph,
    'emptyGlyph': emptyGlyph,
    'healthyColor': healthyColor,
    'warningColor': warningColor,
    'criticalColor': criticalColor,
    'damageColor': damageColor,
    'emptyColor': emptyColor,
    'warningThreshold': warningThreshold,
    'criticalThreshold': criticalThreshold,
    'decimals': decimals,
  }, extras);

  GlossHealthBar copy() => GlossHealthBar.fromJson(toJson());

  String render(int segments, double health, double maximum, double previous) {
    final int count = segments.clamp(1, 40);
    final double fraction = maximum > 0 ? (health / maximum).clamp(0, 1) : 0;
    final double priorFraction = maximum > 0
        ? (previous / maximum).clamp(0, 1)
        : fraction;
    final int filled = (fraction * count).ceil();
    final int prior = math.max(filled, (priorFraction * count).ceil());
    final double warning = warningThreshold.isFinite
        ? warningThreshold.clamp(0, 1)
        : 0.5;
    final double critical = math.min(
      warning,
      criticalThreshold.isFinite ? criticalThreshold.clamp(0, 1) : 0.25,
    );
    final String color = fraction >= warning
        ? healthyColor
        : fraction >= critical
        ? warningColor
        : criticalColor;
    return '$color${glyph * filled}$damageColor${glyph * (prior - filled)}$emptyColor${emptyGlyph * (count - prior)}';
  }

  String number(double value) {
    final String formatted = previewStdFunction('fixed', <Object?>[value.isFinite ? value : 0.0, decimals.clamp(0, 6).toDouble()]) as String;
    return formatted.contains('.')
        ? formatted
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '')
        : formatted;
  }
}
