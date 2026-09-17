/// Surface validation: what `SurfaceDoc.java` refuses at parse as errors, what
/// it silently clamps, and what `Presentation.forKind` silently drops.
library;

import 'dart:io';

import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/surface_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossSurfaceDoc _doc({
  String surface = glossSurfaceKindActionbar,
  GlossSurfacePresentation? presentation,
  GlossSurfaceSelect? select,
  List<GlossSurfaceVariant>? variants,
  int revision = 1,
}) => GlossSurfaceDoc(
  revision: revision,
  surface: surface,
  select: select ?? GlossSurfaceSelect(priority: 0, when: 'viewer.level > 0'),
  presentation: presentation ?? GlossSurfacePresentation(text: '&7Welcome'),
  variants: variants,
);

List<HuiIssue> _at(List<HuiIssue> issues, String path) =>
    issues.where((HuiIssue issue) => issue.path == path).toList();

void main() {
  test('a well-formed actionbar validates clean', () {
    expect(validateSurfaceDoc(_doc()), isEmpty);
  });

  test('the seeded welcome document validates clean', () {
    final GlossSurfaceDoc doc = buildDefaultGlossSurface();
    final List<HuiIssue> issues = validateSurfaceDoc(doc);
    expect(
      issues.where((HuiIssue issue) => issue.severity != HuiSeverity.info),
      isEmpty,
    );
    // The shipped default ships Selection.NEVER, which is the one thing worth
    // saying out loud about it.
    expect(issues.single.severity, HuiSeverity.info);
    expect(issues.single.path, r'$.select.when');
  });

  test('the fixture matches the shipped Gloss default', () {
    final String fixture = File(
      'test/fixtures/gloss/surface-welcome.json',
    ).readAsStringSync();
    expect(kGlossSurfaceWelcomeJson, fixture);
  });

  test('an out-of-range revision is an error', () {
    final List<HuiIssue> issues = validateSurfaceDoc(_doc(revision: 0));
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  group('surface kind', () {
    test('a blank surface is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(_doc(surface: '')),
        r'$.surface',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('actionbar'));
      expect(issues.single.message, contains('bossbar'));
      expect(issues.single.message, contains('title'));
    });

    test('an unknown surface is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(_doc(surface: 'subtitle')),
        r'$.surface',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('subtitle'));
    });
  });

  group('selection', () {
    test('a blank condition is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(select: GlossSurfaceSelect(when: '   ')),
        ),
        r'$.select.when',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a condition that does not compile is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(select: GlossSurfaceSelect(when: 'viewer.level >')),
        ),
        r'$.select.when',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('the never-shown default is an info, not an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(select: GlossSurfaceSelect(when: glossSurfaceNeverCondition)),
        ),
        r'$.select.when',
      );
      expect(issues.single.severity, HuiSeverity.info);
      expect(issues.single.message, contains('false'));
    });
  });

  group('required presentation fields', () {
    test('an actionbar with no text is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(presentation: GlossSurfacePresentation(title: '&6Boss')),
        ),
        r'$.presentation.text',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('actionbar'));
    });

    test('a bossbar with no title is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(text: '&7hi'),
          ),
        ),
        r'$.presentation.title',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('bossbar'));
    });

    test('a title with no title is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindTitle,
            presentation: GlossSurfacePresentation(subtitle: '&7sub'),
          ),
        ),
        r'$.presentation.title',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a blank required field counts as missing', () {
      // Presentation.trimToNull turns "   " into null before forKind looks.
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(presentation: GlossSurfacePresentation(text: '   ')),
        ),
        r'$.presentation.text',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });
  });

  group('fields the kind drops', () {
    test('a bossbar carrying text is told the text is ignored', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              text: '&7leftover',
            ),
          ),
        ),
        r'$.presentation.text',
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.message, contains('bossbar'));
      expect(issues.single.message, contains('text'));
    });

    test('an actionbar carrying a title is told the title is ignored', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            presentation: GlossSurfacePresentation(
              text: '&7hi',
              title: '&6leftover',
            ),
          ),
        ),
        r'$.presentation.title',
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.message, contains('actionbar'));
    });

    test('a dropped knob is an info, not a warning', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            presentation: GlossSurfacePresentation(
              text: '&7hi',
              color: 'red',
            ),
          ),
        ),
        r'$.presentation.color',
      );
      expect(issues.single.severity, HuiSeverity.info);
    });

    test('a field the kind uses is never reported as dropped', () {
      expect(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              progress: 'viewer.healthPercent / 100',
              color: 'red',
              style: 'segmented_10',
              slots: <String>['center'],
              priority: 'progress',
              ttlTicks: 60,
            ),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('clamped values', () {
    test('a ttl past the ceiling warns with the clamped value', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            presentation: GlossSurfacePresentation(
              text: '&7hi',
              ttlTicks: 5000,
            ),
          ),
        ),
        r'$.presentation.ttlTicks',
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.message, contains('$glossSurfaceMaxTtlTicks'));
    });

    test('a ttl below the floor warns', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            presentation: GlossSurfacePresentation(text: '&7hi', ttlTicks: 0),
          ),
        ),
        r'$.presentation.ttlTicks',
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.message, contains('$glossSurfaceMinTtlTicks'));
    });

    test('each fade past the ceiling warns on a title surface', () {
      final List<HuiIssue> issues = validateSurfaceDoc(
        _doc(
          surface: glossSurfaceKindTitle,
          presentation: GlossSurfacePresentation(
            title: '&dWelcome',
            fadeInTicks: -1,
            stayTicks: 4000,
            fadeOutTicks: 4000,
          ),
        ),
      );
      for (final String field in <String>[
        'fadeInTicks',
        'stayTicks',
        'fadeOutTicks',
      ]) {
        final List<HuiIssue> fieldIssues = _at(
          issues,
          r'$.presentation.' + field,
        );
        expect(fieldIssues.single.severity, HuiSeverity.warning, reason: field);
      }
    });

    test('a repeat interval past the ceiling warns', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindTitle,
            presentation: GlossSurfacePresentation(
              title: '&dWelcome',
              trigger: 'repeat',
              repeatTicks: 900000,
            ),
          ),
        ),
        r'$.presentation.repeatTicks',
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.message, contains('$glossSurfaceMaxRepeatTicks'));
    });

    test('an in-range value is silent', () {
      expect(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindTitle,
            presentation: GlossSurfacePresentation(
              title: '&dWelcome',
              ttlTicks: 60,
              fadeInTicks: 10,
              stayTicks: 40,
              fadeOutTicks: 10,
              trigger: 'repeat',
              repeatTicks: 200,
            ),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('named values', () {
    test('an unknown slot is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            presentation: GlossSurfacePresentation(
              text: '&7hi',
              slots: <String>['center', 'middle'],
            ),
          ),
        ),
        r'$.presentation.slots',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('middle'));
    });

    test('an unknown colour is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              color: 'teal',
            ),
          ),
        ),
        r'$.presentation.color',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('teal'));
    });

    test('an unknown style is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              style: 'segmented_4',
            ),
          ),
        ),
        r'$.presentation.style',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('an unknown trigger is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindTitle,
            presentation: GlossSurfacePresentation(
              title: '&dWelcome',
              trigger: 'always',
            ),
          ),
        ),
        r'$.presentation.trigger',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('an unknown priority is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            presentation: GlossSurfacePresentation(
              text: '&7hi',
              priority: 'urgent',
            ),
          ),
        ),
        r'$.presentation.priority',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('urgent'));
      expect(issues.single.message, contains(glossSurfaceDefaultPriority));
    });

    test('every listed priority name is accepted', () {
      for (final String name in glossSurfacePriorities) {
        expect(
          validateSurfaceDoc(
            _doc(
              presentation: GlossSurfacePresentation(
                text: '&7hi',
                priority: name,
              ),
            ),
          ),
          isEmpty,
          reason: name,
        );
      }
    });
  });

  group('progress', () {
    test('an empty expression is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              progress: '{{  }}',
            ),
          ),
        ),
        r'$.presentation.progress',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('an expression that does not compile is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              progress: 'viewer.health /',
            ),
          ),
        ),
        r'$.presentation.progress',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a wrapped expression compiles like an unwrapped one', () {
      expect(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(
              title: '&6Boss',
              progress: '{{ viewer.health / viewer.maxHealth }}',
            ),
          ),
        ),
        isEmpty,
      );
    });
  });

  group('variants', () {
    GlossSurfaceVariant variant({
      String id = 'low',
      int priority = 10,
      String when = 'viewer.healthPercent <= 25',
      GlossSurfacePresentation? presentation,
    }) => GlossSurfaceVariant(
      id: id,
      priority: priority,
      when: when,
      presentation: presentation ?? GlossSurfacePresentation(text: '&cLow'),
    );

    test('a well-formed variant is clean', () {
      expect(
        validateSurfaceDoc(
          _doc(variants: <GlossSurfaceVariant>[variant()]),
        ),
        isEmpty,
      );
    });

    test('a blank id is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(variants: <GlossSurfaceVariant>[variant(id: '  ')]),
        ),
        r'$.variants[0].id',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('an unsupported character in an id is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(variants: <GlossSurfaceVariant>[variant(id: 'low health')]),
        ),
        r'$.variants[0].id',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a duplicated id is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            variants: <GlossSurfaceVariant>[variant(), variant(priority: 20)],
          ),
        ),
        r'$.variants[1].id',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a blank condition is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(variants: <GlossSurfaceVariant>[variant(when: '  ')]),
        ),
        r'$.variants[0].when',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a condition that does not compile is an error', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(variants: <GlossSurfaceVariant>[variant(when: 'viewer.x <')]),
        ),
        r'$.variants[0].when',
      );
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a variant presentation of the wrong kind is an error', () {
      // SurfaceDoc.copyVariants runs forKind on every variant, so a variant
      // that cannot open the document's surface refuses the whole file.
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            surface: glossSurfaceKindBossbar,
            presentation: GlossSurfacePresentation(title: '&6Boss'),
            variants: <GlossSurfaceVariant>[
              variant(
                presentation: GlossSurfacePresentation(text: '&cLow'),
              ),
            ],
          ),
        ),
        r'$.variants[0].presentation.title',
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.message, contains('bossbar'));
    });

    test('a variant is checked for dropped fields too', () {
      final List<HuiIssue> issues = _at(
        validateSurfaceDoc(
          _doc(
            variants: <GlossSurfaceVariant>[
              variant(
                presentation: GlossSurfacePresentation(
                  text: '&cLow',
                  subtitle: '&7dropped',
                ),
              ),
            ],
          ),
        ),
        r'$.variants[0].presentation.subtitle',
      );
      expect(issues.single.severity, HuiSeverity.warning);
    });
  });

  test('a document show condition is validated like every other kind', () {
    final GlossSurfaceDoc doc = _doc();
    doc.extras['show'] = 'not an expression (';
    final List<HuiIssue> issues = _at(validateSurfaceDoc(doc), r'$.show');
    expect(issues.single.severity, HuiSeverity.error);
  });

  test('a broken text expression is reported against the text', () {
    final List<HuiIssue> issues = _at(
      validateSurfaceDoc(
        _doc(
          presentation: GlossSurfacePresentation(text: '{{ viewer.name + }}'),
        ),
      ),
      r'$.presentation.text',
    );
    expect(issues.single.severity, HuiSeverity.warning);
    expect(issues.single.message, contains('cannot run'));
  });

  test('the scoped viewer names are known variables here', () {
    expect(
      validateSurfaceDoc(
        _doc(
          presentation: GlossSurfacePresentation(
            text: '&7Welcome, &f{{ viewer.name }}',
          ),
        ),
      ),
      isEmpty,
    );
  });
}
