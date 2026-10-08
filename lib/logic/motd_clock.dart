import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as zones;

bool _initialized = false;

DateTime motdZonedTime(String zone, int epochMillis) {
  if (const <String>{'UTC', 'GMT', 'UT', 'Z'}.contains(zone)) {
    return DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true);
  }
  final RegExpMatch? offset = RegExp(
    r'^(?:(?:UTC|GMT|UT))?([+-])(\d{1,2})(?::?(\d{2}))?(?::?(\d{2}))?$',
  ).firstMatch(zone);
  if (offset != null) {
    final int hours = int.parse(offset.group(2)!);
    final int minutes = int.parse(offset.group(3) ?? '0');
    final int seconds = int.parse(offset.group(4) ?? '0');
    if (hours > 18 ||
        minutes > 59 ||
        seconds > 59 ||
        hours == 18 && (minutes != 0 || seconds != 0)) {
      throw FormatException('Invalid time zone offset', zone);
    }
    final int total =
        (hours * 3600 + minutes * 60 + seconds) *
        (offset.group(1) == '-' ? -1 : 1);
    return DateTime.fromMillisecondsSinceEpoch(
      epochMillis,
      isUtc: true,
    ).add(Duration(seconds: total));
  }
  if (!_initialized) {
    database.initializeTimeZones();
    _initialized = true;
  }
  try {
    return zones.TZDateTime.fromMillisecondsSinceEpoch(
      zones.getLocation(zone),
      epochMillis,
    );
  } on zones.LocationNotFoundException {
    throw FormatException('Unknown time zone', zone);
  }
}

int? motdTimeNanos(String value) {
  final RegExpMatch? match = RegExp(
    r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?$',
  ).firstMatch(value);
  if (match == null) return null;
  final int hours = int.parse(match.group(1)!);
  final int minutes = int.parse(match.group(2)!);
  final int seconds = int.parse(match.group(3) ?? '0');
  if (hours > 23 || minutes > 59 || seconds > 59) return null;
  return (hours * 3600 + minutes * 60 + seconds) * 1000000000 +
      int.parse((match.group(4) ?? '').padRight(9, '0'));
}
