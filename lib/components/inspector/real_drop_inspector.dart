library;

import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'real_drop_expr_field.dart';
import 'real_drop_animation_inspector.dart';
import 'reorder_list.dart';
import 'particle_layers_editor.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class RealDropInspector extends StatefulWidget {
  const RealDropInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<RealDropInspector> createState() => _RealDropInspectorState();
}

class _RealDropInspectorState extends State<RealDropInspector> {
  int? _variantDraftIndex;
  String _variantDraft = '';
  String? _variantDraftError;

  EditorStore get _store => component.store;

  GlossRealDropSettingsDoc? get _doc => _store.realDropSettingsDoc;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossRealDropSettingsDoc? doc = _doc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-real-drops', <Widget>[
      _header(doc),
      _conditionalVariants(doc),
      ParticleLayersEditor(
        layers: doc.presentation.particleLayers,
        sectionKey: 'real-drops.particleLayers',
        mutate: (String label, void Function(List<GlossParticleLayer>) edit) =>
            _mutate(
              label,
              (GlossRealDropSettingsDoc edited) =>
                  edit(edited.presentation.particleLayers),
            ),
      ),
      _audience(doc),
      _limits(doc),
      _scales(doc),
      _motion(doc),
      _landing(doc),
      _labels(doc),
      _filters(doc),
      _physics(doc),
      _script(doc),
      RealDropAnimationInspector(store: _store),
    ]);
  }

  Widget _header(GlossRealDropSettingsDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-real-drops', <Widget>[
          HuiEyebrow(huiText('Real drops')),
          dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
            Text(_store.menuId),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              'Native item models, motion, landing, labels, and render limits.',
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]);

  Widget _conditionalVariants(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Conditional variants'),
    children: <Widget>[
      HuiNote(
        huiText(
          'The highest-priority matching variant replaces the entire default '
          'presentation; equal priorities use the smaller id.',
        ),
      ),
      for (int index = 0; index < doc.variants.length; index++)
        _variant(doc, index),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.plus(size: IconSize.sm),
        onPressed: () => _mutate(
          'add real-drop variant',
          (GlossRealDropSettingsDoc edited) => edited.variants.add(
            GlossRealDropVariant(
              id: _nextVariantId(edited),
              when: "drop.material == 'DIAMOND'",
              presentation: edited.presentation.copy(),
            ),
          ),
        ),
        label: huiText('Add variant'),
      ),
      HuiInlineIssues(_issuesFor(r'$.variants')),
    ],
  );

  Widget _variant(GlossRealDropSettingsDoc doc, int index) {
    final GlossRealDropVariant variant = doc.variants[index];
    final String path = '\$.variants[$index]';
    final bool editingPresentation = _variantDraftIndex == index;
    return dom.div(classes: 'hui-drop-subgroup', <Widget>[
      TextInput(
        value: variant.id,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText('variant-id'),
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
        onInput: (String value) => _mutate(
          'rename real-drop variant',
          (GlossRealDropSettingsDoc edited) =>
              edited.variants[index].id = value,
        ),
      ),
      HuiNumberField(
        value: variant.priority.toDouble(),
        step: 1,
        decimals: 0,
        integer: true,
        onChanged: (double value) => _mutate(
          'real-drop variant priority',
          (GlossRealDropSettingsDoc edited) =>
              edited.variants[index].priority = value.round(),
        ),
      ),
      TextInput(
        value: variant.when,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText("drop.material == 'DIAMOND'"),
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
        onInput: (String value) => _mutate(
          'real-drop variant condition',
          (GlossRealDropSettingsDoc edited) =>
              edited.variants[index].when = value,
        ),
      ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: () => setState(() {
          if (editingPresentation) {
            _variantDraftIndex = null;
            _variantDraft = '';
            _variantDraftError = null;
          } else {
            _variantDraftIndex = index;
            _variantDraft = const JsonEncoder.withIndent(
              '  ',
            ).convert(variant.presentation.toJson());
            _variantDraftError = null;
          }
        }),
        label: editingPresentation
            ? huiText('Close presentation')
            : huiText('Edit complete presentation'),
      ),
      if (editingPresentation)
        TextArea(
          value: _variantDraft,
          rows: 16,
          fullWidth: true,
          styles: huiTechnicalInputStyles,
          error: _variantDraftError,
          onInput: (String value) => _editVariantPresentation(index, value),
        ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        onPressed: () => _mutate(
          'remove real-drop variant',
          (GlossRealDropSettingsDoc edited) => edited.variants.removeAt(index),
        ),
        label: huiText('Remove variant'),
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]);
  }

  Widget _audience(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Audience'),
    children: <Widget>[
      HuiNote(
        huiText(
          'This condition is evaluated separately for every viewer. A false '
          'result leaves that viewer on the vanilla dropped item.',
        ),
      ),
      TextInput(
        value: doc.audience.when,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText("hasPermission('viewer', 'gloss.drops')"),
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
        onInput: (String value) => _mutate(
          'real-drop audience condition',
          (GlossRealDropSettingsDoc edited) => edited.audience.when = value,
        ),
      ),
      HuiInlineIssues(_issuesFor(r'$.audience.when')),
    ],
  );

  void _editVariantPresentation(int index, String value) {
    String? error;
    GlossRealDropPresentation? presentation;
    try {
      presentation = GlossRealDropPresentation.fromJson(
        jsonDecode(value),
        '\$.variants[$index].presentation',
      );
    } on Object catch (caught) {
      error = caught.toString();
    }
    setState(() {
      _variantDraft = value;
      _variantDraftError = error;
    });
    if (presentation == null) return;
    _mutate(
      'edit real-drop variant presentation',
      (GlossRealDropSettingsDoc edited) =>
          edited.variants[index].presentation = presentation!,
    );
  }

  String _nextVariantId(GlossRealDropSettingsDoc doc) {
    int suffix = doc.variants.length + 1;
    String id = 'variant-$suffix';
    while (doc.variants.any((GlossRealDropVariant item) => item.id == id)) {
      suffix++;
      id = 'variant-$suffix';
    }
    return id;
  }

  Widget _limits(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Performance and density'),
    children: <Widget>[
      _integer(
        label: huiText('Moving update interval'),
        help: huiText(
          'Ticks between interpolated targets while an item is moving. 1..20.',
        ),
        path: r'$.presentation.limits.updateIntervalTicks',
        value: doc.presentation.limits.updateIntervalTicks,
        onChanged: (int value) => _mutate(
          'drop update interval',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.limits.updateIntervalTicks = value,
        ),
      ),
      _integer(
        label: huiText('Settled poll interval'),
        help: huiText(
          'Ticks between checks after the item is stable; landing slides retain the moving cadence. 2..200.',
        ),
        path: r'$.presentation.limits.settledPollIntervalTicks',
        value: doc.presentation.limits.settledPollIntervalTicks,
        onChanged: (int value) => _mutate(
          'settled drop interval',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.limits.settledPollIntervalTicks = value,
        ),
      ),
      _integer(
        label: huiText('Models per stack'),
        help: huiText(
          'Maximum visible item models for one dropped stack. 1..5.',
        ),
        path: r'$.presentation.limits.maxVisualsPerStack',
        value: doc.presentation.limits.maxVisualsPerStack,
        onChanged: (int value) => _mutate(
          'models per drop',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.limits.maxVisualsPerStack = value,
        ),
      ),
      _integer(
        label: huiText('Models per chunk'),
        help: huiText('Hard chunk budget across all dropped stacks. 8..1024.'),
        path: r'$.presentation.limits.maxVisualsPerChunk',
        value: doc.presentation.limits.maxVisualsPerChunk,
        onChanged: (int value) => _mutate(
          'models per chunk',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.limits.maxVisualsPerChunk = value,
        ),
      ),
      _decimal(
        label: huiText('Model view range'),
        help: huiText(
          'Client tracking range for drop models in blocks. 4..128.',
        ),
        path: r'$.presentation.limits.viewRange',
        value: doc.presentation.limits.viewRange,
        step: 1,
        onChanged: (double value) => _mutate(
          'drop model range',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.limits.viewRange = value,
        ),
      ),
      _decimal(
        label: huiText('Stack spread'),
        help: huiText(
          'Horizontal separation between models in one stack. 0..1.',
        ),
        path: r'$.presentation.limits.spread',
        value: doc.presentation.limits.spread,
        onChanged: (double value) => _mutate(
          'drop model spread',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.limits.spread = value,
        ),
      ),
    ],
  );

  Widget _scales(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Model scale'),
    children: <Widget>[
      _decimal(
        label: huiText('Default items'),
        help: huiText(
          'Scale for ordinary three-dimensional block models. 0.05..2.',
        ),
        path: r'$.presentation.scale.defaultScale',
        value: doc.presentation.scale.defaultScale,
        onChanged: (double value) => _mutate(
          'default drop scale',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.scale.defaultScale = value,
        ),
      ),
      _decimal(
        label: huiText('Flat items'),
        help: huiText(
          'Scale for non-block items rendered by ItemDisplay. Every block material uses true BlockDisplay geometry. 0.05..2.',
        ),
        path: r'$.presentation.scale.flatItems',
        value: doc.presentation.scale.flatItems,
        onChanged: (double value) => _mutate(
          'flat item scale',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.scale.flatItems = value,
        ),
      ),
      _decimal(
        label: huiText('Thin blocks'),
        help: huiText(
          'Scale for slabs, carpets, pressure plates, and snow layers. 0.05..2.',
        ),
        path: r'$.presentation.scale.thinBlocks',
        value: doc.presentation.scale.thinBlocks,
        onChanged: (double value) => _mutate(
          'thin block scale',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.scale.thinBlocks = value,
        ),
      ),
    ],
  );

  Widget _motion(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Tumble'),
    children: <Widget>[
      HuiSwitchRow(
        label: huiText('Tumble while moving'),
        value: doc.presentation.motion.tumble,
        onChanged: (bool value) => _mutate(
          'drop tumble',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.tumble = value,
        ),
      ),
      _decimal(
        label: huiText('Animation speed'),
        help: huiText('Multiplier applied to every tumble axis. 0.1..4.'),
        path: r'$.presentation.motion.speedMultiplier',
        value: doc.presentation.motion.speedMultiplier,
        onChanged: (double value) => _mutate(
          'drop animation speed',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.speedMultiplier = value,
        ),
      ),
      _decimal(
        label: huiText('X rotation'),
        help: huiText('Base X-axis degrees per second. -1440..1440.'),
        path: r'$.presentation.motion.degreesPerSecondX',
        value: doc.presentation.motion.degreesPerSecondX,
        step: 5,
        onChanged: (double value) => _mutate(
          'drop x rotation',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.degreesPerSecondX = value,
        ),
      ),
      _decimal(
        label: huiText('Y rotation'),
        help: huiText('Base Y-axis degrees per second. -1440..1440.'),
        path: r'$.presentation.motion.degreesPerSecondY',
        value: doc.presentation.motion.degreesPerSecondY,
        step: 5,
        onChanged: (double value) => _mutate(
          'drop y rotation',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.degreesPerSecondY = value,
        ),
      ),
      _decimal(
        label: huiText('Z rotation'),
        help: huiText('Base Z-axis degrees per second. -1440..1440.'),
        path: r'$.presentation.motion.degreesPerSecondZ',
        value: doc.presentation.motion.degreesPerSecondZ,
        step: 5,
        onChanged: (double value) => _mutate(
          'drop z rotation',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.degreesPerSecondZ = value,
        ),
      ),
      _decimal(
        label: huiText('Per-item variance'),
        help: huiText('Deterministic variation around the base axes. 0..1.'),
        path: r'$.presentation.motion.variance',
        value: doc.presentation.motion.variance,
        onChanged: (double value) => _mutate(
          'drop tumble variance',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.variance = value,
        ),
      ),
      HuiSwitchRow(
        label: huiText('Change tumble on bounce'),
        value: doc.presentation.motion.changeOnBounce,
        onChanged: (bool value) => _mutate(
          'bounce tumble change',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.changeOnBounce = value,
        ),
      ),
      _decimal(
        label: huiText('Throw momentum'),
        help: huiText(
          'How strongly real movement speed increases tumble speed. 0 ignores throw momentum; higher values tumble harder throws faster. 0..4.',
        ),
        path: r'$.presentation.motion.velocityInfluence',
        value: doc.presentation.motion.velocityInfluence,
        onChanged: (double value) => _mutate(
          'drop throw momentum',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.velocityInfluence = value,
        ),
      ),
      _decimal(
        label: huiText('Submerged spin'),
        help: huiText(
          'Angular-speed multiplier while the item is in water. 0 stops rotation; 1 preserves airborne spin. 0..1.',
        ),
        path: r'$.presentation.motion.submergedSpinMultiplier',
        value: doc.presentation.motion.submergedSpinMultiplier,
        onChanged: (double value) => _mutate(
          'drop submerged spin',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.submergedSpinMultiplier = value,
        ),
      ),
      _decimal(
        label: huiText('Ground roll'),
        help: huiText(
          'Rotation produced by real distance travelled on a surface. 0 slides without rolling; 1 uses the model radius. 0..4.',
        ),
        path: r'$.presentation.motion.groundRollMultiplier',
        value: doc.presentation.motion.groundRollMultiplier,
        onChanged: (double value) => _mutate(
          'drop ground roll',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.motion.groundRollMultiplier = value,
        ),
      ),
    ],
  );

  Widget _landing(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Landing'),
    children: <Widget>[
      HuiField(
        label: huiText('Landing mode'),
        help: huiText(
          'Natural lets block models settle on any of six faces; Flat lays every model down; Upright removes pitch and roll.',
        ),
        control: ArcaneSelect(
          value: doc.presentation.landing.mode,
          size: ComponentSize.sm,
          fullWidth: true,
          options: <ArcaneSelectOption>[
            ArcaneSelectOption(label: huiText('Natural'), value: 'NATURAL'),
            ArcaneSelectOption(label: huiText('Flat'), value: 'FLAT'),
            ArcaneSelectOption(label: huiText('Upright'), value: 'UPRIGHT'),
          ],
          onChange: (String value) => _mutate(
            'drop landing mode',
            (GlossRealDropSettingsDoc edited) =>
                edited.presentation.landing.mode = value,
          ),
        ),
      ),
      _decimal(
        label: huiText('Natural face rotation'),
        help: huiText(
          'Maximum in-face variation for stationary or rebuilt natural blocks; momentum landings preserve their physical heading. 0..45.',
        ),
        path: r'$.presentation.landing.tiltDegrees',
        value: doc.presentation.landing.tiltDegrees,
        step: 1,
        onChanged: (double value) => _mutate(
          'drop landing tilt',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.tiltDegrees = value,
        ),
      ),
      HuiSwitchRow(
        label: huiText('Random landing yaw'),
        value: doc.presentation.landing.randomYaw,
        onChanged: (bool value) => _mutate(
          'drop landing yaw',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.randomYaw = value,
        ),
      ),
      _integer(
        label: huiText('Landing transition'),
        help: huiText(
          'Client interpolation ticks between continuous pose samples. 0..20.',
        ),
        path: r'$.presentation.landing.transitionTicks',
        value: doc.presentation.landing.transitionTicks,
        onChanged: (int value) => _mutate(
          'drop landing transition',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.transitionTicks = value,
        ),
      ),
      _decimal(
        label: huiText('Resting face pull'),
        help: huiText(
          'How strongly gravity pulls a nearly still item toward its nearest stable face each sample. 0..1.',
        ),
        path: r'$.presentation.landing.faceAttraction',
        value: doc.presentation.landing.faceAttraction,
        onChanged: (double value) => _mutate(
          'drop resting face attraction',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.faceAttraction = value,
        ),
      ),
      _decimal(
        label: huiText('Moving face pull'),
        help: huiText(
          'Face attraction retained while the item is still rolling. Lower values preserve momentum longer. 0..1.',
        ),
        path: r'$.presentation.landing.movingFaceAttraction',
        value: doc.presentation.landing.movingFaceAttraction,
        onChanged: (double value) => _mutate(
          'drop moving face attraction',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.movingFaceAttraction = value,
        ),
      ),
      _decimal(
        label: huiText('Face snap tolerance'),
        help: huiText(
          'Final subvisual angle where settling may become exactly flush. 0.05..10 degrees.',
        ),
        path: r'$.presentation.landing.alignmentDegrees',
        value: doc.presentation.landing.alignmentDegrees,
        onChanged: (double value) => _mutate(
          'drop face snap tolerance',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.alignmentDegrees = value,
        ),
      ),
      _integer(
        label: huiText('Stable delay'),
        help: huiText(
          'Ticks the item must remain aligned and motionless before sparse settled polling. 0..100.',
        ),
        path: r'$.presentation.landing.settleDelayTicks',
        value: doc.presentation.landing.settleDelayTicks,
        onChanged: (int value) => _mutate(
          'drop stable delay',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.landing.settleDelayTicks = value,
        ),
      ),
    ],
  );

  Widget _labels(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Nametag'),
    children: <Widget>[
      HuiSwitchRow(
        label: huiText('Show item labels'),
        value: doc.presentation.labels.enabled,
        onChanged: (bool value) => _mutate(
          'drop labels',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.enabled = value,
        ),
      ),
      _decimal(
        label: huiText('Height'),
        help: huiText('Blocks above the dropped item. 0..4.'),
        path: r'$.presentation.labels.yOffset',
        value: doc.presentation.labels.yOffset,
        onChanged: (double value) => _mutate(
          'drop label height',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.yOffset = value,
        ),
      ),
      _decimal(
        label: huiText('Text scale'),
        help: huiText('TextDisplay scale. 0.1..4.'),
        path: r'$.presentation.labels.scale',
        value: doc.presentation.labels.scale,
        onChanged: (double value) => _mutate(
          'drop label scale',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.scale = value,
        ),
      ),
      _decimal(
        label: huiText('Label view range'),
        help: huiText('Client tracking range for item labels. 4..128.'),
        path: r'$.presentation.labels.viewRange',
        value: doc.presentation.labels.viewRange,
        step: 1,
        onChanged: (double value) => _mutate(
          'drop label range',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.viewRange = value,
        ),
      ),
      HuiField(
        label: huiText('Billboard'),
        help: huiText('How the text rotates toward the viewer.'),
        control: ArcaneSelect(
          value: doc.presentation.labels.billboard,
          size: ComponentSize.sm,
          fullWidth: true,
          options: <ArcaneSelectOption>[
            ArcaneSelectOption(
              label: huiTextKey('billboard.center', 'Center'),
              value: 'CENTER',
            ),
            ArcaneSelectOption(label: huiText('Fixed'), value: 'FIXED'),
            ArcaneSelectOption(
              label: huiText('Horizontal'),
              value: 'HORIZONTAL',
            ),
            ArcaneSelectOption(label: huiText('Vertical'), value: 'VERTICAL'),
          ],
          onChange: (String value) => _mutate(
            'drop label billboard',
            (GlossRealDropSettingsDoc edited) =>
                edited.presentation.labels.billboard = value,
          ),
        ),
      ),
      HuiSwitchRow(
        label: huiText('See through blocks'),
        value: doc.presentation.labels.seeThrough,
        onChanged: (bool value) => _mutate(
          'drop label visibility',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.seeThrough = value,
        ),
      ),
      HuiSwitchRow(
        label: huiText('Text shadow'),
        value: doc.presentation.labels.shadow,
        onChanged: (bool value) => _mutate(
          'drop label shadow',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.shadow = value,
        ),
      ),
      HuiSwitchRow(
        label: huiText('Background'),
        value: doc.presentation.labels.background,
        onChanged: (bool value) => _mutate(
          'drop label background',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.background = value,
        ),
      ),
      _integer(
        label: huiText('Background red'),
        help: huiText('Red channel. 0..255.'),
        path: r'$.presentation.labels.backgroundRed',
        value: doc.presentation.labels.backgroundRed,
        onChanged: (int value) => _mutate(
          'drop label red',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.backgroundRed = value,
        ),
      ),
      _integer(
        label: huiText('Background green'),
        help: huiText('Green channel. 0..255.'),
        path: r'$.presentation.labels.backgroundGreen',
        value: doc.presentation.labels.backgroundGreen,
        onChanged: (int value) => _mutate(
          'drop label green',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.backgroundGreen = value,
        ),
      ),
      _integer(
        label: huiText('Background blue'),
        help: huiText('Blue channel. 0..255.'),
        path: r'$.presentation.labels.backgroundBlue',
        value: doc.presentation.labels.backgroundBlue,
        onChanged: (int value) => _mutate(
          'drop label blue',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.backgroundBlue = value,
        ),
      ),
      _integer(
        label: huiText('Background alpha'),
        help: huiText('Background opacity. 0..255.'),
        path: r'$.presentation.labels.backgroundAlpha',
        value: doc.presentation.labels.backgroundAlpha,
        onChanged: (int value) => _mutate(
          'drop label alpha',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.labels.backgroundAlpha = value,
        ),
      ),
    ],
  );

  Widget _filters(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: huiText('Filters'),
    children: <Widget>[
      HuiSwitchRow(
        label: huiText('Only player-thrown drops'),
        value: doc.presentation.filters.onlyPlayerDrops,
        onChanged: (bool value) => _mutate(
          'drop source filter',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.filters.onlyPlayerDrops = value,
        ),
      ),
      _list(
        label: huiText('Disabled worlds'),
        help: huiText(
          'Comma-separated world names that keep vanilla item rendering.',
        ),
        value: doc.presentation.filters.disabledWorlds,
        onChanged: (List<String> value) => _mutate(
          'disabled drop worlds',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.filters.disabledWorlds = value,
        ),
      ),
      _list(
        label: huiText('Material blacklist'),
        help: huiText('Comma-separated Bukkit material names kept vanilla.'),
        value: doc.presentation.filters.materialBlacklist,
        onChanged: (List<String> value) => _mutate(
          'drop material blacklist',
          (GlossRealDropSettingsDoc edited) =>
              edited.presentation.filters.materialBlacklist = value,
        ),
      ),
    ],
  );

  // --- physics --------------------------------------------------------------

  /// The block that moves the real `Item` entity.
  ///
  /// Both optional blocks are absent from a document until somebody touches
  /// them, so every control here reads through the null and every edit
  /// materialises the block. A file written before the feature existed stays
  /// byte-identical until it is actually changed.
  Widget _physics(GlossRealDropSettingsDoc doc) {
    final GlossRealDropPhysics? physics = doc.presentation.physics;
    final bool enabled = physics?.enabled ?? false;
    return InspectorSection(
      title: huiText('Item physics'),
      sectionKey: 'realDrops.physics',
      description: huiText(
        'Real changes to how the dropped item moves. These write to the '
        'entity, so its position, its collision and its pickup radius all '
        'follow.',
      ),
      trailing: const HuiFieldHelp('realDrops.physics'),
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Move the item entity'),
          value: enabled,
          trailing: const HuiFieldHelp('realDrops.physics.enabled'),
          onChanged: (bool value) => _mutatePhysics(
            'drop physics',
            (GlossRealDropPhysics edited) => edited.enabled = value,
          ),
        ),
        _physicsNumber(
          label: huiText('Gravity multiplier'),
          docKey: 'realDrops.physics.gravityMultiplier',
          path: r'$.presentation.physics.gravityMultiplier',
          value: physics?.gravityMultiplier ?? 1,
          fallback: '1',
          onChanged: (double value) => _mutatePhysics(
            'drop gravity',
            (GlossRealDropPhysics edited) => edited.gravityMultiplier = value,
          ),
        ),
        _physicsNumber(
          label: huiText('Bounce'),
          docKey: 'realDrops.physics.bounce',
          path: r'$.presentation.physics.bounce',
          value: physics?.bounce ?? 0,
          fallback: '0',
          onChanged: (double value) => _mutatePhysics(
            'drop bounce',
            (GlossRealDropPhysics edited) => edited.bounce = value,
          ),
        ),
        _physicsNumber(
          label: huiText('Water buoyancy'),
          docKey: 'realDrops.physics.waterBuoyancy',
          path: r'$.presentation.physics.waterBuoyancy',
          value: physics?.waterBuoyancy ?? 0,
          fallback: '0',
          onChanged: (double value) => _mutatePhysics(
            'drop buoyancy',
            (GlossRealDropPhysics edited) => edited.waterBuoyancy = value,
          ),
        ),
        _physicsNumber(
          label: huiText('Water drag'),
          docKey: 'realDrops.physics.waterDrag',
          path: r'$.presentation.physics.waterDrag',
          value: physics?.waterDrag ?? 0,
          fallback: '0',
          onChanged: (double value) => _mutatePhysics(
            'drop water drag',
            (GlossRealDropPhysics edited) => edited.waterDrag = value,
          ),
        ),
      ],
    );
  }

  Widget _physicsNumber({
    required String label,
    required String docKey,
    required String path,
    required double value,
    required String fallback,
    required void Function(double value) onChanged,
  }) => HuiField(
    label: label,
    defaultValue: fallback,
    onReset: value == double.parse(fallback)
        ? null
        : () => onChanged(double.parse(fallback)),
    trailing: HuiFieldHelp(docKey),
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value,
        step: 0.05,
        decimals: 2,
        onChanged: onChanged,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  // --- script ---------------------------------------------------------------

  /// The block that moves the picture and nothing else.
  ///
  /// Every expression here is compiled and type-checked by the server whether
  /// or not the switch is on, so the validation panel reports a broken one
  /// either way — which is why the switch does not gate any of these controls.
  Widget _script(GlossRealDropSettingsDoc doc) {
    final GlossRealDropScript? script = doc.presentation.script;
    return InspectorSection(
      title: huiText('Script'),
      sectionKey: 'realDrops.script',
      description: huiText(
        'Expressions are compiled once; stack-shared and settled-static '
        'results are reused when their inputs do not change. They move the '
        'displays only: the item, its collision and its pickup radius stay '
        'where Minecraft put them.',
      ),
      trailing: const HuiFieldHelp('realDrops.script'),
      children: <Widget>[
        HuiSwitchRow(
          label: huiText('Run the script'),
          value: script?.enabled ?? false,
          trailing: const HuiFieldHelp('realDrops.script.enabled'),
          onChanged: (bool value) => _mutateScript(
            'drop script',
            (GlossRealDropScript edited) => edited.enabled = value,
          ),
        ),
        _vars(script),
        _axis(
          title: huiText('Offset'),
          docKey: 'realDrops.script.offset',
          field: 'offset',
          axis: script?.offset,
          neutral: '0',
        ),
        _axis(
          title: huiText('Rotation'),
          docKey: 'realDrops.script.rotation',
          field: 'rotation',
          axis: script?.rotation,
          neutral: '0',
        ),
        _axis(
          title: huiText('Scale'),
          docKey: 'realDrops.script.scale',
          field: 'scale',
          axis: script?.scale,
          neutral: '1',
        ),
        RealDropExprField(
          label: huiText('Glow'),
          docKey: 'realDrops.script.glow',
          value: script?.glow ?? '',
          placeholder: huiText("materialIs('torch') ? #FFAA55 : 0"),
          issues: _exact(r'$.presentation.script.glow'),
          onChanged: (String value) => _mutateScript(
            'drop script glow',
            (GlossRealDropScript edited) => edited.glow = value,
          ),
        ),
        RealDropExprField(
          label: huiText('Visible'),
          docKey: 'realDrops.script.visible',
          value: script?.visible ?? 'true',
          neutral: 'true',
          issues: _exact(r'$.presentation.script.visible'),
          onChanged: (String value) => _mutateScript(
            'drop script visible',
            (GlossRealDropScript edited) =>
                edited.visible = value.isEmpty ? 'true' : value,
          ),
        ),
      ],
    );
  }

  /// One axis object: three expressions on one row each, sharing the shared
  /// `axis` doc entry so the three vectors never drift apart in the help.
  Widget _axis({
    required String title,
    required String docKey,
    required String field,
    required GlossRealDropScriptAxis? axis,
    required String neutral,
  }) => dom.div(classes: 'hui-drop-subgroup', <Widget>[
    dom.div(classes: 'hui-drop-subhead', <Widget>[
      Text(title),
      HuiFieldHelp(docKey),
    ]),
    for (final String name in const <String>['x', 'y', 'z'])
      RealDropExprField(
        label: name.toUpperCase(),
        docKey: 'realDrops.axis.$name',
        neutral: neutral,
        value: switch (name) {
          'x' => axis?.x ?? neutral,
          'y' => axis?.y ?? neutral,
          _ => axis?.z ?? neutral,
        },
        issues: _exact('\$.presentation.script.$field.$name'),
        onChanged: (String value) => _mutateScript('drop script $field $name', (
          GlossRealDropScript edited,
        ) {
          final GlossRealDropScriptAxis target = switch (field) {
            'offset' => edited.offset,
            'rotation' => edited.rotation,
            _ => edited.scale,
          };
          final String next = value.isEmpty ? neutral : value;
          switch (name) {
            case 'x':
              target.x = next;
            case 'y':
              target.y = next;
            default:
              target.z = next;
          }
        }),
      ),
  ]);

  /// The `vars` list: add, remove and reorder, and never a sort.
  ///
  /// Declaration order decides what each entry can read — an expression sees
  /// every var declared before it and none declared after — so the order in
  /// this list is the order in the file, and moving a row is a real edit to the
  /// document rather than a view preference.
  Widget _vars(GlossRealDropScript? script) {
    final List<GlossRealDropScriptVar> vars =
        script?.vars ?? const <GlossRealDropScriptVar>[];
    return dom.div(classes: 'hui-drop-subgroup', <Widget>[
      dom.div(classes: 'hui-drop-subhead', <Widget>[
        Text(huiText('Variables')),
        const HuiFieldHelp('realDrops.script.vars'),
      ]),
      HuiInlineIssues(_issuesFor(r'$.presentation.script.vars')),
      if (vars.isEmpty)
        dom.p(classes: 'hui-drop-empty', <Widget>[
          Text(
            huiText(
              'No variables. Name a condition once here and every expression '
              'after it can read it.',
            ),
          ),
        ])
      else
        HuiReorderList(
          itemCount: vars.length,
          handleLabel: huiText(
            'Drag to reorder — order decides what each one can read',
          ),
          onReorder: (int from, int to) => _mutateScript(
            'reorder drop script variables',
            (GlossRealDropScript edited) =>
                edited.vars.insert(to, edited.vars.removeAt(from)),
          ),
          itemBuilder: (int index) => _varRow(vars, index),
        ),
      Button(
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: vars.length >= GlossRealDropScript.maxVars
            ? null
            : () => _mutateScript(
                'add drop script variable',
                (GlossRealDropScript edited) => edited.vars.add(
                  GlossRealDropScriptVar(
                    name: _freshVarName(edited.vars),
                    expression: '0',
                  ),
                ),
              ),
        label: huiText('Add variable'),
      ),
    ]);
  }

  Widget _varRow(List<GlossRealDropScriptVar> vars, int index) {
    final GlossRealDropScriptVar variable = vars[index];
    return dom.div(classes: 'hui-drop-var-row', <Widget>[
      TextInput(
        value: variable.name,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText('name'),
        styles: huiTechnicalInputStyles,
        attributes: <String, String>{
          ...huiTechnicalInputAttributes,
          'aria-label': huiText('Variable name'),
        },
        onInput: (String value) => _mutateScript(
          'rename drop script variable',
          (GlossRealDropScript edited) =>
              edited.vars[index].name = value.trim(),
        ),
      ),
      RealDropExprField(
        label: huiText('Expression'),
        bare: true,
        value: variable.expression,
        placeholder: huiText('expression'),
        issues: _exact('\$.presentation.script.vars.\${variable.name}'),
        onChanged: (String value) => _mutateScript(
          'edit drop script variable',
          (GlossRealDropScript edited) => edited.vars[index].expression = value,
        ),
      ),
      dom.div(classes: 'hui-drop-rowactions', <Widget>[
        _rowButton(
          label: huiText('Move up'),
          icon: ArcaneIcon.chevronUp(size: IconSize.sm),
          onPressed: index == 0 ? null : () => _moveVar(index, index - 1),
        ),
        _rowButton(
          label: huiText('Move down'),
          icon: ArcaneIcon.chevronDown(size: IconSize.sm),
          onPressed: index >= vars.length - 1
              ? null
              : () => _moveVar(index, index + 1),
        ),
        _rowButton(
          label: huiText('Remove variable'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onPressed: () => _mutateScript(
            'remove drop script variable',
            (GlossRealDropScript edited) => edited.vars.removeAt(index),
          ),
        ),
      ]),
    ]);
  }

  Widget _rowButton({
    required String label,
    required ArcaneGlyph icon,
    required void Function()? onPressed,
  }) => Button(
    variant: ButtonVariant.ghost,
    size: ButtonSize.iconSm,
    onPressed: onPressed,
    attributes: <String, String>{'aria-label': label, 'title': label},
    icon: icon,
  );

  void _moveVar(int from, int to) => _mutateScript(
    'reorder drop script variables',
    (GlossRealDropScript edited) =>
        edited.vars.insert(to, edited.vars.removeAt(from)),
  );

  /// A name nothing in the list already uses, so adding a row twice in a row
  /// does not produce two entries the server refuses as declared twice.
  static String _freshVarName(List<GlossRealDropScriptVar> vars) {
    final Set<String> taken = <String>{
      for (final GlossRealDropScriptVar entry in vars) entry.name,
    };
    for (int index = 1; ; index++) {
      final String name = 'value$index';
      if (!taken.contains(name)) return name;
    }
  }

  /// Issues on exactly this path. The prefix match [_issuesFor] does is wrong
  /// for an expression field: `$.presentation.script.scale` would swallow all three axes.
  List<HuiIssue> _exact(String path) =>
      _store.issues.where((HuiIssue issue) => issue.path == path).toList();

  Widget _integer({
    required String label,
    required String help,
    required String path,
    required int value,
    required void Function(int value) onChanged,
  }) => HuiField(
    label: label,
    help: help,
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value.toDouble(),
        step: 1,
        decimals: 0,
        integer: true,
        onChanged: (double parsed) => onChanged(parsed.round()),
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _decimal({
    required String label,
    required String help,
    required String path,
    required double value,
    required void Function(double value) onChanged,
    double step = 0.05,
  }) => HuiField(
    label: label,
    help: help,
    control: dom.div(<Widget>[
      HuiNumberField(
        value: value,
        step: step,
        decimals: 2,
        onChanged: onChanged,
      ),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );

  Widget _list({
    required String label,
    required String help,
    required List<String> value,
    required void Function(List<String> value) onChanged,
  }) => HuiField(
    label: label,
    help: help,
    control: TextInput(
      value: value.join(', '),
      size: ComponentSize.sm,
      fullWidth: true,
      styles: huiTechnicalInputStyles,
      onInput: (String raw) => onChanged(
        raw
            .split(',')
            .map((String entry) => entry.trim())
            .where((String entry) => entry.isNotEmpty)
            .toList(),
      ),
      attributes: huiTechnicalInputAttributes,
    ),
  );

  void _mutate(
    String label,
    void Function(GlossRealDropSettingsDoc doc) change,
  ) => _store.mutateRealDropSettings(label, change);

  /// Edits the physics block, creating it if the document never had one. This
  /// is the only place the block comes into existence, which is what keeps an
  /// untouched document byte-identical through the editor.
  void _mutatePhysics(
    String label,
    void Function(GlossRealDropPhysics physics) change,
  ) => _mutate(
    label,
    (GlossRealDropSettingsDoc doc) =>
        change(doc.presentation.physics ??= GlossRealDropPhysics()),
  );

  /// The same, for the script block.
  void _mutateScript(
    String label,
    void Function(GlossRealDropScript script) change,
  ) => _mutate(
    label,
    (GlossRealDropSettingsDoc doc) =>
        change(doc.presentation.script ??= GlossRealDropScript()),
  );
}
