/// Vectors and 4x4 matrices for the GL side, column-major like
/// `projection.dart` and css `matrix3d()`, so nothing is ever transposed.
///
/// World frame: +X east, +Y up, +Z south (Minecraft's), right-handed. The
/// menu preview's authoring frame mirrors X; `mc_projection_bridge.dart` is
/// where that meets this.
library;

import 'dart:math' as math;
import 'dart:typed_data';

const double _degToRad = math.pi / 180;

final class McVec3 {
  const McVec3(this.x, this.y, this.z);

  static const McVec3 zero = McVec3(0, 0, 0);
  static const McVec3 up = McVec3(0, 1, 0);

  final double x;
  final double y;
  final double z;

  McVec3 operator +(McVec3 o) => McVec3(x + o.x, y + o.y, z + o.z);
  McVec3 operator -(McVec3 o) => McVec3(x - o.x, y - o.y, z - o.z);
  McVec3 operator *(double s) => McVec3(x * s, y * s, z * s);
  McVec3 operator -() => McVec3(-x, -y, -z);

  double dot(McVec3 o) => x * o.x + y * o.y + z * o.z;
  McVec3 cross(McVec3 o) =>
      McVec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));

  /// Unit vector, or [zero] for a (near) zero input.
  McVec3 get normalized {
    final double l = length;
    return l <= 1e-12 ? zero : this * (1 / l);
  }

  List<double> toList() => <double>[x, y, z];

  @override
  bool operator ==(Object other) =>
      other is McVec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'McVec3($x, $y, $z)';
}

/// Column-major: element `(row, col)` lives at `m[col * 4 + row]`.
final class McMat4 {
  McMat4(this.m) : assert(m.length == 16);

  factory McMat4.identity() => McMat4(
    Float64List.fromList(<double>[
      1, 0, 0, 0, //
      0, 1, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]),
  );

  factory McMat4.translation(double x, double y, double z) => McMat4(
    Float64List.fromList(<double>[
      1, 0, 0, 0, //
      0, 1, 0, 0, //
      0, 0, 1, 0, //
      x, y, z, 1, //
    ]),
  );

  factory McMat4.scale(double x, double y, double z) => McMat4(
    Float64List.fromList(<double>[
      x, 0, 0, 0, //
      0, y, 0, 0, //
      0, 0, z, 0, //
      0, 0, 0, 1, //
    ]),
  );

  /// Right-handed: positive degrees turn +Y toward +Z.
  factory McMat4.rotationX(double degrees) {
    final double c = math.cos(degrees * _degToRad);
    final double s = math.sin(degrees * _degToRad);
    return McMat4(
      Float64List.fromList(<double>[
        1, 0, 0, 0, //
        0, c, s, 0, //
        0, -s, c, 0, //
        0, 0, 0, 1, //
      ]),
    );
  }

  /// Right-handed: positive degrees turn +Z toward +X (so +X goes to -Z).
  factory McMat4.rotationY(double degrees) {
    final double c = math.cos(degrees * _degToRad);
    final double s = math.sin(degrees * _degToRad);
    return McMat4(
      Float64List.fromList(<double>[
        c, 0, -s, 0, //
        0, 1, 0, 0, //
        s, 0, c, 0, //
        0, 0, 0, 1, //
      ]),
    );
  }

  /// Right-handed: positive degrees turn +X toward +Y.
  factory McMat4.rotationZ(double degrees) {
    final double c = math.cos(degrees * _degToRad);
    final double s = math.sin(degrees * _degToRad);
    return McMat4(
      Float64List.fromList(<double>[
        c, s, 0, 0, //
        -s, c, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]),
    );
  }

  /// OpenGL clip space: camera looks down -Z, depth in [-1, 1].
  factory McMat4.perspective(
    double fovYRadians,
    double aspect,
    double near,
    double far,
  ) {
    final double f = 1 / math.tan(fovYRadians / 2);
    final double range = 1 / (near - far);
    return McMat4(
      Float64List.fromList(<double>[
        f / aspect, 0, 0, 0, //
        0, f, 0, 0, //
        0, 0, (near + far) * range, -1, //
        0, 0, 2 * near * far * range, 0, //
      ]),
    );
  }

  /// View matrix: [eye] to the origin, [target] onto -Z, [up] roughly +Y.
  factory McMat4.lookAt(McVec3 eye, McVec3 target, McVec3 up) {
    final McVec3 f = (target - eye).normalized;
    final McVec3 s = f.cross(up).normalized;
    final McVec3 u = s.cross(f);
    return McMat4(
      Float64List.fromList(<double>[
        s.x, u.x, -f.x, 0, //
        s.y, u.y, -f.y, 0, //
        s.z, u.z, -f.z, 0, //
        -s.dot(eye), -u.dot(eye), f.dot(eye), 1, //
      ]),
    );
  }

  final Float64List m;

  /// `this * other`: applies [other] first, then this.
  McMat4 multiply(McMat4 other) {
    final Float64List a = m;
    final Float64List b = other.m;
    final Float64List out = Float64List(16);
    for (int col = 0; col < 4; col++) {
      for (int row = 0; row < 4; row++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += a[k * 4 + row] * b[col * 4 + k];
        }
        out[col * 4 + row] = sum;
      }
    }
    return McMat4(out);
  }

  /// Transforms a point (w = 1), dividing by w when a projection set it.
  McVec3 transformPoint(McVec3 p) {
    final double x = m[0] * p.x + m[4] * p.y + m[8] * p.z + m[12];
    final double y = m[1] * p.x + m[5] * p.y + m[9] * p.z + m[13];
    final double z = m[2] * p.x + m[6] * p.y + m[10] * p.z + m[14];
    final double w = m[3] * p.x + m[7] * p.y + m[11] * p.z + m[15];
    return w == 1 || w == 0 ? McVec3(x, y, z) : McVec3(x / w, y / w, z / w);
  }

  List<double> toList() => m.toList();

  Float32List toFloat32() => Float32List.fromList(m);

  @override
  String toString() => 'McMat4(${m.join(', ')})';
}
