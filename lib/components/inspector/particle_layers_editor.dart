library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/particle_layer.dart';
import '../../model/vec3.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

typedef ParticleLayersMutation =
    void Function(
      String label,
      void Function(List<GlossParticleLayer> layers) edit,
    );

class ParticleLayersEditor extends StatelessWidget {
  const ParticleLayersEditor({
    required this.layers,
    required this.mutate,
    this.sectionKey = 'particle-layers',
    this.initiallyOpen = false,
    super.key,
  });

  final List<GlossParticleLayer> layers;
  final ParticleLayersMutation mutate;
  final String sectionKey;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: huiText('Particle layers'),
    sectionKey: sectionKey,
    initiallyOpen: initiallyOpen,
    trailing: Button(
      variant: ButtonVariant.outline,
      size: ButtonSize.sm,
      disabled: layers.length >= glossParticleMaxLayers,
      icon: ArcaneIcon.plus(size: IconSize.sm),
      onPressed: layers.length >= glossParticleMaxLayers
          ? null
          : () => mutate(
              'add particle layer',
              (List<GlossParticleLayer> edited) =>
                  edited.add(GlossParticleLayer(id: _nextId(edited))),
            ),
      child: Text(huiText('Add')),
    ),
    children: <Widget>[
      if (layers.isNotEmpty)
        for (int index = 0; index < layers.length; index++)
          _ParticleLayerCard(
            index: index,
            layer: layers[index],
            layerCount: layers.length,
            mutate: mutate,
          ),
    ],
  );

  String _nextId(List<GlossParticleLayer> existing) {
    int suffix = existing.length + 1;
    String candidate = 'particle-$suffix';
    while (existing.any((GlossParticleLayer layer) => layer.id == candidate)) {
      suffix++;
      candidate = 'particle-$suffix';
    }
    return candidate;
  }
}

class _ParticleLayerCard extends StatelessWidget {
  const _ParticleLayerCard({
    required this.index,
    required this.layer,
    required this.layerCount,
    required this.mutate,
  });

  final int index;
  final GlossParticleLayer layer;
  final int layerCount;
  final ParticleLayersMutation mutate;

  void _edit(String label, void Function(GlossParticleLayer layer) edit) =>
      mutate(label, (List<GlossParticleLayer> layers) {
        if (index >= 0 && index < layers.length) edit(layers[index]);
      });

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-particle-layer',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '10px',
        'padding': '10px',
        'border': '1px solid var(--hui-border-soft, var(--border))',
        'border-radius': 'var(--hui-radius, 6px)',
      },
    ),
    <Widget>[
      dom.div(
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'justify-content': 'space-between',
            'gap': '8px',
          },
        ),
        <Widget>[
          HuiEyebrow(layer.id.isEmpty ? '#${index + 1}' : layer.id),
          HuiRowTools(
            onMoveUp: index == 0
                ? null
                : () => mutate('move particle layer', (
                    List<GlossParticleLayer> layers,
                  ) {
                    final GlossParticleLayer moved = layers.removeAt(index);
                    layers.insert(index - 1, moved);
                  }),
            onMoveDown: index >= layerCount - 1
                ? null
                : () => mutate('move particle layer', (
                    List<GlossParticleLayer> layers,
                  ) {
                    final GlossParticleLayer moved = layers.removeAt(index);
                    layers.insert(index + 1, moved);
                  }),
            onRemove: () => mutate('remove particle layer', (
              List<GlossParticleLayer> layers,
            ) {
              if (index >= 0 && index < layers.length) {
                layers.removeAt(index);
              }
            }),
            removeLabel: huiText('Delete'),
          ),
        ],
      ),
      HuiField(
        label: huiText('Component id'),
        required: true,
        control: TextInput(
          value: layer.id,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: 'green-glow',
          onInput: (String value) =>
              _edit('particle layer id', (GlossParticleLayer edited) {
                edited.id = value;
              }),
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
      ),
      _targetFields(),
      _geometryFields(),
      _placementFields(),
      _particleFields(),
      _emissionFields(),
      HuiField(
        label: huiText('Priority'),
        control: HuiNumberField(
          value: layer.priority.toDouble(),
          integer: true,
          min: -1000,
          max: 1000,
          onChanged: (double value) =>
              _edit('particle layer priority', (GlossParticleLayer edited) {
                edited.priority = value.round();
              }),
        ),
      ),
    ],
  );

  Widget _targetFields() => dom.div(<Widget>[
    HuiEyebrow(huiText('Target')),
    _choiceField(
      label: huiText('Scope'),
      value: layer.target.scope,
      values: glossParticleTargetScopes,
      labels: const <String, String>{
        'projection': 'Projection',
        'component': 'Component',
        'text': 'Text',
        'line': 'Text line',
        'span': 'Named text span',
        'label': 'Label',
        'model': 'Model',
        'local': 'Local geometry',
      },
      onChanged: (String value) => _edit('particle target scope', (
        GlossParticleLayer edited,
      ) {
        edited.target.scope = value;
        edited.target.name = value == 'span'
            ? edited.target.name ?? 'highlight'
            : null;
        edited.target.component = value == 'component'
            ? edited.target.component ?? 'component-id'
            : null;
        edited.target.line = value == 'line' ? edited.target.line ?? 1 : null;
      }),
    ),
    if (layer.target.scope == 'span')
      HuiField(
        label: huiText('Text'),
        required: true,
        control: TextInput(
          value: layer.target.name ?? '',
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: 'highlight',
          onInput: (String value) =>
              _edit('particle span name', (GlossParticleLayer edited) {
                edited.target.name = value;
              }),
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
        help: '<particles:name>text</particles>',
      ),
    if (layer.target.scope == 'component')
      HuiField(
        label: huiText('Component id'),
        required: true,
        control: TextInput(
          value: layer.target.component ?? '',
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: 'title',
          onInput: (String value) =>
              _edit('particle component id', (GlossParticleLayer edited) {
                edited.target.component = value;
              }),
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
      ),
    if (layer.target.scope == 'line')
      HuiField(
        label: huiText('Line'),
        required: true,
        control: HuiNumberField(
          value: (layer.target.line ?? 1).toDouble(),
          integer: true,
          min: 1,
          onChanged: (double value) =>
              _edit('particle line target', (GlossParticleLayer edited) {
                edited.target.line = value.round();
              }),
        ),
      ),
  ]);

  Widget _geometryFields() {
    final GlossParticleGeometry geometry = layer.geometry;
    return dom.div(<Widget>[
      HuiEyebrow(huiText('Settings')),
      _choiceField(
        label: huiText('Type'),
        value: geometry.type,
        values: glossParticleGeometryTypes,
        labels: const <String, String>{
          'point': 'Point',
          'line': 'Line',
          'polyline': 'Polyline',
          'outline': 'Frame outline',
          'filledPlane': 'Filled plane',
          'cuboid': 'Cuboid',
          'letterBounds': 'Letter boxes',
          'glyphOutline': 'Glyph outlines',
          'glyphFill': 'Glyph fill',
        },
        onChanged: _setGeometryType,
      ),
      if (geometry.type == 'line') ...<Widget>[
        _vectorField(
          label: huiText('Position'),
          value: geometry.from ?? Vec3.zero(),
          onChanged: (Vec3 value) =>
              _edit('particle line start', (GlossParticleLayer edited) {
                edited.geometry.from = value;
              }),
        ),
        _vectorField(
          label: huiText('Position'),
          value: geometry.to ?? Vec3(1, 0, 0),
          onChanged: (Vec3 value) =>
              _edit('particle line end', (GlossParticleLayer edited) {
                edited.geometry.to = value;
              }),
        ),
      ],
      if (geometry.type == 'polyline') _polylineFields(geometry),
      if (<String>{
        'outline',
        'filledPlane',
        'cuboid',
      }.contains(geometry.type)) ...<Widget>[
        _optionalDimension(
          label: huiText('Width'),
          value: geometry.width,
          suggested: 1,
          onChanged: (double? value) =>
              _edit('particle geometry width', (GlossParticleLayer edited) {
                edited.geometry.width = value;
              }),
        ),
        _optionalDimension(
          label: huiText('Height'),
          value: geometry.height,
          suggested: 1,
          onChanged: (double? value) =>
              _edit('particle geometry height', (GlossParticleLayer edited) {
                edited.geometry.height = value;
              }),
        ),
        if (geometry.type == 'cuboid')
          _optionalDimension(
            label: huiText('Size'),
            value: geometry.depth,
            suggested: 1,
            onChanged: (double? value) =>
                _edit('particle geometry depth', (GlossParticleLayer edited) {
                  edited.geometry.depth = value;
                }),
          ),
      ],
      HuiField(
        label: 'padding',
        control: HuiNumberField(
          value: geometry.padding,
          min: 0,
          max: 16,
          step: 0.01,
          decimals: 3,
          onChanged: (double value) =>
              _edit('particle geometry padding', (GlossParticleLayer edited) {
                edited.geometry.padding = value;
              }),
        ),
      ),
      HuiField(
        label: 'spacing',
        control: HuiNumberField(
          value: geometry.spacing,
          min: 0.02,
          max: 16,
          step: 0.01,
          decimals: 3,
          onChanged: (double value) =>
              _edit('particle geometry spacing', (GlossParticleLayer edited) {
                edited.geometry.spacing = value;
              }),
        ),
      ),
    ]);
  }

  void _setGeometryType(String value) =>
      _edit('particle geometry shape', (GlossParticleLayer edited) {
        final GlossParticleGeometry geometry = edited.geometry;
        geometry.type = value;
        if (value == 'line') {
          geometry.from ??= Vec3.zero();
          geometry.to ??= Vec3(1, 0, 0);
        }
        if (value == 'polyline' && geometry.points.length < 2) {
          geometry.points = <Vec3>[Vec3.zero(), Vec3(1, 0, 0)];
        }
      });

  Widget _polylineFields(GlossParticleGeometry geometry) => HuiField(
    label: huiText('Position'),
    required: true,
    control: dom.div(
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '8px',
        },
      ),
      <Widget>[
        for (
          int pointIndex = 0;
          pointIndex < geometry.points.length;
          pointIndex++
        )
          dom.div(
            styles: const dom.Styles(
              raw: <String, String>{
                'display': 'grid',
                'grid-template-columns': 'minmax(0, 1fr) auto',
                'align-items': 'center',
                'gap': '6px',
              },
            ),
            <Widget>[
              HuiVec3Field(
                value: geometry.points[pointIndex],
                step: 0.1,
                decimals: 3,
                onChanged: (Vec3 value) => _edit('particle polyline point', (
                  GlossParticleLayer edited,
                ) {
                  if (pointIndex < edited.geometry.points.length) {
                    edited.geometry.points[pointIndex] = value;
                  }
                }),
              ),
              HuiIconButton(
                icon: ArcaneIcon.trash2(size: IconSize.sm),
                label: huiText('Delete'),
                disabled: geometry.points.length <= 2,
                onPressed: geometry.points.length <= 2
                    ? null
                    : () => _edit('remove particle polyline point', (
                        GlossParticleLayer edited,
                      ) {
                        if (pointIndex < edited.geometry.points.length) {
                          edited.geometry.points.removeAt(pointIndex);
                        }
                      }),
              ),
            ],
          ),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: () =>
              _edit('add particle polyline point', (GlossParticleLayer edited) {
                final Vec3 next = edited.geometry.points.isEmpty
                    ? Vec3.zero()
                    : edited.geometry.points.last.copy();
                edited.geometry.points.add(next);
              }),
          child: Text(huiText('Add')),
        ),
      ],
    ),
  );

  Widget _placementFields() => dom.div(<Widget>[
    HuiEyebrow(huiText('Placement')),
    _choiceField(
      label: huiText('Placement'),
      value: layer.placement.layer,
      values: glossParticlePlacementLayers,
      labels: const <String, String>{
        'behind': 'Behind',
        'front': 'Front',
        'center': 'Centered',
      },
      onChanged: (String value) =>
          _edit('particle placement plane', (GlossParticleLayer edited) {
            edited.placement.layer = value;
          }),
    ),
    HuiField(
      label: 'depth',
      control: HuiNumberField(
        value: layer.placement.depth,
        min: 0,
        max: 16,
        step: 0.01,
        decimals: 3,
        onChanged: (double value) =>
            _edit('particle placement depth', (GlossParticleLayer edited) {
              edited.placement.depth = value;
            }),
      ),
    ),
    _vectorField(
      label: huiText('Offset'),
      value: layer.placement.offset,
      onChanged: (Vec3 value) =>
          _edit('particle placement offset', (GlossParticleLayer edited) {
            edited.placement.offset = value;
          }),
    ),
  ]);

  Widget _particleFields() {
    final bool dust =
        layer.particle.key.trim().toLowerCase() == 'minecraft:dust';
    return dom.div(<Widget>[
      HuiEyebrow(huiText('Particle layers')),
      HuiField(
        label: huiText('Type'),
        required: true,
        control: TextInput(
          value: layer.particle.key,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: 'minecraft:dust',
          onInput: _setParticleKey,
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
      ),
      HuiSegmented(
        value: dust
            ? 'minecraft:dust'
            : layer.particle.key == 'minecraft:soul'
            ? 'minecraft:soul'
            : 'custom',
        segments: <HuiSegment>[
          const HuiSegment(value: 'minecraft:dust', label: 'dust'),
          const HuiSegment(value: 'minecraft:soul', label: 'soul'),
          HuiSegment(value: 'custom', label: huiText('Custom')),
        ],
        onChanged: (String value) {
          if (value == 'custom') return;
          _setParticleKey(value);
        },
      ),
      if (dust) ...<Widget>[
        HuiField(
          label: huiText('Color'),
          required: true,
          control: HuiColorField(
            value: layer.particle.color ?? '#ffffff',
            format: HuiColorFormat.rgb,
            label: huiText('Color'),
            onChanged: (String value) =>
                _edit('particle dust color', (GlossParticleLayer edited) {
                  edited.particle.color = value;
                }),
          ),
        ),
        HuiField(
          label: huiText('Size'),
          control: HuiNumberField(
            value: layer.particle.size ?? 1,
            min: 0.01,
            max: 4,
            step: 0.05,
            decimals: 2,
            onChanged: (double value) =>
                _edit('particle dust size', (GlossParticleLayer edited) {
                  edited.particle.size = value;
                }),
          ),
        ),
      ],
    ]);
  }

  void _setParticleKey(String value) =>
      _edit('particle type', (GlossParticleLayer edited) {
        edited.particle.key = value;
        if (value.trim().toLowerCase() == 'minecraft:dust') {
          edited.particle.color ??= '#ffffff';
          edited.particle.size ??= 1;
        } else {
          edited.particle.color = null;
          edited.particle.size = null;
        }
      });

  Widget _emissionFields() => dom.div(<Widget>[
    HuiEyebrow(huiText('Settings')),
    _choiceField(
      label: huiText('Type'),
      value: layer.emission.pattern,
      values: glossParticleEmissionPatterns,
      labels: const <String, String>{
        'steady': 'Steady',
        'chase': 'Chase',
        'pulse': 'Pulse',
        'twinkle': 'Twinkle',
        'scan': 'Scan',
        'corners': 'Corners',
      },
      onChanged: (String value) =>
          _edit('particle emission pattern', (GlossParticleLayer edited) {
            edited.emission.pattern = value;
          }),
    ),
    HuiField(
      label: huiText('Speed'),
      control: HuiNumberField(
        value: layer.emission.intervalTicks.toDouble(),
        integer: true,
        min: 1,
        max: 200,
        suffix: huiText('ticks'),
        onChanged: (double value) =>
            _edit('particle emission interval', (GlossParticleLayer edited) {
              edited.emission.intervalTicks = value.round();
            }),
      ),
    ),
    HuiField(
      label: huiText('Speed'),
      control: HuiNumberField(
        value: layer.emission.periodTicks.toDouble(),
        integer: true,
        min: 1,
        max: 72000,
        suffix: huiText('ticks'),
        onChanged: (double value) =>
            _edit('particle emission period', (GlossParticleLayer edited) {
              edited.emission.periodTicks = value.round();
            }),
      ),
    ),
    HuiField(
      label: huiText('Value'),
      control: HuiNumberField(
        value: layer.emission.seed.toDouble(),
        integer: true,
        onChanged: (double value) =>
            _edit('particle emission seed', (GlossParticleLayer edited) {
              edited.emission.seed = value.round();
            }),
      ),
    ),
  ]);

  Widget _choiceField({
    required String label,
    required String value,
    required List<String> values,
    required Map<String, String> labels,
    required void Function(String value) onChanged,
  }) => HuiField(
    label: label,
    control: ArcaneSelect(
      value: value,
      size: ComponentSize.sm,
      fullWidth: true,
      options: <ArcaneSelectOption>[
        for (final String option in values)
          ArcaneSelectOption(label: labels[option] ?? option, value: option),
      ],
      onChange: onChanged,
    ),
  );

  Widget _vectorField({
    required String label,
    required Vec3 value,
    required void Function(Vec3 value) onChanged,
  }) => HuiField(
    label: label,
    control: HuiVec3Field(
      value: value,
      step: 0.1,
      decimals: 3,
      onChanged: onChanged,
    ),
  );

  Widget _optionalDimension({
    required String label,
    required double? value,
    required double suggested,
    required void Function(double? value) onChanged,
  }) => HuiField(
    label: label,
    trailing: ArcaneCheckbox(
      checked: value == null,
      size: ComponentSize.sm,
      label: huiText('Reset'),
      onChanged: (bool checked) => onChanged(checked ? null : suggested),
    ),
    control: value == null
        ? const dom.span(<Widget>[])
        : HuiNumberField(
            value: value,
            min: 0,
            max: 128,
            step: 0.05,
            decimals: 3,
            suffix: huiText('blocks'),
            onChanged: onChanged,
          ),
  );
}
