/// The editor's single source of truth.
///
/// Every document change goes through [EditorStore.mutate], which snapshots the
/// document, runs the mutation, revalidates, schedules the workspace autosave
/// and notifies listeners. Nothing else is allowed to write the menu, which is
/// what keeps undo, validation and persistence in lockstep.
///
/// The store is DOM-free so it can be exercised on the VM: storage arrives as
/// injected functions and user-facing messages go to [EditorStore.onError] /
/// [EditorStore.onInfo] sinks that the shell wires to the toast stack.
library;

import 'dart:async';
import 'dart:convert';

import 'package:jaspr/jaspr.dart' show ChangeNotifier;

import '../config/defaults.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../services/catalogs.dart';
import '../services/image_library.dart';
import 'undo_stack.dart';
import 'workspace.dart';

enum EditorView { visual, code, split }

/// Canvas background treatment. Lives in the store because the settings dialog
/// persists it and the status bar reflects it.
enum HuiBackdropMode { none, dark, light, image }

typedef EditorMessageSink = void Function(String message);

class EditorStore extends ChangeNotifier {
  EditorStore({
    Workspace? workspace,
    HuiCatalogs? catalogs,
    ImageLibrary? images,
    this.autosaveDelay = const Duration(milliseconds: 500),
    bool autoLoad = true,
  })  : workspace = workspace ?? Workspace(),
        _catalogs = catalogs ?? HuiCatalogs.empty(),
        _images = images {
    _images?.addListener(_onImagesChanged);
    _menu = createDefaultMenu();
    if (autoLoad) {
      _loadPreferences();
      _adoptActiveDocument();
    } else {
      _issues = _validate();
    }
  }

  /// Preview and canvas flags, persisted separately from the documents so a
  /// corrupt preference blob can never take the menus down with it.
  static const String preferencesKey = 'holoui.prefs.v1';

  final Workspace workspace;

  /// Debounce window for the workspace autosave.
  final Duration autosaveDelay;

  /// Routed to the toast stack by the shell.
  EditorMessageSink? onError;
  EditorMessageSink? onInfo;

  late HuiMenu _menu;
  String _menuId = huiDefaultMenuId;
  String? _selectedId;
  EditorView _view = EditorView.visual;
  double _previewUiScale = 1;
  bool _showHitboxes = false;
  bool _showAnchors = true;
  bool _showGrid = true;
  bool _snapToGrid = true;
  bool _trueRender = false;
  double _gridSize = 0.05;
  HuiBackdropMode _backdrop = HuiBackdropMode.image;
  bool _animationsPlaying = true;
  final Map<String, bool> _togglePreviewState = <String, bool>{};

  List<HuiIssue> _issues = const <HuiIssue>[];
  final UndoStack _undo = UndoStack();
  HuiCatalogs _catalogs;
  final ImageLibrary? _images;

  Timer? _autosaveTimer;
  bool _documentDirty = false;
  bool _preferencesDirty = false;
  DateTime? _lastSavedAt;
  bool _dragActive = false;
  bool _dragPushed = false;
  String? _coalesceLabel;
  DateTime? _coalesceAt;
  bool _disposed = false;
  String? _lastError;
  String? _codeError;

  // --- document -------------------------------------------------------------

  /// Read-only handle on the document. Write through [mutate] so the change is
  /// undoable, validated and saved.
  HuiMenu get menu => _menu;

  List<HuiComponent> get components => _menu.components;

  /// Export file base name, always sanitized.
  String get menuId => _menuId;

  set menuId(String value) => setMenuId(value);

  String get exportFileName => '$_menuId.json';

  void setMenuId(String value) {
    final String sanitized = sanitizeMenuId(value);
    if (sanitized == _menuId) return;
    _menuId = sanitized;
    _documentDirty = true;
    _scheduleSave();
    _notify();
  }

  String? get selectedId => _selectedId;

  set selectedId(String? value) => select(value);

  HuiComponent? get selected => _selectedId == null
      ? null
      : _menu.componentById(_selectedId!);

  /// Passing an unknown id is ignored; passing null deselects.
  void select(String? id) {
    if (id != null && _menu.componentById(id) == null) return;
    if (id == _selectedId) return;
    _selectedId = id;
    _notify();
  }

  // --- view state -----------------------------------------------------------

  EditorView get view => _view;

  set view(EditorView value) {
    if (_view == value) return;
    _view = value;
    _savePreference();
  }

  double get previewUiScale => _previewUiScale;

  set previewUiScale(double value) {
    final double clamped = value.isFinite ? value.clamp(0.25, 4).toDouble() : 1;
    if (clamped == _previewUiScale) return;
    _previewUiScale = clamped;
    _savePreference();
  }

  bool get showHitboxes => _showHitboxes;

  set showHitboxes(bool value) {
    if (_showHitboxes == value) return;
    _showHitboxes = value;
    _savePreference();
  }

  bool get showAnchors => _showAnchors;

  set showAnchors(bool value) {
    if (_showAnchors == value) return;
    _showAnchors = value;
    _savePreference();
  }

  bool get showGrid => _showGrid;

  set showGrid(bool value) {
    if (_showGrid == value) return;
    _showGrid = value;
    _savePreference();
  }

  bool get snapToGrid => _snapToGrid;

  set snapToGrid(bool value) {
    if (_snapToGrid == value) return;
    _snapToGrid = value;
    _savePreference();
  }

  bool get trueRender => _trueRender;

  set trueRender(bool value) {
    if (_trueRender == value) return;
    _trueRender = value;
    _savePreference();
  }

  /// Snap step in blocks.
  double get gridSize => _gridSize;

  set gridSize(double value) {
    final double clamped =
        value.isFinite && value > 0 ? value.clamp(0.01, 1).toDouble() : 0.05;
    if (clamped == _gridSize) return;
    _gridSize = clamped;
    _savePreference();
  }

  HuiBackdropMode get backdrop => _backdrop;

  set backdrop(HuiBackdropMode value) {
    if (_backdrop == value) return;
    _backdrop = value;
    _savePreference();
  }

  bool get animationsPlaying => _animationsPlaying;

  set animationsPlaying(bool value) {
    if (_animationsPlaying == value) return;
    _animationsPlaying = value;
    _notify();
  }

  /// Which icon a toggle previews on the canvas. Defaults to the true icon.
  Map<String, bool> get togglePreviewState => _togglePreviewState;

  bool togglePreviewFor(String id) => _togglePreviewState[id] ?? true;

  void setTogglePreview(String id, bool showTrue) {
    if (togglePreviewFor(id) == showTrue) return;
    _togglePreviewState[id] = showTrue;
    _notify();
  }

  // --- validation -----------------------------------------------------------

  List<HuiIssue> get issues => _issues;

  bool get hasErrors => errorCount > 0;

  int get errorCount => _countSeverity(HuiSeverity.error);

  int get warningCount => _countSeverity(HuiSeverity.warning);

  int get infoCount => _countSeverity(HuiSeverity.info);

  List<HuiIssue> issuesFor(String componentId) => _issues
      .where((HuiIssue issue) => issue.componentId == componentId)
      .toList();

  HuiCatalogs get catalogs => _catalogs;

  ImageLibrary? get images => _images;

  /// Swaps in the catalogs once they finish loading and re-runs validation.
  void setCatalogs(HuiCatalogs value) {
    _catalogs = value;
    _issues = _validate();
    _notify();
  }

  void refreshValidation() {
    _issues = _validate();
    _notify();
  }

  // --- history --------------------------------------------------------------

  UndoStack get undo => _undo;

  bool get canUndo => _undo.canUndo;

  bool get canRedo => _undo.canRedo;

  String? get undoLabel => _undo.undoLabel;

  String? get redoLabel => _undo.redoLabel;

  /// The only write path into the document.
  void mutate(String label, void Function(HuiMenu menu) fn) {
    final String before = _snapshot();
    final int countBefore = _menu.components.length;
    fn(_menu);
    final String after = _snapshot();
    if (after == before) {
      _notify();
      return;
    }
    // Adding or removing a component is a step in its own right, however fast
    // it follows the last one; field edits are not.
    _pushUndo(
      label,
      before,
      coalesce: countBefore == _menu.components.length,
    );
    _afterChange();
  }

  /// Replaces the whole document in one undoable step.
  void replaceMenu(String label, HuiMenu next) {
    final String before = _snapshot();
    _menu = next;
    _pruneSelection();
    _pushUndo(label, before, coalesce: false);
    _afterChange();
  }

  /// Canvas drags call [beginDrag] on pointer down and [endDrag] on pointer up
  /// so the whole gesture collapses into a single undo step.
  void beginDrag() {
    _dragActive = true;
    _dragPushed = false;
    _clearCoalesce();
  }

  void endDrag() {
    _dragActive = false;
    _dragPushed = false;
    _clearCoalesce();
  }

  bool performUndo() {
    _clearCoalesce();
    final String? restored = _undo.undo(_snapshot());
    if (restored == null) return false;
    return _applySnapshot(restored);
  }

  bool performRedo() {
    _clearCoalesce();
    final String? restored = _undo.redo(_snapshot());
    if (restored == null) return false;
    return _applySnapshot(restored);
  }

  // --- component operations -------------------------------------------------

  /// Adds a component of [type] with sensible defaults at the first free slot
  /// and selects it. Returns the new id.
  String? addComponent(String type, {Vec3? offset, String? id}) {
    final String normalized =
        huiComponentTypes.contains(type) ? type : 'decoration';
    final String newId = uniqueComponentId(id ?? normalized, _takenIds());
    final Vec3 place = offset ?? nextFreeOffset(_menu);
    _selectedId = newId;
    mutate('add $normalized', (HuiMenu menu) {
      menu.components.add(
        HuiComponent(newId, place, createDefaultComponentData(normalized)),
      );
    });
    return newId;
  }

  /// Deep-copies [id] one slot below the original and selects the copy.
  String? duplicateComponent(String id) {
    final HuiComponent? source = _menu.componentById(id);
    if (source == null) return null;
    final int index = _menu.indexOfComponent(id);
    final String newId = _duplicateId(source.id, _takenIds());
    final HuiComponent copy = source.copy()
      ..id = newId
      ..offset = Vec3(
        source.offset.x,
        _round(source.offset.y - huiPlacementStep),
        source.offset.z,
      );
    _selectedId = newId;
    mutate('duplicate $id', (HuiMenu menu) {
      menu.components.insert(index + 1, copy);
    });
    return newId;
  }

  void deleteComponent(String id) {
    final int index = _menu.indexOfComponent(id);
    if (index < 0) return;
    if (_selectedId == id) _selectedId = null;
    mutate('delete $id', (HuiMenu menu) {
      // removeAt, never removeWhere: duplicate ids are legal and deleting one
      // row must never take its namesakes with it.
      menu.components.removeAt(index);
    });
    if (_menu.componentById(id) == null) _togglePreviewState.remove(id);
  }

  /// Order is click-dispatch order, so reordering is a real document change.
  void reorder(String id, int newIndex) {
    final int index = _menu.indexOfComponent(id);
    if (index < 0) return;
    final int target = newIndex.clamp(0, _menu.components.length - 1);
    if (target == index) return;
    mutate('reorder components', (HuiMenu menu) {
      final HuiComponent component = menu.components.removeAt(index);
      menu.components.insert(target, component);
    });
  }

  /// Relative move (arrow-key nudge). Only the axes [delta] actually touches
  /// are snapped: an authored `z` of 0.13 must survive a vertical nudge, the
  /// same way it survives an xy drag on the canvas.
  void moveComponent(String id, Vec3 delta) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null) return;
    _applyOffset(
      id,
      Vec3(
        delta.x == 0
            ? component.offset.x
            : snapValue(component.offset.x + delta.x),
        delta.y == 0
            ? component.offset.y
            : snapValue(component.offset.y + delta.y),
        delta.z == 0
            ? component.offset.z
            : snapValue(component.offset.z + delta.z),
      ),
    );
  }

  /// Absolute move; snaps all three axes because the caller is setting all
  /// three.
  void setComponentOffset(String id, Vec3 offset) =>
      _applyOffset(id, snapVec(offset));

  void _applyOffset(String id, Vec3 target) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null || component.offset == target) return;
    mutate('move $id', (HuiMenu menu) {
      menu.componentById(id)?.offset = target;
    });
  }

  /// Inspector edits: mutate one component by id.
  void editComponent(
    String id,
    String label,
    void Function(HuiComponent component) fn,
  ) {
    if (_menu.componentById(id) == null) return;
    mutate(label, (HuiMenu menu) {
      final HuiComponent? component = menu.componentById(id);
      if (component != null) fn(component);
    });
  }

  /// Renames a component and carries the selection and preview state across.
  bool renameComponent(String id, String nextId) {
    final HuiComponent? component = _menu.componentById(id);
    if (component == null) return false;
    final String sanitized = sanitizeComponentId(nextId);
    if (sanitized == id) return true;
    final bool wasSelected = _selectedId == id;
    final bool? preview = _togglePreviewState.remove(id);
    if (preview != null) _togglePreviewState[sanitized] = preview;
    if (wasSelected) _selectedId = sanitized;
    mutate('rename $id', (HuiMenu menu) {
      menu.componentById(id)?.id = sanitized;
    });
    return true;
  }

  double snapValue(double value) {
    if (!value.isFinite) return 0;
    if (!_snapToGrid || _gridSize <= 0) return _round(value);
    return _round((value / _gridSize).roundToDouble() * _gridSize);
  }

  Vec3 snapVec(Vec3 value) =>
      Vec3(snapValue(value.x), snapValue(value.y), snapValue(value.z));

  // --- import / export ------------------------------------------------------

  String exportJson() => encodeHuiMenu(_menu);

  /// Replaces the document with [content]. Parse failures report through
  /// [onError] and leave the current document untouched.
  void importJson(String name, String content) {
    final HuiMenu parsed;
    try {
      parsed = decodeHuiMenu(content);
    } on HuiFormatException catch (e) {
      _fail('${e.message} (at ${e.path})');
      return;
    } catch (_) {
      _fail('That file could not be read as HoloUI menu JSON.');
      return;
    }
    _lastError = null;
    _codeError = null;
    _selectedId = null;
    _togglePreviewState.clear();
    final String importedId = menuIdFromFileName(name);
    final String before = _snapshot();
    _menu = parsed;
    _menuId = importedId;
    _pushUndo('import $importedId', before, coalesce: false);
    _afterChange();
    onInfo?.call('Imported $importedId.');
  }

  String? get codeError => _codeError;

  /// Code-editor commit. Returns false and keeps the text when it does not
  /// parse, so the editor can show the error without losing the user's typing.
  bool applyCode(String text) {
    final HuiMenu parsed;
    try {
      parsed = decodeHuiMenu(text);
    } on HuiFormatException catch (e) {
      _codeError = '${e.message} (at ${e.path})';
      _notify();
      return false;
    } catch (_) {
      _codeError = 'That is not valid JSON.';
      _notify();
      return false;
    }
    _codeError = null;
    final String before = _snapshot();
    final String after = encodeHuiMenu(parsed);
    if (after == before) {
      _notify();
      return true;
    }
    _menu = parsed;
    _pruneSelection();
    _pushUndo('code edit', before);
    _afterChange();
    return true;
  }

  // --- documents ------------------------------------------------------------

  String? get lastError => _lastError;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    _notify();
  }

  DateTime? get lastSavedAt => _lastSavedAt;

  bool get hasUnsavedChanges => _documentDirty || _preferencesDirty;

  /// Starts a new document in its own workspace entry.
  void newDocument({String? name, HuiMenu? from}) {
    flushAutosave();
    final HuiMenu next = from ?? createDefaultMenu();
    final String id = sanitizeMenuId(name ?? huiDefaultMenuId);
    workspace.create(name: id, json: encodeHuiMenu(next));
    _adopt(next, id);
  }

  /// Templates apply as a brand new document.
  void createDocumentFromMenu(String name, HuiMenu template) =>
      newDocument(name: name, from: template);

  bool openDocument(String docId) {
    if (docId == workspace.activeId) return true;
    flushAutosave();
    if (!workspace.switchTo(docId)) return false;
    _adoptActiveDocument();
    return true;
  }

  bool deleteDocument(String docId) {
    final bool wasActive = docId == workspace.activeId;
    if (!workspace.delete(docId)) return false;
    if (wasActive) {
      _documentDirty = false;
      _adoptActiveDocument();
    } else {
      _notify();
    }
    return true;
  }

  /// Writes pending changes immediately. Called by the debounce timer, before a
  /// document switch, and on dispose.
  ///
  /// The notification at the end is load-bearing: the dirty flags and
  /// [lastSavedAt] only change here, and the status bar reads exactly those, so
  /// without it "Saving..." never clears.
  void flushAutosave({bool notify = true}) {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    bool saved = false;
    if (_documentDirty) {
      workspace.updateActive(name: _menuId, json: _snapshot());
      _documentDirty = false;
      saved = true;
    }
    if (_preferencesDirty) {
      _writePreferences();
      _preferencesDirty = false;
      saved = true;
    }
    if (!saved) return;
    _lastSavedAt = DateTime.now();
    if (notify) _notify();
  }

  @override
  void dispose() {
    flushAutosave(notify: false);
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _images?.removeListener(_onImagesChanged);
    _disposed = true;
    super.dispose();
  }

  // --- internals ------------------------------------------------------------

  Set<String> _takenIds() =>
      _menu.components.map((HuiComponent c) => c.id).toSet();

  /// `button-2` duplicates as `button-3` and `slot-1` as `slot-2`: an existing
  /// numeric suffix is incremented, never dropped, because the number is just
  /// as often the author's own naming scheme as it is editor bookkeeping.
  String _duplicateId(String id, Set<String> taken) {
    final RegExpMatch? match = RegExp(r'^(.*)-(\d+)$').firstMatch(id);
    if (match == null) return uniqueComponentId(id, taken);
    final String root = sanitizeComponentId(match.group(1)!);
    final int start = int.tryParse(match.group(2)!) ?? 1;
    for (int i = start + 1; i < start + 100000; i++) {
      final String candidate = '$root-$i';
      if (!taken.contains(candidate)) return candidate;
    }
    return uniqueComponentId(root, taken);
  }

  String _snapshot() => encodeHuiMenu(_menu);

  /// Blocks are authored to two or three decimals; killing float noise keeps
  /// exported JSON and snapshot comparisons stable.
  double _round(double value) =>
      !value.isFinite ? 0 : (value * 10000).roundToDouble() / 10000;

  int _countSeverity(HuiSeverity severity) =>
      _issues.where((HuiIssue issue) => issue.severity == severity).length;

  List<HuiIssue> _validate() => validateHuiMenu(
        _menu,
        knownImagePaths: _images?.paths,
        knownMaterials: _catalogs.loaded ? _catalogs.materialKeys : null,
        knownSounds: _catalogs.loaded ? _catalogs.soundKeys : null,
      );

  /// Text fields and sliders mutate on every keystroke and every pointer move,
  /// so a burst of same-label edits collapses into one step. Without this a
  /// 110-character label would evict the entire 100-entry history and undo
  /// would walk back one character at a time.
  static const Duration _coalesceWindow = Duration(milliseconds: 700);

  void _pushUndo(String label, String before, {bool coalesce = true}) {
    if (_dragActive) {
      if (_dragPushed) return;
      _dragPushed = true;
      _clearCoalesce();
      _undo.push(label, before);
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? last = _coalesceAt;
    if (coalesce &&
        label == _coalesceLabel &&
        last != null &&
        now.difference(last) < _coalesceWindow) {
      _coalesceAt = now;
      return;
    }
    _coalesceLabel = coalesce ? label : null;
    _coalesceAt = coalesce ? now : null;
    _undo.push(label, before);
  }

  /// Any deliberate step boundary starts a fresh entry.
  void _clearCoalesce() {
    _coalesceLabel = null;
    _coalesceAt = null;
  }

  void _afterChange() {
    _issues = _validate();
    _documentDirty = true;
    _scheduleSave();
    _notify();
  }

  bool _applySnapshot(String snapshot) {
    try {
      _menu = decodeHuiMenu(snapshot);
    } on HuiFormatException catch (e) {
      _fail('Could not restore that step: ${e.message}');
      return false;
    }
    _pruneSelection();
    _afterChange();
    return true;
  }

  void _pruneSelection() {
    final String? id = _selectedId;
    if (id != null && _menu.componentById(id) == null) {
      _selectedId = null;
    }
  }

  void _fail(String message) {
    _lastError = message;
    onError?.call(message);
    _notify();
  }

  void _onImagesChanged() {
    _issues = _validate();
    _notify();
  }

  void _scheduleSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, flushAutosave);
  }

  void _savePreference() {
    _preferencesDirty = true;
    _scheduleSave();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _adoptActiveDocument() {
    final WorkspaceDoc? doc = workspace.active;
    if (doc == null) {
      final HuiMenu fresh = createDefaultMenu();
      workspace.create(name: huiDefaultMenuId, json: encodeHuiMenu(fresh));
      _adopt(fresh, huiDefaultMenuId);
      return;
    }
    HuiMenu menu;
    String? failure;
    try {
      menu = decodeHuiMenu(doc.json);
    } on HuiFormatException catch (e) {
      menu = createDefaultMenu();
      failure = 'The saved document "${doc.name}" was unreadable '
          '(${e.message}) and was replaced with a new menu.';
    } catch (_) {
      menu = createDefaultMenu();
      failure = 'The saved document "${doc.name}" was unreadable and was '
          'replaced with a new menu.';
    }
    _adopt(menu, doc.name);
    if (failure != null) {
      _lastError = failure;
      onError?.call(failure);
      _notify();
    }
  }

  void _adopt(HuiMenu menu, String menuId) {
    _menu = menu;
    _menuId = sanitizeMenuId(menuId);
    _selectedId = null;
    _codeError = null;
    _togglePreviewState.clear();
    _clearCoalesce();
    _undo.clear();
    _documentDirty = false;
    _issues = _validate();
    _notify();
  }

  void _loadPreferences() {
    final String? raw = workspace.read(preferencesKey);
    if (raw == null || raw.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    _view = _viewFromName(decoded['view']);
    _previewUiScale = _readDouble(decoded['previewUiScale'], 1, 0.25, 4);
    _gridSize = _readDouble(decoded['gridSize'], 0.05, 0.01, 1);
    _showHitboxes = _readBool(decoded['showHitboxes'], false);
    _showAnchors = _readBool(decoded['showAnchors'], true);
    _showGrid = _readBool(decoded['showGrid'], true);
    _snapToGrid = _readBool(decoded['snapToGrid'], true);
    _trueRender = _readBool(decoded['trueRender'], false);
    _backdrop = _backdropFromName(decoded['backdrop']);
  }

  void _writePreferences() {
    workspace.write(
      preferencesKey,
      jsonEncode(<String, dynamic>{
        'view': _view.name,
        'previewUiScale': _previewUiScale,
        'gridSize': _gridSize,
        'showHitboxes': _showHitboxes,
        'showAnchors': _showAnchors,
        'showGrid': _showGrid,
        'snapToGrid': _snapToGrid,
        'trueRender': _trueRender,
        'backdrop': _backdrop.name,
      }),
    );
  }

  static EditorView _viewFromName(Object? raw) {
    for (final EditorView value in EditorView.values) {
      if (value.name == raw) return value;
    }
    return EditorView.visual;
  }

  static HuiBackdropMode _backdropFromName(Object? raw) {
    for (final HuiBackdropMode value in HuiBackdropMode.values) {
      if (value.name == raw) return value;
    }
    return HuiBackdropMode.image;
  }

  static bool _readBool(Object? raw, bool fallback) =>
      raw is bool ? raw : fallback;

  static double _readDouble(
    Object? raw,
    double fallback,
    double min,
    double max,
  ) {
    if (raw is! num) return fallback;
    final double value = raw.toDouble();
    if (!value.isFinite) return fallback;
    return value.clamp(min, max).toDouble();
  }
}
