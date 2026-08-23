import 'package:arcane_jaspr/arcane_jaspr.dart' show ArcaneStyleData;

const Map<String, String> huiTechnicalInputAttributes = <String, String>{
  'autocomplete': 'off',
  'spellcheck': 'false',
  'dir': 'ltr',
};

const ArcaneStyleData huiTechnicalInputStyles = ArcaneStyleData(
  raw: <String, String>{
    'direction': 'ltr',
    'unicode-bidi': 'isolate',
    'text-align': 'left',
  },
);
