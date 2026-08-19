library;

import 'dart:math' as math;

import 'package:arcane_jaspr/arcane_jaspr.dart'
    show ArcaneIcon, IconSize, Widget;

import '../config/defaults.dart';
import '../config/templates.dart';
import '../logic/canvas_scene.dart';
import '../logic/validation.dart';
import '../model/model.dart';
import '../services/showcase_randomizer.dart';
import '../state/editor_store.dart';
import '../state/workspace.dart';
import 'document_type.dart';

/// The HoloUI menu document: the original four-view editor.
final class MenuDocumentType extends DocumentTypeAdapter {
  const MenuDocumentType();

  @override
  WorkspaceDocKind get kind => WorkspaceDocKind.menu;

  @override
  String get noun => 'menu';

  @override
  String get createLabel => 'New menu';

  @override
  List<EditorView> get availableViews => const <EditorView>[
    EditorView.visual,
    EditorView.preview,
    EditorView.code,
    EditorView.split,
  ];

  @override
  bool get hasRuntimeId => true;

  @override
  bool get transferable => true;

  @override
  bool get undoable => true;

  @override
  bool get sourcePreserving => true;

  @override
  String? get syncWireKind => 'menu';

  @override
  Widget railIcon() => ArcaneIcon.fileBraces(size: IconSize.sm);

  @override
  Widget createIcon() => ArcaneIcon.filePlus(size: IconSize.sm);

  @override
  void createNew(EditorStore store, {String? folderId, String? runtimeId}) =>
      store.newDocument(
        name: 'New menu',
        runtimeId: runtimeId,
        folderId: folderId,
      );

  @override
  AdoptedDocument adopt(WorkspaceDoc doc) {
    final String editorId = sanitizeMenuId(doc.runtimeId!);
    try {
      return AdoptedDocument(
        editorId: editorId,
        model: decodeHuiMenu(doc.json),
        preservedSource: doc.json,
      );
    } on HuiFormatException catch (e) {
      return AdoptedDocument(
        editorId: editorId,
        model: createDefaultMenu(),
        failure:
            'The saved document "${doc.title}" was unreadable '
            '(${e.message}) and was replaced with a new menu.',
      );
    } catch (_) {
      return AdoptedDocument(
        editorId: editorId,
        model: createDefaultMenu(),
        failure:
            'The saved document "${doc.title}" was unreadable and was '
            'replaced with a new menu.',
      );
    }
  }

  @override
  Object decodeSnapshot(String snapshot) => decodeHuiMenu(snapshot);

  @override
  String snapshot(DocumentStateView state) =>
      state.preservedMenuSource ?? encodeHuiMenu(state.menu);

  @override
  String exportJson(DocumentStateView state) => snapshot(state);

  @override
  String formattedJson(DocumentStateView state) => encodeHuiMenu(state.menu);

  @override
  List<HuiIssue> validate(DocumentStateView state) {
    final CanvasScene scene = state.resolveValidationScene();
    return validateHuiMenu(
      state.menu,
      knownImagePaths: state.images?.paths,
      knownMaterials: state.catalogs.loaded
          ? state.catalogs.materialKeys
          : null,
      knownSounds: state.catalogs.loaded ? state.catalogs.soundKeys : null,
      customItems: state.catalogs.customItems,
      overlaps: scene.overlaps,
      emoji: state.workspaceEmoji,
    );
  }

  @override
  MenuRenameRewrite rewriteForMenuRename(
    WorkspaceDoc doc,
    String previous,
    String next,
  ) {
    final HuiMenu menu;
    try {
      menu = decodeHuiMenu(doc.json);
    } catch (_) {
      return MenuRenameRewrite(
        failure:
            'Cannot safely rename while menu "${doc.runtimeId}" is unreadable.',
      );
    }
    final int changed = _rewriteNavigationTargets(menu, previous, next);
    if (changed == 0) return MenuRenameRewrite.none;
    return MenuRenameRewrite(
      json: encodeHuiMenu(menu),
      navigationLinks: changed,
    );
  }

  int _rewriteNavigationTargets(HuiMenu menu, String previous, String next) {
    int changed = 0;
    for (final HuiComponent component in menu.components) {
      final List<List<HuiAction>> branches = switch (component.data) {
        final HuiButtonData button => <List<HuiAction>>[button.actions],
        final HuiToggleData toggle => <List<HuiAction>>[
          toggle.trueActions,
          toggle.falseActions,
        ],
        HuiDecorationData() => const <List<HuiAction>>[],
      };
      for (final List<HuiAction> actions in branches) {
        for (final HuiAction action in actions) {
          if (action is HuiNavigateAction && action.target == previous) {
            action.target = next;
            changed++;
          }
        }
      }
    }
    return changed;
  }

  @override
  String? get templatesTabLabel => 'Menu';

  @override
  String get templatesNote =>
      'Every template is valid as-is: sounds carry a category '
      'and a volume, commands carry a source, and no '
      'template references an image you do not have. It '
      'opens as a new document, so your current one is '
      'untouched.';

  @override
  List<DocumentTemplateSection> get templateSections =>
      <DocumentTemplateSection>[
        DocumentTemplateSection(
          templates: <DocumentTemplate>[
            DocumentTemplate(
              id: 'feature-gallery',
              name: 'Everything showcase',
              description:
                  'A complete editable menu with every component type, all '
                  'six action types, click triggers, custom hitboxes, styled '
                  'icons, resizing, and live placeholders.',
              highlights: const <String>[
                'All component types',
                'All action types',
                'Styles + hitboxes',
              ],
              create: (EditorStore store) => store.createDocumentFromMenu(
                'feature-gallery',
                buildRandomMenuShowcase(store, math.Random(20260819)),
              ),
            ),
            for (final HuiTemplate template in huiTemplates)
              DocumentTemplate(
                id: template.id,
                name: template.name,
                description: template.description,
                highlights: template.highlights,
                create: (EditorStore store) =>
                    store.createDocumentFromMenu(template.id, template.build()),
              ),
          ],
        ),
      ];
}
