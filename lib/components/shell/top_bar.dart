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
import '../../l10n/hui_localizations.dart';
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
    required this.activeLocale,
    required this.localeLoading,
    required this.onLocaleChanged,
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
  final String activeLocale;
  final bool localeLoading;
  final ValueChanged<String> onLocaleChanged;
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
      ..write(component.activeLocale)
      ..write('|')
      ..write(component.localeLoading)
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
            _cluster(huiText('Application'), 'app', <Widget>[_brand()]),
            _cluster(huiText('Document'), 'doc', <Widget>[
              if (_armedDelete) _deleteStrip() else _documentSwitcher(),
            ]),
          ]),
          dom.div(classes: 'hui-bar-group hui-bar-right', <Widget>[
            _cluster(huiText('History'), 'history', <Widget>[
              _action(
                icon: ArcaneIcon.undo(size: IconSize.sm),
                label: _store.undoLabel == null
                    ? huiText('Undo')
                    : huiText('Undo {action}', <String, Object?>{
                        'action': _store.undoLabel,
                      }),
                shortcut: 'mod+Z',
                disabled: !_store.canUndo,
                onPressed: _intents.undo,
              ),
              _action(
                icon: ArcaneIcon.redo(size: IconSize.sm),
                label: _store.redoLabel == null
                    ? huiText('Redo')
                    : huiText('Redo {action}', <String, Object?>{
                        'action': _store.redoLabel,
                      }),
                shortcut: 'mod+Shift+Z',
                disabled: !_store.canRedo,
                onPressed: _intents.redo,
              ),
            ]),
            _cluster(huiText('File'), 'file', <Widget>[
              _action(
                icon: ArcaneIcon.upload(size: IconSize.sm),
                label: huiText('Import JSON'),
                visibleLabel: huiText('Import'),
                hint: huiText('Dropping a .json file anywhere works too.'),
                onPressed: () => _intents.importMenu(),
                disabled: !_store.canTransferDocument,
              ),
              _action(
                icon: ArcaneIcon.download(size: IconSize.sm),
                label: huiText('Export {document} JSON', <String, Object?>{
                  'document': _documentNoun,
                }),
                visibleLabel: huiText('Export'),
                shortcut: 'mod+S',
                onPressed: _intents.exportMenu,
                disabled: !_store.canTransferDocument,
              ),
              _action(
                icon: ArcaneIcon.copy(size: IconSize.sm),
                label: huiText('Copy {document} JSON', <String, Object?>{
                  'document': _documentNoun,
                }),
                onPressed: () => _intents.copyJson(),
                disabled: !_store.canTransferDocument,
              ),
            ]),
            _cluster(huiText('Assets'), 'assets', <Widget>[
              _action(
                icon: ArcaneIcon.images(size: IconSize.sm),
                label: huiText('Images'),
                visibleLabel: huiText('Images'),
                hint: huiText(
                  'Upload the textures your textImage icons point at.',
                ),
                onPressed: _intents.openImages,
              ),
            ]),
            for (int tier = 1; tier <= _overflowTiers; tier++)
              _overflowMenu(tier),
            _cluster(huiText('Language'), 'language', <Widget>[
              _languagePicker(),
            ]),
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

  Widget _languagePicker() => BarMenu(
    id: 'hui-language-picker',
    align: BarMenuAlign.right,
    triggerIcon: ArcaneIcon.languages(size: IconSize.sm),
    triggerLabel: component.localeLoading
        ? huiText('Loading language')
        : huiText('Choose language'),
    width: 240,
    entries: _languageItems,
  );

  List<BarMenuEntry> _languageItems() => <BarMenuEntry>[
    BarMenuHeading(huiText('Languages')),
    for (final HuiLocale locale in huiSupportedLocales)
      BarMenuAction(
        label: locale.nativeName,
        icon: locale.code == component.activeLocale
            ? ArcaneIcon.check(size: IconSize.sm)
            : null,
        onSelect: component.localeLoading
            ? null
            : () {
                if (locale.code != component.activeLocale) {
                  component.onLocaleChanged(locale.code);
                }
              },
        attributes: <String, String>{
          'role': 'menuitemradio',
          'aria-checked': (locale.code == component.activeLocale).toString(),
          'lang': locale.htmlLanguage,
          'dir': locale.rightToLeft ? 'rtl' : 'ltr',
          'data-locale': locale.code,
          if (locale.code == component.activeLocale)
            'data-hui-menu-initial': 'true',
          if (locale.code == component.activeLocale) 'aria-current': 'true',
        },
      ),
  ];

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
    attributes: <String, String>{
      'role': 'group',
      'aria-label': huiText('Document kinds'),
    },
    <Widget>[
      BarMenu(
        id: 'hui-kind-picker-menu',
        triggerIcon: _activeKindIcon(),
        triggerText: _activeKindLabel,
        triggerLabel: huiText('Document kind: {kind}', <String, Object?>{
          'kind': _activeKindLabel,
        }),
        width: 220,
        entries: _kindItems,
      ),
    ],
  );

  String get _activeKindLabel => _store.mode?.pluralLabel ?? huiText('All');

  ArcaneGlyph _activeKindIcon() =>
      _store.mode?.tabIcon() ?? ArcaneIcon.layoutList(size: IconSize.sm);

  List<BarMenuEntry> _kindItems() {
    final String active = _store.mode?.kind.name ?? _allKindsValue;
    return <BarMenuEntry>[
      BarMenuHeading(huiText('Document kinds')),
      _kindItem(
        value: _allKindsValue,
        label: huiText('All'),
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
    required ArcaneGlyph icon,
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
    attributes: <String, String>{
      'role': 'group',
      'aria-label': huiText('Editor mode'),
    },
    <Widget>[
      BarMenu(
        id: 'hui-view-picker-menu',
        align: BarMenuAlign.right,
        triggerIcon: ViewSwitcher.iconOf(_store.view),
        triggerText: ViewSwitcher.labelOf(_store.view),
        triggerLabel: huiText('Editor mode: {mode}', <String, Object?>{
          'mode': ViewSwitcher.labelOf(_store.view),
        }),
        width: 200,
        entries: _viewItems,
      ),
    ],
  );

  /// A view the open kind cannot serve stays selectable here for the same
  /// reason it stays clickable in the segmented control: the click is what
  /// reports why.
  List<BarMenuEntry> _viewItems() => <BarMenuEntry>[
    BarMenuHeading(huiText('Editor mode')),
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
          triggerLabel: huiText('More actions'),
          entries: () => _overflowEntries(tier),
        ),
      ]);

  /// Cumulative by construction: every tier carries what the tiers above it
  /// carry plus the cluster its own breakpoint folded. Read top to bottom this
  /// is the give-way order — secondary actions, Assets, File, then History.
  List<BarMenuEntry> _overflowEntries(int tier) => <BarMenuEntry>[
    if (tier >= 4) ...<BarMenuEntry>[
      BarMenuHeading(huiText('History')),
      BarMenuAction(
        label: huiText('Undo'),
        icon: ArcaneIcon.undo(size: IconSize.sm),
        onSelect: _store.canUndo ? _intents.undo : null,
      ),
      BarMenuAction(
        label: huiText('Redo'),
        icon: ArcaneIcon.redo(size: IconSize.sm),
        onSelect: _store.canRedo ? _intents.redo : null,
      ),
      const BarMenuSeparator(),
    ],
    if (tier >= 3) ...<BarMenuEntry>[
      BarMenuHeading(huiText('Document')),
      BarMenuAction(
        label: huiText('Import JSON'),
        icon: ArcaneIcon.upload(size: IconSize.sm),
        onSelect: _store.canTransferDocument
            ? () => _intents.importMenu()
            : null,
      ),
      BarMenuAction(
        label: huiText('Export {document} JSON', <String, Object?>{
          'document': _documentNoun,
        }),
        icon: ArcaneIcon.download(size: IconSize.sm),
        onSelect: _store.canTransferDocument ? _intents.exportMenu : null,
      ),
      BarMenuAction(
        label: huiText('Copy {document} JSON', <String, Object?>{
          'document': _documentNoun,
        }),
        icon: ArcaneIcon.copy(size: IconSize.sm),
        onSelect: _store.canTransferDocument ? () => _intents.copyJson() : null,
      ),
      const BarMenuSeparator(),
    ],
    BarMenuHeading(huiText('Resources')),
    if (tier >= 2)
      BarMenuAction(
        label: huiText('Images'),
        icon: ArcaneIcon.images(size: IconSize.sm),
        onSelect: _intents.openImages,
      ),
    BarMenuAction(
      label: huiText('Templates'),
      icon: ArcaneIcon.layoutTemplate(size: IconSize.sm),
      onSelect: _intents.openTemplates,
    ),
    const BarMenuSeparator(),
    BarMenuHeading(huiText('Editor')),
    BarMenuAction(
      label: huiText('Command palette'),
      icon: ArcaneIcon.command(size: IconSize.sm),
      onSelect: _intents.openPalette,
    ),
    BarMenuAction(
      label: huiText('Help'),
      icon: ArcaneIcon.circleQuestionMark(size: IconSize.sm),
      onSelect: _intents.openHelp,
    ),
    BarMenuAction(
      label: huiText('Settings'),
      icon: ArcaneIcon.settings(size: IconSize.sm),
      onSelect: _intents.openSettings,
    ),
    BarMenuAction(
      label: component.darkMode
          ? huiText('Light theme')
          : huiText('Dark theme'),
      icon: component.darkMode
          ? ArcaneIcon.sun(size: IconSize.sm)
          : ArcaneIcon.moon(size: IconSize.sm),
      onSelect: _intents.toggleTheme,
    ),
  ];

  Widget _mobilePaneControls() => dom.div(
    classes: 'hui-bar-cluster hui-mobile-panes',
    attributes: <String, String>{
      'role': 'group',
      'aria-label': huiText('Workspace panes'),
    },
    <Widget>[
      _mobilePaneAction(
        icon: ArcaneIcon.panelLeft(size: IconSize.sm),
        label: component.mobileRailOpen
            ? huiText('Close library')
            : huiText('Open library'),
        visibleLabel: huiText('Files'),
        pressed: component.mobileRailOpen,
        onPressed: component.onToggleMobileRail,
      ),
      _mobilePaneAction(
        icon: ArcaneIcon.panelRight(size: IconSize.sm),
        label: component.mobileInspectorOpen
            ? huiText('Close inspector')
            : huiText('Open inspector'),
        visibleLabel: huiText('Inspect'),
        pressed: component.mobileInspectorOpen,
        onPressed: component.onToggleMobileInspector,
      ),
    ],
  );

  Widget _mobilePaneAction({
    required ArcaneGlyph icon,
    required String label,
    required String visibleLabel,
    required bool pressed,
    required VoidCallback onPressed,
  }) => Button(
    icon: icon,
    label: visibleLabel,
    variant: pressed ? ButtonVariant.secondary : ButtonVariant.ghost,
    size: ButtonSize.sm,
    onPressed: onPressed,
    attributes: <String, String>{
      'data-hui-responsive-label': 'mobile-pane',
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
        Text(huiText('No document'))
      else if (_store.isPanelDoc)
        Text(_store.workspace.active?.title ?? huiText('Menu flow map'))
      else
        dom.span(classes: 'hui-ltr', <Widget>[
          MutableText(
            _store.menuId,
            onChanged: _store.renameActiveRuntimeId,
            placeholder: 'menu-id',
            variant: MutableTextStyle.dashed,
          ),
        ]),
    ]),
    dom.span(
      classes: _store.isPanelDoc ? 'hui-doc-ext' : 'hui-doc-ext hui-ltr',
      <Widget>[
        if (_store.hasActiveDocument)
          Text(_store.isPanelDoc ? ' · ${huiText('flow map')}' : '.json'),
      ],
    ),
    BarMenu(
      id: 'hui-doc-menu',
      triggerIcon: ArcaneIcon.chevronDown(size: IconSize.sm),
      triggerLabel: huiText('Switch document'),
      align: BarMenuAlign.right,
      width: 260,
      entries: _documentItems,
    ),
  ]);

  List<BarMenuEntry> _documentItems() {
    final Workspace workspace = _store.workspace;
    final List<BarMenuEntry> items = <BarMenuEntry>[
      BarMenuHeading(huiText('Recent documents')),
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
          label: huiText('New menu'),
          icon: ArcaneIcon.filePlus(size: IconSize.sm),
          onSelect: _intents.newDocument,
        ),
      )
      ..add(
        BarMenuAction(
          label: huiText('Delete this document'),
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
          huiText('Delete {name}?', <String, Object?>{
            'name':
                '${_store.workspace.active?.title ?? _store.menuId}${_store.isPanelDoc ? '' : '.json'}',
          }),
        ),
      ]),
      Button.destructive(
        size: ButtonSize.sm,
        icon: ArcaneIcon.check(size: IconSize.sm),
        label: huiText('Delete'),
        onPressed: () {
          setState(() => _armedDelete = false);
          _intents.deleteActiveDocument();
        },
      ),
      Button.ghost(
        size: ButtonSize.sm,
        icon: ArcaneIcon.x(size: IconSize.sm),
        label: huiText('Keep'),
        onPressed: () => setState(() => _armedDelete = false),
      ),
    ],
  );

  Widget _action({
    required ArcaneGlyph icon,
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
