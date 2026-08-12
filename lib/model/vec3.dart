import 'json_codec.dart';

/// A HoloUI vector. The plugin's Bukkit `Vector` adapter reads exactly three
/// numbers; two or four elements throw and kill the entire menu file.
class Vec3 {
  double x;
  double y;
  double z;

  Vec3(this.x, this.y, this.z);

  Vec3.zero() : x = 0, y = 0, z = 0;

  Vec3 copy() => Vec3(x, y, z);

  List<double> toJson() => <double>[x, y, z];

  static Vec3 fromJson(Object? raw, {String path = 'offset'}) {
    if (raw == null) return Vec3.zero();
    if (raw is! List) {
      throw HuiFormatException('Expected a 3-number array', path);
    }
    if (raw.length != 3) {
      throw HuiFormatException(
        'Expected exactly 3 numbers, found ${raw.length}',
        path,
      );
    }
    return Vec3(
      _component(raw[0], path),
      _component(raw[1], path),
      _component(raw[2], path),
    );
  }

  static double _component(Object? value, String path) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final double? parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw HuiFormatException('Vector components must be numbers', path);
  }

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}
