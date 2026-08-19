library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

enum GlossPreviewAlignment { center, end, top, bottom }

class GlossPreviewZoom extends StatefulWidget {
  const GlossPreviewZoom({
    required this.child,
    required this.label,
    this.alignment = GlossPreviewAlignment.center,
    super.key,
  });

  final Widget child;
  final String label;
  final GlossPreviewAlignment alignment;

  @override
  State<GlossPreviewZoom> createState() => _GlossPreviewZoomState();
}

class _GlossPreviewZoomState extends State<GlossPreviewZoom> {
  static const double _minimumScale = 0.5;
  static const double _maximumScale = 2;
  static const double _scaleStep = 0.25;

  double _scale = 1;

  void _zoomBy(double delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minimumScale, _maximumScale);
    });
  }

  void _fit() {
    if (_scale == 1) return;
    setState(() => _scale = 1);
  }

  @override
  Widget build(BuildContext context) => dom.div(
    classes:
        'hui-gloss-preview-viewport '
        'is-${component.alignment.name}',
    <Widget>[
      dom.div(
        classes: 'hui-gloss-preview-content',
        styles: dom.Styles(
          raw: <String, String>{
            '--hui-gloss-preview-scale': _scale.toStringAsFixed(2),
          },
        ),
        <Widget>[component.child],
      ),
      dom.div(
        classes: 'hui-gloss-preview-controls',
        attributes: <String, String>{
          'role': 'group',
          'aria-label': '${component.label} zoom',
        },
        <Widget>[
          _action(
            label: 'Zoom out',
            icon: ArcaneIcon.zoomOut(size: IconSize.sm),
            onPressed: _scale <= _minimumScale
                ? null
                : () => _zoomBy(-_scaleStep),
          ),
          dom.span(classes: 'hui-gloss-preview-percent', <Widget>[
            Text('${(_scale * 100).round()}%'),
          ]),
          _action(
            label: 'Zoom in',
            icon: ArcaneIcon.zoomIn(size: IconSize.sm),
            onPressed: _scale >= _maximumScale
                ? null
                : () => _zoomBy(_scaleStep),
          ),
          _action(
            label: 'Fit preview',
            icon: ArcaneIcon.maximize(size: IconSize.sm),
            onPressed: _fit,
          ),
        ],
      ),
    ],
  );

  Widget _action({
    required String label,
    required Widget icon,
    required void Function()? onPressed,
  }) => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    onPressed: onPressed,
    attributes: <String, String>{'aria-label': label, 'title': label},
    child: icon,
  );
}
