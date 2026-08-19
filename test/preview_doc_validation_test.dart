/// [parseCheckPreviewDoc]: the import dialog's non-blocking expression-syntax
/// check for a container-preview document.
library;

import 'package:gloss_editor/logic/preview_doc_validation.dart';
import 'package:gloss_editor/logic/preview_expr.dart';
import 'package:gloss_editor/logic/validation.dart' show HuiIssue, HuiSeverity;
import 'package:gloss_editor/model/preview_doc.dart';
import 'package:test/test.dart';

void main() {
  group('parseCheckPreviewDoc', () {
    test('a clean document reports no issues', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(
          framed: true,
          title: "'Hello'",
          accent: '#FFFFFFFF',
        ),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: '#FF000000'),
          HuiPreviewElement('label', x: 0, y: 10, text: "'&fLabel'"),
        ],
      );
      expect(parseCheckPreviewDoc(doc), isEmpty);
    });

    test('a numeric or boolean field is never parsed as an expression', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(framed: true),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', x: 0, y: 0, size: 8, color: 0xFF000000),
        ],
      );
      expect(parseCheckPreviewDoc(doc), isEmpty);
    });

    test(
      'a broken element expression is reported with its index and field',
      () {
        final HuiPreviewDoc doc = HuiPreviewDoc(
          elements: <HuiPreviewElement>[
            HuiPreviewElement('cell', size: 8, color: '#FF000000'),
            HuiPreviewElement('cell', size: 8, color: '1 +'),
          ],
        );
        final List<HuiIssue> result = parseCheckPreviewDoc(doc);
        expect(result, hasLength(1));
        expect(result.single.severity, HuiSeverity.error);
        expect(result.single.path, 'elements[1].color');
      },
    );

    test('a broken card expression is reported by field name', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        card: HuiPreviewCard(title: "'unterminated"),
        elements: <HuiPreviewElement>[],
      );
      final List<HuiIssue> result = parseCheckPreviewDoc(doc);
      expect(result, hasLength(1));
      expect(result.single.path, 'card.title');
    });

    test('a broken repeat count is reported under its element', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 8,
            color: '#FF000000',
            repeat: HuiPreviewRepeat(count: '1 +', varName: 'i'),
          ),
        ],
      );
      final List<HuiIssue> result = parseCheckPreviewDoc(doc);
      expect(result, hasLength(1));
      expect(result.single.path, 'elements[0].repeat.count');
    });

    test('several broken fields each report their own path', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement(
            'panel',
            x: '1 +',
            y: 0,
            width: '2 +',
            height: 4,
            color: '#FF000000',
          ),
        ],
      );
      final List<HuiIssue> result = parseCheckPreviewDoc(doc);
      expect(result.map((HuiIssue issue) => issue.path).toSet(), <String>{
        'elements[0].x',
        'elements[0].width',
      });
    });
  });

  group('validatePreviewDoc', () {
    HuiPreviewDoc chestDoc(List<HuiPreviewElement> elements) => HuiPreviewDoc(
      match: HuiPreviewMatch(blocks: <String>['CHEST']),
      elements: elements,
    );

    List<String> paths(List<HuiIssue> issues) =>
        issues.map((HuiIssue issue) => issue.path).toList();

    test('a well-formed document reports no issues', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 8, color: '#FF000000'),
        HuiPreviewElement('slot', size: 18, index: 0),
        HuiPreviewElement('panel', width: 40, height: 20, color: 1),
        HuiPreviewElement('label', text: "'hi'"),
      ]);
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test('missing element type is an error naming the field', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement(''),
      ]);
      final List<HuiIssue> issues = validatePreviewDoc(doc);
      expect(issues, hasLength(1));
      expect(issues.single.path, 'elements[0].type');
      expect(issues.single.severity, HuiSeverity.error);
    });

    test('a document decoded from JSON with no type key still reports it', () {
      final HuiPreviewDoc doc = decodeHuiPreviewDoc('{"elements":[{"x":1}]}');
      expect(doc.elements.single.type, isEmpty);
      final List<HuiIssue> issues = validatePreviewDoc(doc);
      expect(
        issues.where((HuiIssue i) => i.path == 'elements[0].type'),
        hasLength(1),
      );
    });

    test('unknown element type is an error', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('circle'),
      ]);
      final List<HuiIssue> issues = validatePreviewDoc(doc);
      expect(issues.single.path, 'elements[0].type');
      expect(issues.single.message, contains('circle'));
    });

    test('panel requires width, height and color', () {
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[
              HuiPreviewElement('panel', height: 1, color: 1),
            ]),
          ),
        ),
        contains('elements[0].width'),
      );
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[
              HuiPreviewElement('panel', width: 1, color: 1),
            ]),
          ),
        ),
        contains('elements[0].height'),
      );
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[
              HuiPreviewElement('panel', width: 1, height: 1),
            ]),
          ),
        ),
        contains('elements[0].color'),
      );
    });

    test('cell requires size and color', () {
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[HuiPreviewElement('cell', color: 1)]),
          ),
        ),
        contains('elements[0].size'),
      );
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[HuiPreviewElement('cell', size: 4)]),
          ),
        ),
        contains('elements[0].color'),
      );
    });

    test('slot requires size and index', () {
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[HuiPreviewElement('slot', index: 0)]),
          ),
        ),
        contains('elements[0].size'),
      );
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[HuiPreviewElement('slot', size: 18)]),
          ),
        ),
        contains('elements[0].index'),
      );
    });

    test('label requires text', () {
      expect(
        paths(
          validatePreviewDoc(
            chestDoc(<HuiPreviewElement>[HuiPreviewElement('label')]),
          ),
        ),
        contains('elements[0].text'),
      );
    });

    test('repeat.count is required', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement(
          'cell',
          size: 4,
          color: 1,
          repeat: HuiPreviewRepeat(varName: 'i'),
        ),
      ]);
      expect(
        paths(validatePreviewDoc(doc)),
        contains('elements[0].repeat.count'),
      );
    });

    test('constant repeat count over cap is an error mentioning 1024', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement(
          'cell',
          size: 4,
          color: 1,
          repeat: HuiPreviewRepeat(count: 2000),
        ),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].repeat.count');
      expect(issue.severity, HuiSeverity.error);
      expect(issue.message, contains('1024'));
    });

    test('non-constant repeat count skips the cap check', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement(
          'cell',
          size: 4,
          color: 1,
          repeat: HuiPreviewRepeat(count: 'inventory.size'),
        ),
      ]);
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test(
      'total compiled template count over cap is an error mentioning 4096',
      () {
        final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
          for (int i = 0; i < 4; i++)
            HuiPreviewElement(
              'cell',
              size: 4,
              color: 1,
              repeat: HuiPreviewRepeat(count: 1024),
            ),
          HuiPreviewElement('cell', size: 4, color: 1),
        ]);
        final HuiIssue issue = validatePreviewDoc(
          doc,
        ).firstWhere((HuiIssue i) => i.path == 'elements');
        expect(issue.severity, HuiSeverity.error);
        expect(issue.message, contains('4096'));
      },
    );

    test('repeat var must be a valid identifier', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement(
          'cell',
          size: 4,
          color: 1,
          repeat: HuiPreviewRepeat(count: 2, varName: '1bad'),
        ),
      ]);
      expect(
        paths(validatePreviewDoc(doc)),
        contains('elements[0].repeat.var'),
      );
    });

    test('repeat var colliding with a catalog variable is an error', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement(
          'cell',
          size: 4,
          color: 1,
          repeat: HuiPreviewRepeat(count: 2, varName: 'cookTime'),
        ),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].repeat.var');
      expect(issue.message, contains('cookTime'));
    });

    test(
      'repeat var is in scope for other fields but not for its own count',
      () {
        final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 4,
            color: 1,
            x: 'i * 20',
            repeat: HuiPreviewRepeat(count: 3),
          ),
        ]);
        expect(validatePreviewDoc(doc), isEmpty);

        final HuiPreviewDoc badDoc = chestDoc(<HuiPreviewElement>[
          HuiPreviewElement(
            'cell',
            size: 4,
            color: 1,
            repeat: HuiPreviewRepeat(count: 'i'),
          ),
        ]);
        final HuiIssue issue = validatePreviewDoc(
          badDoc,
        ).firstWhere((HuiIssue i) => i.path == 'elements[0].repeat.count');
        expect(issue.message, contains('i'));
      },
    );

    test('a bare name outside any scope is an unknown-variable error', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: 'noSuchThing'),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].x');
      expect(issue.severity, HuiSeverity.error);
      expect(issue.message, contains('noSuchThing'));
    });

    test('a cataloged adapter variable is accepted from any category', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: 'cookTime'),
      ]);
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test('a universal catalog name is accepted', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: 'time'),
      ]);
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test('declared vars are accepted and undeclared vars are rejected', () {
      final HuiPreviewDoc goodDoc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          blocks: <String>['CHEST'],
          vars: <String, dynamic>{'foo': 1},
        ),
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 4, color: 1, x: 'vars.foo'),
        ],
      );
      expect(validatePreviewDoc(goodDoc), isEmpty);

      final HuiPreviewDoc badDoc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 4, color: 1, x: 'vars.bar'),
        ],
      );
      final HuiIssue issue = validatePreviewDoc(
        badDoc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].x');
      expect(issue.message, contains('vars.bar'));
    });

    test('vars declared only on a variant are accepted document-wide', () {
      // The variant deliberately names no blocks/entities of its own (mirrors
      // the plugin's own `varsDeclaredOnAVariantAreAcceptedDocumentWide`), so
      // the document also earns the separate "will never match anything" info
      // — this test only cares that `vars.tint` is not flagged as unknown.
      final HuiPreviewDoc doc = HuiPreviewDoc(
        variants: <HuiPreviewVariant>[
          HuiPreviewVariant(vars: <String, dynamic>{'tint': 1}),
        ],
        elements: <HuiPreviewElement>[
          HuiPreviewElement('cell', size: 4, color: 'vars.tint'),
        ],
      );
      expect(
        validatePreviewDoc(
          doc,
        ).where((HuiIssue i) => i.severity != HuiSeverity.info),
        isEmpty,
      );
    });

    test('an unreserved dotted prefix warns instead of erroring', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: 'adapt.xp'),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].x');
      expect(issue.severity, HuiSeverity.warning);
    });

    test('a reserved-namespace typo is an error', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: 'surge.bogus'),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].x');
      expect(issue.severity, HuiSeverity.error);
      expect(issue.message, contains('surge.bogus'));
    });

    test('a known category root with an unknown specific name is an error', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: 'inventory.bogus'),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].x');
      expect(issue.severity, HuiSeverity.error);
    });

    test('an unknown special value is an error', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(special: 'bogus'),
      );
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'match.special');
      expect(issue.severity, HuiSeverity.error);
    });

    test('every valid special value is accepted', () {
      for (final String special in <String>[
        'enderChest',
        'locked',
        'anyInventoryHolder',
      ]) {
        final HuiPreviewDoc doc = HuiPreviewDoc(
          match: HuiPreviewMatch(special: special),
        );
        expect(validatePreviewDoc(doc), isEmpty, reason: special);
      }
    });

    test('an unknown exact material warns when a catalog is supplied', () {
      // Lowercase, matching the real shape of `HuiCatalogs.materialKeys`
      // (`catalogs.dart` normalizes every key to lowercase) - an uppercase
      // catalog here would mask a casing bug in the membership check, which
      // is exactly what happened before this test was corrected.
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(blocks: <String>['NOT_A_REAL_MATERIAL_XYZ']),
      );
      final List<HuiIssue> issues = validatePreviewDoc(
        doc,
        knownMaterials: <String>{'chest', 'furnace'},
      );
      expect(issues.single.severity, HuiSeverity.warning);
      expect(issues.single.path, 'match.blocks[0]');
    });

    test('an unknown material with no catalog supplied is silent', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(blocks: <String>['NOT_A_REAL_MATERIAL_XYZ']),
      );
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test(
      'an exact material differing only in case from the catalog is not warned',
      () {
        // Regression for a real casing bug: match names are always written in
        // Bukkit enum casing ("FURNACE"), but `HuiCatalogs.materialKeys` -
        // exactly what `EditorStore` passes as `knownMaterials` - is lowercase
        // ("furnace"). A case-sensitive membership check flagged every valid
        // exact block name in every shipped document as unknown.
        final HuiPreviewDoc doc = HuiPreviewDoc(
          match: HuiPreviewMatch(blocks: <String>['FURNACE']),
        );
        final List<HuiIssue> issues = validatePreviewDoc(
          doc,
          knownMaterials: <String>{'furnace', 'blast_furnace', 'smoker'},
        );
        expect(issues, isEmpty);
      },
    );

    test('a glob matching nothing in a supplied catalog is an info', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(blocks: <String>['ZZZZ_NO_MATCH_*']),
      );
      final List<HuiIssue> issues = validatePreviewDoc(
        doc,
        knownMaterials: <String>{'chest', 'furnace'},
      );
      expect(issues.single.severity, HuiSeverity.info);
      expect(issues.single.path, 'match.blocks[0]');
    });

    test('a glob matching something in the supplied catalog is silent', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(blocks: <String>['OAK_*']),
      );
      final List<HuiIssue> issues = validatePreviewDoc(
        doc,
        knownMaterials: <String>{'oak_log', 'furnace'},
      );
      expect(issues, isEmpty);
    });

    test('a non-scalar vars entry is an error', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          vars: <String, dynamic>{
            'bad': <int>[1, 2],
          },
        ),
      );
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'match.vars.bad');
      expect(issue.severity, HuiSeverity.error);
    });

    test('a malformed color-literal vars entry is an error', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(vars: <String, dynamic>{'accent': '#GGGGGG'}),
      );
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'match.vars.accent');
      expect(issue.severity, HuiSeverity.error);
    });

    test('a valid color-literal vars entry is accepted', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          blocks: <String>['CHEST'],
          vars: <String, dynamic>{'accent': '#F2A535'},
        ),
      );
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test('a plain vars string that is not a color literal is left alone', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(
          blocks: <String>['CHEST'],
          vars: <String, dynamic>{'key': 'holoui.preview.theme.title'},
        ),
      );
      expect(validatePreviewDoc(doc), isEmpty);
    });

    test('a document with no match and no variants gets an info nudge', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        elements: <HuiPreviewElement>[HuiPreviewElement('label', text: "'hi'")],
      );
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'match');
      expect(issue.severity, HuiSeverity.info);
    });

    test('a variant naming a block counts as non-empty match', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        variants: <HuiPreviewVariant>[
          HuiPreviewVariant(blocks: <String>['CHEST']),
        ],
      );
      expect(
        validatePreviewDoc(doc).where((HuiIssue i) => i.path == 'match'),
        isEmpty,
      );
    });

    test('division by zero in a constant field names the field path', () {
      final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
        HuiPreviewElement('cell', size: 4, color: 1, x: '1/0'),
      ]);
      final HuiIssue issue = validatePreviewDoc(
        doc,
      ).firstWhere((HuiIssue i) => i.path == 'elements[0].x');
      expect(issue.severity, HuiSeverity.error);
      expect(issue.message, contains('division by zero'));
    });

    test(
      'an element with an invalid type still contributes to the issue list once',
      () {
        final HuiPreviewDoc doc = chestDoc(<HuiPreviewElement>[
          HuiPreviewElement('circle', x: 'noSuchThing'),
        ]);
        // Only the type error - fields of a document with an unrecognised type
        // are never compiled by the plugin either, so the editor does not pile
        // on with an unknown-variable error for a field that would never run.
        expect(validatePreviewDoc(doc), hasLength(1));
      },
    );
  });

  group('previewFlatCatalog / previewReservedNamespaces', () {
    test('the flat catalog contains every group\'s names', () {
      expect(previewFlatCatalog, contains('time'));
      expect(previewFlatCatalog, contains('cookTime'));
      expect(previewFlatCatalog, contains('inventory.size'));
      expect(previewFlatCatalog, contains('surge.active'));
    });

    test('reserved namespaces include the dotted prefix and "vars"', () {
      expect(previewReservedNamespaces, contains('vars'));
      expect(previewReservedNamespaces, contains('inventory'));
      expect(previewReservedNamespaces, contains('surge'));
      expect(previewReservedNamespaces, isNot(contains('adapt')));
    });
  });

  group('previewCheckVariableName', () {
    test('a cataloged name is always accepted', () {
      expect(
        previewCheckVariableName('time', declaredVars: const <String>{}),
        isNull,
      );
    });

    test('vars.<declared> is accepted, vars.<undeclared> is an error', () {
      expect(
        previewCheckVariableName(
          'vars.foo',
          declaredVars: const <String>{'foo'},
        ),
        isNull,
      );
      final PreviewVarProblem? problem = previewCheckVariableName(
        'vars.bar',
        declaredVars: const <String>{'foo'},
      );
      expect(problem?.severity, HuiSeverity.error);
    });

    test('a bare name in scope is accepted, out of scope is an error', () {
      expect(
        previewCheckVariableName(
          'i',
          declaredVars: const <String>{},
          scope: const <String>{'i'},
        ),
        isNull,
      );
      expect(
        previewCheckVariableName('i', declaredVars: const <String>{})?.severity,
        HuiSeverity.error,
      );
    });

    test(
      'a reserved dotted prefix is an error, an unreserved one is a warning',
      () {
        expect(
          previewCheckVariableName(
            'surge.bogus',
            declaredVars: const <String>{},
          )?.severity,
          HuiSeverity.error,
        );
        expect(
          previewCheckVariableName(
            'adapt.xp',
            declaredVars: const <String>{},
          )?.severity,
          HuiSeverity.warning,
        );
      },
    );
  });

  group('previewCollectVarRefs', () {
    test('visits every variable reference, including nested ones', () {
      final PExpr expr = parsePreviewExpr(
        'cookTime > 0 ? vars.a + sin(surge.gain) : palette([i, adapt.xp], 0)',
      );
      final Set<String> names = <String>{};
      previewCollectVarRefs(expr, names.add);
      expect(names, <String>{
        'cookTime',
        'vars.a',
        'surge.gain',
        'i',
        'adapt.xp',
      });
    });

    test('a literal expression visits nothing', () {
      final Set<String> names = <String>{};
      previewCollectVarRefs(parsePreviewExpr("'hi' + 1"), names.add);
      expect(names, isEmpty);
    });
  });

  group('previewIsConstantExpr', () {
    test('literals and pure arithmetic on them are constant', () {
      expect(previewIsConstantExpr(parsePreviewExpr('1 + 2 * 3')), isTrue);
      expect(
        previewIsConstantExpr(parsePreviewExpr("true ? 'a' : 'b'")),
        isTrue,
      );
    });

    test('a variable or a call anywhere makes the whole tree non-constant', () {
      expect(previewIsConstantExpr(parsePreviewExpr('1 + cookTime')), isFalse);
      expect(previewIsConstantExpr(parsePreviewExpr('sin(1)')), isFalse);
      expect(previewIsConstantExpr(parsePreviewExpr('[1, cookTime]')), isFalse);
    });
  });

  group('previewFoldConstantNumber', () {
    test('a num constant folds to itself', () {
      expect(previewFoldConstantNumber(5), 5.0);
    });

    test('a constant arithmetic expression string folds', () {
      expect(previewFoldConstantNumber('2 * 10'), 20.0);
    });

    test('a non-constant expression folds to null', () {
      expect(previewFoldConstantNumber('cookTime'), isNull);
    });

    test('a syntax error folds to null rather than throwing', () {
      expect(previewFoldConstantNumber('1 +'), isNull);
    });

    test('a constant division by zero folds to null rather than throwing', () {
      expect(previewFoldConstantNumber('1 / 0'), isNull);
    });

    test('a bool or null input folds to null', () {
      expect(previewFoldConstantNumber(true), isNull);
      expect(previewFoldConstantNumber(null), isNull);
    });
  });

  group('previewDeclaredVars', () {
    test('collects the document\'s own vars and every variant\'s', () {
      final HuiPreviewDoc doc = HuiPreviewDoc(
        match: HuiPreviewMatch(vars: <String, dynamic>{'a': 1}),
        variants: <HuiPreviewVariant>[
          HuiPreviewVariant(vars: <String, dynamic>{'b': 2}),
          HuiPreviewVariant(vars: <String, dynamic>{'c': 3}),
        ],
      );
      expect(previewDeclaredVars(doc), <String>{'a', 'b', 'c'});
    });
  });

  group('previewSuggestExprTokens', () {
    test(
      'suggests a bare catalog name once the token reaches the minimum length',
      () {
        final List<String> suggestions = previewSuggestExprTokens(
          'coo',
          declaredVars: const <String>{},
          scope: const <String>{},
        );
        expect(suggestions, contains('cookTime'));
      },
    );

    test('a bare token below the minimum length suggests nothing', () {
      // 't' is a prefix of the catalog's own "time", but a single bare
      // character would open a list of dozens of names before the user has
      // typed anything to narrow it with - this is the exact regression the
      // review caught: with the old '.'-only gate every bare name (22 of 26
      // catalog entries) was unreachable no matter how much was typed, and
      // this case proves the new gate does not swing to the other extreme.
      expect(
        previewSuggestExprTokens(
          't',
          declaredVars: const <String>{},
          scope: const <String>{},
        ),
        isEmpty,
      );
    });

    test(
      'a dotted token fires immediately, even with nothing typed after the dot',
      () {
        final List<String> suggestions = previewSuggestExprTokens(
          'inventory.',
          declaredVars: const <String>{},
          scope: const <String>{},
        );
        expect(
          suggestions,
          containsAll(<String>['inventory.size', 'inventory.occupied']),
        );
      },
    );

    test('offers vars.<declared> and nothing else under the vars. prefix', () {
      final List<String> suggestions = previewSuggestExprTokens(
        'vars.a',
        declaredVars: const <String>{'accent', 'fill'},
        scope: const <String>{},
      );
      expect(suggestions, <String>['vars.accent']);
    });

    test(
      'offers a repeat variable from scope once it reaches the minimum length',
      () {
        final List<String> suggestions = previewSuggestExprTokens(
          'id',
          declaredVars: const <String>{},
          scope: const <String>{'idx'},
        );
        expect(suggestions, contains('idx'));
      },
    );

    test('excludes an exact match to the token but keeps a longer sibling', () {
      // "cookTime" is itself a complete catalog entry AND a strict prefix of
      // "cookTimeTotal": typing it in full should drop it from its own
      // suggestion list (nothing left to complete) while still offering the
      // sibling entry that extends it.
      final List<String> suggestions = previewSuggestExprTokens(
        'cookTime',
        declaredVars: const <String>{},
        scope: const <String>{},
      );
      expect(suggestions, isNot(contains('cookTime')));
      expect(suggestions, contains('cookTimeTotal'));
    });

    test('merges catalog, vars and scope sources and sorts the result', () {
      final List<String> suggestions = previewSuggestExprTokens(
        'vars.a',
        declaredVars: const <String>{'accentDim', 'accent'},
        scope: const <String>{},
      );
      expect(suggestions, <String>['vars.accent', 'vars.accentDim']);
    });

    test('an empty draft suggests nothing', () {
      expect(
        previewSuggestExprTokens(
          '',
          declaredVars: const <String>{},
          scope: const <String>{},
        ),
        isEmpty,
      );
    });

    test('a token nothing starts with suggests nothing', () {
      expect(
        previewSuggestExprTokens(
          'zzqq',
          declaredVars: const <String>{},
          scope: const <String>{},
        ),
        isEmpty,
      );
    });
  });
}
