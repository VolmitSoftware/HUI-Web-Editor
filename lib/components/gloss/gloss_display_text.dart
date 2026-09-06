library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import '../../model/hui_icons.dart';
import '../../model/gloss_hologram_box.dart';

String glossArgbCss(String value) {
  final String hex = value.replaceFirst('#', '');
  final int? argb = int.tryParse(hex, radix: 16);
  if (hex.length != 8 || argb == null) return 'transparent';
  return 'rgba(${(argb >> 16) & 255},${(argb >> 8) & 255},${argb & 255},${((argb >> 24) & 255) / 255})';
}

class GlossDisplayText extends StatelessWidget {
  const GlossDisplayText({
    required this.style,
    required this.box,
    required this.child,
    this.pixelsPerFontPixel = 2,
    super.key,
  });
  final HuiIconStyle style;
  final GlossHologramBox box;
  final Widget child;
  final double pixelsPerFontPixel;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-display-text',
    styles: dom.Styles(
      raw: <String, String>{
        'position': 'relative',
        'display': 'inline-block',
        'text-align': style.textAlignment,
        'padding':
            '${box.enabled ? box.padding.clamp(0, 64) * pixelsPerFontPixel : 0}px',
        'border': box.enabled
            ? '${box.borderWidth.clamp(0, 16) * pixelsPerFontPixel}px solid ${glossArgbCss(box.borderArgb)}'
            : 'none',
        'background': box.enabled
            ? glossArgbCss(box.backgroundArgb)
            : 'transparent',
        'background-clip': 'padding-box',
      },
    ),
    <Widget>[
      dom.div(
        styles: dom.Styles(
          raw: <String, String>{
            'background': glossArgbCss(style.backgroundArgb),
            'opacity': (style.textOpacity.clamp(0, 255) / 255).toString(),
            'text-shadow': style.shadow
                ? '${pixelsPerFontPixel}px ${pixelsPerFontPixel}px rgba(0,0,0,.65)'
                : 'none',
            'max-width':
                '${style.lineWidth.clamp(1, 16384) * pixelsPerFontPixel}px',
            'white-space': 'pre-wrap',
            'overflow-wrap': 'anywhere',
          },
        ),
        <Widget>[child],
      ),
    ],
  );
}
