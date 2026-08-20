library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class RealDropInspector extends StatefulWidget {
  const RealDropInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<RealDropInspector> createState() => _RealDropInspectorState();
}

class _RealDropInspectorState extends State<RealDropInspector> {
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
      _limits(doc),
      _scales(doc),
      _motion(doc),
      _landing(doc),
      _labels(doc),
      _filters(doc),
    ]);
  }

  Widget _header(GlossRealDropSettingsDoc doc) => dom.div(
    classes: 'hui-inspector-headgroup',
    <Widget>[
      dom.div(classes: 'hui-inspector-header is-real-drops', <Widget>[
        const HuiEyebrow('Real drops'),
        dom.h2(classes: 'hui-inspector-title', <Widget>[Text(_store.menuId)]),
      ]),
      const dom.p(classes: 'hui-inspector-lede', <Widget>[
        Text('Native item models, motion, landing, labels, and render limits.'),
      ]),
      HuiRevisionRow(revision: doc.revision),
    ],
  );

  Widget _limits(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: 'Performance and density',
    children: <Widget>[
      _integer(
        label: 'Moving update interval',
        help: 'Ticks between updates while an item is moving. 1..20.',
        path: r'$.limits.updateIntervalTicks',
        value: doc.limits.updateIntervalTicks,
        onChanged: (int value) => _mutate(
          'drop update interval',
          (GlossRealDropSettingsDoc edited) =>
              edited.limits.updateIntervalTicks = value,
        ),
      ),
      _integer(
        label: 'Settled poll interval',
        help: 'Ticks between checks after an item has landed. 2..200.',
        path: r'$.limits.settledPollIntervalTicks',
        value: doc.limits.settledPollIntervalTicks,
        onChanged: (int value) => _mutate(
          'settled drop interval',
          (GlossRealDropSettingsDoc edited) =>
              edited.limits.settledPollIntervalTicks = value,
        ),
      ),
      _integer(
        label: 'Models per stack',
        help: 'Maximum visible item models for one dropped stack. 1..5.',
        path: r'$.limits.maxVisualsPerStack',
        value: doc.limits.maxVisualsPerStack,
        onChanged: (int value) => _mutate(
          'models per drop',
          (GlossRealDropSettingsDoc edited) =>
              edited.limits.maxVisualsPerStack = value,
        ),
      ),
      _integer(
        label: 'Models per chunk',
        help: 'Hard chunk budget across all dropped stacks. 8..1024.',
        path: r'$.limits.maxVisualsPerChunk',
        value: doc.limits.maxVisualsPerChunk,
        onChanged: (int value) => _mutate(
          'models per chunk',
          (GlossRealDropSettingsDoc edited) =>
              edited.limits.maxVisualsPerChunk = value,
        ),
      ),
      _decimal(
        label: 'Model view range',
        help: 'Client tracking range for drop models in blocks. 4..128.',
        path: r'$.limits.viewRange',
        value: doc.limits.viewRange,
        step: 1,
        onChanged: (double value) => _mutate(
          'drop model range',
          (GlossRealDropSettingsDoc edited) => edited.limits.viewRange = value,
        ),
      ),
      _decimal(
        label: 'Stack spread',
        help: 'Horizontal separation between models in one stack. 0..1.',
        path: r'$.limits.spread',
        value: doc.limits.spread,
        onChanged: (double value) => _mutate(
          'drop model spread',
          (GlossRealDropSettingsDoc edited) => edited.limits.spread = value,
        ),
      ),
    ],
  );

  Widget _scales(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: 'Model scale',
    children: <Widget>[
      _decimal(
        label: 'Default items',
        help: 'Scale for ordinary block-like items. 0.05..2.',
        path: r'$.scale.defaultScale',
        value: doc.scale.defaultScale,
        onChanged: (double value) => _mutate(
          'default drop scale',
          (GlossRealDropSettingsDoc edited) =>
              edited.scale.defaultScale = value,
        ),
      ),
      _decimal(
        label: 'Flat items',
        help: 'Scale for sprite-like items. 0.05..2.',
        path: r'$.scale.flatItems',
        value: doc.scale.flatItems,
        onChanged: (double value) => _mutate(
          'flat item scale',
          (GlossRealDropSettingsDoc edited) => edited.scale.flatItems = value,
        ),
      ),
      _decimal(
        label: 'Thin blocks',
        help: 'Scale for slabs, panes, and other thin blocks. 0.05..2.',
        path: r'$.scale.thinBlocks',
        value: doc.scale.thinBlocks,
        onChanged: (double value) => _mutate(
          'thin block scale',
          (GlossRealDropSettingsDoc edited) => edited.scale.thinBlocks = value,
        ),
      ),
    ],
  );

  Widget _motion(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: 'Tumble',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Tumble while moving',
        value: doc.motion.tumble,
        onChanged: (bool value) => _mutate(
          'drop tumble',
          (GlossRealDropSettingsDoc edited) => edited.motion.tumble = value,
        ),
      ),
      _decimal(
        label: 'Animation speed',
        help: 'Multiplier applied to every tumble axis. 0.1..4.',
        path: r'$.motion.speedMultiplier',
        value: doc.motion.speedMultiplier,
        onChanged: (double value) => _mutate(
          'drop animation speed',
          (GlossRealDropSettingsDoc edited) =>
              edited.motion.speedMultiplier = value,
        ),
      ),
      _decimal(
        label: 'X rotation',
        help: 'Base X-axis degrees per second. -1440..1440.',
        path: r'$.motion.degreesPerSecondX',
        value: doc.motion.degreesPerSecondX,
        step: 5,
        onChanged: (double value) => _mutate(
          'drop x rotation',
          (GlossRealDropSettingsDoc edited) =>
              edited.motion.degreesPerSecondX = value,
        ),
      ),
      _decimal(
        label: 'Y rotation',
        help: 'Base Y-axis degrees per second. -1440..1440.',
        path: r'$.motion.degreesPerSecondY',
        value: doc.motion.degreesPerSecondY,
        step: 5,
        onChanged: (double value) => _mutate(
          'drop y rotation',
          (GlossRealDropSettingsDoc edited) =>
              edited.motion.degreesPerSecondY = value,
        ),
      ),
      _decimal(
        label: 'Z rotation',
        help: 'Base Z-axis degrees per second. -1440..1440.',
        path: r'$.motion.degreesPerSecondZ',
        value: doc.motion.degreesPerSecondZ,
        step: 5,
        onChanged: (double value) => _mutate(
          'drop z rotation',
          (GlossRealDropSettingsDoc edited) =>
              edited.motion.degreesPerSecondZ = value,
        ),
      ),
      _decimal(
        label: 'Per-item variance',
        help: 'Deterministic variation around the base axes. 0..1.',
        path: r'$.motion.variance',
        value: doc.motion.variance,
        onChanged: (double value) => _mutate(
          'drop tumble variance',
          (GlossRealDropSettingsDoc edited) => edited.motion.variance = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Change tumble on bounce',
        value: doc.motion.changeOnBounce,
        onChanged: (bool value) => _mutate(
          'bounce tumble change',
          (GlossRealDropSettingsDoc edited) =>
              edited.motion.changeOnBounce = value,
        ),
      ),
    ],
  );

  Widget _landing(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: 'Landing',
    children: <Widget>[
      HuiField(
        label: 'Landing mode',
        help: 'Natural tilt, completely flat, or standing upright.',
        control: ArcaneSelect(
          value: doc.landing.mode,
          size: ComponentSize.sm,
          fullWidth: true,
          options: const <ArcaneSelectOption>[
            ArcaneSelectOption(label: 'Natural', value: 'NATURAL'),
            ArcaneSelectOption(label: 'Flat', value: 'FLAT'),
            ArcaneSelectOption(label: 'Upright', value: 'UPRIGHT'),
          ],
          onChange: (String value) => _mutate(
            'drop landing mode',
            (GlossRealDropSettingsDoc edited) => edited.landing.mode = value,
          ),
        ),
      ),
      _decimal(
        label: 'Natural tilt',
        help: 'Maximum landing tilt in degrees. 0..45.',
        path: r'$.landing.tiltDegrees',
        value: doc.landing.tiltDegrees,
        step: 1,
        onChanged: (double value) => _mutate(
          'drop landing tilt',
          (GlossRealDropSettingsDoc edited) =>
              edited.landing.tiltDegrees = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Random landing yaw',
        value: doc.landing.randomYaw,
        onChanged: (bool value) => _mutate(
          'drop landing yaw',
          (GlossRealDropSettingsDoc edited) => edited.landing.randomYaw = value,
        ),
      ),
      _integer(
        label: 'Landing transition',
        help: 'Ticks used to settle into the landing pose. 0..20.',
        path: r'$.landing.transitionTicks',
        value: doc.landing.transitionTicks,
        onChanged: (int value) => _mutate(
          'drop landing transition',
          (GlossRealDropSettingsDoc edited) =>
              edited.landing.transitionTicks = value,
        ),
      ),
    ],
  );

  Widget _labels(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: 'Nametag',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Show item labels',
        value: doc.labels.enabled,
        onChanged: (bool value) => _mutate(
          'drop labels',
          (GlossRealDropSettingsDoc edited) => edited.labels.enabled = value,
        ),
      ),
      _decimal(
        label: 'Height',
        help: 'Blocks above the dropped item. 0..4.',
        path: r'$.labels.yOffset',
        value: doc.labels.yOffset,
        onChanged: (double value) => _mutate(
          'drop label height',
          (GlossRealDropSettingsDoc edited) => edited.labels.yOffset = value,
        ),
      ),
      _decimal(
        label: 'Text scale',
        help: 'TextDisplay scale. 0.1..4.',
        path: r'$.labels.scale',
        value: doc.labels.scale,
        onChanged: (double value) => _mutate(
          'drop label scale',
          (GlossRealDropSettingsDoc edited) => edited.labels.scale = value,
        ),
      ),
      _decimal(
        label: 'Label view range',
        help: 'Client tracking range for item labels. 4..128.',
        path: r'$.labels.viewRange',
        value: doc.labels.viewRange,
        step: 1,
        onChanged: (double value) => _mutate(
          'drop label range',
          (GlossRealDropSettingsDoc edited) => edited.labels.viewRange = value,
        ),
      ),
      HuiField(
        label: 'Billboard',
        help: 'How the text rotates toward the viewer.',
        control: ArcaneSelect(
          value: doc.labels.billboard,
          size: ComponentSize.sm,
          fullWidth: true,
          options: const <ArcaneSelectOption>[
            ArcaneSelectOption(label: 'Center', value: 'CENTER'),
            ArcaneSelectOption(label: 'Fixed', value: 'FIXED'),
            ArcaneSelectOption(label: 'Horizontal', value: 'HORIZONTAL'),
            ArcaneSelectOption(label: 'Vertical', value: 'VERTICAL'),
          ],
          onChange: (String value) => _mutate(
            'drop label billboard',
            (GlossRealDropSettingsDoc edited) =>
                edited.labels.billboard = value,
          ),
        ),
      ),
      HuiSwitchRow(
        label: 'See through blocks',
        value: doc.labels.seeThrough,
        onChanged: (bool value) => _mutate(
          'drop label visibility',
          (GlossRealDropSettingsDoc edited) => edited.labels.seeThrough = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Text shadow',
        value: doc.labels.shadow,
        onChanged: (bool value) => _mutate(
          'drop label shadow',
          (GlossRealDropSettingsDoc edited) => edited.labels.shadow = value,
        ),
      ),
      HuiSwitchRow(
        label: 'Background',
        value: doc.labels.background,
        onChanged: (bool value) => _mutate(
          'drop label background',
          (GlossRealDropSettingsDoc edited) => edited.labels.background = value,
        ),
      ),
      _integer(
        label: 'Background red',
        help: 'Red channel. 0..255.',
        path: r'$.labels.backgroundRed',
        value: doc.labels.backgroundRed,
        onChanged: (int value) => _mutate(
          'drop label red',
          (GlossRealDropSettingsDoc edited) =>
              edited.labels.backgroundRed = value,
        ),
      ),
      _integer(
        label: 'Background green',
        help: 'Green channel. 0..255.',
        path: r'$.labels.backgroundGreen',
        value: doc.labels.backgroundGreen,
        onChanged: (int value) => _mutate(
          'drop label green',
          (GlossRealDropSettingsDoc edited) =>
              edited.labels.backgroundGreen = value,
        ),
      ),
      _integer(
        label: 'Background blue',
        help: 'Blue channel. 0..255.',
        path: r'$.labels.backgroundBlue',
        value: doc.labels.backgroundBlue,
        onChanged: (int value) => _mutate(
          'drop label blue',
          (GlossRealDropSettingsDoc edited) =>
              edited.labels.backgroundBlue = value,
        ),
      ),
      _integer(
        label: 'Background alpha',
        help: 'Background opacity. 0..255.',
        path: r'$.labels.backgroundAlpha',
        value: doc.labels.backgroundAlpha,
        onChanged: (int value) => _mutate(
          'drop label alpha',
          (GlossRealDropSettingsDoc edited) =>
              edited.labels.backgroundAlpha = value,
        ),
      ),
    ],
  );

  Widget _filters(GlossRealDropSettingsDoc doc) => InspectorSection(
    title: 'Filters',
    children: <Widget>[
      HuiSwitchRow(
        label: 'Only player-thrown drops',
        value: doc.filters.onlyPlayerDrops,
        onChanged: (bool value) => _mutate(
          'drop source filter',
          (GlossRealDropSettingsDoc edited) =>
              edited.filters.onlyPlayerDrops = value,
        ),
      ),
      _list(
        label: 'Disabled worlds',
        help: 'Comma-separated world names that keep vanilla item rendering.',
        value: doc.filters.disabledWorlds,
        onChanged: (List<String> value) => _mutate(
          'disabled drop worlds',
          (GlossRealDropSettingsDoc edited) =>
              edited.filters.disabledWorlds = value,
        ),
      ),
      _list(
        label: 'Material blacklist',
        help: 'Comma-separated Bukkit material names kept vanilla.',
        value: doc.filters.materialBlacklist,
        onChanged: (List<String> value) => _mutate(
          'drop material blacklist',
          (GlossRealDropSettingsDoc edited) =>
              edited.filters.materialBlacklist = value,
        ),
      ),
    ],
  );

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
      onInput: (String raw) => onChanged(
        raw
            .split(',')
            .map((String entry) => entry.trim())
            .where((String entry) => entry.isNotEmpty)
            .toList(),
      ),
    ),
  );

  void _mutate(
    String label,
    void Function(GlossRealDropSettingsDoc doc) change,
  ) => _store.mutateRealDropSettings(label, change);
}
