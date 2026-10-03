import 'dart:convert';

import 'package:gloss_editor/logic/canvas_scene.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/logic/icon_content.dart';
import 'package:gloss_editor/logic/menu_component_expansion.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:gloss_editor/preview/preview_types.dart';
import 'package:gloss_editor/preview/simulation.dart';
import 'package:gloss_editor/preview/action_log.dart';
import 'package:test/test.dart';

CanvasScene _scene(
  HuiMenu menu, {
  Map<String, Object> values = const <String, Object>{},
}) => buildCanvasScene(
  menu: menu,
  uiScale: 2,
  trueRender: true,
  togglePreview: (String id) => true,
  textCache: McTextCache(),
  expressionSamples: GlossTextExpressionSamples(values: values),
);

void main() {
  test(
    'list layout honors page, cap, flow and authoring identity without changing exported data',
    () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent(
            'stock',
            Vec3(1, 2, 0),
            HuiListData(
              variable: 'entry',
              source: "['Oak', 'Birch', 'Spruce', 'Cherry']",
              pageSize: 3,
              flow: <String, Object?>{
                'columns': 2,
                'spacingX': 1.5,
                'spacingY': 0.75,
              },
              template: HuiDecorationData(HuiTextIcon('&a{{entry}}')),
            ),
          ),
        ],
      );
      final String before = jsonEncode(menu.toJson());
      final List<ExpandedMenuComponent> expanded = expandMenuComponents(
        menu.components,
        maxListEntries: 2,
      );
      expect(
        expanded.map((ExpandedMenuComponent value) => value.component.id),
        <String>['stock[0]', 'stock[1]'],
      );
      expect(expanded.last.component.offset.x, 2.5);
      final CanvasScene scene = _scene(menu);
      expect(scene.items.length, 3);
      expect(
        scene.items.map((CanvasItem item) => item.text!.plainLines.single),
        <String>['Oak', 'Birch', 'Spruce'],
      );
      expect(
        scene.items
            .map(
              (CanvasItem item) => spriteCacheKey(
                item,
                pxPerBlock: 64,
                uiScale: 2,
                obfuscationTick: 0,
              ),
            )
            .toSet()
            .length,
        3,
      );
      expect(scene.items.last.anchor.y, 2.5);
      expect(
        scene.items.every((CanvasItem value) => value.selectionId == 'stock'),
        isTrue,
      );
      expect(jsonEncode(menu.toJson()), before);
    },
  );

  test('list click actions resolve each entry independently', () {
    final HuiMenu menu = HuiMenu(
      components: <HuiComponent>[
        HuiComponent(
          'stock',
          Vec3.zero(),
          HuiListData(
            variable: 'entry',
            source: "['Oak', 'Birch']",
            template: HuiButtonData(0, <HuiAction>[
              HuiCommandAction('buy {{entry}}', 'player'),
            ], HuiTextIcon('{{entry}}')),
          ),
        ),
      ],
    );
    final PreviewSimulation simulation = PreviewSimulation(
      menu: menu,
      openFeet: PVec3.zero,
    );
    expect(
      (simulation.click(componentId: 'stock[0]').single.actions.single
              as LoggedCommand)
          .command,
      'buy Oak',
    );
    expect(
      (simulation.click(componentId: 'stock[1]').single.actions.single
              as LoggedCommand)
          .command,
      'buy Birch',
    );
  });

  test(
    'tabs draw independent labels at centered offsets and retain authoring selection',
    () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent(
            'pages',
            Vec3.zero(),
            HuiTabsData(
              variable: 'page',
              spacing: 2,
              tabs: <HuiTab>[
                HuiTab(id: 'shop', label: '&aShop'),
                HuiTab(id: 'help', label: '&bHelp'),
              ],
            ),
          ),
        ],
      );
      final CanvasScene scene = _scene(menu);
      expect(scene.items.map((CanvasItem value) => value.id), <String>[
        'pages#0',
        'pages#1',
      ]);
      expect(scene.items.map((CanvasItem value) => value.anchor.x), <double>[
        -2,
        2,
      ]);
      expect(
        scene.items.map((CanvasItem value) => value.text!.plainLines.single),
        <String>['Shop', 'Help'],
      );
      expect(scene.items.every((CanvasItem value) => value.clickable), isTrue);
      expect(scene.byId('pages'), isNotNull);
    },
  );

  test(
    'slider clicks clamp, reverse and multiply steps and update rendered expressions',
    () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent(
            'amount',
            Vec3.zero(),
            HuiSliderData(
              variable: 'amount',
              min: 0,
              max: 10,
              step: 2,
              width: 3,
              label: "&aAmount {{session.amount}}",
            ),
          ),
        ],
      )..extras['vars'] = <String, Object?>{'amount': '1'};
      final PreviewSimulation simulation = PreviewSimulation(
        menu: menu,
        openFeet: PVec3.zero,
      );
      simulation.click(componentId: 'amount');
      expect(simulation.sessionValues['session.amount'], 3);
      simulation.click(componentId: 'amount', trigger: 'shift_left_click');
      expect(simulation.sessionValues['session.amount'], 10);
      simulation.click(componentId: 'amount', trigger: 'right_click');
      expect(simulation.sessionValues['session.amount'], 8);
      final CanvasItem item = _scene(
        menu,
        values: simulation.sessionValues,
      ).items.single;
      expect(item.text!.plainLines.single, 'Amount 8');
      expect(item.hitbox.w, 6);
      final CanvasItem initial = _scene(menu).items.single;
      expect(
        spriteCacheKey(item, pxPerBlock: 64, uiScale: 2, obfuscationTick: 0),
        isNot(
          spriteCacheKey(
            initial,
            pxPerBlock: 64,
            uiScale: 2,
            obfuscationTick: 0,
          ),
        ),
      );
    },
  );

  test(
    'tabs and field input write local state without mutating authored values',
    () {
      final HuiMenu menu = HuiMenu(
        components: <HuiComponent>[
          HuiComponent(
            'pages',
            Vec3.zero(),
            HuiTabsData(
              variable: 'page',
              tabs: <HuiTab>[
                HuiTab(id: 'shop'),
                HuiTab(id: 'help'),
              ],
            ),
          ),
          HuiComponent(
            'name',
            Vec3(0, -1, 0),
            HuiFieldData(
              variable: 'name',
              initial: 'Builder',
              prompt: 'anvil',
              label: '&bName',
            ),
          ),
        ],
      );
      final String before = jsonEncode(menu.toJson());
      final PreviewSimulation simulation = PreviewSimulation(
        menu: menu,
        openFeet: PVec3.zero,
      );
      simulation.click(componentId: 'pages#1');
      expect(simulation.sessionValues['session.page'], 'help');
      simulation.click(componentId: 'name');
      expect(simulation.pendingField?.prompt, 'anvil');
      expect(simulation.fieldInitial, 'Builder');
      simulation.answerField('Trader');
      expect(simulation.sessionValues['session.name'], 'Trader');
      expect(simulation.pendingField, isNull);
      simulation.click(componentId: 'name');
      expect(simulation.fieldInitial, 'Trader');
      simulation.cancelField();
      expect(jsonEncode(menu.toJson()), before);
    },
  );
}
