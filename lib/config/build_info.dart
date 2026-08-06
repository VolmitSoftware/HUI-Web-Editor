/// Build identity shown in the status bar's version tile.
///
/// CI injects both values with --dart-define (HUI_VERSION from the release
/// tag or pubspec, HUI_COMMIT as the short commit SHA); a plain local build
/// falls back to the pubspec version and "local".
library;

const String huiBuildVersion =
    String.fromEnvironment('HUI_VERSION', defaultValue: '3.1.0');

const String huiBuildCommit =
    String.fromEnvironment('HUI_COMMIT', defaultValue: 'local');

const String huiBuildBadge = '$huiBuildVersion-$huiBuildCommit';
