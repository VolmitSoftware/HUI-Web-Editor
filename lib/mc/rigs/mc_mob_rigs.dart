/// Mob rigs: zombie and skeleton on the client's `HumanoidModel.createMesh`
/// (26.2 jar: the left arm and leg are the right limbs' rects at (40,16) and
/// (0,16) with `mirror()`; only `PlayerModel` has dedicated left rects), the
/// creeper, and the quadrupeds (pig, cow, sheep) built on the client's
/// `QuadrupedModel` pivots. All model space, Y down, feet at y = 24.
library;

import '../scene/mc_math.dart';
import 'mc_rig.dart';

McRig mcZombieRig() => const McRig(
  id: 'zombie',
  textureWidth: 64,
  textureHeight: 64,
  heightBlocks: 1.95,
  eyeHeightBlocks: 1.74,
  parts: <McRigPart>[
    McRigPart(name: 'head', pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 0, v: 0)]),
    McRigPart(name: 'body', pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-4, 0, -2), size: McVec3(8, 12, 4), u: 16, v: 16)]),
    McRigPart(
      name: 'right_arm',
      pivot: McVec3(-5, 2, 0),
      rotationDeg: McVec3(-90, 0, 0),
      boxes: <McBox>[McBox(origin: McVec3(-3, -2, -2), size: McVec3(4, 12, 4), u: 40, v: 16)],
    ),
    McRigPart(
      name: 'left_arm',
      pivot: McVec3(5, 2, 0),
      rotationDeg: McVec3(-90, 0, 0),
      boxes: <McBox>[McBox(origin: McVec3(-1, -2, -2), size: McVec3(4, 12, 4), u: 40, v: 16, mirror: true)],
    ),
    McRigPart(name: 'right_leg', pivot: McVec3(-1.9, 12, 0), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)]),
    McRigPart(name: 'left_leg', pivot: McVec3(1.9, 12, 0), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16, mirror: true)]),
  ],
);

McRig mcSkeletonRig() => const McRig(
  id: 'skeleton',
  textureWidth: 64,
  textureHeight: 64,
  heightBlocks: 1.99,
  eyeHeightBlocks: 1.74,
  parts: <McRigPart>[
    McRigPart(name: 'head', pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 0, v: 0)]),
    McRigPart(name: 'body', pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-4, 0, -2), size: McVec3(8, 12, 4), u: 16, v: 16)]),
    McRigPart(
      name: 'right_arm',
      pivot: McVec3(-5, 2, 0),
      rotationDeg: McVec3(-90, 0, 0),
      boxes: <McBox>[McBox(origin: McVec3(-1, -2, -1), size: McVec3(2, 12, 2), u: 40, v: 16)],
    ),
    McRigPart(
      name: 'left_arm',
      pivot: McVec3(5, 2, 0),
      rotationDeg: McVec3(-90, 0, 0),
      boxes: <McBox>[McBox(origin: McVec3(-1, -2, -1), size: McVec3(2, 12, 2), u: 40, v: 16, mirror: true)],
    ),
    McRigPart(name: 'right_leg', pivot: McVec3(-1.9, 12, 0), boxes: <McBox>[McBox(origin: McVec3(-1, 0, -1), size: McVec3(2, 12, 2), u: 0, v: 16)]),
    McRigPart(name: 'left_leg', pivot: McVec3(1.9, 12, 0), boxes: <McBox>[McBox(origin: McVec3(-1, 0, -1), size: McVec3(2, 12, 2), u: 0, v: 16, mirror: true)]),
  ],
);

// Legs' pivot y + leg length = 24, so feet land exactly at the floor.
McRig mcCreeperRig() => const McRig(
  id: 'creeper',
  textureWidth: 64,
  textureHeight: 32,
  heightBlocks: 1.7,
  eyeHeightBlocks: 1.445,
  parts: <McRigPart>[
    McRigPart(name: 'head', pivot: McVec3(0, 6, 0), boxes: <McBox>[McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 0, v: 0)]),
    McRigPart(name: 'body', pivot: McVec3(0, 6, 0), boxes: <McBox>[McBox(origin: McVec3(-4, 0, -2), size: McVec3(8, 12, 4), u: 16, v: 16)]),
    McRigPart(name: 'leg_front_right', pivot: McVec3(-2, 18, 4), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_front_left', pivot: McVec3(2, 18, 4), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_back_right', pivot: McVec3(-2, 18, -4), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_back_left', pivot: McVec3(2, 18, -4), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
  ],
);

// QuadrupedModel: head/body pivot y is `6 + offset`/`5 + offset` with
// `offset = 12 - legLength` (zero for the 12px legs cow and sheep share; 6
// for the pig's shorter 6px legs). Legs' pivot y is `24 - legLength`, so
// their fixed length always reaches the floor at model y = 24. The body box
// carries rotationDeg X 90 so its 10x16x8 cuboid, tall in local Y, lies
// down as a horizontal torso.

McRig mcPigRig() => const McRig(
  id: 'pig',
  textureWidth: 64,
  textureHeight: 32,
  heightBlocks: 0.9,
  eyeHeightBlocks: 0.6375,
  parts: <McRigPart>[
    McRigPart(
      name: 'head',
      pivot: McVec3(0, 12, -8),
      boxes: <McBox>[
        McBox(origin: McVec3(-4, -4, -6), size: McVec3(8, 8, 8), u: 0, v: 0),
        // Both boxes carry the same -2 compensation for the pivot moving from
        // the client's z = -6 to z = -8, so the snout stays flush with the face.
        McBox(origin: McVec3(-2, 0, -7), size: McVec3(4, 3, 1), u: 16, v: 16),
      ],
    ),
    McRigPart(
      name: 'body',
      pivot: McVec3(0, 11, 2),
      rotationDeg: McVec3(90, 0, 0),
      boxes: <McBox>[McBox(origin: McVec3(-5, -10, -7), size: McVec3(10, 16, 8), u: 28, v: 8)],
    ),
    McRigPart(name: 'leg_front_right', pivot: McVec3(-3, 18, 7), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_front_left', pivot: McVec3(3, 18, 7), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_back_right', pivot: McVec3(-3, 18, -5), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_back_left', pivot: McVec3(3, 18, -5), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16)]),
  ],
);

McRig mcCowRig() => const McRig(
  id: 'cow',
  textureWidth: 64,
  textureHeight: 32,
  heightBlocks: 1.4,
  eyeHeightBlocks: 1.3,
  parts: <McRigPart>[
    McRigPart(
      name: 'head',
      pivot: McVec3(0, 6, -8),
      boxes: <McBox>[
        McBox(origin: McVec3(-4, -4, -6), size: McVec3(8, 8, 8), u: 0, v: 0),
        McBox(origin: McVec3(-5, -5, -7), size: McVec3(1, 3, 1), u: 22, v: 0),
        McBox(origin: McVec3(4, -5, -7), size: McVec3(1, 3, 1), u: 22, v: 0),
      ],
    ),
    McRigPart(
      name: 'body',
      pivot: McVec3(0, 5, 2),
      rotationDeg: McVec3(90, 0, 0),
      boxes: <McBox>[
        McBox(origin: McVec3(-5, -10, -7), size: McVec3(10, 16, 8), u: 28, v: 8),
        McBox(origin: McVec3(-2, -2, -8), size: McVec3(4, 6, 1), u: 52, v: 0),
      ],
    ),
    McRigPart(name: 'leg_front_right', pivot: McVec3(-3, 12, 7), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_front_left', pivot: McVec3(3, 12, 7), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_back_right', pivot: McVec3(-3, 12, -5), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)]),
    McRigPart(name: 'leg_back_left', pivot: McVec3(3, 12, -5), boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)]),
  ],
);

// Wool overlay parts (`overlay: true`) drawn with the sheep_wool texture,
// each a child riding the same local frame as its base part (pivot zero).
McRig mcSheepRig() => const McRig(
  id: 'sheep',
  textureWidth: 64,
  textureHeight: 32,
  heightBlocks: 1.3,
  eyeHeightBlocks: 1.235,
  parts: <McRigPart>[
    McRigPart(
      name: 'head',
      pivot: McVec3(0, 6, -8),
      boxes: <McBox>[McBox(origin: McVec3(-3, -4, -6), size: McVec3(6, 6, 8), u: 0, v: 0)],
      children: <McRigPart>[
        McRigPart(
          name: 'head_wool',
          overlay: true,
          pivot: McVec3.zero,
          boxes: <McBox>[McBox(origin: McVec3(-3, -4, -6), size: McVec3(6, 6, 6), u: 0, v: 0, inflate: 0.6)],
        ),
      ],
    ),
    McRigPart(
      name: 'body',
      pivot: McVec3(0, 5, 2),
      rotationDeg: McVec3(90, 0, 0),
      boxes: <McBox>[McBox(origin: McVec3(-5, -10, -7), size: McVec3(10, 16, 8), u: 28, v: 8)],
      children: <McRigPart>[
        McRigPart(
          name: 'body_wool',
          overlay: true,
          pivot: McVec3.zero,
          boxes: <McBox>[McBox(origin: McVec3(-5, -10, -7), size: McVec3(10, 16, 8), u: 28, v: 8, inflate: 1.75)],
        ),
      ],
    ),
    McRigPart(
      name: 'leg_front_right',
      pivot: McVec3(-3, 12, 7),
      boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)],
      children: <McRigPart>[
        McRigPart(name: 'leg_front_right_wool', overlay: true, pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16, inflate: 0.5)]),
      ],
    ),
    McRigPart(
      name: 'leg_front_left',
      pivot: McVec3(3, 12, 7),
      boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)],
      children: <McRigPart>[
        McRigPart(name: 'leg_front_left_wool', overlay: true, pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16, inflate: 0.5)]),
      ],
    ),
    McRigPart(
      name: 'leg_back_right',
      pivot: McVec3(-3, 12, -5),
      boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)],
      children: <McRigPart>[
        McRigPart(name: 'leg_back_right_wool', overlay: true, pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16, inflate: 0.5)]),
      ],
    ),
    McRigPart(
      name: 'leg_back_left',
      pivot: McVec3(3, 12, -5),
      boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16)],
      children: <McRigPart>[
        McRigPart(name: 'leg_back_left_wool', overlay: true, pivot: McVec3.zero, boxes: <McBox>[McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 6, 4), u: 0, v: 16, inflate: 0.5)]),
      ],
    ),
  ],
);
