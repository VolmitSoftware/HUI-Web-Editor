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
      // The switcher's item set is a function of the document kind, so the bar
      // has to rebuild when the kind changes even if nothing else did.
      ..write(_store.docKind.name)
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

  /// Four clusters, each a labelled group with a hairline between it and the
  /// next (drawn by `.hui-bar-cluster + .hui-bar-cluster` in 02-shell.css) so
  /// the right-hand run reads as history / file / assets / app instead of as
  /// eleven identical icons.
  Widget _bar() => dom.header(
    classes: 'hui-bar',
    attributes: const <String, String>{'role': 'banner'},
    <Widget>[
      dom.div(classes: 'hui-bar-group hui-bar-left', <Widget>[
        _cluster('Application', <Widget>[_brand()]),
        _cluster('Document', <Widget>[
          _documentSwitcher(),
          if (_armedDelete) _deleteStrip(),
        ]),
      ]),
      dom.div(classes: 'hui-bar-group hui-bar-center', <Widget>[
        if (_store.hasActiveDocument)
          ViewSwitcher(
            view: _store.view,
            views: _store.availableViews,
            onChanged: _intents.setView,
          ),
      ]),
      dom.div(classes: 'hui-bar-group hui-bar-right', <Widget>[
        _cluster('History', <Widget>[
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
        _cluster('File', <Widget>[
          _action(
            icon: ArcaneIcon.upload(size: IconSize.sm),
            label: 'Import $_documentNoun JSON',
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
        _cluster('Assets', <Widget>[
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
        _cluster('Editor', <Widget>[
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
        _overflow(),
      ]),
    ],
  );

  Widget _cluster(String label, List<Widget> children) => dom.div(
    classes: 'hui-bar-cluster',
    attributes: <String, String>{'role': 'group', 'aria-label': label},
    children,
  );

  /// The `is-optional` actions, reachable once the bar is too narrow to show
  /// them. Both forms are always in the markup and the stylesheet swaps which
  /// one is visible — measuring the bar in Dart would cost a layout read per
  /// resize, and wrapping the bar is what made it two rows tall.
  Widget _overflow() =>
      dom.div(classes: 'hui-bar-cluster hui-bar-overflow', <Widget>[
        BarMenu(
          id: 'hui-bar-more',
          align: BarMenuAlign.right,
          triggerIcon: ArcaneIcon.ellipsis(size: IconSize.sm),
          triggerLabel: 'More actions',
          entries: () => <BarMenuEntry>[
            const BarMenuHeading('Document'),
            BarMenuAction(
              label: 'Import $_documentNoun JSON',
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
              onSelect: _store.canTransferDocument
                  ? () => _intents.copyJson()
                  : null,
            ),
            if (component.syncControls != null)
              BarMenuAction(
                label: component.syncControls!.publishLabel,
                icon: ArcaneIcon.cloudUpload(size: IconSize.sm),
                onSelect: component.syncControls!.canPublish
                    ? component.syncControls!.onPublish
                    : null,
              ),
            const BarMenuSeparator(),
            const BarMenuHeading('Resources'),
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
          ],
        ),
      ]);

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
