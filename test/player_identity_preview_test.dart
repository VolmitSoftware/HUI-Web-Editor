import 'package:gloss_editor/components/scoreboard/scoreboard_selection.dart';
import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/player_identity_preview.dart';
import 'package:gloss_editor/logic/gloss_text.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  test('nameplate names inherit workspace nametags with stable priority ties', () {
    final GlossNametagDoc first = GlossNametagDoc(
      presentation: GlossNametagPresentation(prefix: '&b[Member] ', color: 'aqua'),
    );
    final GlossNametagDoc second = GlossNametagDoc(
      presentation: GlossNametagPresentation(prefix: '&c[Staff] ', color: 'red'),
    );
    final GlossConditionContext scope = identityPreviewContext('Builder', <String>{});
    final String identity = resolveIdentityPreviewName(
      <({String id, GlossNametagDoc doc})>[(id: 'z-staff', doc: second), (id: 'a-member', doc: first)],
      scope,
    );
    expect(renderGlossLine(identity).plainText, '[Member] Builder');
    second.select.priority = 10;
    expect(renderGlossLine(resolveIdentityPreviewName(
      <({String id, GlossNametagDoc doc})>[(id: 'z-staff', doc: second), (id: 'a-member', doc: first)], scope,
    )).plainText, '[Staff] Builder');
  });

  test(
    'nametag permissions gate wearer and choose highest matching variant',
    () {
      final GlossNametagDoc doc = buildDefaultGlossNametag();
      expect(
        resolveNametagPreview(
          doc,
          identityPreviewContext('Builder', <String>{}),
        ),
        isNull,
      );
      final GlossConditionContext scope = identityPreviewContext(
        'Builder',
        <String>{'gloss.nametag.default', 'gloss.nametag.staff'},
      );
      expect(resolveNametagPreview(doc, scope)?.prefix, '&c[Staff] ');
      doc.variants.add(
        GlossNametagVariant(
          id: 'higher',
          priority: 20,
          presentation: GlossNametagPresentation(prefix: '&6[Guide] '),
        )..permission = 'gloss.nametag.staff',
      );
      expect(resolveNametagPreview(doc, scope)?.prefix, '&6[Guide] ');
      doc.variants.last.when = 'false';
      expect(resolveNametagPreview(doc, scope)?.prefix, '&c[Staff] ');
      doc.extras['show'] = false;
      expect(resolveNametagPreview(doc, scope), isNull);
    },
  );

  test('nameplate permission rules and variants survive export', () {
    final GlossNameplateDoc doc = buildDefaultGlossNameplate();
    doc.select.permission = 'ranks.member';
    doc.variants.add(
      GlossNameplateVariant(
        id: 'staff',
        priority: 10,
        presentation: GlossNameplatePresentation(
          lines: <GlossNameplateLine>[
            GlossNameplateLine(text: 'Staff {{ subject.name }}'),
          ],
        ),
      )..permission = 'ranks.staff',
    );
    final GlossNameplateDoc decoded = decodeGlossNameplateDoc(
      encodeGlossNameplateDoc(doc),
    );
    expect(
      resolveNameplatePreview(
        decoded,
        identityPreviewContext('Builder', <String>{'ranks.staff'}),
      ),
      isNull,
    );
    expect(
      resolveNameplatePreview(
        decoded,
        identityPreviewContext('Builder', <String>{
          'ranks.member',
          'ranks.staff',
        }),
      )?.lines.single.text,
      'Staff {{ subject.name }}',
    );
    expect(decoded.select.permission, 'ranks.member');
    expect(decoded.variants.single.permission, 'ranks.staff');
  });

  test('omitted nametag selection and variant conditions are active', () {
    final GlossNametagDoc doc = decodeGlossNametagDoc('''
      {"schemaVersion":1,"revision":1,"presentation":{"prefix":"Member "},
       "variants":[{"id":"staff","permission":"ranks.staff","presentation":{"prefix":"Staff "}}]}
    ''');
    expect(
      resolveNametagPreview(
        doc,
        identityPreviewContext('Builder', <String>{}),
      )?.prefix,
      'Member ',
    );
    expect(
      resolveNametagPreview(
        doc,
        identityPreviewContext('Builder', <String>{'ranks.staff'}),
      )?.prefix,
      'Staff ',
    );
  });
}
