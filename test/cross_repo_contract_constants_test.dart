/// Drift guards for the Gloss constants this editor hand-ports.
///
/// Enum spellings, the custom-item provider order, the icon-style clamp table
/// and the icon geometry are typed out again in Dart because the editor is a
/// separate program, not because anyone wants two copies. Nothing here
/// generates code: each test lifts the value back out of the Java source in
/// `../Gloss` (or `GLOSS_REPOSITORY`) and asserts the Dart mirror still says
/// the same thing, naming the drifted member when it does not.
///
/// Gloss is the truth repo. A failure means the Dart side is refreshed from
/// the Java side, never the reverse.
library;

import 'dart:io';

import 'package:gloss_editor/logic/bubble_stack_math.dart';
import 'package:gloss_editor/logic/hui_geometry.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

import 'support/java_source.dart';

const String _enumPackage = 'src/main/java/art/arcane/gloss/enums';
const String _iconPackage = 'src/main/java/art/arcane/gloss/config/icon';
const String _menuIconPackage = 'src/main/java/art/arcane/gloss/menu/icon';

/// Java float/double literals are re-parsed here as decimal text, so an exact
/// match is expected; the tolerance only absorbs the arithmetic in expressions
/// like `2 * NAMETAG_SIZE - TEXT_DISPLAY_BASELINE`.
const double _epsilon = 1e-9;

String _refresh(String dartFile, String javaFile) =>
    'refresh $dartFile from $javaFile — Gloss is the truth repo, so the Java '
    'side is never edited to make this pass';

void main() {
  group('enum spellings match the Gloss enums', () {
    test('MenuIconType covers every authorable icon type', () {
      final Map<String, String> java = javaEnumConstants(
        readGlossJava('$_enumPackage/MenuIconType.java'),
      );
      expect(
        java['ITEM_STACK'],
        'itemStack',
        reason:
            'ITEM_STACK is the API-only member huiIconTypes deliberately '
            'omits; if it gained a data class it becomes authorable',
      );
      final Set<String> authorable = java.entries
          .where((MapEntry<String, String> entry) => entry.key != 'ITEM_STACK')
          .map((MapEntry<String, String> entry) => entry.value)
          .toSet();
      // Declaration order is not the editor's order here: huiIconTypes is the
      // authoring list, MenuIconType is the Gson dispatch table.
      expect(
        huiIconTypes.toSet(),
        authorable,
        reason: _refresh('lib/model/hui_icons.dart', 'MenuIconType.java'),
      );
      expect(huiIconTypes.length, authorable.length);
    });

    test('MenuActionType matches huiActionTypes in order', () {
      final Map<String, String> java = javaEnumConstants(
        readGlossJava('$_enumPackage/MenuActionType.java'),
      );
      expect(
        java.values.toList(),
        huiActionTypes,
        reason: _refresh('lib/model/hui_actions.dart', 'MenuActionType.java'),
      );
    });

    test('MenuComponentType matches huiComponentTypes in order', () {
      final Map<String, String> java = javaEnumConstants(
        readGlossJava('$_enumPackage/MenuComponentType.java'),
      );
      expect(
        java.values.toList(),
        huiComponentTypes,
        reason: _refresh(
          'lib/model/hui_component.dart',
          'MenuComponentType.java',
        ),
      );
    });

    test('NavigationMode matches huiNavigationModes in order', () {
      expect(
        javaSerializedNames(readGlossJava('$_enumPackage/NavigationMode.java')),
        huiNavigationModes,
        reason: _refresh('lib/model/hui_actions.dart', 'NavigationMode.java'),
      );
    });

    test('SoundSource matches huiSoundSources in declaration order', () {
      expect(
        javaSerializedNames(readGlossJava('$_enumPackage/SoundSource.java')),
        huiSoundSources,
        reason: _refresh('lib/model/hui_actions.dart', 'SoundSource.java'),
      );
    });

    test('MenuActionCommandSource matches huiCommandSources', () {
      expect(
        javaSerializedNames(
          readGlossJava('$_enumPackage/MenuActionCommandSource.java'),
        ),
        huiCommandSources,
        reason: _refresh(
          'lib/model/hui_actions.dart',
          'MenuActionCommandSource.java',
        ),
      );
    });

    test('HoloClickTrigger matches huiActionTriggers in order', () {
      final Map<String, String> java = javaEnumConstants(
        readGlossJava(
          'src/main/java/art/arcane/gloss/api/HoloClickTrigger.java',
        ),
      );
      expect(
        java.values.toList(),
        huiActionTriggers,
        reason: _refresh('lib/model/hui_actions.dart', 'HoloClickTrigger.java'),
      );
    });

    test('IconBillboard matches huiIconBillboards in order', () {
      expect(
        javaSerializedNames(readGlossJava('$_iconPackage/IconBillboard.java')),
        huiIconBillboards,
        reason: _refresh('lib/model/hui_icons.dart', 'IconBillboard.java'),
      );
    });

    test('IconTextAlignment matches huiIconTextAlignments in order', () {
      expect(
        javaSerializedNames(
          readGlossJava('$_iconPackage/IconTextAlignment.java'),
        ),
        huiIconTextAlignments,
        reason: _refresh('lib/model/hui_icons.dart', 'IconTextAlignment.java'),
      );
    });

    test('HoverEasing matches HuiHoverEasing in order', () {
      expect(
        javaSerializedNames(
          readGlossJava(
            'src/main/java/art/arcane/gloss/config/components/HoverEasing.java',
          ),
        ),
        <String>[
          for (final HuiHoverEasing easing in HuiHoverEasing.values)
            easing.jsonValue,
        ],
        reason: _refresh('lib/model/hui_component.dart', 'HoverEasing.java'),
      );
    });
  });

  test('the custom-item provider list keeps ItemProviderRegistry order', () {
    // Declaration order is load-bearing: `auto` resolution tries providers in
    // the order they activated, which is the order they are declared.
    final List<String> java = javaConstructorFirstStrings(
      readGlossJava(
        'src/main/java/art/arcane/gloss/integration/ItemProviderRegistry.java',
      ),
      'ProviderDefinition',
    ).map((String name) => name.toLowerCase()).toList();
    expect(java, hasLength(10));
    expect(
      huiCustomItemProviders,
      java,
      reason: _refresh(
        'lib/model/hui_icons.dart',
        'ItemProviderRegistry.java (BUILT_IN_PROVIDERS, lowercased)',
      ),
    );
  });

  group('validation clamps match the plugin', () {
    test('every IconDisplayStyle range is checked with the same bounds', () {
      final String java = readGlossJava('$_iconPackage/IconDisplayStyle.java');
      final Map<String, List<double>> expected = <String, List<double>>{};
      for (final RegExpMatch match in RegExp(
        r'require(?:Finite)?Range\(\s*([^,]+),\s*([-\d.]+)[FfDdLl]?,'
        r'\s*([-\d.]+)[FfDdLl]?,\s*"(\w+)"\s*\)',
      ).allMatches(java)) {
        expected[match.group(4)!] = <double>[
          double.parse(match.group(2)!),
          double.parse(match.group(3)!),
        ];
      }
      expect(
        expected.keys,
        containsAll(<String>['textOpacity', 'lineWidth', 'viewRange']),
        reason: 'IconDisplayStyle stopped declaring its ranges inline',
      );
      expect(
        expected, // 12 today; a new clamp needs an editor-side check too.
        hasLength(greaterThanOrEqualTo(12)),
        reason: 'fewer ranges than expected were read out of the Java source',
      );

      final String dart = File(
        'lib/logic/validation.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      final Map<String, List<double>> actual = <String, List<double>>{};
      for (final RegExpMatch match in RegExp(
        r"_validateStyleNumber\(\s*[^,]+,\s*'\$path\.(\w+)',"
        r'\s*([-\d.]+),\s*([-\d.]+)\s*,?\s*\)',
      ).allMatches(dart)) {
        actual[match.group(1)!] = <double>[
          double.parse(match.group(2)!),
          double.parse(match.group(3)!),
        ];
      }

      for (final MapEntry<String, List<double>> entry in expected.entries) {
        expect(
          actual[entry.key],
          isNotNull,
          reason:
              '${entry.key} is clamped by IconDisplayStyle but unchecked in '
              'lib/logic/validation.dart',
        );
        expect(
          actual[entry.key]![0],
          closeTo(entry.value[0], _epsilon),
          reason:
              '${entry.key} minimum drifted; '
              '${_refresh('lib/logic/validation.dart', 'IconDisplayStyle.java')}',
        );
        expect(
          actual[entry.key]![1],
          closeTo(entry.value[1], _epsilon),
          reason:
              '${entry.key} maximum drifted; '
              '${_refresh('lib/logic/validation.dart', 'IconDisplayStyle.java')}',
        );
      }
    });

    test('the hover-duration ceiling is MAX_HOVER_DURATION_TICKS', () {
      final String java = readGlossJava(
        'src/main/java/art/arcane/gloss/config/components/'
        'ButtonComponentData.java',
      );
      final int maximum = constantInt(java, 'MAX_HOVER_DURATION_TICKS');
      final int fallback = constantInt(java, 'DEFAULT_HOVER_DURATION_TICKS');

      final String dart = File(
        'lib/logic/validation.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      final RegExpMatch? checked = RegExp(
        r'void _validateHoverDuration\(int value, String path\) \{ '
        r'if \(value < 0 \|\| value > (\d+)\)',
      ).firstMatch(dart);
      expect(
        checked,
        isNotNull,
        reason: '_validateHoverDuration no longer has an inline ceiling',
      );
      expect(
        int.parse(checked!.group(1)!),
        maximum,
        reason: _refresh(
          'lib/logic/validation.dart',
          'ButtonComponentData.MAX_HOVER_DURATION_TICKS',
        ),
      );
      expect(
        huiRuntimeDefaultHoverDurationTicks,
        fallback,
        reason: _refresh(
          'lib/model/hui_component.dart',
          'ButtonComponentData.DEFAULT_HOVER_DURATION_TICKS',
        ),
      );
    });
  });

  group('icon geometry matches the runtime constants', () {
    late final String menuIcon = readGlossJava(
      '$_menuIconPackage/MenuIcon.java',
    );
    late final String itemIcon = readGlossJava(
      '$_menuIconPackage/ItemMenuIcon.java',
    );
    late final String blockIcon = readGlossJava(
      '$_menuIconPackage/BlockMenuIcon.java',
    );
    late final String containerPreview = readGlossJava(
      'src/main/java/art/arcane/gloss/preview/ContainerPreview.java',
    );

    test('huiLineHeight is MenuIcon.NAMETAG_SIZE', () {
      expect(
        huiLineHeight,
        closeTo(constantNumber(menuIcon, 'NAMETAG_SIZE'), _epsilon),
        reason: _refresh('lib/logic/hui_geometry.dart', 'MenuIcon.java'),
      );
    });

    test('the character cell and glyph advance are pixel multiples', () {
      final double perPixel = constantNumber(
        containerPreview,
        'VANILLA_TEXT_BLOCKS_PER_PIXEL',
      );
      expect(
        huiCharCell,
        closeTo(9 * perPixel, _epsilon),
        reason:
            'huiCharCell is 8px + 1px spacing at '
            'VANILLA_TEXT_BLOCKS_PER_PIXEL; '
            '${_refresh('lib/logic/hui_geometry.dart', 'ContainerPreview.java')}',
      );
      expect(
        huiTextCharWidth,
        closeTo(6 * perPixel, _epsilon),
        reason:
            'huiTextCharWidth is 5px + 1px spacing at '
            'VANILLA_TEXT_BLOCKS_PER_PIXEL; '
            '${_refresh('lib/logic/hui_geometry.dart', 'ContainerPreview.java')}',
      );
    });

    test('huiTextTrueRenderBias is the display-entity baseline bias', () {
      expect(
        huiTextTrueRenderBias,
        closeTo(
          2 * constantNumber(menuIcon, 'NAMETAG_SIZE') -
              constantNumber(menuIcon, 'TEXT_DISPLAY_BASELINE'),
          _epsilon,
        ),
        reason: _refresh('lib/logic/hui_geometry.dart', 'MenuIcon.java'),
      );
    });

    test('item and block offsets match ItemMenuIcon', () {
      expect(
        huiItemDisplayOffset,
        closeTo(constantNumber(itemIcon, 'ITEM_OFFSET'), _epsilon),
        reason: _refresh('lib/logic/hui_geometry.dart', 'ItemMenuIcon.java'),
      );
      expect(
        huiBlockDisplayOffset,
        closeTo(-constantNumber(itemIcon, 'BLOCK_OFFSET'), _epsilon),
        reason:
            'huiBlockDisplayOffset is the negated BLOCK_OFFSET drop; '
            '${_refresh('lib/logic/hui_geometry.dart', 'ItemMenuIcon.java')}',
      );
    });

    test('item size and hitbox drop match BlockMenuIcon', () {
      expect(
        huiItemSize,
        closeTo(constantNumber(blockIcon, 'DISPLAY_SIZE'), _epsilon),
        reason: _refresh('lib/logic/hui_geometry.dart', 'BlockMenuIcon.java'),
      );
      expect(
        huiItemHitboxDrop,
        closeTo(-constantNumber(blockIcon, 'VERTICAL_OFFSET'), _epsilon),
        reason:
            'huiItemHitboxDrop is the negated VERTICAL_OFFSET; '
            '${_refresh('lib/logic/hui_geometry.dart', 'BlockMenuIcon.java')}',
      );
    });
  });

  group('bubble stacking matches the plugin', () {
    test('the base lift is BubbleStackMath.BASE_LIFT', () {
      expect(
        glossBubbleBaseLift,
        closeTo(
          constantNumber(
            readGlossJava(
              'src/main/java/art/arcane/gloss/bubble/BubbleStackMath.java',
            ),
            'BASE_LIFT',
          ),
          _epsilon,
        ),
        reason: _refresh(
          'lib/logic/bubble_stack_math.dart',
          'BubbleStackMath.java',
        ),
      );
    });

    test('the default spread is the config default stackDistance', () {
      expect(
        glossBubbleDefaultStackSpread,
        closeTo(
          constantNumber(
            readGlossJava(
              'src/main/java/art/arcane/gloss/config/GlossConfigFile.java',
            ),
            'stackDistance',
          ),
          _epsilon,
        ),
        reason: _refresh(
          'lib/logic/bubble_stack_math.dart',
          'GlossConfigFile.java',
        ),
      );
    });
  });

  group('the shine band matches BubbleShimmerPlan', () {
    String plan() => readGlossJava(
      'src/main/java/art/arcane/gloss/bubble/BubbleShimmerPlan.java',
    );

    test('the cycle is CYCLE_GLYPHS glyphs long', () {
      expect(
        glossBubbleShimmerCycleGlyphs,
        constantInt(plan(), 'CYCLE_GLYPHS'),
        reason: _refresh(
          'lib/model/gloss_bubble_style.dart',
          'BubbleShimmerPlan.java',
        ),
      );
    });

    test('the default durationMs is LEGACY_CYCLE_MS', () {
      // The shipped cycle IS the default: a file with no durationMs runs it,
      // and it is the wall time for one full 127-glyph cycle, not one pass.
      expect(
        glossBubbleShimmerDefaultDurationMs,
        constantInt(plan(), 'LEGACY_CYCLE_MS'),
        reason: _refresh(
          'lib/model/gloss_bubble_style.dart',
          'BubbleShimmerPlan.java',
        ),
      );
      expect(
        GlossBubbleShimmer().durationMs,
        glossBubbleShimmerDefaultDurationMs,
      );
    });

    test('the solid band color is the shipped original Gloss white', () {
      final String doc = readGlossJava(
        'src/main/java/art/arcane/gloss/bubble/BubbleStyleDoc.java',
      );
      expect(
        glossBubbleShimmerDefaultColor,
        stringLiteral(doc, 'DEFAULT_COLOR'),
        reason: _refresh(
          'lib/model/gloss_bubble_style.dart',
          'BubbleStyleDoc.java',
        ),
      );
      expect(GlossBubbleShimmer().color, glossBubbleShimmerDefaultColor);
    });
  });
}
