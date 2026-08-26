/// The real-drops `physics` and `script` blocks: the model that carries them,
/// the validation that refuses what the server refuses, and the expression
/// engine that evaluates them.
///
/// Both blocks are additive and optional, so an untouched canonical document
/// that omits them must continue to omit them.
///
/// The worked examples at the end come out of `DROP_SCRIPT_FORMAT.md` in the
/// paired plugin checkout, which is where the plugin's own
/// `RealDropDocumentScriptTest` reads them from. Both suites parse the same
/// fenced blocks, so an example that stops compiling on one side fails on both.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/real_drop_model.dart';
import 'package:gloss_editor/logic/real_drop_script.dart';
import 'package:gloss_editor/logic/real_drop_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

import 'support/gloss_repository.dart';

String _withoutOptionalBlocksJson() {
  final Map<String, dynamic> map =
      jsonDecode(kGlossRealDropsDefaultJson) as Map<String, dynamic>;
  final Map<String, dynamic> presentation =
      map['presentation'] as Map<String, dynamic>;
  presentation.remove('physics');
  presentation.remove('script');
  return huiWriteJson(map);
}

GlossRealDropSettingsDoc _doc(String json) =>
    decodeGlossRealDropSettingsDoc(json);

/// A document carrying only `script`, the way the format doc's examples are
/// written — everything else falls back to the shipped defaults.
GlossRealDropSettingsDoc _scripted(String scriptJson) => _doc(
  '{"schemaVersion":3,"revision":2,'
  '"presentation":{"script":$scriptJson},'
  '"variants":[],"audience":{"when":"true"}}',
);

RealDropScriptContext _context({
  double t = 0,
  int age = 0,
  int index = 0,
  int count = 1,
  int amount = 1,
  bool onGround = false,
  bool settled = false,
  bool inWater = false,
  bool inLava = false,
  int bounces = 0,
  double velocityX = 0,
  double velocityY = 0,
  double velocityZ = 0,
  double height = 0,
  int blockLight = 15,
  int skyLight = 15,
  double random = 0.5,
  String material = 'STONE',
  DropModelKind kind = DropModelKind.block,
}) => RealDropScriptContext(
  t: t,
  age: age,
  index: index,
  count: count,
  amount: amount,
  onGround: onGround,
  settled: settled,
  inWater: inWater,
  inLava: inLava,
  bounces: bounces,
  velocityX: velocityX,
  velocityY: velocityY,
  velocityZ: velocityZ,
  height: height,
  blockLight: blockLight,
  skyLight: skyLight,
  random: random,
  material: material,
  kind: kind,
);

List<String> _messages(GlossRealDropSettingsDoc doc) =>
    validateRealDropSettingsDoc(
      doc,
    ).map((HuiIssue issue) => issue.message).toList();

/// Every fenced JSON block in the format doc that turns something on, which is
/// the same filter `RealDropDocumentScriptTest.workedExamples` applies.
List<String> _workedExamples() {
  final File document = File(glossRepositoryFilePath('DROP_SCRIPT_FORMAT.md'));
  expect(document.existsSync(), isTrue, reason: document.path);
  return RegExp(r'```json\n(.*?)```', dotAll: true)
      .allMatches(document.readAsStringSync())
      .map((RegExpMatch match) => match.group(1)!)
      .where((String block) => block.contains('"enabled": true'))
      .toList();
}

void main() {
  group('a canonical document without optional blocks never grows them', () {
    test('round-trips byte for byte', () {
      final String source = _withoutOptionalBlocksJson();
      final GlossRealDropSettingsDoc doc = _doc(source);
      expect(doc.presentation.physics, isNull);
      expect(doc.presentation.script, isNull);
      expect(encodeGlossRealDropSettingsDoc(doc), source);
      expect(encodeGlossRealDropSettingsDoc(doc.copy()), source);
    });

    test('validates clean and evaluates to nothing', () {
      final GlossRealDropSettingsDoc doc = _doc(_withoutOptionalBlocksJson());
      expect(validateRealDropSettingsDoc(doc), isEmpty);
      expect(RealDropScriptPlan.empty.issues, isEmpty);
      expect(
        RealDropScriptPlan.empty.sample(_context()).isNeutral,
        isTrue,
        reason: 'no script block composes nothing onto the presentation',
      );
    });

    test('grows the block only once somebody touches it', () {
      final GlossRealDropSettingsDoc doc = _doc(_withoutOptionalBlocksJson());
      expect(encodeGlossRealDropSettingsDoc(doc), isNot(contains('physics')));
      doc.presentation.physics = GlossRealDropPhysics();
      final Map<String, dynamic> written =
          jsonDecode(encodeGlossRealDropSettingsDoc(doc))
              as Map<String, dynamic>;
      final Map<String, dynamic> presentation =
          written['presentation'] as Map<String, dynamic>;
      expect(presentation.containsKey('physics'), isTrue);
      expect(
        presentation.containsKey('script'),
        isFalse,
        reason: 'touching one block must not conjure the other',
      );
    });
  });

  group('the kind sniffer accepts what the plugin accepts', () {
    test('the shipped shape, and a document made only of the new blocks', () {
      expect(
        looksLikeRealDropSettingsDoc(jsonDecode(kGlossRealDropsDefaultJson)),
        isTrue,
      );
      for (final String example in _workedExamples()) {
        expect(
          looksLikeRealDropSettingsDoc(jsonDecode(example)),
          isTrue,
          reason:
              'the code view refuses anything this says no to, and the server '
              'loads every one of these',
        );
      }
    });

    test('and still says no to another kind entirely', () {
      expect(
        looksLikeRealDropSettingsDoc(
          jsonDecode('{"schemaVersion":3,"revision":1,"lines":["hi"]}'),
        ),
        isFalse,
      );
      expect(looksLikeRealDropSettingsDoc(<String, Object?>{}), isFalse);
    });
  });

  group('the shipped default carries both blocks', () {
    test('decodes them disabled and neutral', () {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      expect(doc.presentation.physics, isNotNull);
      expect(doc.presentation.physics!.enabled, isFalse);
      expect(doc.presentation.physics!.gravityMultiplier, 1);
      expect(doc.presentation.physics!.bounce, 0);
      expect(doc.presentation.script, isNotNull);
      expect(doc.presentation.script!.enabled, isFalse);
      expect(doc.presentation.script!.vars, isEmpty);
      expect(doc.presentation.script!.offset.x, '0');
      expect(doc.presentation.script!.scale.z, '1');
      expect(doc.presentation.script!.glow, '');
      expect(doc.presentation.script!.visible, 'true');
      expect(validateRealDropSettingsDoc(doc), isEmpty);
    });

    test('re-encodes stably, empty vars object included', () {
      final GlossRealDropSettingsDoc doc = buildDefaultGlossRealDrops();
      final String written = encodeGlossRealDropSettingsDoc(doc);
      expect(written, contains('"vars": {}'));
      expect(encodeGlossRealDropSettingsDoc(_doc(written)), written);
    });
  });

  group('vars keep their declaration order', () {
    const String source = '''
{
  "schemaVersion": 3,
  "revision": 2,
  "presentation": {
  "script": {
    "enabled": true,
    "vars": { "zulu": "1", "alpha": "zulu + 1", "mike": "alpha * 2" },
    "offset": { "y": "mike" }
  }
  },
  "variants": [],
  "audience": {"when": "true"}
}
''';

    test('on read, in file order rather than alphabetical', () {
      final GlossRealDropSettingsDoc doc = _doc(source);
      expect(
        doc.presentation.script!.vars.map((GlossRealDropScriptVar v) => v.name),
        <String>['zulu', 'alpha', 'mike'],
      );
      expect(validateRealDropSettingsDoc(doc), isEmpty);
    });

    test('on write, so a later entry still reads an earlier one', () {
      final GlossRealDropSettingsDoc doc = _doc(source);
      final String written = encodeGlossRealDropSettingsDoc(doc);
      expect(
        written.indexOf('"zulu"'),
        lessThan(written.indexOf('"alpha"')),
        reason: 'alpha reads zulu, so zulu has to come first',
      );
      expect(written.indexOf('"alpha"'), lessThan(written.indexOf('"mike"')));
      expect(validateRealDropSettingsDoc(_doc(written)), isEmpty);
    });

    test('on edit: moving a reader above what it reads is an error', () {
      final GlossRealDropSettingsDoc doc = _doc(source);
      doc.presentation.script!.vars.insert(
        0,
        doc.presentation.script!.vars.removeAt(1),
      );
      expect(
        _messages(doc),
        contains("script.vars.alpha: unknown variable 'zulu' at position 0"),
        reason:
            'declaration order is semantic, so a reorder really can break the '
            'document',
      );
    });

    test('and the order survives an add and a remove', () {
      final GlossRealDropSettingsDoc doc = _doc(source);
      doc.presentation.script!.vars.add(
        GlossRealDropScriptVar(name: 'tail', expression: 'mike + 1'),
      );
      doc.presentation.script!.vars.removeAt(0);
      doc.presentation.script!.vars.insert(
        0,
        GlossRealDropScriptVar(name: 'zulu', expression: '1'),
      );
      expect(
        doc.presentation.script!.vars.map((GlossRealDropScriptVar v) => v.name),
        <String>['zulu', 'alpha', 'mike', 'tail'],
      );
      expect(validateRealDropSettingsDoc(doc), isEmpty);
    });
  });

  group('validation says what the server says', () {
    test('a parse error names the field and the character', () {
      expect(
        _messages(_scripted('{"enabled": true, "offset": {"y": "sin(t"}}')),
        contains('script.offset.y: unclosed paren at position 5'),
      );
    });

    test('an unknown variable and an unknown function', () {
      expect(
        _messages(
          _scripted('{"enabled": true, "offset": {"z": "wobble * 2"}}'),
        ),
        contains("script.offset.z: unknown variable 'wobble' at position 0"),
      );
      expect(
        _messages(_scripted('{"enabled": true, "offset": {"x": "wiggle(2)"}}')),
        contains("script.offset.x: unknown function 'wiggle' at position 0"),
      );
    });

    test('a broken expression is refused with the script switched off', () {
      expect(
        _messages(
          _scripted('{"enabled": false, "scale": {"x": "nonsense*2"}}'),
        ),
        contains("script.scale.x: unknown variable 'nonsense' at position 0"),
        reason:
            'the server compiles every expression at load either way, so the '
            'file will not load whatever the switch says',
      );
    });

    test('a field that evaluates to the wrong type', () {
      expect(
        _messages(_scripted(r'{"enabled": true, "offset": {"x": "material"}}')),
        contains('script.offset.x must evaluate to a number, got string'),
      );
      expect(
        _messages(_scripted('{"enabled": true, "visible": "amount"}')),
        contains('script.visible must evaluate to true or false, got number'),
      );
      expect(
        _messages(_scripted("""{"enabled": true, "glow": "'not a colour'"}""")),
        contains(
          "script.glow string must be #RRGGBB or #AARRGGBB, got 'not a colour'",
        ),
      );
    });

    test('a division that only fails in one of the four sample states', () {
      expect(
        _messages(_scripted('{"enabled": true, "offset": {"y": "1 / speed"}}')),
        contains('script.offset.y: division by zero'),
        reason:
            'one of the sample contexts is settled and motionless, which is '
            'what catches this at load rather than a tick later',
      );
    });

    test('bad variable names', () {
      expect(
        _messages(_scripted('{"enabled": true, "vars": {"speed": "1"}}')),
        contains('script.vars.speed shadows the built-in variable speed'),
      );
      expect(
        _messages(_scripted('{"enabled": true, "vars": {"my var": "1"}}')),
        contains(
          'script.vars.my var is not a valid name; use letters, digits and '
          'underscores starting with a letter or underscore',
        ),
      );
      expect(
        _messages(_scripted('{"enabled": true, "vars": {"  ": "1"}}')),
        contains('script.vars declares an entry with no name'),
      );
      expect(
        _messages(_scripted('{"enabled": true, "vars": {"wobble": "   "}}')),
        contains('script.vars.wobble must be a non-blank expression'),
      );
    });

    test('a variable declared twice, which JSON alone cannot express', () {
      final GlossRealDropSettingsDoc doc = _scripted(
        '{"enabled": true, "vars": {"mine": "1"}}',
      );
      doc.presentation.script!.vars.add(
        GlossRealDropScriptVar(name: 'mine', expression: '2'),
      );
      expect(_messages(doc), contains('script.vars.mine is declared twice'));
    });

    test('more than thirty-two variables', () {
      final GlossRealDropSettingsDoc doc = _scripted('{"enabled": true}');
      for (int index = 0; index <= GlossRealDropScript.maxVars; index++) {
        doc.presentation.script!.vars.add(
          GlossRealDropScriptVar(name: 'v$index', expression: '1'),
        );
      }
      expect(
        _messages(doc),
        contains('script.vars declares 33 variables; the limit is 32'),
      );
    });

    test('an expression over five hundred and twelve characters', () {
      final String long = '1 + ${'1 + ' * 200}1';
      expect(long.length, greaterThan(GlossRealDropScript.maxSourceLength));
      expect(
        _messages(_scripted('{"enabled": true, "offset": {"y": "$long"}}')),
        contains('script.offset.y exceeds 512 characters'),
      );
    });

    test('every script problem is an error, not a clampable warning', () {
      final List<HuiIssue> issues = validateRealDropSettingsDoc(
        _scripted('{"enabled": true, "offset": {"y": "sin(t"}}'),
      );
      expect(issues, hasLength(1));
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, r'$.presentation.script.offset.y');
    });

    test('physics clamps are warnings, because the server clamps them', () {
      final GlossRealDropSettingsDoc doc = _doc(
        '{"schemaVersion":3,"revision":2,'
        '"presentation":{"physics":{'
        '"enabled":true,"gravityMultiplier":9,"bounce":2}},'
        '"variants":[],"audience":{"when":"true"}}',
      );
      final List<HuiIssue> issues = validateRealDropSettingsDoc(doc);
      expect(issues, hasLength(2));
      expect(
        issues.every((HuiIssue i) => i.severity == HuiSeverity.warning),
        isTrue,
      );
      expect(
        doc.presentation.physics!.gravityMultiplier,
        9,
        reason: 'the editor sends what the author typed and warns about it',
      );
    });
  });

  group('the material tests are the plugin normalisation', () {
    RealDropScriptPlan plan(String glow) => RealDropScriptPlan.compile(
      _scripted('{"glow": "$glow"}').presentation.script!,
    );

    int glowFor(String source, String material) =>
        plan(source).sample(_context(material: material)).glowArgb;

    test('materialIs is exact and case-insensitive', () {
      const String source = r"materialIs('torch') ? #FFFFFF : 0";
      expect(glowFor(source, 'TORCH'), 0xFFFFFFFF);
      expect(glowFor(source, 'REDSTONE_TORCH'), 0);
      expect(
        glowFor(
          r"materialIs('minecraft:soul torch') ? #FFFFFF : 0",
          'SOUL_TORCH',
        ),
        0xFFFFFFFF,
        reason: 'a namespace is stripped and spaces fold to underscores',
      );
    });

    test('materialMatches is a glob, and the doc means what it says', () {
      const String source = r"materialMatches('*_TORCH') ? #FFFFFF : 0";
      for (final String material in <String>[
        'REDSTONE_TORCH',
        'SOUL_TORCH',
        'WALL_TORCH',
      ]) {
        expect(glowFor(source, material), 0xFFFFFFFF, reason: material);
      }
      for (final String material in <String>['TORCH', 'TORCHFLOWER']) {
        expect(glowFor(source, material), 0, reason: material);
      }
    });
  });

  group('evaluation', () {
    test('vars run first, in order, and feed everything after them', () {
      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        _scripted('''
{
  "enabled": true,
  "vars": { "base": "index + 1", "doubled": "base * 2" },
  "offset": { "y": "doubled" },
  "scale": { "x": "base" }
}
''').presentation.script!,
      );
      expect(plan.issues, isEmpty);
      final RealDropScriptSample sample = plan.sample(_context(index: 3));
      expect(sample.offsetY, 8);
      expect(sample.scaleX, 4);
    });

    test('every result is clamped the way the server clamps it', () {
      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        _scripted(
          '{"enabled": true, "offset": {"y": "900"}, '
          '"rotation": {"x": "-9000"}, "scale": {"z": "40"}}',
        ).presentation.script!,
      );
      final RealDropScriptSample sample = plan.sample(_context());
      expect(sample.offsetY, realDropScriptMaxOffset);
      expect(sample.rotationX, -realDropScriptMaxRotation);
      expect(sample.scaleZ, realDropScriptMaxScale);
    });

    test('one field failing at runtime takes only its own value', () {
      // Passes the four load-time samples (amounts 1, 32, 64 and 8) and only
      // divides by zero on a stack of exactly five.
      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        _scripted(
          '{"enabled": true, "offset": {"y": "1 / (amount - 5)"}, '
          '"scale": {"x": "2"}}',
        ).presentation.script!,
      );
      expect(plan.issues, isEmpty, reason: 'nothing to refuse at load');
      final RealDropScriptSample sample = plan.sample(_context(amount: 5));
      expect(sample.offsetY, 0, reason: 'the neutral fallback for offset');
      expect(sample.scaleX, 2, reason: 'and nothing else is touched');
      expect(sample.failed, <String>{'script.offset.y'});
    });

    test('a blank glow is the feature off, not an empty expression', () {
      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        _scripted('{"enabled": true, "glow": ""}').presentation.script!,
      );
      expect(plan.issues, isEmpty);
      expect(plan.sample(_context()).glowArgb, 0);
    });

    test('the environment is only probed when something asks for it', () {
      expect(
        RealDropScriptPlan.compile(
          _scripted(
            '{"enabled": true, "offset": {"y": "sin(t) * 0.1"}}',
          ).presentation.script!,
        ).environmentReferenced,
        isFalse,
      );
      expect(
        RealDropScriptPlan.compile(
          _scripted(
            '{"enabled": true, "offset": {"y": "height * 0.1"}}',
          ).presentation.script!,
        ).environmentReferenced,
        isTrue,
      );
    });
  });

  group('the format document\'s worked examples', () {
    test('are all four still there, and all four load clean', () {
      final List<String> examples = _workedExamples();
      expect(
        examples,
        hasLength(4),
        reason:
            'the plugin test pins the same four; a fifth on one side and not '
            'the other means the two engines have drifted',
      );
      for (final String example in examples) {
        final GlossRealDropSettingsDoc doc = _doc(example);
        expect(validateRealDropSettingsDoc(doc), isEmpty, reason: example);
        expect(
          (doc.presentation.script?.enabled ?? false) ||
              (doc.presentation.physics?.enabled ?? false),
          isTrue,
          reason: 'a worked example that enables nothing shows nothing',
        );
      }
    });

    test('7.1 a torch that glows, and nothing else does', () {
      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        _doc(_workedExamples()[0]).presentation.script!,
      );
      expect(plan.issues, isEmpty);
      for (final String torch in <String>[
        'TORCH',
        'REDSTONE_TORCH',
        'SOUL_TORCH',
        'WALL_TORCH',
      ]) {
        expect(
          plan.sample(_context(material: torch)).glowArgb,
          0xFFFFAA55,
          reason: torch,
        );
      }
      for (final String other in <String>['STONE', 'TORCHFLOWER']) {
        expect(
          plan.sample(_context(material: other)).glowArgb,
          0,
          reason: other,
        );
      }
    });

    test('7.1 with a named intermediate, driving three fields at once', () {
      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        _doc(_workedExamples()[1]).presentation.script!,
      );
      expect(plan.issues, isEmpty);
      expect(
        plan.environmentReferenced,
        isTrue,
        reason: 'isLit reads blockLight, which is what makes Gloss probe',
      );

      final RealDropScriptSample lit = plan.sample(
        _context(material: 'TORCH', blockLight: 15),
      );
      expect(lit.offsetY, closeTo(0.08, 1e-12), reason: 'it sits higher');
      expect(lit.scaleX, closeTo(1.15, 1e-12), reason: 'and a touch larger');
      expect(lit.scaleY, closeTo(1.15, 1e-12));
      expect(lit.scaleZ, closeTo(1.15, 1e-12));
      expect(lit.glowArgb, 0xFFFFCC66, reason: 'the lit colour');

      final RealDropScriptSample dark = plan.sample(
        _context(material: 'SOUL_TORCH', blockLight: 2),
      );
      expect(dark.glowArgb, 0xFFFFAA55, reason: 'the unlit torch colour');
      expect(dark.offsetY, closeTo(0.08, 1e-12));

      final RealDropScriptSample stone = plan.sample(
        _context(material: 'STONE', blockLight: 15),
      );
      expect(stone.glowArgb, 0);
      expect(stone.offsetY, 0);
      expect(stone.scaleX, 1, reason: 'everything else is untouched');
    });

    test('7.2 a stack that bobs in water, and lies still out of it', () {
      final GlossRealDropSettingsDoc doc = _doc(_workedExamples()[2]);
      expect(doc.presentation.physics!.enabled, isTrue);
      expect(doc.presentation.physics!.waterBuoyancy, closeTo(0.35, 1e-12));
      expect(doc.presentation.physics!.waterDrag, closeTo(0.12, 1e-12));

      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        doc.presentation.script!,
      );
      expect(plan.issues, isEmpty);

      final RealDropScriptSample dry = plan.sample(_context(t: 1.5));
      expect(dry.offsetY, 0, reason: 'no bob out of water');
      expect(dry.rotationY, 0);
      expect(dry.rotationZ, 0);

      final RealDropScriptSample wet = plan.sample(
        _context(t: 1.5, index: 2, random: 0.5, inWater: true),
      );
      // phase = t * 2 + index * 1.2 + random * 6.283
      const double phase = 1.5 * 2 + 2 * 1.2 + 0.5 * 6.283;
      expect(wet.offsetY, closeTo(math.sin(phase) * 0.09, 1e-12));
      expect(wet.rotationZ, closeTo(math.sin(phase) * 6, 1e-12));
      expect(wet.rotationY, closeTo(1.5 * 20, 1e-12), reason: 'a slow spin');

      final RealDropScriptSample neighbour = plan.sample(
        _context(t: 1.5, index: 0, random: 0.5, inWater: true),
      );
      expect(
        neighbour.offsetY,
        isNot(closeTo(wet.offsetY, 1e-6)),
        reason: 'index offsets the models within one stack from each other',
      );
    });

    test('7.3 a squash on the bounce that loses energy as it goes', () {
      final GlossRealDropSettingsDoc doc = _doc(_workedExamples()[3]);
      expect(doc.presentation.physics!.enabled, isTrue);
      expect(doc.presentation.physics!.bounce, closeTo(0.45, 1e-12));

      final RealDropScriptPlan plan = RealDropScriptPlan.compile(
        doc.presentation.script!,
      );
      expect(plan.issues, isEmpty);

      // On the ground: pop is 0, so the model is energy on all three axes.
      final RealDropScriptSample rested = plan.sample(
        _context(t: 4, onGround: true, bounces: 0),
      );
      expect(rested.scaleX, closeTo(1, 1e-12));
      expect(rested.scaleY, closeTo(1, 1e-12));
      expect(rested.rotationX, 0);

      // Airborne right after a landing: stretched on X and Z, squashed on Y.
      final RealDropScriptSample popped = plan.sample(
        _context(t: 4, onGround: false, bounces: 0),
      );
      expect(popped.scaleX, greaterThan(1));
      expect(popped.scaleZ, closeTo(popped.scaleX, 1e-12));
      expect(popped.scaleY, lessThan(1));
      expect(popped.rotationX, greaterThan(0));

      // energy = clamp(1 - bounces * 0.08, 0.6, 1), and it floors at 0.6.
      final RealDropScriptSample tired = plan.sample(
        _context(t: 4, onGround: true, bounces: 3),
      );
      expect(tired.scaleY, closeTo(0.76, 1e-12));
      expect(
        plan.sample(_context(t: 4, onGround: true, bounces: 40)).scaleY,
        closeTo(0.6, 1e-12),
      );
    });
  });
}
