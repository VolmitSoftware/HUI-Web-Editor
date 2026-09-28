library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../l10n/hui_localizations.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';

class DisplayStyleEditor extends StatelessWidget {
  const DisplayStyleEditor({
    required this.style,
    required this.onChanged,
    required this.issues,
    this.defaults,
    this.title = 'Display style',
    this.sectionKey,
    this.entityOverlay = false,
  });

  final HuiIconStyle? style;
  final HuiIconStyle? defaults;
  final String title;
  final String? sectionKey;
  final bool entityOverlay;
  final void Function(String label, HuiIconStyle? style) onChanged;
  final List<HuiIssue> issues;

  HuiIconStyle get _defaultStyle =>
      defaults?.copy() ?? createDefaultIconStyle();

  HuiIconStyle _next(void Function(HuiIconStyle style) update) {
    final HuiIconStyle next = style?.copy() ?? _defaultStyle;
    update(next);
    return next;
  }

  List<ArcaneSelectOption> _options(
    List<String> values,
    String current,
    String Function(String value) label,
  ) => <ArcaneSelectOption>[
    for (final String value in values)
      ArcaneSelectOption(label: label(value), value: value),
    if (!values.contains(current))
      ArcaneSelectOption(
        label: huiText("{current} (unknown)", <String, Object?>{
          'current': current,
        }),
        value: current,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final HuiIconStyle? current = style;
    if (current == null) {
      return InspectorSection(
        title: huiText(title),
        sectionKey: sectionKey,
        description: huiText('Uses the runtime display-entity defaults.'),
        children: <Widget>[
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () => onChanged('add display style', _defaultStyle),
            label: huiText('Customize display'),
          ),
        ],
      );
    }

    return InspectorSection(
      title: huiText(title),
      sectionKey:
          sectionKey ??
          (entityOverlay ? 'entity-overlays.style' : 'icon.style'),
      description: entityOverlay
          ? huiText('Appearance of the entity pane and its box decoration.')
          : huiText('Native display metadata for this surface.'),
      trailing: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () => onChanged('remove display style', null),
        label: huiText('Use defaults'),
      ),
      children: <Widget>[
        HuiField(
          label: huiText('Billboard'),
          help: entityOverlay
              ? huiText(
                  'Fixed keeps the pane orientation; other modes face viewers.',
                )
              : huiText(
                  'Fixed follows the menu transform; other modes face viewers.',
                ),
          trailing: const HuiFieldHelp('icon.style.billboard'),
          defaultValue: _billboardLabel(_defaultStyle.billboard),
          onReset: current.billboard == _defaultStyle.billboard
              ? null
              : () => onChanged(
                  'icon billboard',
                  _next(
                    (HuiIconStyle next) =>
                        next.billboard = _defaultStyle.billboard,
                  ),
                ),
          control: ArcaneSelect(
            value: current.billboard,
            size: ComponentSize.sm,
            fullWidth: true,
            options: _options(
              huiIconBillboards,
              current.billboard,
              _billboardLabel,
            ),
            onChanged: (String value) => onChanged(
              'icon billboard',
              _next((HuiIconStyle next) => next.billboard = value),
            ),
          ),
        ),
        HuiField(
          label: huiText('Non-uniform scale'),
          help: entityOverlay
              ? huiText(
                  'X changes width, Y changes height, and Z changes depth.',
                )
              : huiText(
                  'Multiplied by the server uiScale. X and Y also resize the '
                  'automatic click plane; Z never does.',
                ),
          defaultValue:
              '${_defaultStyle.scaleX}, ${_defaultStyle.scaleY}, ${_defaultStyle.scaleZ}',
          onReset:
              current.scaleX == _defaultStyle.scaleX &&
                  current.scaleY == _defaultStyle.scaleY &&
                  current.scaleZ == _defaultStyle.scaleZ
              ? null
              : () => onChanged(
                  'icon scale',
                  _next((HuiIconStyle next) {
                    next.scaleX = _defaultStyle.scaleX;
                    next.scaleY = _defaultStyle.scaleY;
                    next.scaleZ = _defaultStyle.scaleZ;
                  }),
                ),
          control: dom.div(<Widget>[
            HuiVec3Field(
              value: Vec3(current.scaleX, current.scaleY, current.scaleZ),
              step: 0.05,
              decimals: 2,
              axisHints: entityOverlay
                  ? <String>[
                      huiText('Width'),
                      huiText('Height'),
                      huiText('Depth'),
                    ]
                  : <String>[
                      huiText('x: width, and the click plane with it'),
                      huiText(
                        'y: height, which also re-spaces multi-line text',
                      ),
                      huiText('z: depth. Visible on block and item icons only'),
                    ],
              onChanged: (Vec3 value) => onChanged(
                'icon scale',
                _next((HuiIconStyle next) {
                  next.scaleX = value.x;
                  next.scaleY = value.y;
                  next.scaleZ = value.z;
                }),
              ),
            ),
            HuiHelpCluster(<String>[
              'icon.style.scaleX',
              'icon.style.scaleY',
              'icon.style.scaleZ',
            ], label: huiText('Per axis')),
          ]),
        ),
        InspectorSection(
          title: huiText('Text appearance'),
          sectionKey: entityOverlay
              ? 'entity-overlays.style.text'
              : 'icon.style.text',
          initiallyOpen: false,
          children: <Widget>[
            if (!entityOverlay)
              HuiNote(
                huiText(
                  'Text displays only. On an item, custom-item or block icon '
                  'every field in this group is silently inert — image icons do '
                  'honour them, because Gloss draws them as text.',
                ),
                tone: HuiNoteTone.info,
              ),
            HuiSwitchRow(
              label: huiText('Text shadow'),
              value: current.shadow,
              trailing: const HuiFieldHelp('icon.style.shadow'),
              onChanged: (bool value) => onChanged(
                'text shadow',
                _next((HuiIconStyle next) => next.shadow = value),
              ),
            ),
            HuiSwitchRow(
              label: huiText('See through blocks'),
              value: current.seeThrough,
              trailing: const HuiFieldHelp('icon.style.seeThrough'),
              onChanged: (bool value) => onChanged(
                'text see through',
                _next((HuiIconStyle next) => next.seeThrough = value),
              ),
            ),
            HuiField(
              label: huiText('Alignment'),
              trailing: const HuiFieldHelp('icon.style.textAlignment'),
              defaultValue: _alignmentLabel('center'),
              onReset: current.textAlignment == 'center'
                  ? null
                  : () => onChanged(
                      'text alignment',
                      _next(
                        (HuiIconStyle next) => next.textAlignment = 'center',
                      ),
                    ),
              control: ArcaneSelect(
                value: current.textAlignment,
                size: ComponentSize.sm,
                fullWidth: true,
                options: _options(
                  huiIconTextAlignments,
                  current.textAlignment,
                  _alignmentLabel,
                ),
                onChanged: (String value) => onChanged(
                  'text alignment',
                  _next((HuiIconStyle next) => next.textAlignment = value),
                ),
              ),
            ),
            HuiField(
              label: huiText('Background'),
              trailing: const HuiFieldHelp('icon.style.backgroundArgb'),
              help: huiText('Eight hexadecimal digits in #AARRGGBB order.'),
              defaultValue: '#00000000',
              onReset: current.backgroundArgb == '#00000000'
                  ? null
                  : () => onChanged(
                      'text background',
                      _next(
                        (HuiIconStyle next) =>
                            next.backgroundArgb = '#00000000',
                      ),
                    ),
              control: HuiColorField(
                value: current.backgroundArgb,
                label: huiText('text background'),
                placeholder: '#00000000',
                onChanged: (String value) => onChanged(
                  'text background',
                  _next((HuiIconStyle next) => next.backgroundArgb = value),
                ),
              ),
            ),
            HuiField(
              label: huiText('Opacity'),
              trailing: const HuiFieldHelp('icon.style.textOpacity'),
              defaultValue: '255',
              onReset: current.textOpacity == 255
                  ? null
                  : () => onChanged(
                      'text opacity',
                      _next((HuiIconStyle next) => next.textOpacity = 255),
                    ),
              control: HuiNumberField(
                value: current.textOpacity.toDouble(),
                min: 0,
                max: 255,
                step: 1,
                integer: true,
                onChanged: (double value) => onChanged(
                  'text opacity',
                  _next(
                    (HuiIconStyle next) => next.textOpacity = value.round(),
                  ),
                ),
              ),
            ),
            HuiField(
              label: huiText('Line width'),
              help: huiText('Vanilla text-display wrap width in font pixels.'),
              trailing: const HuiFieldHelp('icon.style.lineWidth'),
              defaultValue: '16384',
              onReset: current.lineWidth == 16384
                  ? null
                  : () => onChanged(
                      'text line width',
                      _next((HuiIconStyle next) => next.lineWidth = 16384),
                    ),
              control: HuiNumberField(
                value: current.lineWidth.toDouble(),
                min: 1,
                max: 16384,
                step: 1,
                integer: true,
                onChanged: (double value) => onChanged(
                  'text line width',
                  _next((HuiIconStyle next) => next.lineWidth = value.round()),
                ),
              ),
            ),
          ],
        ),
        InspectorSection(
          title: huiText('Lighting, shadow and culling'),
          sectionKey: entityOverlay
              ? 'entity-overlays.style.lighting'
              : 'icon.style.lighting',
          initiallyOpen: false,
          children: <Widget>[
            HuiSwitchRow(
              label: huiText('Override brightness'),
              value: current.hasBrightnessOverride,
              help: huiText(
                'Pins the icon to a constant light level. Both channels '
                'travel together; one alone is rejected.',
              ),
              trailing: const HuiFieldHelp('icon.style.blockLight'),
              onChanged: (bool value) => onChanged(
                'brightness override',
                _next((HuiIconStyle next) {
                  next.blockLight = value ? 15 : null;
                  next.skyLight = value ? 15 : null;
                }),
              ),
            ),
            if (current.hasBrightnessOverride)
              _numberGrid(<Widget>[
                HuiField(
                  label: huiText('Block light'),
                  trailing: const HuiFieldHelp('icon.style.blockLight'),
                  control: _number(
                    huiText('Block'),
                    (current.blockLight ?? 15).toDouble(),
                    0,
                    15,
                    (double value) => onChanged(
                      'block light',
                      _next(
                        (HuiIconStyle next) => next.blockLight = value.round(),
                      ),
                    ),
                    integer: true,
                  ),
                ),
                HuiField(
                  label: huiText('Sky light'),
                  trailing: const HuiFieldHelp('icon.style.skyLight'),
                  control: _number(
                    huiText('Sky'),
                    (current.skyLight ?? 15).toDouble(),
                    0,
                    15,
                    (double value) => onChanged(
                      'sky light',
                      _next(
                        (HuiIconStyle next) => next.skyLight = value.round(),
                      ),
                    ),
                    integer: true,
                  ),
                ),
              ]),
            HuiField(
              label: huiText('Display view range'),
              help: huiText(
                'A multiplier on the client cull distance, not blocks.',
              ),
              trailing: const HuiFieldHelp('icon.style.viewRange'),
              defaultValue: '1',
              onReset: current.viewRange == 1
                  ? null
                  : () => onChanged(
                      'display view range',
                      _next((HuiIconStyle next) => next.viewRange = 1),
                    ),
              control: HuiNumberField(
                value: current.viewRange,
                min: 0.01,
                max: 64,
                onChanged: (double value) => onChanged(
                  'display view range',
                  _next((HuiIconStyle next) => next.viewRange = value),
                ),
              ),
            ),
            _numberGrid(<Widget>[
              HuiField(
                label: huiText('Shadow radius'),
                trailing: const HuiFieldHelp('icon.style.shadowRadius'),
                control: _number(
                  huiText('Radius'),
                  current.shadowRadius,
                  0,
                  64,
                  (double value) => onChanged(
                    'shadow radius',
                    _next((HuiIconStyle next) => next.shadowRadius = value),
                  ),
                ),
              ),
              HuiField(
                label: huiText('Shadow strength'),
                trailing: const HuiFieldHelp('icon.style.shadowStrength'),
                control: _number(
                  huiText('Strength'),
                  current.shadowStrength,
                  0,
                  1,
                  (double value) => onChanged(
                    'shadow strength',
                    _next((HuiIconStyle next) => next.shadowStrength = value),
                  ),
                ),
              ),
            ]),
            _numberGrid(<Widget>[
              HuiField(
                label: huiText('Cull width'),
                trailing: const HuiFieldHelp('icon.style.cullingWidth'),
                control: _number(
                  huiText('Width'),
                  current.cullingWidth,
                  0,
                  4096,
                  (double value) => onChanged(
                    'culling width',
                    _next((HuiIconStyle next) => next.cullingWidth = value),
                  ),
                ),
              ),
              HuiField(
                label: huiText('Cull height'),
                trailing: const HuiFieldHelp('icon.style.cullingHeight'),
                control: _number(
                  huiText('Height'),
                  current.cullingHeight,
                  0,
                  4096,
                  (double value) => onChanged(
                    'culling height',
                    _next((HuiIconStyle next) => next.cullingHeight = value),
                  ),
                ),
              ),
            ]),
            HuiSwitchRow(
              label: huiText('Glow outline'),
              value: current.glowColor != null,
              help: huiText(
                'Setting the colour is what turns the outline on; there is '
                'no separate glowing flag.',
              ),
              trailing: const HuiFieldHelp('icon.style.glowColor'),
              onChanged: (bool value) => onChanged(
                'glow outline',
                _next(
                  (HuiIconStyle next) =>
                      next.glowColor = value ? '#FFFFFFFF' : null,
                ),
              ),
            ),
            if (current.glowColor != null)
              HuiField(
                label: huiText('Glow colour'),
                trailing: const HuiFieldHelp('icon.style.glowColor'),
                help: huiText('Eight hexadecimal digits in #AARRGGBB order.'),
                control: HuiColorField(
                  value: current.glowColor!,
                  label: huiText('glow colour'),
                  placeholder: huiText('#FFFFFFFF'),
                  onChanged: (String value) => onChanged(
                    'glow color',
                    _next((HuiIconStyle next) => next.glowColor = value),
                  ),
                ),
              ),
          ],
        ),
        HuiInlineIssues(issues),
      ],
    );
  }

  Widget _number(
    String axis,
    double value,
    double minimum,
    double maximum,
    void Function(double value) onChanged, {
    bool integer = false,
  }) => HuiNumberField(
    value: value,
    min: minimum,
    max: maximum,
    step: integer ? 1 : 0.05,
    integer: integer,
    prefixLabel: axis,
    onChanged: onChanged,
  );

  /// Two or three fields on one line when the pane is wide enough for it.
  Widget _numberGrid(List<Widget> children) => dom.div(
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'grid',
        'grid-template-columns': 'repeat(auto-fit, minmax(120px, 1fr))',
        'gap': '8px',
      },
    ),
    children,
  );

  static String _billboardLabel(String value) => switch (value) {
    'fixed' => huiText('Fixed'),
    'vertical' => huiText('Vertical'),
    'horizontal' => huiText('Horizontal'),
    'center' => huiTextKey('billboard.center', 'Center'),
    _ => value,
  };

  static String _alignmentLabel(String value) => switch (value) {
    'center' => huiTextKey('alignment.center', 'Center'),
    'left' => huiText('Left'),
    'right' => huiText('Right'),
    _ => value,
  };
}
