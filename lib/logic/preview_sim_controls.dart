/// The simulation panel's control model.
///
/// [PreviewSim] (`preview_sim.dart`) is the simulated state itself; this file
/// is everything a UI needs to let an author drive it by hand: which control
/// each published variable gets (a native range input, a toggle, or text),
/// sane bounds per variable, how an edit turns into a [PreviewSim] override or
/// a slot edit, and the play/pause/step/reset semantics the panel and the
/// card surface's ticker share.
///
/// [PreviewSimController] is the ownership seam: the pixel-card viewport and
/// the simulation panel are sibling widgets with no reference to each other,
/// so the one [PreviewSim] a document's preview uses has to live somewhere
/// both can reach. It lives on [EditorStore] (`editor_store.dart`) — one
/// controller for the store's whole life, reset per document inside [sync].
/// Every mutator here calls `notifyListeners`, which [EditorStore] forwards
/// into its own `notifyListeners` (see `previewSim.addListener(_notify)` in
/// the store's constructor); that is deliberately NOT the same signal as
/// `EditorStore.previewRevision`, which means "the DOCUMENT changed" (an
/// undoable edit) — simulation state is not document state, so a pinned
/// override or a tick must repaint the card without touching undo, dirty
/// tracking or the revision the viewport memoizes its category/vars
/// resolution against.
///
/// DOM-free: pure logic plus one small stateful controller, runs on the VM
/// under `dart test`.
library;

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../l10n/hui_localizations.dart';
import '../model/preview_doc.dart';
import 'preview_card_edit.dart'
    show previewAutoSimCategory, previewDocIsAnimated;
import 'preview_sim.dart';
import 'preview_variant_resolver.dart';

/// One game tick every 50 ms — the plugin's own refresh cadence. Lives here
/// (not on the viewport, which imports `dart:js_interop` and cannot be
/// imported into a DOM-free test) so the surface's ticker and this module's
/// own tests agree on the cadence.
const Duration previewSimTickInterval = Duration(milliseconds: 50);

/// Ticks the step control advances: one second.
const int previewSimStepTicks = 20;

/// Which native control a published variable gets in the panel.
enum PreviewSimControlKind { number, boolean, string }

/// One row the panel renders for a published variable: which [kind] of
/// control, and — for a number — the bounds a native `input[type=range]`
/// needs. Bounds are static per name rather than derived from the live sim
/// (e.g. `cookTime`'s real ceiling is whatever `cookTimeTotal` happens to be)
/// because an override is a display pin, not physics — see [PreviewSim]'s own
/// doc comment on `overrides`.
class PreviewSimVarControl {
  const PreviewSimVarControl(
    this.name,
    this.kind, {
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.decimals = 0,
  });

  /// The dotted variable name, exactly as [PreviewSim.variable] resolves it.
  final String name;
  final PreviewSimControlKind kind;
  final double min;
  final double max;
  final double step;
  final int decimals;
}

/// `surge.active`/`surge.gain` get a dedicated toggle+gain control (driven by
/// [PreviewSim.setSurge], which also feeds the tick advance — not a display
/// pin), so the generic per-variable list excludes them.
const Set<String> _surgeVarNames = <String>{'surge.active', 'surge.gain'};

/// One entry per name [previewSimGroupVariables] publishes, surge included
/// (its bounds are still used by the dedicated surge control) — pinned
/// against that map by `preview_sim_controls_test.dart`'s drift gate, so an
/// unmapped name fails loudly instead of silently vanishing from the panel.
const Map<String, PreviewSimVarControl>
_varControlSpecs = <String, PreviewSimVarControl>{
  'time': PreviewSimVarControl(
    'time',
    PreviewSimControlKind.number,
    max: 24000,
    step: 20,
  ),
  'blockType': PreviewSimVarControl('blockType', PreviewSimControlKind.string),
  'customName': PreviewSimVarControl(
    'customName',
    PreviewSimControlKind.string,
  ),
  'inventory.size': PreviewSimVarControl(
    'inventory.size',
    PreviewSimControlKind.number,
    max: 54,
  ),
  'inventory.occupied': PreviewSimVarControl(
    'inventory.occupied',
    PreviewSimControlKind.number,
    max: 54,
  ),
  'cookTime': PreviewSimVarControl(
    'cookTime',
    PreviewSimControlKind.number,
    max: 1200,
    step: 20,
  ),
  'cookTimeTotal': PreviewSimVarControl(
    'cookTimeTotal',
    PreviewSimControlKind.number,
    max: 1200,
    step: 20,
  ),
  'burnTime': PreviewSimVarControl(
    'burnTime',
    PreviewSimControlKind.number,
    max: 1200,
    step: 20,
  ),
  'fuelTicks': PreviewSimVarControl(
    'fuelTicks',
    PreviewSimControlKind.number,
    max: 32000,
    step: 20,
  ),
  'fuelSeconds': PreviewSimVarControl(
    'fuelSeconds',
    PreviewSimControlKind.number,
    max: 60,
  ),
  'bankedXp': PreviewSimVarControl(
    'bankedXp',
    PreviewSimControlKind.number,
    max: 100,
    step: 0.1,
    decimals: 2,
  ),
  'lit': PreviewSimVarControl('lit', PreviewSimControlKind.boolean),
  'powered': PreviewSimVarControl('powered', PreviewSimControlKind.boolean),
  'surge.active': PreviewSimVarControl(
    'surge.active',
    PreviewSimControlKind.boolean,
  ),
  'surge.gain': PreviewSimVarControl(
    'surge.gain',
    PreviewSimControlKind.number,
    max: 30,
    step: 0.1,
    decimals: 1,
  ),
  'brewTime': PreviewSimVarControl(
    'brewTime',
    PreviewSimControlKind.number,
    max: 800,
    step: 20,
  ),
  'brewTotal': PreviewSimVarControl(
    'brewTotal',
    PreviewSimControlKind.number,
    max: 800,
    step: 20,
  ),
  'fuelLevel': PreviewSimVarControl(
    'fuelLevel',
    PreviewSimControlKind.number,
    max: 20,
  ),
  'maxFuel': PreviewSimVarControl(
    'maxFuel',
    PreviewSimControlKind.number,
    max: 20,
  ),
  'bees': PreviewSimVarControl('bees', PreviewSimControlKind.number, max: 10),
  'maxBees': PreviewSimVarControl(
    'maxBees',
    PreviewSimControlKind.number,
    max: 10,
  ),
  'honey': PreviewSimVarControl('honey', PreviewSimControlKind.number, max: 10),
  'maxHoney': PreviewSimVarControl(
    'maxHoney',
    PreviewSimControlKind.number,
    max: 10,
  ),
  'level': PreviewSimVarControl('level', PreviewSimControlKind.number, max: 3),
  'maxLevel': PreviewSimVarControl(
    'maxLevel',
    PreviewSimControlKind.number,
    max: 3,
  ),
  'fluid': PreviewSimVarControl('fluid', PreviewSimControlKind.string),
  'playing': PreviewSimVarControl('playing', PreviewSimControlKind.boolean),
  'record': PreviewSimVarControl('record', PreviewSimControlKind.string),
};

const Map<String, String> _varLabels = <String, String>{
  'time': 'World time (game ticks)',
  'blockType': 'Block type',
  'customName': 'Custom name',
  'inventory.size': 'Inventory size',
  'inventory.occupied': 'Occupied inventory slots',
  'cookTime': 'Smelting progress (game ticks)',
  'cookTimeTotal': 'Total smelting time (game ticks)',
  'burnTime': 'Furnace fuel remaining (game ticks)',
  'fuelTicks': 'Minecart fuel remaining (game ticks)',
  'fuelSeconds': 'Fuel remaining (seconds)',
  'bankedXp': 'Stored recipe XP',
  'lit': 'Furnace lit',
  'powered': 'Minecart powered',
  'surge.active': 'Speed-up active',
  'surge.gain': 'Speed-up gain',
  'brewTime': 'Brewing time remaining (game ticks)',
  'brewTotal': 'Total brewing time (game ticks)',
  'fuelLevel': 'Blaze powder charges',
  'maxFuel': 'Maximum blaze powder charges',
  'bees': 'Bees inside',
  'maxBees': 'Bee capacity',
  'honey': 'Honey level',
  'maxHoney': 'Maximum honey level',
  'level': 'Fluid level',
  'maxLevel': 'Maximum fluid level',
  'fluid': 'Fluid type',
  'playing': 'Music disc playing',
  'record': 'Music disc',
};

const Map<String, String> _categoryLabels = <String, String>{
  'chest': 'Chest',
  'furnace': 'Furnace',
  'poweredMinecart': 'Furnace minecart',
  'brewing': 'Brewing stand',
  'beehive': 'Beehive',
  'cauldron': 'Cauldron',
  'jukebox': 'Jukebox',
  'enderChest': 'Ender chest',
  'entity': 'Hopper minecart',
  'statics': 'No target (static)',
};

/// Friendly panel label for a published variable name.
String previewSimVarLabel(String name) =>
    _varLabels.containsKey(name) ? huiText(_varLabels[name]!) : name;

/// Friendly panel label for a [previewSimCategories] entry.
String previewSimCategoryLabel(String category) =>
    _categoryLabels.containsKey(category)
    ? huiText(_categoryLabels[category]!)
    : category;

/// The controls the panel shows for [category], in catalog order, generic
/// per-variable controls only — `surge.*` is the dedicated surge section's.
List<PreviewSimVarControl> previewSimControlsFor(String category) {
  final List<PreviewSimVarControl> controls = <PreviewSimVarControl>[];
  final Set<String> seen = <String>{};
  for (final String group
      in previewSimCategoryGroups[category] ?? const <String>['universal']) {
    for (final String name
        in previewSimGroupVariables[group] ?? const <String>[]) {
      if (_surgeVarNames.contains(name) || !seen.add(name)) continue;
      final PreviewSimVarControl? spec = _varControlSpecs[name];
      if (spec != null) controls.add(spec);
    }
  }
  return controls;
}

/// Whether [category] publishes `surge.active`/`surge.gain` — mirrors
/// `PreviewStateAdapters.tracksTimeFlow` (furnace and brewing only).
bool previewSimCategorySupportsSurge(String category) =>
    (previewSimCategoryGroups[category] ?? const <String>['universal']).any(
      (String group) => (previewSimGroupVariables[group] ?? const <String>[])
          .contains('surge.active'),
    );

/// Whether [category] simulates an inventory at all — the sample-item
/// pickers only make sense when it does.
bool previewSimCategorySupportsSlots(String category) =>
    (previewSimCategoryGroups[category] ?? const <String>['universal'])
        .contains('inventory');

/// Coerces a raw UI value (a range input's number, a switch's bool, a text
/// field's string) into what [control] should actually store: a numeric
/// value clamped to bounds and rounded to its declared decimals, a real
/// `bool`, or a plain `String`.
Object previewSimCoerceOverride(PreviewSimVarControl control, Object rawValue) {
  switch (control.kind) {
    case PreviewSimControlKind.number:
      double value = rawValue is num
          ? rawValue.toDouble()
          : double.tryParse(rawValue.toString()) ?? control.min;
      // NaN has no natural direction to clamp toward, so it falls back to the
      // minimum explicitly; `clamp` already does the right thing for +/-
      // infinity (each saturates to the bound it overshoots).
      if (value.isNaN) value = control.min;
      value = value.clamp(control.min, control.max);
      if (control.decimals <= 0) return value.roundToDouble();
      final double factor = _pow10(control.decimals);
      return (value * factor).roundToDouble() / factor;
    case PreviewSimControlKind.boolean:
      return rawValue is bool
          ? rawValue
          : rawValue.toString().toLowerCase() == 'true';
    case PreviewSimControlKind.string:
      return rawValue is String ? rawValue : rawValue.toString();
  }
}

double _pow10(int digits) {
  double out = 1;
  for (int i = 0; i < digits; i++) {
    out *= 10;
  }
  return out;
}

/// Pins [control.name] to a coerced [rawValue] on [sim]. A display pin only —
/// see [PreviewSim.overrides]'s own doc comment.
void previewSimSetOverride(
  PreviewSim sim,
  PreviewSimVarControl control,
  Object rawValue,
) {
  sim.overrides[control.name] = previewSimCoerceOverride(control, rawValue);
}

/// Hands [name] back to the live simulation.
void previewSimClearOverride(PreviewSim sim, String name) =>
    sim.overrides.remove(name);

/// [items] with [slot] set to a stack of [material] x [count], or cleared if
/// [material] is blank or [count] is not positive — the same emptiness rule
/// [SimSlotItem.isEmpty] uses, applied by omission instead of storing an
/// empty stack. The result stays sorted by slot index.
List<SimSlotItem> previewSimSetSlot(
  List<SimSlotItem> items,
  int slot, {
  required String material,
  required int count,
}) {
  final List<SimSlotItem> kept = <SimSlotItem>[
    for (final SimSlotItem item in items)
      if (item.slot != slot) item,
  ];
  final String trimmed = material.trim();
  if (trimmed.isNotEmpty && count > 0) {
    kept.add(SimSlotItem(slot, trimmed, count));
  }
  kept.sort((SimSlotItem a, SimSlotItem b) => a.slot.compareTo(b.slot));
  return kept;
}

/// The sample stack at [slot], or null when it is empty/unset.
SimSlotItem? previewSimSlotAt(List<SimSlotItem> items, int slot) {
  for (final SimSlotItem item in items) {
    if (item.slot == slot) return item;
  }
  return null;
}

/// Whether the surface's periodic ticker should be running right now.
///
/// [autoAnimated] is [previewDocIsAnimated]'s answer for the open document —
/// the perf gate that keeps a card built only from constants from repainting
/// twenty times a second for no visible change. [forcePlay] is the panel's
/// own "run it anyway" latch: pressing play is a deliberate request, and a
/// heuristic that only ever OVER-reports (see `previewDocIsAnimated`'s own
/// doc comment) can still leave an author who trusts neither the heuristic
/// nor their own not-yet-finished expression without a way to just watch the
/// clock run. `playing` (`EditorStore.animationsPlaying`) still has to be
/// true either way — forcing the clock on is not the same as un-pausing it.
bool previewSimClockWanted({
  required bool hasArea,
  required bool isPreviewDoc,
  required bool playing,
  required bool autoAnimated,
  required bool forcePlay,
}) => hasArea && isPreviewDoc && playing && (autoAnimated || forcePlay);

/// Owns the one [PreviewSim] a document's preview-card viewport and
/// simulation panel share. See the library doc comment for the ownership
/// story and why every mutator here notifies independently of
/// `EditorStore.previewRevision`.
class PreviewSimController extends ChangeNotifier {
  PreviewSim sim = PreviewSim('statics');

  /// An explicit pick from the panel's category control; null follows
  /// [previewAutoSimCategory]. Reset to null whenever [sync] sees the
  /// document instance itself change (undo/redo/import/applyCode/adopt) — an
  /// in-place edit (`mutatePreview`, same instance) keeps it.
  String? categoryOverride;

  /// The panel's "force ticking on a static card" latch. Per-document, like
  /// [categoryOverride]: [sync] resets it to false on the same document-swap
  /// signal, so enabling it for one document can never silently keep the
  /// clock running at 20 Hz on every OTHER static document opened afterward
  /// for the rest of the session. See [previewSimClockWanted].
  bool forcePlay = false;

  String _resolvedCategory = 'statics';
  bool _autoAnimated = false;
  int _syncedRevision = -1;
  HuiPreviewDoc? _lastDoc;

  /// The category the simulation is actually drawing against right now:
  /// [categoryOverride] if set, otherwise the document's own auto-detected
  /// one.
  String get category => _resolvedCategory;

  /// [previewDocIsAnimated] for the document [sync] last saw.
  bool get autoAnimated => _autoAnimated;

  /// Re-derives the category and variant vars from [doc] — cheap, but the
  /// clock's animation gate depends on it, so [EditorStore]'s viewport calls
  /// this every frame and it costs nothing once nothing has changed.
  void sync(HuiPreviewDoc doc, int revision, PreviewLangCatalog lang) {
    final bool swapped = !identical(doc, _lastDoc);
    _lastDoc = doc;
    if (swapped) {
      categoryOverride = null;
      forcePlay = false;
    }
    sim.lang = lang;
    final String wanted = categoryOverride ?? previewAutoSimCategory(doc);
    if (!swapped &&
        revision == _syncedRevision &&
        wanted == _resolvedCategory) {
      return;
    }
    _syncedRevision = revision;
    _applyCategory(wanted, doc, lang: lang, forceRebuild: swapped);
  }

  /// Picks a category explicitly (sticking until [sync] sees a document
  /// swap), or follows the document's own auto-detected one when
  /// [category] is null. Resolves immediately — the panel that just called
  /// this reads [PreviewSimController.category] right back, and must not
  /// wait for the viewport's next paint to see its own pick take effect.
  void setCategory(String? category) {
    if (categoryOverride == category) return;
    categoryOverride = category;
    final HuiPreviewDoc? doc = _lastDoc;
    final String wanted =
        category ?? (doc == null ? 'statics' : previewAutoSimCategory(doc));
    _applyCategory(wanted, doc, lang: sim.lang, forceRebuild: false);
    notifyListeners();
  }

  void _applyCategory(
    String wanted,
    HuiPreviewDoc? doc, {
    required PreviewLangCatalog lang,
    required bool forceRebuild,
  }) {
    if (forceRebuild || wanted != _resolvedCategory) {
      _resolvedCategory = wanted;
      sim = PreviewSim(wanted, lang: lang);
    }
    if (doc != null) {
      sim.vars = PreviewSim.parseVars(
        previewVarsForMaterial(
          doc,
          sim.blockType.isEmpty ? null : sim.blockType,
        ),
      );
      _autoAnimated = previewDocIsAnimated(doc);
    }
  }

  /// Pins [control] to [rawValue]. See [previewSimSetOverride].
  void setOverride(PreviewSimVarControl control, Object rawValue) {
    previewSimSetOverride(sim, control, rawValue);
    notifyListeners();
  }

  /// Hands [name] back to the live simulation.
  void clearOverride(String name) {
    if (!sim.overrides.containsKey(name)) return;
    sim.overrides.remove(name);
    notifyListeners();
  }

  /// Edits the sample inventory. See [previewSimSetSlot].
  void setSlot(int slot, {required String material, required int count}) {
    sim.slotItems = previewSimSetSlot(
      sim.slotItems,
      slot,
      material: material,
      count: count,
    );
    notifyListeners();
  }

  /// Turns the simulated surge on or off. Real tick physics, not a display
  /// pin — see [PreviewSim.setSurge] — which is why it is not routed through
  /// [setOverride] like every other published variable.
  void setSurge(bool active, {double? gain}) {
    sim.setSurge(
      active,
      gain:
          gain ??
          (sim.surgeGain > 0 ? sim.surgeGain : previewSimDefaultSurgeGain),
    );
    notifyListeners();
  }

  void setForcePlay(bool value) {
    if (forcePlay == value) return;
    forcePlay = value;
    notifyListeners();
  }

  /// Advances the simulation by [ticks] game ticks. A non-positive value is a
  /// no-op that does not notify, so a paused surface calling this on a timer
  /// tick costs nothing.
  void tick(int ticks) {
    if (ticks <= 0) return;
    sim.tick(ticks);
    notifyListeners();
  }

  /// One second of simulated progress.
  void step([int ticks = previewSimStepTicks]) => tick(ticks);

  /// Restores the category's canned state. Keeps [sim]'s `vars` and
  /// `overrides` — a pinned value is the author's own choice, not part of
  /// what "reset" means here — matching [PreviewSim.reset]'s own contract.
  void reset() {
    sim.reset();
    notifyListeners();
  }
}
