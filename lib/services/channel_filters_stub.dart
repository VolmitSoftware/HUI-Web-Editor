library;

Map<String, Object?> run(Map<String, Object?> doc, String message) =>
    <String, Object?>{
      'message': message,
      'notice': 'RE2 filtering preview requires a browser.',
    };

String? validate(Map<String, Object?> doc) => null;
String? validateBehavior(Map<String, Object?> doc) => null;
