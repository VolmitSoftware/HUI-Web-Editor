/// The simulation control panel: category picker, per-variable sample-value
/// controls, the surge toggle, sample-item pickers, and playback transport —
/// the showcase surface an author watches a container-preview card animate
/// through.
///
/// Everything this renders is a direct read of `store.previewSim`
/// ([PreviewSimController], `lib/logic/preview_sim_controls.dart`), the ONE
/// simulation the pixel-card viewport paints from — this panel is a sibling
/// widget with no reference to the viewport, so sharing that one controller
/// (rather than building a second [PreviewSim]) is what keeps the two from
/// ever disagreeing about what is on screen. Every control here writes
/// through the controller, never through `EditorStore.mutatePreview`: a
/// pinned sample value is simulation state, not document state, so it must
/// repaint the card without an undo step, without dirtying the workspace, and
/// without the document-revision bump the viewport memoizes its own
/// category/vars resolution against.
///
/// Mounted for every view except [EditorView.code] (see
/// `doctype/document_inspector.dart`) — the "preview HUD-ish chrome" the brief
/// asks for belongs to the surface that is actually animating, and the code
/// view of the same document has nothing on screen to animate.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/preview_card_edit.dart' show previewAutoSimCategory;
import '../../logic/preview_sim.dart';
import '../../logic/preview_sim_controls.dart';
import '../../model/preview_doc.dart';
import '../../services/catalogs.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../inspector/inspector_widgets.dart';
import '../inspector/registry_picker.dart';

class PreviewSimPanel extends StatelessWidget {
  const PreviewSimPanel({required this.store, this.catalogs, super.key});

  final EditorStore store;

  /// Boot snapshot; `store.catalogs` wins once it holds anything — same
  /// freshness rule the rest of the inspector uses.
  final HuiCatalogs? catalogs;

  @override
  Widget build(BuildContext context) {
    final PreviewSimController controller = store.previewSim;
    final PreviewSim sim = controller.sim;
    final HuiCatalogs cats = huiFreshestCatalogs(store.catalogs, catalogs);
    return dom.div(classes: 'hui-inspector-body is-preview-sim', <Widget>[
      _header(),
      _categorySection(controller),
      _playbackSection(controller),
      ..._variableSection(controller, sim),
      if (previewSimCategorySupportsSurge(controller.category))
        _surgeSection(controller, sim),
      if (previewSimCategorySupportsSlots(controller.category))
        _slotsSection(controller, sim, cats),
    ]);
  }

  Widget _header() =>
      const dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        HuiEyebrow('Simulation'),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            'The editor has no server, so this is a canned target the card '
            'previews against. Pin any value below to hold it still; '
            'anything not pinned follows the simulation.',
          ),
        ]),
      ]);

  // --- category ---------------------------------------------------------

  Widget _categorySection(PreviewSimController controller) {
    final HuiPreviewDoc? doc = store.previewDoc;
    final String auto = doc == null ? 'statics' : previewAutoSimCategory(doc);
    final bool manual = controller.categoryOverride != null;
    return InspectorSection(
      title: 'Target',
      children: <Widget>[
        HuiField(
          label: 'Simulated target',
          help:
              'Which canned state (a chest, a running furnace, ...) the '
              'card previews against.',
          trailing: !manual
              ? null
              : HuiIconButton(
                  icon: ArcaneIcon.refreshCcw(size: IconSize.sm),
                  label:
                      'Follow the document\'s own match '
                      '(${previewSimCategoryLabel(auto)})',
                  onPressed: () => controller.setCategory(null),
                ),
          control: ArcaneSelect(
            value: controller.category,
            size: ComponentSize.sm,
            fullWidth: true,
            options: <ArcaneSelectOption>[
              for (final String category in previewSimCategories)
                ArcaneSelectOption(
                  label: previewSimCategoryLabel(category),
                  value: category,
                ),
            ],
            onChange: (String value) => controller.setCategory(value),
          ),
        ),
      ],
    );
  }

  // --- playback -----------------------------------------------------------

  Widget _playbackSection(PreviewSimController controller) => InspectorSection(
    title: 'Playback',
    description:
        'Drives the same clock the canvas toolbar\'s play/pause '
        'does — one simulated game tick every 50 ms.',
    children: <Widget>[
      dom.div(
        styles: const dom.Styles(
          raw: <String, String>{'display': 'flex', 'gap': '6px'},
        ),
        <Widget>[
          Button(
            variant: store.animationsPlaying
                ? ButtonVariant.secondary
                : ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: store.animationsPlaying
                ? ArcaneIcon.pause(size: IconSize.sm)
                : ArcaneIcon.play(size: IconSize.sm),
            onPressed: () => store.animationsPlaying = !store.animationsPlaying,
            attributes: <String, String>{
              'aria-pressed': '${store.animationsPlaying}',
              'aria-label': store.animationsPlaying ? 'Pause' : 'Play',
            },
            child: Text(store.animationsPlaying ? 'Pause' : 'Play'),
          ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.stepForward(size: IconSize.sm),
            onPressed: controller.step,
            attributes: const <String, String>{
              'aria-label': 'Step one second of simulation',
            },
            child: const Text('Step'),
          ),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.rotateCcw(size: IconSize.sm),
            onPressed: controller.reset,
            attributes: const <String, String>{
              'aria-label': 'Reset the simulated state',
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      HuiSwitchRow(
        label: 'Force ticking on a static card',
        value: controller.forcePlay,
        onChanged: controller.setForcePlay,
        help:
            'Runs the clock even if nothing in this document reads a '
            'value it moves. Normally the surface skips ticking a card '
            'that would draw the same picture every frame.',
      ),
    ],
  );

  // --- per-variable controls -----------------------------------------------

  List<Widget> _variableSection(
    PreviewSimController controller,
    PreviewSim sim,
  ) {
    final List<PreviewSimVarControl> controls = previewSimControlsFor(
      controller.category,
    );
    if (controls.isEmpty) return const <Widget>[];
    return <Widget>[
      InspectorSection(
        title: 'Sample values',
        children: <Widget>[
          for (final PreviewSimVarControl c in controls)
            _controlRow(controller, sim, c),
        ],
      ),
    ];
  }

  Widget _controlRow(
    PreviewSimController controller,
    PreviewSim sim,
    PreviewSimVarControl control,
  ) {
    final bool pinned = sim.overrides.containsKey(control.name);
    final Object current =
        sim.overrides[control.name] ??
        sim.variable(control.name) ??
        _fallback(control.kind);
    final Widget? unpin = !pinned
        ? null
        : HuiIconButton(
            icon: ArcaneIcon.pinOff(size: IconSize.sm),
            label: 'Unpin ${previewSimVarLabel(control.name)}',
            onPressed: () => controller.clearOverride(control.name),
          );
    switch (control.kind) {
      case PreviewSimControlKind.number:
        return HuiField(
          label: previewSimVarLabel(control.name),
          trailing: unpin,
          control: HuiSliderField(
            label: previewSimVarLabel(control.name),
            value: (current as num).toDouble(),
            min: control.min,
            max: control.max,
            step: control.step,
            decimals: control.decimals,
            onChanged: (double value) => controller.setOverride(control, value),
          ),
        );
      case PreviewSimControlKind.boolean:
        return HuiSwitchRow(
          label: previewSimVarLabel(control.name),
          value: current == true,
          trailing: unpin,
          onChanged: (bool value) => controller.setOverride(control, value),
        );
      case PreviewSimControlKind.string:
        return HuiField(
          label: previewSimVarLabel(control.name),
          trailing: unpin,
          control: TextInput(
            value: current.toString(),
            size: ComponentSize.sm,
            fullWidth: true,
            onInput: (String value) => controller.setOverride(control, value),
            attributes: const <String, String>{
              'autocomplete': 'off',
              'spellcheck': 'false',
            },
          ),
        );
    }
  }

  static Object _fallback(PreviewSimControlKind kind) => switch (kind) {
    PreviewSimControlKind.number => 0.0,
    PreviewSimControlKind.boolean => false,
    PreviewSimControlKind.string => '',
  };

  // --- surge ----------------------------------------------------------------

  Widget _surgeSection(PreviewSimController controller, PreviewSim sim) =>
      InspectorSection(
        title: 'Surge',
        description:
            'Simulates the plugin\'s own catch-up window after a '
            'refresh gap: progress jumps by more than the elapsed ticks, '
            'which is what `surge.active`/`surge.gain` report.',
        children: <Widget>[
          HuiSwitchRow(
            label: 'Surge active',
            value: sim.surgeActive,
            onChanged: (bool value) => controller.setSurge(value),
          ),
          if (sim.surgeActive)
            HuiField(
              label: 'Gain (seconds)',
              control: HuiSliderField(
                label: 'Surge gain',
                value: sim.surgeGain,
                min: 0,
                max: 30,
                step: 0.1,
                decimals: 1,
                onChanged: (double value) =>
                    controller.setSurge(true, gain: value),
              ),
            ),
        ],
      );

  // --- sample items -----------------------------------------------------

  Widget _slotsSection(
    PreviewSimController controller,
    PreviewSim sim,
    HuiCatalogs cats,
  ) {
    final int size = sim.inventorySize;
    if (size <= 0) return const dom.div(<Widget>[]);
    return HuiMore(
      summary: 'Sample items ($size slots)',
      children: <Widget>[
        for (int slot = 0; slot < size; slot++)
          _slotRow(controller, sim, cats, slot),
      ],
    );
  }

  Widget _slotRow(
    PreviewSimController controller,
    PreviewSim sim,
    HuiCatalogs cats,
    int slot,
  ) {
    final SimSlotItem? item = previewSimSlotAt(sim.slotItems, slot);
    final String material = item?.material ?? '';
    final int count = item?.count ?? 0;
    return HuiField(
      label: 'Slot $slot',
      control: dom.div(
        styles: const dom.Styles(
          raw: <String, String>{
            'display': 'grid',
            'grid-template-columns': 'minmax(0, 1fr) 72px',
            'gap': '8px',
            'min-width': '0',
          },
        ),
        <Widget>[
          RegistryPicker(
            // The sim stores Bukkit enum names (`IRON_ORE`); the catalogue and
            // every other picker in this editor use lowercase namespaced keys
            // (`iron_ore`) — bridge here so the UI stays consistent while
            // `SimSlotItem.material` keeps the form `item()`/`readable()`
            // expect.
            value: material.toLowerCase(),
            placeholder: 'air',
            browseLabel: 'Browse items',
            searchPlaceholder: 'Search ${cats.materials.length} materials',
            catalogAvailable: cats.materials.isNotEmpty,
            textureFor: cats.textureFor,
            search: (String query, int limit) => cats
                .searchMaterials(query, limit: limit)
                .map(
                  (MaterialEntry entry) =>
                      RegistryOption(entry.key, entry.texture),
                )
                .toList(),
            onChanged: (String value) => controller.setSlot(
              slot,
              material: value.toUpperCase(),
              count: count > 0 ? count : 1,
            ),
          ),
          HuiNumberField(
            value: count.toDouble(),
            min: 0,
            max: 6400,
            step: 1,
            integer: true,
            steppers: false,
            onChanged: (double value) => controller.setSlot(
              slot,
              material: material,
              count: value.round(),
            ),
          ),
        ],
      ),
    );
  }
}
