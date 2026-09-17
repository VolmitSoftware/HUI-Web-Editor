/// Connection-message validation: what `ConnectionsDoc.java` rejects at parse
/// as errors, and what a standalone server quietly ignores as info.
library;

import 'package:gloss_editor/logic/connections_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

GlossConnectionsDoc _doc({
  String joinText = '&a+ &f{{ subject.name }} &7joined',
  String audience = glossConnectionsAudienceNetwork,
  List<GlossConnectionsVariant>? variants,
  int revision = 1,
}) => GlossConnectionsDoc(
  revision: revision,
  join: GlossConnectionsSection(
    audience: audience,
    presentation: GlossConnectionsPresentation(text: joinText),
    variants: variants,
  ),
  leave: GlossConnectionsSection(
    presentation: GlossConnectionsPresentation(
      text: '&c- &f{{ subject.name }} &7left',
    ),
  ),
);

void main() {
  test('the shipped default validates clean', () {
    expect(validateConnectionsDoc(_doc()), isEmpty);
  });

  test('an out-of-range revision is an error', () {
    final List<HuiIssue> issues = validateConnectionsDoc(_doc(revision: 0));
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.revision');
  });

  group('audience', () {
    test('a spelling the enum does not list is an error', () {
      final List<HuiIssue> issues = validateConnectionsDoc(
        _doc(audience: 'lobby'),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, r'$.join.audience');
      expect(issues.single.message, contains('network'));
      expect(issues.single.message, contains('server'));
    });

    test('a listed spelling is clean; the server simply ignores it', () {
      // The field help carries the proxy note; an info on every document
      // would be noise, not information.
      expect(
        validateConnectionsDoc(_doc(audience: glossConnectionsAudienceServer)),
        isEmpty,
      );
    });
  });

  group('variants', () {
    test('a blank condition is an error — the plugin refuses the file', () {
      final List<HuiIssue> issues = validateConnectionsDoc(
        _doc(
          variants: <GlossConnectionsVariant>[
            GlossConnectionsVariant(
              priority: 1,
              when: '   ',
              presentation: GlossConnectionsPresentation(text: 'x'),
            ),
          ],
        ),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, r'$.join.variants[0].when');
    });

    test('a condition that does not compile is an error', () {
      final List<HuiIssue> issues = validateConnectionsDoc(
        _doc(
          variants: <GlossConnectionsVariant>[
            GlossConnectionsVariant(
              priority: 1,
              when: 'viewer.health <',
              presentation: GlossConnectionsPresentation(text: 'x'),
            ),
          ],
        ),
      );
      expect(issues.single.severity, HuiSeverity.error);
      expect(issues.single.path, r'$.join.variants[0].when');
      expect(issues.single.message, contains('condition'));
    });

    test('a well-formed variant is clean', () {
      expect(
        validateConnectionsDoc(
          _doc(
            variants: <GlossConnectionsVariant>[
              GlossConnectionsVariant(
                priority: 10,
                when: 'viewer.health < 5',
                presentation: GlossConnectionsPresentation(
                  text: '&c{{ subject.name }}',
                ),
              ),
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('text', () {
    test('an enabled section with no text warns', () {
      final List<HuiIssue> issues = validateConnectionsDoc(
        _doc(joinText: '  '),
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.path, r'$.join.presentation.text');
    });

    test(r'$player is a tablist token and warns here', () {
      final List<HuiIssue> issues = validateConnectionsDoc(
        _doc(joinText: r'&a+ $player joined'),
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.path, r'$.join.presentation.text');
      expect(issues.single.message, contains(r'$player'));
      expect(issues.single.message, contains('subject.name'));
    });

    test('a broken text expression is reported against the text', () {
      final List<HuiIssue> issues = validateConnectionsDoc(
        _doc(joinText: '{{ subject.name + }}'),
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.path, r'$.join.presentation.text');
      expect(issues.single.message, contains('cannot run'));
    });

    test('the scoped viewer and subject are known variables here', () {
      // ConnectionsService.render scopes the line to the recipient and the
      // connecting player, so neither name is an unknown-variable warning.
      expect(
        validateConnectionsDoc(
          _doc(joinText: '{{ subject.name }} greets {{ viewer.name }}'),
        ),
        isEmpty,
      );
    });
  });

  test('an off section is not measured for text', () {
    // Section.DISABLED: an absent block broadcasts nothing, so a blank text
    // in it is not a mistake worth a warning.
    final GlossConnectionsDoc doc = GlossConnectionsDoc(
      join: GlossConnectionsSection.absent(),
      leave: GlossConnectionsSection.absent(),
    );
    expect(validateConnectionsDoc(doc), isEmpty);
  });

  test('a document show condition is validated like every other kind', () {
    final GlossConnectionsDoc doc = _doc();
    doc.extras['show'] = 'not an expression (';
    final List<HuiIssue> issues = validateConnectionsDoc(doc);
    expect(issues.single.severity, HuiSeverity.error);
    expect(issues.single.path, r'$.show');
  });
}
