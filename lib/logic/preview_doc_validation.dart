/// Structural parse-check for an imported container-preview document.
///
/// This is deliberately narrower than the semantic validation a later task
/// adds (required fields per element type, repeat caps, match sanity,
/// mirroring the Java parser's hard-fail rules): it only runs every raw
/// expression-string field through [parsePreviewExpr] and reports a syntax
/// failure, exactly the way the import dialog already treats menu validation
/// issues — informational, never blocking. A document whose JSON itself does
/// not parse is rejected before this ever runs; a document that parses but
/// carries a broken expression is still imported, because an editor that
/// refuses to open a slightly-broken document can't be used to fix it.
///
/// DOM-free: pure logic, runs on the VM under `dart test`.
library;

import 'preview_expr.dart';
import 'particle_layer_validation.dart';
import 'preview_expr_functions.dart' show previewStandardFunctionNames;
import 'preview_sim.dart'
    show
        kLegacyPreviewLangPrefix,
        previewRenamedLangKey,
        previewSimGroupVariables,
        previewStandardVariableNames;
import 'preview_variant_resolver.dart' show previewMatchesGlob;
import 'validation.dart';
import '../model/preview_doc.dart';

/// Parses (never evaluates) every expression-string field of [doc] and
/// returns one [HuiIssue] per syntax failure, its `path` naming the field
/// (`elements[3].color`, `card.title`, ...). A `num`/`bool` field is a
/// constant, not an expression, and is skipped — only a `String` value is
/// ever parsed.
List<HuiIssue> parseCheckPreviewDoc(HuiPreviewDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[];
  issues.addAll(validateParticleLayers(doc.particleLayers));

  void check(Object? raw, String path) {
    if (raw is! String) return;
    try {
      parsePreviewExpr(raw);
    } on PExprException catch (e) {
      issues.add(
        HuiIssue(
          severity: HuiSeverity.error,
          path: path,
          message: e.englishMessage,
          messageArguments: e.arguments,
        ),
      );
    }
  }

  check(previewShowExpression(doc.show), 'show');
  final HuiPreviewCard? card = doc.card;
  if (card != null) {
    check(previewShowExpression(card.show), 'card.show');
    check(card.framed, 'card.framed');
    check(card.title, 'card.title');
    check(card.accent, 'card.accent');
  }

  for (int i = 0; i < doc.elements.length; i++) {
    final HuiPreviewElement element = doc.elements[i];
    final String path = 'elements[$i]';
    check(element.x, '$path.x');
    check(element.y, '$path.y');
    check(element.z, '$path.z');
    check(element.width, '$path.width');
    check(element.height, '$path.height');
    check(element.size, '$path.size');
    check(element.color, '$path.color');
    check(element.wellColor, '$path.wellColor');
    check(element.index, '$path.index');
    check(element.background, '$path.background');
    check(element.text, '$path.text');
    check(element.visible, '$path.visible');
    check(previewShowExpression(element.show), '$path.show');
    check(element.repeat?.count, '$path.repeat.count');
  }

  return issues;
}

// ---------------------------------------------------------------------------
// Variable-name checking, shared by [validatePreviewDoc] below and by the
// inspector's inline expression-field warnings.
// ---------------------------------------------------------------------------

/// Every adapter/state variable name any simulated category publishes: the
/// editor's mirror of `PreviewDocumentParser.flatCatalog`, built from
/// [previewSimGroupVariables] (the editor's own port of
/// `PreviewStateAdapters.catalog()`) rather than retyped. A cataloged name is
/// accepted in ANY document regardless of which category it actually gets
/// simulated against — `knownAdapterVariableFromAnyCategoryIsAccepted` in the
/// plugin's parser tests — because a compiled document is not statically
/// bound to one category.
final Set<String> previewFlatCatalog = <String>{
  for (final List<String> group in previewSimGroupVariables.values) ...group,
  ...previewStandardVariableNames,
};

/// Functions available to every compiled preview expression. A chosen
/// autocomplete entry includes `(` so the next keystroke is the first
/// argument, while variable suggestions remain bare identifiers.
const List<String> previewExpressionFunctionNames = <String>[
  'lang',
  'count',
  'occupied',
  'item',
  'papi',
  'papiNumber',
  'metric',
  ...previewStandardFunctionNames,
];

/// Every name a provider namespace may not take: each cataloged variable, the
/// first segment of the dotted ones (`inventory`, `surge`), and `vars`. Port
/// of `PreviewStateAdapters.reservedNamespaces`.
final Set<String> previewReservedNamespaces = <String>{
  'vars',
  for (final String name in previewFlatCatalog) ...<String>[
    name,
    if (name.contains('.')) name.substring(0, name.indexOf('.')),
  ],
};

/// One problem with a single `PVar` reference: either a hard failure the
/// plugin itself refuses to compile, or a soft warning it logs and still
/// compiles ([HuiSeverity.warning] for an unreserved provider namespace).
class PreviewVarProblem {
  const PreviewVarProblem(
    this.severity,
    this.message, [
    this.messageArguments = const <String, Object?>{},
  ]);

  final HuiSeverity severity;
  final String message;
  final Map<String, Object?> messageArguments;
}

/// Port of `PreviewDocumentParser.checkVariableName`. [declaredVars] is every
/// name declared in the document's own `match.vars` plus every variant's
/// `vars` — document-wide, per
/// `varsDeclaredOnAVariantAreAcceptedDocumentWide`. [scope] is the current
/// element's repeat variable name, or empty when the field being checked is
/// outside any repeat (or is the repeat's own `count`, which is evaluated
/// before its variable comes into scope).
PreviewVarProblem? previewCheckVariableName(
  String name, {
  required Set<String> declaredVars,
  Set<String> scope = const <String>{},
}) {
  if (previewFlatCatalog.contains(name)) return null;
  if (name.startsWith('vars.')) {
    if (declaredVars.contains(name.substring('vars.'.length))) return null;
    return PreviewVarProblem(
      HuiSeverity.error,
      'Unknown variable: {name}',
      <String, Object?>{'name': name},
    );
  }
  final int dot = name.indexOf('.');
  if (dot < 0) {
    if (scope.contains(name)) return null;
    return PreviewVarProblem(
      HuiSeverity.error,
      'Unknown variable: {name}',
      <String, Object?>{'name': name},
    );
  }
  final String prefix = name.substring(0, dot);
  if (previewReservedNamespaces.contains(prefix)) {
    return PreviewVarProblem(
      HuiSeverity.error,
      'Unknown variable: {name}',
      <String, Object?>{'name': name},
    );
  }
  return PreviewVarProblem(
    HuiSeverity.warning,
    '{name} references provider namespace "{prefix}", which nothing currently '
    'cataloged publishes. It may be supplied by another plugin at runtime, or '
    'it may be a typo.',
    <String, Object?>{'name': name, 'prefix': prefix},
  );
}

/// Visits every `PVar` name referenced anywhere in [expr] — inside list
/// literals, unary/binary operands, ternary branches and call arguments. A
/// function's own name is never visited: names are never dotted the way a
/// variable is, and the parser never validates a function name statically
/// either (an unknown one is only ever caught by evaluating it).
void previewCollectVarRefs(PExpr expr, void Function(String name) visit) {
  switch (expr) {
    case PVar(name: final String name):
      visit(name);
    case PList(items: final List<PExpr> items):
      for (final PExpr item in items) {
        previewCollectVarRefs(item, visit);
      }
    case PUnary(operand: final PExpr operand):
      previewCollectVarRefs(operand, visit);
    case PBinary(left: final PExpr left, right: final PExpr right):
      previewCollectVarRefs(left, visit);
      previewCollectVarRefs(right, visit);
    case PTernary(
      condition: final PExpr condition,
      ifTrue: final PExpr ifTrue,
      ifFalse: final PExpr ifFalse,
    ):
      previewCollectVarRefs(condition, visit);
      previewCollectVarRefs(ifTrue, visit);
      previewCollectVarRefs(ifFalse, visit);
    case PCall(args: final List<PExpr> args):
      for (final PExpr arg in args) {
        previewCollectVarRefs(arg, visit);
      }
    case PNum():
    case PStr():
    case PBool():
      break;
  }
}

/// Visits every `PStr` literal anywhere in [expr], mirroring
/// [previewCollectVarRefs]'s traversal — used to spot legacy
/// `holoui.preview.*` lang keys passed to `lang()` or concatenated into text.
void _previewCollectStrLiterals(PExpr expr, void Function(String value) visit) {
  switch (expr) {
    case PStr(value: final String value):
      visit(value);
    case PList(items: final List<PExpr> items):
      for (final PExpr item in items) {
        _previewCollectStrLiterals(item, visit);
      }
    case PUnary(operand: final PExpr operand):
      _previewCollectStrLiterals(operand, visit);
    case PBinary(left: final PExpr left, right: final PExpr right):
      _previewCollectStrLiterals(left, visit);
      _previewCollectStrLiterals(right, visit);
    case PTernary(
      condition: final PExpr condition,
      ifTrue: final PExpr ifTrue,
      ifFalse: final PExpr ifFalse,
    ):
      _previewCollectStrLiterals(condition, visit);
      _previewCollectStrLiterals(ifTrue, visit);
      _previewCollectStrLiterals(ifFalse, visit);
    case PCall(args: final List<PExpr> args):
      for (final PExpr arg in args) {
        _previewCollectStrLiterals(arg, visit);
      }
    case PNum():
    case PVar():
    case PBool():
      break;
  }
}

/// True when [expr] contains no `PVar` and no `PCall` anywhere in its tree —
/// the editor's mirror of the plugin's `ExprEvaluator.isConstant`. A call is
/// never folded even with constant arguments: folding runs against an empty
/// scope with no function library wired in, so attempting one would flag
/// every document that uses a pure function like `sin(1)` in an otherwise
/// constant field as broken.
bool previewIsConstantExpr(PExpr expr) {
  switch (expr) {
    case PNum():
    case PStr():
    case PBool():
      return true;
    case PList(items: final List<PExpr> items):
      return items.every(previewIsConstantExpr);
    case PVar():
    case PCall():
      return false;
    case PUnary(operand: final PExpr operand):
      return previewIsConstantExpr(operand);
    case PBinary(left: final PExpr left, right: final PExpr right):
      return previewIsConstantExpr(left) && previewIsConstantExpr(right);
    case PTernary(
      condition: final PExpr condition,
      ifTrue: final PExpr ifTrue,
      ifFalse: final PExpr ifFalse,
    ):
      return previewIsConstantExpr(condition) &&
          previewIsConstantExpr(ifTrue) &&
          previewIsConstantExpr(ifFalse);
  }
}

class _PreviewEmptyScope implements PExprScope {
  const _PreviewEmptyScope();

  @override
  Object? variable(String dottedName) => null;

  @override
  Object? call(String name, List<Object?> args) => null;
}

/// Never actually reached: every expression handed to it has already been
/// proven constant by [previewIsConstantExpr], which is false for any tree
/// containing a `PVar` or `PCall`.
const PExprScope _previewEmptyScope = _PreviewEmptyScope();

/// The constant number [raw] folds to, or null when it is not one: a `num`
/// constant, or a `String` expression that is [previewIsConstantExpr] and
/// evaluates to a `double`. Mirrors `PreviewDocumentParser.fold`/`compileNumericField`
/// restricted to the numeric, already-constant case; a syntax error or a
/// genuinely non-constant expression both fold to null rather than throwing —
/// callers that care about the syntax error see it separately, from parsing
/// the same field for variable references.
double? previewFoldConstantNumber(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is! String) return null;
  final PExpr expr;
  try {
    expr = parsePreviewExpr(raw);
  } on PExprException {
    return null;
  }
  if (!previewIsConstantExpr(expr)) return null;
  try {
    final Object value = evalPreviewExpr(expr, _previewEmptyScope);
    return value is double ? value : null;
  } on PExprException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Document-level semantic validation
// ---------------------------------------------------------------------------

final Set<String> _previewElementTypeSet = previewElementTypes.toSet();

const Set<String> _previewSpecialValueSet = <String>{
  'enderChest',
  'locked',
  'anyInventoryHolder',
};

final RegExp _previewIdentifierPattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Cap on a constant `repeat.count`, ported from
/// `PreviewDocumentParser.MAX_REPEAT_COUNT`.
const int previewMaxRepeatCount = 1024;

/// Cap on the compiled element total after expanding every repeat, ported
/// from `PreviewDocumentParser.MAX_TOTAL_TEMPLATES`.
const int previewMaxTotalTemplates = 4096;

/// Every name reachable as `vars.<name>` anywhere in [doc]: the document's own
/// `match.vars` plus every variant's `vars`, document-wide (a variant's own
/// vars are readable from any field, not just that variant's own match — see
/// `varsDeclaredOnAVariantAreAcceptedDocumentWide`). Shared by
/// [validatePreviewDoc] and the inspector's autocomplete list, so the two can
/// never disagree on what `vars.` offers.
Set<String> previewDeclaredVars(HuiPreviewDoc doc) => <String>{
  ...doc.match.vars.keys,
  for (final HuiPreviewVariant variant in doc.variants) ...variant.vars.keys,
};

// ---------------------------------------------------------------------------
// Expression-field autocomplete: DOM-free suggestion-source logic shared by
// `PreviewExprField` (which owns the draft text and the click handling; this
// file only decides WHAT to suggest and WHEN).
// ---------------------------------------------------------------------------

/// Trailing identifier-ish run at the very end of a draft, used both to
/// decide whether to offer suggestions and to know how much of the text a
/// chosen suggestion replaces. Deliberately anchored to the end of the string
/// rather than the caret: plain `<input>` elements do not report caret
/// position through Jaspr's event model, and most typing happens at the end
/// of a short expression anyway.
final RegExp previewTrailingExprToken = RegExp(r'[A-Za-z_][A-Za-z0-9_.]*$');

/// Minimum length of a BARE (non-dotted) trailing token before suggestions
/// fire. A dotted token fires from its first character — typing a lone `.`
/// after a namespace is already a strong enough signal — but most catalog
/// names are bare (`cookTime`, `time`, `lit`, ...) and a repeat variable is
/// always bare, so gating every bare name on a literal dot (an earlier
/// version of the field did exactly that) made the catalog and scope sources
/// unreachable: only `vars.*` could ever be suggested. Two characters keeps a
/// single letter from opening a list of several dozen names before there is
/// anything to narrow it with.
const int previewSuggestMinBareLength = 2;

/// Every suggestion for the trailing identifier-ish token in [text]: the flat
/// catalog, functions, `vars.<name>` for each of [declaredVars], and the current
/// element's repeat [scope] — merged, filtered to names that start with the
/// token, excluding an exact match to the token itself (nothing left to
/// complete once it is already typed in full), sorted and capped at eight.
List<String> previewSuggestExprTokens(
  String text, {
  required Set<String> declaredVars,
  required Set<String> scope,
}) {
  final RegExpMatch? match = previewTrailingExprToken.firstMatch(text);
  if (match == null) return const <String>[];
  final String token = match.group(0)!;
  if (!token.contains('.') && token.length < previewSuggestMinBareLength) {
    return const <String>[];
  }
  final Set<String> source = <String>{
    ...previewFlatCatalog,
    for (final String name in previewExpressionFunctionNames) '$name(',
    for (final String name in declaredVars) 'vars.$name',
    ...scope,
  };
  final List<String> matches =
      source
          .where((String name) => name != token && name.startsWith(token))
          .toList()
        ..sort();
  return matches.take(8).toList();
}

/// Semantic validation of [doc] against the Java parser's real rules
/// (`PreviewDocumentParserTest`), reported as [HuiIssue]s rather than thrown.
///
/// This is deliberately non-blocking, unlike the parser it mirrors: the
/// editor must still be able to open and keep editing a document the plugin
/// would refuse to load, which is why every rule below is a severity flag
/// rather than an exception. A rule the plugin hard-fails on is reported as
/// [HuiSeverity.error]; one it logs a warning for and still compiles is
/// [HuiSeverity.warning]; a rule that is purely an editor convenience (a glob
/// that currently matches nothing, a document that will never be selected for
/// anything) is [HuiSeverity.info].
///
/// [knownMaterials] and [knownEntityTypes] are optional catalogs: membership
/// and glob-match checks against them are skipped for whichever one is
/// omitted or empty, exactly like [validateHuiMenu]'s own catalog parameters.
List<HuiIssue> validatePreviewDoc(
  HuiPreviewDoc doc, {
  Set<String>? knownMaterials,
  Set<String>? knownEntityTypes,
}) {
  final List<HuiIssue> issues = <HuiIssue>[];

  void add(
    HuiSeverity severity,
    String path,
    String message, {
    String? fix,
    Map<String, Object?> messageArguments = const <String, Object?>{},
    Map<String, Object?> fixArguments = const <String, Object?>{},
  }) {
    issues.add(
      HuiIssue(
        severity: severity,
        path: path,
        message: message,
        messageArguments: messageArguments,
        fix: fix,
        fixArguments: fixArguments,
      ),
    );
  }

  final Set<String> declaredVars = previewDeclaredVars(doc);

  void warnLegacyLangKey(String value, String path) {
    if (!value.startsWith(kLegacyPreviewLangPrefix)) return;
    add(
      HuiSeverity.warning,
      path,
      "Lang key \"{value}\" uses the legacy \"{kLegacyPreviewLangPrefix}\" prefix, renamed in Gloss; imported docs are rewritten on import.",
      fix: "Use \"{previewRenamedLangKey}\".",
      messageArguments: <String, Object?>{
        'value': value,
        'kLegacyPreviewLangPrefix': kLegacyPreviewLangPrefix,
      },
      fixArguments: <String, Object?>{
        'previewRenamedLangKey': previewRenamedLangKey(value),
      },
    );
  }

  /// Parses [raw] (when it is an expression string) and checks every
  /// variable reference plus, when the whole expression is constant, that it
  /// evaluates cleanly (catching a constant division by zero, for instance).
  /// A `num`/`bool` constant has nothing to check and is a no-op.
  void checkExpr(
    Object? raw,
    String path,
    Set<String> scope, {
    bool requireBoolean = false,
  }) {
    if (raw is! String) {
      if (requireBoolean && raw != null && raw is! bool) {
        add(
          HuiSeverity.error,
          path,
          '{field}: must be a boolean or a string expression',
          messageArguments: <String, Object?>{'field': path},
        );
      }
      return;
    }
    final PExpr expr;
    try {
      expr = parsePreviewExpr(raw);
    } on PExprException catch (e) {
      if (e.position == previewNoPosition) {
        add(
          HuiSeverity.error,
          path,
          e.englishMessage,
          messageArguments: e.arguments,
        );
      } else {
        add(
          HuiSeverity.error,
          path,
          '{message} at character {position}',
          messageArguments: <String, Object?>{
            'message': e.localizedMessageArgument,
            'position': e.position,
          },
        );
      }
      return;
    }
    previewCollectVarRefs(expr, (String name) {
      final PreviewVarProblem? problem = previewCheckVariableName(
        name,
        declaredVars: declaredVars,
        scope: scope,
      );
      if (problem != null) {
        add(
          problem.severity,
          path,
          problem.message,
          messageArguments: problem.messageArguments,
        );
      }
    });
    _previewCollectStrLiterals(expr, (String value) {
      warnLegacyLangKey(value, path);
    });
    if (previewIsConstantExpr(expr)) {
      try {
        if (requireBoolean) {
          evalBool(expr, _previewEmptyScope);
        } else {
          evalPreviewExpr(expr, _previewEmptyScope);
        }
      } on PExprException catch (e) {
        add(
          HuiSeverity.error,
          path,
          e.englishMessage,
          messageArguments: e.arguments,
        );
      }
    }
  }

  void checkVarsMap(Map<String, dynamic> vars, String pathPrefix) {
    vars.forEach((String key, dynamic value) {
      if (value is num || value is bool) return;
      final String path = '$pathPrefix.$key';
      if (value is String) {
        warnLegacyLangKey(value, path);
        if (!value.startsWith('#')) return;
        try {
          final PExpr expr = parsePreviewExpr(value);
          if (expr is! PNum) {
            add(
              HuiSeverity.error,
              path,
              "Invalid color literal \"{value}\".",
              messageArguments: <String, Object?>{'value': value},
            );
          }
        } on PExprException catch (e) {
          add(
            HuiSeverity.error,
            path,
            "Invalid color literal \"{value}\": {message}",
            messageArguments: <String, Object?>{
              'value': value,
              'message': e.message,
            },
          );
        }
        return;
      }
      add(
        HuiSeverity.error,
        path,
        'Must be a number, boolean, or string constant.',
      );
    });
  }

  void checkSpecial(String? special, String path) {
    if (special == null) return;
    if (!_previewSpecialValueSet.contains(special)) {
      add(
        HuiSeverity.error,
        path,
        "Unknown special value \"{special}\"; must be one of {join}.",
        messageArguments: <String, Object?>{
          'special': special,
          'join': _previewSpecialValueSet.join(", "),
        },
      );
    }
  }

  void checkNames(
    List<String> names,
    String pathPrefix,
    Set<String>? known,
    String kind,
  ) {
    for (int i = 0; i < names.length; i++) {
      final String raw = names[i];
      final String upper = raw.toUpperCase();
      final String path = '$pathPrefix[$i]';
      if (upper.contains('*')) {
        if (known != null && known.isNotEmpty) {
          final bool anyMatch = known.any(
            (String candidate) =>
                previewMatchesGlob(upper, candidate.toUpperCase()),
          );
          if (!anyMatch) {
            add(
              HuiSeverity.info,
              path,
              "Glob \"{raw}\" does not currently match any known {kind}.",
              fix:
                  'Double check the pattern; a target added later can still '
                  'match it.',
              messageArguments: <String, Object?>{'raw': raw, 'kind': kind},
            );
          }
        }
        continue;
      }
      // Catalog keys are the server's own registry casing (lowercase, e.g.
      // "furnace" from `HuiCatalogs.materialKeys`), while every match name in
      // this format is written in Bukkit enum casing (e.g. "FURNACE") -
      // compare case-insensitively so a perfectly valid exact name never
      // warns as unknown.
      if (known != null &&
          known.isNotEmpty &&
          !known.any((String candidate) => candidate.toUpperCase() == upper)) {
        add(
          HuiSeverity.warning,
          path,
          "Unknown {kind} \"{raw}\"; it may still be valid on a newer server.",
          messageArguments: <String, Object?>{'kind': kind, 'raw': raw},
        );
      }
    }
  }

  // --- match / variants ------------------------------------------------
  checkSpecial(doc.match.special, 'match.special');
  checkNames(
    doc.match.blocks,
    'match.blocks',
    knownMaterials,
    'block material',
  );
  checkNames(
    doc.match.entities,
    'match.entities',
    knownEntityTypes,
    'entity type',
  );
  checkVarsMap(doc.match.vars, 'match.vars');

  bool anyVariantMatches = false;
  for (int i = 0; i < doc.variants.length; i++) {
    final HuiPreviewVariant variant = doc.variants[i];
    checkSpecial(variant.special, 'variants[$i].special');
    checkNames(
      variant.blocks,
      'variants[$i].blocks',
      knownMaterials,
      'block material',
    );
    checkNames(
      variant.entities,
      'variants[$i].entities',
      knownEntityTypes,
      'entity type',
    );
    checkVarsMap(variant.vars, 'variants[$i].vars');
    if (variant.blocks.isNotEmpty ||
        variant.entities.isNotEmpty ||
        variant.special != null) {
      anyVariantMatches = true;
    }
  }

  final bool matchEmpty =
      doc.match.blocks.isEmpty &&
      doc.match.entities.isEmpty &&
      doc.match.special == null;
  if (matchEmpty && !anyVariantMatches) {
    add(
      HuiSeverity.info,
      'match',
      'This document declares no blocks, entities or special marker, and '
          'neither does any variant, so it will never be selected for '
          'anything in game.',
      fix: 'Add at least one block or entity to match, or a special value.',
    );
  }

  // --- card --------------------------------------------------------------
  checkExpr(
    previewShowExpression(doc.show),
    'show',
    const <String>{},
    requireBoolean: true,
  );
  final HuiPreviewCard? card = doc.card;
  if (card != null) {
    checkExpr(
      previewShowExpression(card.show),
      'card.show',
      const <String>{},
      requireBoolean: true,
    );
    checkExpr(card.framed, 'card.framed', const <String>{});
    checkExpr(card.title, 'card.title', const <String>{});
    checkExpr(card.accent, 'card.accent', const <String>{});
  }

  // --- elements ------------------------------------------------------------
  int totalTemplateCount = 0;
  for (int i = 0; i < doc.elements.length; i++) {
    final HuiPreviewElement element = doc.elements[i];
    final String path = 'elements[$i]';
    final String type = element.type;

    if (!_previewElementTypeSet.contains(type)) {
      add(
        HuiSeverity.error,
        '$path.type',
        type.isEmpty
            ? 'Element type is required: one of panel, cell, slot, label.'
            : 'Unknown element type "$type"; must be one of panel, cell, '
                  'slot, label.',
      );
      totalTemplateCount += 1;
      // The plugin never even reads the rest of an element whose type it
      // does not recognise; piling on more issues for fields that would
      // never run would be noise, not help.
      continue;
    }

    Set<String> scope = const <String>{};
    final HuiPreviewRepeat? repeat = element.repeat;
    if (repeat != null) {
      final String varName = (repeat.varName == null || repeat.varName!.isEmpty)
          ? 'i'
          : repeat.varName!;
      if (!_previewIdentifierPattern.hasMatch(varName)) {
        add(
          HuiSeverity.error,
          '$path.repeat.var',
          "Repeat var \"{varName}\" must be a valid identifier.",
          messageArguments: <String, Object?>{'varName': varName},
        );
      } else if (varName == 'vars' || previewFlatCatalog.contains(varName)) {
        add(
          HuiSeverity.error,
          '$path.repeat.var',
          "Repeat var \"{varName}\" collides with a reserved variable name and would be unreachable.",
          messageArguments: <String, Object?>{'varName': varName},
        );
      } else {
        scope = <String>{varName};
      }

      double? countConstant;
      if (repeat.count == null) {
        add(
          HuiSeverity.error,
          '$path.repeat.count',
          'repeat.count is required.',
        );
      } else {
        // The count itself is evaluated in an EMPTY scope: the repeat var is
        // not in scope for its own count expression.
        checkExpr(repeat.count, '$path.repeat.count', const <String>{});
        countConstant = previewFoldConstantNumber(repeat.count);
        if (countConstant != null && countConstant > previewMaxRepeatCount) {
          add(
            HuiSeverity.error,
            '$path.repeat.count',
            "Constant repeat count {previewFormatNumber} exceeds {previewMaxRepeatCount}.",
            messageArguments: <String, Object?>{
              'previewFormatNumber': _previewFormatNumber(countConstant),
              'previewMaxRepeatCount': previewMaxRepeatCount,
            },
          );
        }
      }
      totalTemplateCount += countConstant == null
          ? 1
          : (countConstant.floor() < 0 ? 0 : countConstant.floor());
    } else {
      totalTemplateCount += 1;
    }

    checkExpr(element.x, '$path.x', scope);
    checkExpr(element.y, '$path.y', scope);
    checkExpr(element.z, '$path.z', scope);
    checkExpr(element.visible, '$path.visible', scope);
    checkExpr(
      previewShowExpression(element.show),
      '$path.show',
      scope,
      requireBoolean: true,
    );

    switch (type) {
      case 'panel':
        if (element.width == null) {
          add(
            HuiSeverity.error,
            '$path.width',
            'width is required for type panel.',
          );
        } else {
          checkExpr(element.width, '$path.width', scope);
        }
        if (element.height == null) {
          add(
            HuiSeverity.error,
            '$path.height',
            'height is required for type panel.',
          );
        } else {
          checkExpr(element.height, '$path.height', scope);
        }
        if (element.color == null) {
          add(
            HuiSeverity.error,
            '$path.color',
            'color is required for type panel.',
          );
        } else {
          checkExpr(element.color, '$path.color', scope);
        }
      case 'cell':
        if (element.size == null) {
          add(
            HuiSeverity.error,
            '$path.size',
            'size is required for type cell.',
          );
        } else {
          checkExpr(element.size, '$path.size', scope);
        }
        if (element.color == null) {
          add(
            HuiSeverity.error,
            '$path.color',
            'color is required for type cell.',
          );
        } else {
          checkExpr(element.color, '$path.color', scope);
        }
      case 'slot':
        if (element.size == null) {
          add(
            HuiSeverity.error,
            '$path.size',
            'size is required for type slot.',
          );
        } else {
          checkExpr(element.size, '$path.size', scope);
        }
        if (element.index == null) {
          add(
            HuiSeverity.error,
            '$path.index',
            'index is required for type slot.',
          );
        } else {
          checkExpr(element.index, '$path.index', scope);
        }
        if (element.wellColor != null) {
          checkExpr(element.wellColor, '$path.wellColor', scope);
        }
      case 'label':
        if (element.text == null) {
          add(
            HuiSeverity.error,
            '$path.text',
            'text is required for type label.',
          );
        } else {
          checkExpr(element.text, '$path.text', scope);
        }
        if (element.background != null) {
          checkExpr(element.background, '$path.background', scope);
        }
    }
  }

  if (totalTemplateCount > previewMaxTotalTemplates) {
    add(
      HuiSeverity.error,
      'elements',
      "Total compiled element count ({totalTemplateCount}, after expanding repeats) exceeds {previewMaxTotalTemplates}.",
      messageArguments: <String, Object?>{
        'totalTemplateCount': totalTemplateCount,
        'previewMaxTotalTemplates': previewMaxTotalTemplates,
      },
    );
  }

  return issues;
}

String _previewFormatNumber(double value) {
  if (value.isFinite && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
