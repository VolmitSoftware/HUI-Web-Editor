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
import 'package:web/web.dart' as web;

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

  /// Kind whose tab was last scrolled into view. The strip is centred and only
  /// as wide as the bar can spare, so a mode picked from the palette, the rail
  /// or a document open can land outside the visible run.
  String? _revealedKind;

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

  /// Identity and document on the left, the kind tabs in the middle, and the
  /// action clusters on the right — each a labelled group with a hairline
  /// between it and the next (drawn by `.hui-bar-cluster + .hui-bar-cluster`
  /// in 02-shell.css) so the right-hand run reads as mode / history / file /
  /// assets / app instead of as fifteen identical icons.
  ///
  /// The centre is the kind tabs rather than the view switcher because the two
  /// answer different questions and only one of them is navigation: the tabs
  /// say what you are working on, the switcher how you are looking at it. Both
  /// in the middle came to about 700px of chrome, which is more than the bar
  /// has to give at laptop widths.
  ///
  /// The bar is a three-column grid whose side columns are always the same
  /// width, so the centre column is centred on the viewport rather than on
  /// whatever the two unequal side runs left over. That only works while the
  /// right-hand run fits its column, which is what the give-way ladder in
  /// 02-shell.css buys: as the viewport narrows, whole clusters fold into the
  /// overflow menu of the matching tier ([_overflowMenu]), and below 700px the
  /// tab strip itself folds into [_kindPicker]. Every collapsible surface is
  /// rendered here at every width and chosen by CSS — nothing in this file
  /// measures the viewport.
  Widget _bar() {
    _scheduleKindTabReveal();
    return dom.header(
      classes: 'hui-bar',
      attributes: const <String, String>{'role': 'banner'},
      <Widget>[
        dom.div(classes: 'hui-bar-group hui-bar-left', <Widget>[
          _cluster('Application', 'app', <Widget>[_brand()]),
          // The armed strip names the document it is about to delete, so it
          // stands in for the switcher rather than sitting beside it: two
          // copies of the same name never fit the left column, and the one
          // that mattered — the confirm — was the one that lost the space.
          _cluster('Document', 'doc', <Widget>[
            if (_armedDelete) _deleteStrip() else _documentSwitcher(),
          ]),
        ]),
        dom.div(classes: 'hui-bar-group hui-bar-center', <Widget>[
          _kindTabs(),
          _kindPicker(),
        ]),
        dom.div(classes: 'hui-bar-group hui-bar-right', <Widget>[
          if (_store.hasActiveDocument) ...<Widget>[
            dom.div(
              classes: 'hui-bar-cluster hui-bar-views',
              attributes: const <String, String>{
                'role': 'group',
                'aria-label': 'Editor mode',
              },
              <Widget>[
                ViewSwitcher(
                  view: _store.view,
                  surfaceLabel: _store.docType.surfaceLabel,
                  unavailableReason: _store.unavailableViewReason,
                  onChanged: _intents.setView,
                ),
              ],
            ),
            _viewPicker(),
          ],
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
              hint: 'Dropping a .json file anywhere works too.',
              onPressed: () => _intents.importMenu(),
              disabled: !_store.canTransferDocument,
            ),
            _action(
              icon: ArcaneIcon.download(size: IconSize.sm),
              label: 'Export $_documentNoun JSON',
              shortcut: 'mod+S',
              variant: ButtonVariant.outline,
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
              hint: 'Upload the textures your textImage icons point at.',
              onPressed: _intents.openImages,
            ),
            _action(
              icon: ArcaneIcon.layoutTemplate(size: IconSize.sm),
              label: 'Templates',
              optional: true,
              onPressed: _intents.openTemplates,
            ),
          ]),
          _cluster('Editor', 'editor', <Widget>[
            _action(
              icon: ArcaneIcon.command(size: IconSize.sm),
              label: 'Command palette',
              shortcut: 'mod+K',
              optional: true,
              onPressed: _intents.openPalette,
            ),
            _action(
              icon: ArcaneIcon.circleQuestionMark(size: IconSize.sm),
              label: 'Help',
              optional: true,
              onPressed: _intents.openHelp,
            ),
            _action(
              icon: ArcaneIcon.settings(size: IconSize.sm),
              label: 'Settings',
              optional: true,
              onPressed: _intents.openSettings,
            ),
            _action(
              icon: component.darkMode
                  ? ArcaneIcon.sun(size: IconSize.sm)
                  : ArcaneIcon.moon(size: IconSize.sm),
              label: component.darkMode
                  ? 'Switch to the light theme'
                  : 'Switch to the dark theme',
              onPressed: _intents.toggleTheme,
            ),
          ]),
          _mobilePaneControls(),
          for (int tier = 1; tier <= _overflowTiers; tier++) _overflowMenu(tier),
        ]),
      ],
    );
  }

  Widget _cluster(String label, String slug, List<Widget> children) => dom.div(
    classes: 'hui-bar-cluster hui-bar-$slug',
    attributes: <String, String>{'role': 'group', 'aria-label': label},
    children,
  );

  /// The mode tabs: one per document kind, plus the unscoped All.
  ///
  /// Selecting one scopes the library rail to that kind and points its create
  /// action at it — "scoreboard mode shows all my scoreboards". Registry-driven
  /// like the templates dialog's tabs, so a new kind arrives here with its
  /// adapter and nothing else. Only the active tab carries its label; ten
  /// labelled tabs would own the whole bar.
  Widget _kindTabs() => dom.div(
    classes: 'hui-kind-tabs',
    attributes: const <String, String>{'aria-label': 'Document kinds'},
    <Widget>[
      ArcaneToggleGroup(
        id: 'hui-kind-tabs',
        value: _store.mode?.kind.name ?? _allKindsValue,
        variant: ToggleGroupVariant.outline,
        size: ToggleGroupSize.sm,
        onChanged: _onKindTab,
        items: <ToggleGroupItem>[
          _kindTab(
            value: _allKindsValue,
            label: 'All',
            title: 'Every document in the workspace',
            icon: ArcaneIcon.layoutList(size: IconSize.sm),
          ),
          for (final DocumentTypeAdapter type in DocumentTypeRegistry.tabs)
            _kindTab(
              value: type.kind.name,
              label: type.pluralLabel,
              title: '${type.pluralLabel} only',
              icon: type.tabIcon(),
            ),
        ],
      ),
    ],
  );

  ToggleGroupItem _kindTab({
    required String value,
    required String label,
    required String title,
    required Widget icon,
  }) => ToggleGroupItem(
    value: value,
    child: dom.span(
      classes: 'hui-kind-tab',
      attributes: <String, String>{'title': title},
      <Widget>[
        icon,
        dom.span(classes: 'hui-kind-tab-label', <Widget>[Text(label)]),
      ],
    ),
  );

  /// A null value is the toggle group reporting that the active tab was
  /// clicked again; a mode strip has no "nothing selected" state, so it stays
  /// where it is.
  void _onKindTab(String? value) {
    if (value == null) return;
    if (value == _allKindsValue) {
      _intents.setMode(null);
      return;
    }
    final DocumentTypeAdapter? type = DocumentTypeRegistry.byKindName(value);
    if (type != null) _intents.setMode(type);
  }

  /// The tab strip folded into one control, for the phone bar where eleven
  /// tabs cannot be shown and a scroller three tabs wide is worse than a
  /// menu. It carries its kind's name so the current mode stays visible, which
  /// is the one thing the strip did that a bare icon would lose.
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

  /// The view switcher folded into one control for the narrowest bars, where
  /// four segments plus the pane toggles plus the overflow do not fit. The
  /// trigger is the current view's own icon, so the segmented control and this
  /// read as the same control at two sizes.
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

  /// Keeps the selected tab inside the strip's visible run after a mode change
  /// that did not come from clicking a tab — the palette, the rail's create
  /// action and opening a document all move the mode, and the strip is only as
  /// wide as the centred column can spare.
  void _scheduleKindTabReveal() {
    final String kind = _store.mode?.kind.name ?? _allKindsValue;
    if (_revealedKind == kind) return;
    _revealedKind = kind;
    context.binding.addPostFrameCallback(_revealActiveKindTab);
  }

  void _revealActiveKindTab() {
    try {
      final web.Element? strip = web.document.querySelector('.hui-kind-tabs');
      final web.Element? active = strip?.querySelector(
        '.arcane-toggle-group-item.selected',
      );
      if (strip == null || active == null) return;
      final web.DOMRect stripBox = strip.getBoundingClientRect();
      final web.DOMRect activeBox = active.getBoundingClientRect();
      const double margin = 8;
      final double pastRight = activeBox.right - stripBox.right;
      final double pastLeft = stripBox.left - activeBox.left;
      if (pastRight > 0) {
        strip.scrollLeft = strip.scrollLeft + pastRight + margin;
      } else if (pastLeft > 0) {
        strip.scrollLeft = strip.scrollLeft - pastLeft - margin;
      }
    } catch (_) {
      // A strip that is folded into the picker, or a runtime without a DOM,
      // has nothing to reveal.
    }
  }

  /// One overflow menu per rung of the give-way ladder, all four mounted and
  /// exactly one shown by 02-shell.css. A menu carries precisely the actions
  /// its own tier has taken off the bar and nothing else, which is what keeps
  /// any width from offering two routes to the same command.
  ///
  /// Tier 1 is `≤1740px`, tier 2 `≤1400px`, tier 3 `≤1150px`, tier 4
  /// `≤1024px` — the same four numbers the stylesheet folds the clusters at.
  Widget _overflowMenu(int tier) => dom.div(
    classes: 'hui-bar-cluster hui-bar-overflow is-tier$tier',
    <Widget>[
      BarMenu(
        id: 'hui-bar-more-tier$tier',
        align: BarMenuAlign.right,
        triggerIcon: ArcaneIcon.ellipsis(size: IconSize.sm),
        triggerLabel: 'More actions',
        entries: () => _overflowEntries(tier),
      ),
    ],
  );

  /// Cumulative by construction: every tier carries what the tiers above it
  /// carry plus the cluster its own breakpoint folded. Read top to bottom this
  /// is the give-way order — optional actions first, then Assets and Editor,
  /// then File, and History last because undo is the action a narrow bar is
  /// most likely to need.
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
    if (tier >= 2)
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
        pressed: component.mobileRailOpen,
        onPressed: component.onToggleMobileRail,
      ),
      _mobilePaneAction(
        icon: ArcaneIcon.panelRight(size: IconSize.sm),
        label: component.mobileInspectorOpen
            ? 'Close inspector'
            : 'Open inspector',
        pressed: component.mobileInspectorOpen,
        onPressed: component.onToggleMobileInspector,
      ),
    ],
  );

  Widget _mobilePaneAction({
    required Widget icon,
    required String label,
    required bool pressed,
    required VoidCallback onPressed,
  }) => Button(
    icon: icon,
    variant: pressed ? ButtonVariant.secondary : ButtonVariant.ghost,
    size: ButtonSize.iconSm,
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
    bool disabled = false,
    bool optional = false,
    ButtonVariant variant = ButtonVariant.ghost,
  }) {
    final String? aria = _ariaShortcut(shortcut);
    final Widget button = Button(
      icon: icon,
      variant: variant,
      size: ButtonSize.iconSm,
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
        optional ? 'is-optional' : null,
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
