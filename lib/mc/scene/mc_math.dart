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

/// Interpolates two rigid-ish transforms the way the client eases a display
/// entity between packets: translation and scale linearly, rotation by
/// quaternion slerp, so a tumbling drop turns the short way and never shrinks
/// through the midpoint the way a raw matrix lerp would.
///
/// Columns 0..2 are decomposed into scale (their lengths) and a rotation (the
/// normalised columns); a mirrored or sheared input is not expected here.
McMat4 mcLerpTransform(McMat4 a, McMat4 b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  final List<double> sa = _columnScales(a), sb = _columnScales(b);
  final List<double> qa = _quaternionOf(a, sa), qb = _quaternionOf(b, sb);
  final List<double> q = _slerp(qa, qb, t);
  final List<double> s = <double>[
    for (int i = 0; i < 3; i++) sa[i] + (sb[i] - sa[i]) * t,
  ];
  final Float64List out = _matrixFromQuaternion(q, s);
  for (int i = 0; i < 3; i++) {
    out[12 + i] = a.m[12 + i] + (b.m[12 + i] - a.m[12 + i]) * t;
  }
  out[15] = 1;
  return McMat4(out);
}

List<double> _columnScales(McMat4 m) => <double>[
  for (int c = 0; c < 3; c++)
    math.sqrt(
      m.m[c * 4] * m.m[c * 4] +
          m.m[c * 4 + 1] * m.m[c * 4 + 1] +
          m.m[c * 4 + 2] * m.m[c * 4 + 2],
    ),
];

/// `[x, y, z, w]` from the rotation part of [m] (columns divided by [scale]).
List<double> _quaternionOf(McMat4 m, List<double> scale) {
  double r(int col, int row) =>
      scale[col] == 0 ? (col == row ? 1 : 0) : m.m[col * 4 + row] / scale[col];
  final double m00 = r(0, 0), m01 = r(1, 0), m02 = r(2, 0);
  final double m10 = r(0, 1), m11 = r(1, 1), m12 = r(2, 1);
  final double m20 = r(0, 2), m21 = r(1, 2), m22 = r(2, 2);
  final double trace = m00 + m11 + m22;
  double x, y, z, w;
  if (trace > 0) {
    final double s = math.sqrt(trace + 1) * 2;
    w = 0.25 * s;
    x = (m21 - m12) / s;
    y = (m02 - m20) / s;
    z = (m10 - m01) / s;
  } else if (m00 > m11 && m00 > m22) {
    final double s = math.sqrt(1 + m00 - m11 - m22) * 2;
    w = (m21 - m12) / s;
    x = 0.25 * s;
    y = (m01 + m10) / s;
    z = (m02 + m20) / s;
  } else if (m11 > m22) {
    final double s = math.sqrt(1 + m11 - m00 - m22) * 2;
    w = (m02 - m20) / s;
    x = (m01 + m10) / s;
    y = 0.25 * s;
    z = (m12 + m21) / s;
  } else {
    final double s = math.sqrt(1 + m22 - m00 - m11) * 2;
    w = (m10 - m01) / s;
    x = (m02 + m20) / s;
    y = (m12 + m21) / s;
    z = 0.25 * s;
  }
  final double n = math.sqrt(x * x + y * y + z * z + w * w);
  return n == 0 ? <double>[0, 0, 0, 1] : <double>[x / n, y / n, z / n, w / n];
}

List<double> _slerp(List<double> a, List<double> b, double t) {
  double dot = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
  List<double> bb = b;
  if (dot < 0) {
    dot = -dot;
    bb = <double>[-b[0], -b[1], -b[2], -b[3]];
  }
  if (dot > 0.9995) {
    final List<double> lin = <double>[
      for (int i = 0; i < 4; i++) a[i] + (bb[i] - a[i]) * t,
    ];
    final double n = math.sqrt(lin[0] * lin[0] + lin[1] * lin[1] + lin[2] * lin[2] + lin[3] * lin[3]);
    return <double>[for (final double v in lin) v / n];
  }
  final double theta = math.acos(dot);
  final double sinTheta = math.sin(theta);
  final double wa = math.sin((1 - t) * theta) / sinTheta;
  final double wb = math.sin(t * theta) / sinTheta;
  return <double>[for (int i = 0; i < 4; i++) a[i] * wa + bb[i] * wb];
}

Float64List _matrixFromQuaternion(List<double> q, List<double> scale) {
  final double x = q[0], y = q[1], z = q[2], w = q[3];
  final double xx = x * x, yy = y * y, zz = z * z;
  final double xy = x * y, xz = x * z, yz = y * z;
  final double wx = w * x, wy = w * y, wz = w * z;
  final Float64List m = Float64List(16);
  m[0] = (1 - 2 * (yy + zz)) * scale[0];
  m[1] = (2 * (xy + wz)) * scale[0];
  m[2] = (2 * (xz - wy)) * scale[0];
  m[4] = (2 * (xy - wz)) * scale[1];
  m[5] = (1 - 2 * (xx + zz)) * scale[1];
  m[6] = (2 * (yz + wx)) * scale[1];
  m[8] = (2 * (xz + wy)) * scale[2];
  m[9] = (2 * (yz - wx)) * scale[2];
  m[10] = (1 - 2 * (xx + yy)) * scale[2];
  return m;
}
