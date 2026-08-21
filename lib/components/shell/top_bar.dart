/// Glass top bar: identity, document switching, view switching and every
/// global action.
///
/// Rebuilds are narrowed to a signature of the values it actually renders, so
/// canvas drags (which notify the store on every pointer move) do not re-render
/// the bar.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/component/input/mutable_text_types.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Listenable;

import '../../doctype/doctype.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../common/class_names.dart';
import 'bar_menu.dart';
import 'editor_sync_bar.dart';
import 'shell_intents.dart';
import 'shell_keys.dart';
import 'store_selector.dart';
import 'view_switcher.dart';

class TopBar extends StatefulWidget {
  const TopBar({
    required this.intents,
    required this.mobileRailOpen,
    required this.mobileInspectorOpen,
    required this.onToggleMobileRail,
    required this.onToggleMobileInspector,
    this.syncControls,
    this.apple = false,
    this.darkMode = true,
    super.key,
  });

  final ShellIntents intents;
  final bool mobileRailOpen;
  final bool mobileInspectorOpen;
  final VoidCallback onToggleMobileRail;
  final VoidCallback onToggleMobileInspector;
  final EditorSyncControls? syncControls;
  final bool apple;
  final bool darkMode;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  bool _armedDelete = false;
  Listenable? _sources;

  EditorStore get _store => component.intents.store;

  ShellIntents get _intents => component.intents;

  /// Cached: a fresh merged listenable on every build would re-subscribe the
  /// selector each time.
  Listenable get _listenable =>
      _sources ??= Listenable.merge(<Listenable?>[_store, _store.workspace]);

  @override
  void didUpdateComponent(covariant TopBar oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.intents.store, component.intents.store)) {
      _sources = null;
    }
  }

  String _signature() {
    final Workspace workspace = _store.workspace;
    final StringBuffer buffer = StringBuffer()
      ..write(_store.menuId)
      ..write('|')
      ..write(_store.view.name)
      ..write('|')
      // The switcher's disabled entries and the visual mode's label are both
      // functions of the document kind, so the bar has to rebuild when the
      // kind changes even if nothing else did.
      ..write(_store.docKind.name)
      ..write('|')
      // The mode tabs are the other half of the bar's identity.
      ..write(_store.mode?.kind.name)
      ..write('|')
      ..write(_store.canUndo)
      ..write(_store.canRedo)
      ..write('|')
      ..write(_store.undoLabel)
      ..write('|')
      ..write(_store.redoLabel)
      ..write('|')
      ..write(component.syncControls?.status.name)
      ..write('|')
      ..write(component.syncControls?.subjectId)
      ..write('|')
      ..write(component.syncControls?.busy)
      ..write('|')
      ..write(component.syncControls?.message)
      ..write('|')
      ..write(workspace.activeId);
    for (final WorkspaceDoc doc in workspace.recent) {
      buffer
        ..write('|')
        ..write(doc.id)
        ..write(':')
        ..write(doc.title)
        ..write(':')
        ..write(doc.runtimeId)
        ..write(':')
        ..write(doc.kind.name);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) => StoreSelector<String>(
    listenable: _listenable,
    selector: _signature,
    builder: (BuildContext context, String signature) => _bar(),
  );

  /// Identity and document actions occupy the command row. Document kind and
  /// editor mode occupy the navigation row below it, matching the compact
  /// selector chrome used by desktop IDEs. The breakpoint ladder folds whole
  /// action groups into [_overflowMenu] without measuring the viewport in Dart.
  Widget _bar() {
    return dom.header(
      classes: 'hui-bar',
      attributes: const <String, String>{'role': 'banner'},
      <Widget>[
        dom.div(classes: 'hui-bar-primary', <Widget>[
          dom.div(classes: 'hui-bar-group hui-bar-left', <Widget>[
            _cluster('Application', 'app', <Widget>[_brand()]),
            _cluster('Document', 'doc', <Widget>[
              if (_armedDelete) _deleteStrip() else _documentSwitcher(),
            ]),
          ]),
          dom.div(classes: 'hui-bar-group hui-bar-right', <Widget>[
            _cluster('History', 'history', <Widget>[
              _action(
                icon: ArcaneIcon.undo(size: IconSize.sm),
                label: _store.undoLabel == null
                    ? 'Undo'
                    : 'Undo ${_store.undoLabel}',
                shortcut: 'mod+Z',
                disabled: !_store.canUndo,
                onPressed: _intents.undo,
              ),
              _action(
                icon: ArcaneIcon.redo(size: IconSize.sm),
                label: _store.redoLabel == null
                    ? 'Redo'
                    : 'Redo ${_store.redoLabel}',
                shortcut: 'mod+Shift+Z',
                disabled: !_store.canRedo,
                onPressed: _intents.redo,
              ),
            ]),
            _cluster('File', 'file', <Widget>[
              _action(
                icon: ArcaneIcon.upload(size: IconSize.sm),
                label: 'Import JSON',
                visibleLabel: 'Import',
                hint: 'Dropping a .json file anywhere works too.',
                onPressed: () => _intents.importMenu(),
                disabled: !_store.canTransferDocument,
              ),
              _action(
                icon: ArcaneIcon.download(size: IconSize.sm),
                label: 'Export $_documentNoun JSON',
                visibleLabel: 'Export',
                shortcut: 'mod+S',
                onPressed: _intents.exportMenu,
                disabled: !_store.canTransferDocument,
              ),
              _action(
                icon: ArcaneIcon.copy(size: IconSize.sm),
                label: 'Copy $_documentNoun JSON',
                onPressed: () => _intents.copyJson(),
                disabled: !_store.canTransferDocument,
              ),
            ]),
            _cluster('Assets', 'assets', <Widget>[
              _action(
                icon: ArcaneIcon.images(size: IconSize.sm),
                label: 'Images',
                visibleLabel: 'Images',
                hint: 'Upload the textures your textImage icons point at.',
                onPressed: _intents.openImages,
              ),
            ]),
            for (int tier = 1; tier <= _overflowTiers; tier++)
              _overflowMenu(tier),
          ]),
        ]),
        dom.div(classes: 'hui-bar-context', <Widget>[
          dom.div(classes: 'hui-bar-group hui-bar-center', <Widget>[
            _kindPicker(),
          ]),
          dom.div(classes: 'hui-bar-group hui-bar-context-tools', <Widget>[
            if (_store.hasActiveDocument) ...<Widget>[_viewPicker()],
            _mobilePaneControls(),
          ]),
        ]),
      ],
    );
  }

  Widget _cluster(String label, String slug, List<Widget> children) => dom.div(
    classes: 'hui-bar-cluster hui-bar-$slug',
    attributes: <String, String>{'role': 'group', 'aria-label': label},
    children,
  );

  /// A null value has no meaning for the picker, so the active kind stays put.
  void _onKindTab(String? value) {
    if (value == null) return;
    if (value == _allKindsValue) {
      _intents.setMode(null);
      return;
    }
    final DocumentTypeAdapter? type = DocumentTypeRegistry.byKindName(value);
    if (type != null) _intents.setMode(type);
  }

  /// A permanent compact selector keeps the current kind visible without an
  /// icon wall or a horizontally scrollable run of tabs.
  Widget _kindPicker() => dom.div(
    classes: 'hui-bar-cluster hui-kind-picker',
    attributes: const <String, String>{
      'role': 'group',
      'aria-label': 'Document kinds',
    },
    <Widget>[
      BarMenu(
        id: 'hui-kind-picker-menu',
        triggerIcon: _activeKindIcon(),
        triggerText: _activeKindLabel,
        triggerTrailing: ArcaneIcon.chevronDown(size: IconSize.sm),
        triggerLabel: 'Document kind: $_activeKindLabel',
        width: 220,
        entries: _kindItems,
      ),
    ],
  );

  String get _activeKindLabel => _store.mode?.pluralLabel ?? 'All';

  Widget _activeKindIcon() =>
      _store.mode?.tabIcon() ?? ArcaneIcon.layoutList(size: IconSize.sm);

  List<BarMenuEntry> _kindItems() {
    final String active = _store.mode?.kind.name ?? _allKindsValue;
    return <BarMenuEntry>[
      const BarMenuHeading('Document kinds'),
      _kindItem(
        value: _allKindsValue,
        label: 'All',
        icon: ArcaneIcon.layoutList(size: IconSize.sm),
        active: active == _allKindsValue,
      ),
      for (final DocumentTypeAdapter type in DocumentTypeRegistry.tabs)
        _kindItem(
          value: type.kind.name,
          label: type.pluralLabel,
          icon: type.tabIcon(),
          active: active == type.kind.name,
        ),
    ];
  }

  /// The active row is disabled rather than absent, the same way the document
  /// switcher marks the open document: a picker that drops its current value
  /// makes the list a different length every time it opens.
  BarMenuEntry _kindItem({
    required String value,
    required String label,
    required Widget icon,
    required bool active,
  }) => BarMenuAction(
    label: label,
    icon: active ? ArcaneIcon.check(size: IconSize.sm) : icon,
    onSelect: active ? null : () => _onKindTab(value),
  );

  /// The view selector mirrors the kind selector and keeps its current state
  /// visible at every width.
  Widget _viewPicker() => dom.div(
    classes: 'hui-bar-cluster hui-bar-view-picker',
    attributes: const <String, String>{
      'role': 'group',
      'aria-label': 'Editor mode',
    },
    <Widget>[
      BarMenu(
        id: 'hui-view-picker-menu',
        align: BarMenuAlign.right,
        triggerIcon: ViewSwitcher.iconOf(_store.view),
        triggerText: ViewSwitcher.labelOf(_store.view),
        triggerTrailing: ArcaneIcon.chevronDown(size: IconSize.sm),
        triggerLabel: 'Editor mode: ${ViewSwitcher.labelOf(_store.view)}',
        width: 200,
        entries: _viewItems,
      ),
    ],
  );

  /// A view the open kind cannot serve stays selectable here for the same
  /// reason it stays clickable in the segmented control: the click is what
  /// reports why.
  List<BarMenuEntry> _viewItems() => <BarMenuEntry>[
    const BarMenuHeading('Editor mode'),
    for (final EditorView value in EditorView.values)
      BarMenuAction(
        label: ViewSwitcher.labelOf(value),
        icon: value == _store.view
            ? ArcaneIcon.check(size: IconSize.sm)
            : ViewSwitcher.iconOf(value),
        onSelect: () => _intents.setView(value),
      ),
  ];

  /// One overflow menu per rung of the give-way ladder, all four mounted and
  /// exactly one shown by 02-shell.css. Tier 1 is always present for secondary
  /// commands; narrower tiers add the clusters removed at their breakpoint.
  ///
  /// Tier 2 is `≤1400px`, tier 3 `≤1150px`, and tier 4 `≤1024px` — the same
  /// numbers the stylesheet folds the clusters at.
  Widget _overflowMenu(int tier) => dom
      .div(classes: 'hui-bar-cluster hui-bar-overflow is-tier$tier', <Widget>[
        BarMenu(
          id: 'hui-bar-more-tier$tier',
          align: BarMenuAlign.right,
          triggerIcon: ArcaneIcon.ellipsis(size: IconSize.sm),
          triggerLabel: 'More actions',
          entries: () => _overflowEntries(tier),
        ),
      ]);

  /// Cumulative by construction: every tier carries what the tiers above it
  /// carry plus the cluster its own breakpoint folded. Read top to bottom this
  /// is the give-way order — secondary actions, Assets, File, then History.
  List<BarMenuEntry> _overflowEntries(int tier) => <BarMenuEntry>[
    if (tier >= 4) ...<BarMenuEntry>[
      const BarMenuHeading('History'),
      BarMenuAction(
        label: 'Undo',
        icon: ArcaneIcon.undo(size: IconSize.sm),
        onSelect: _store.canUndo ? _intents.undo : null,
      ),
      BarMenuAction(
        label: 'Redo',
        icon: ArcaneIcon.redo(size: IconSize.sm),
        onSelect: _store.canRedo ? _intents.redo : null,
      ),
      const BarMenuSeparator(),
    ],
    if (tier >= 3) ...<BarMenuEntry>[
      const BarMenuHeading('Document'),
      BarMenuAction(
        label: 'Import JSON',
        icon: ArcaneIcon.upload(size: IconSize.sm),
        onSelect: _store.canTransferDocument
            ? () => _intents.importMenu()
            : null,
      ),
      BarMenuAction(
        label: 'Export $_documentNoun JSON',
        icon: ArcaneIcon.download(size: IconSize.sm),
        onSelect: _store.canTransferDocument ? _intents.exportMenu : null,
      ),
      BarMenuAction(
        label: 'Copy $_documentNoun JSON',
        icon: ArcaneIcon.copy(size: IconSize.sm),
        onSelect: _store.canTransferDocument ? () => _intents.copyJson() : null,
      ),
      const BarMenuSeparator(),
    ],
    const BarMenuHeading('Resources'),
    if (tier >= 2)
      BarMenuAction(
        label: 'Images',
        icon: ArcaneIcon.images(size: IconSize.sm),
        onSelect: _intents.openImages,
      ),
    BarMenuAction(
      label: 'Templates',
      icon: ArcaneIcon.layoutTemplate(size: IconSize.sm),
      onSelect: _intents.openTemplates,
    ),
    const BarMenuSeparator(),
    const BarMenuHeading('Editor'),
    BarMenuAction(
      label: 'Command palette',
      icon: ArcaneIcon.command(size: IconSize.sm),
      onSelect: _intents.openPalette,
    ),
    BarMenuAction(
      label: 'Help',
      icon: ArcaneIcon.circleQuestionMark(size: IconSize.sm),
      onSelect: _intents.openHelp,
    ),
    BarMenuAction(
      label: 'Settings',
      icon: ArcaneIcon.settings(size: IconSize.sm),
      onSelect: _intents.openSettings,
    ),
    BarMenuAction(
      label: component.darkMode ? 'Light theme' : 'Dark theme',
      icon: component.darkMode
          ? ArcaneIcon.sun(size: IconSize.sm)
          : ArcaneIcon.moon(size: IconSize.sm),
      onSelect: _intents.toggleTheme,
    ),
  ];

  Widget _mobilePaneControls() => dom.div(
    classes: 'hui-bar-cluster hui-mobile-panes',
    attributes: const <String, String>{
      'role': 'group',
      'aria-label': 'Workspace panes',
    },
    <Widget>[
      _mobilePaneAction(
        icon: ArcaneIcon.panelLeft(size: IconSize.sm),
        label: component.mobileRailOpen ? 'Close library' : 'Open library',
        visibleLabel: 'Files',
        pressed: component.mobileRailOpen,
        onPressed: component.onToggleMobileRail,
      ),
      _mobilePaneAction(
        icon: ArcaneIcon.panelRight(size: IconSize.sm),
        label: component.mobileInspectorOpen
            ? 'Close inspector'
            : 'Open inspector',
        visibleLabel: 'Inspect',
        pressed: component.mobileInspectorOpen,
        onPressed: component.onToggleMobileInspector,
      ),
    ],
  );

  Widget _mobilePaneAction({
    required Widget icon,
    required String label,
    required String visibleLabel,
    required bool pressed,
    required VoidCallback onPressed,
  }) => Button(
    icon: icon,
    child: dom.span(classes: 'hui-mobile-pane-label', <Widget>[
      Text(visibleLabel),
    ]),
    variant: pressed ? ButtonVariant.secondary : ButtonVariant.ghost,
    size: ButtonSize.sm,
    onPressed: onPressed,
    attributes: <String, String>{
      'aria-label': label,
      'aria-pressed': '$pressed',
    },
  );

  String get _documentNoun => _store.docType.noun;

  Widget _brand() => const dom.div(classes: 'hui-brand', <Widget>[
    dom.img(
      src: 'assets/brand/logo.png',
      alt: '',
      classes: 'hui-brand-mark',
      attributes: <String, String>{'aria-hidden': 'true'},
    ),
    dom.span(classes: 'hui-brand-word', <Widget>[Text('Gloss')]),
  ]);

  Widget _documentSwitcher() => dom.div(classes: 'hui-doc', <Widget>[
    dom.span(classes: 'hui-doc-id', <Widget>[
      if (!_store.hasActiveDocument)
        const Text('No document')
      else if (_store.isPanelDoc)
        Text(_store.workspace.active?.title ?? 'Menu flow map')
      else
        MutableText(
          _store.menuId,
          onChanged: _store.renameActiveRuntimeId,
          placeholder: 'menu-id',
          variant: MutableTextStyle.dashed,
        ),
    ]),
    dom.span(classes: 'hui-doc-ext', <Widget>[
      if (_store.hasActiveDocument)
        Text(_store.isPanelDoc ? ' · flow map' : '.json'),
    ]),
    BarMenu(
      id: 'hui-doc-menu',
      triggerIcon: ArcaneIcon.chevronDown(size: IconSize.sm),
      triggerLabel: 'Switch document',
      align: BarMenuAlign.right,
      width: 260,
      entries: _documentItems,
    ),
  ]);

  List<BarMenuEntry> _documentItems() {
    final Workspace workspace = _store.workspace;
    final List<BarMenuEntry> items = <BarMenuEntry>[
      const BarMenuHeading('Recent documents'),
    ];
    for (final WorkspaceDoc doc in workspace.recent) {
      final bool active = doc.id == workspace.activeId;
      items.add(
        BarMenuAction(
          label: _documentLabel(doc),
          icon: active ? ArcaneIcon.check(size: IconSize.sm) : null,
          onSelect: active ? null : () => _intents.openDocument(doc.id),
        ),
      );
    }
    items
      ..add(const BarMenuSeparator())
      ..add(
        BarMenuAction(
          label: 'New menu',
          icon: ArcaneIcon.filePlus(size: IconSize.sm),
          onSelect: _intents.newDocument,
        ),
      )
      ..add(
        BarMenuAction(
          label: 'Delete this document',
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          destructive: true,
          onSelect: _store.hasActiveDocument
              ? () => setState(() => _armedDelete = true)
              : null,
        ),
      );
    return items;
  }

  String _documentLabel(WorkspaceDoc doc) {
    final String? runtimeId = doc.runtimeId;
    if (runtimeId == null || runtimeId == doc.title) return doc.title;
    return '${doc.title} · $runtimeId';
  }

  /// Two-step destructive control: the menu arms it, the bar confirms it. A
  /// modal would be heavier than the action deserves.
  Widget _deleteStrip() => dom.div(
    classes: 'hui-armed',
    attributes: const <String, String>{'role': 'alert'},
    <Widget>[
      dom.span(<Widget>[
        Text(
          'Delete ${_store.workspace.active?.title ?? _store.menuId}${_store.isPanelDoc ? '' : '.json'}?',
        ),
      ]),
      Button.destructive(
        size: ButtonSize.sm,
        icon: ArcaneIcon.check(size: IconSize.sm),
        label: 'Delete',
        onPressed: () {
          setState(() => _armedDelete = false);
          _intents.deleteActiveDocument();
        },
      ),
      Button.ghost(
        size: ButtonSize.sm,
        icon: ArcaneIcon.x(size: IconSize.sm),
        label: 'Keep',
        onPressed: () => setState(() => _armedDelete = false),
      ),
    ],
  );

  Widget _action({
    required Widget icon,
    required String label,
    required void Function() onPressed,
    String? shortcut,
    String? hint,
    String? visibleLabel,
    bool disabled = false,
  }) {
    final String? aria = _ariaShortcut(shortcut);
    final Widget button = Button(
      icon: icon,
      label: visibleLabel,
      variant: ButtonVariant.ghost,
      size: visibleLabel == null ? ButtonSize.iconSm : ButtonSize.sm,
      disabled: disabled,
      onPressed: onPressed,
      attributes: <String, String>{
        'aria-label': label,
        'aria-keyshortcuts': ?aria,
      },
    );
    return dom.span(
      classes: classNames(<String?>[
        'hui-bar-action',
        visibleLabel == null ? null : 'has-label',
      ]),
      <Widget>[
        ArcaneTooltip.custom(
          position: FloatingPosition.bottom,
          content: dom.div(classes: 'hui-tip', <Widget>[
            dom.div(classes: 'hui-tip-head', <Widget>[
              dom.span(<Widget>[Text(label)]),
              if (shortcut != null)
                ArcaneKbd.combo(
                  shortcutKeys(shortcut, apple: component.apple),
                  size: ComponentSize.sm,
                ),
            ]),
            if (hint != null)
              dom.p(classes: 'hui-tip-hint', <Widget>[Text(hint)]),
          ]),
          child: button,
        ),
      ],
    );
  }

  /// `mod+Shift+Z` advertises as both platform chords, which is what screen
  /// readers expect from `aria-keyshortcuts`.
  String? _ariaShortcut(String? spec) {
    if (spec == null) return null;
    final List<String> parts = spec.split('+');
    if (!parts.first.toLowerCase().contains('mod')) {
      return parts.map(_ariaToken).join('+');
    }
    final String tail = parts.skip(1).map(_ariaToken).join('+');
    return 'Meta+$tail Control+$tail';
  }

  String _ariaToken(String token) =>
      token.length == 1 ? token.toUpperCase() : token;
}

/// Tab value of the unscoped mode. Not a kind name, and it cannot collide with
/// one: every kind slug is a lowercase enum name.
const String _allKindsValue = '__all__';

/// Rungs of the give-way ladder, and so the number of overflow menus the bar
/// mounts. Paired one-for-one with the `.hui-bar-overflow.is-tierN` rules in
/// 02-shell.css; changing it here without changing them there leaves a tier
/// with no menu.
const int _overflowTiers = 4;
