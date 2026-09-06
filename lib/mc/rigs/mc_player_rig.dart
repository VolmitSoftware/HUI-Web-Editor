/// The player, wide and slim, with every overlay layer, and the cape.
///
/// Boxes and UVs are the client's `PlayerModel`: head 8x8x8 at (0,0) with
/// the hat at (32,0) inflated 0.5; body 8x12x4 at (16,16) with the jacket at
/// (16,32) inflated 0.25; right arm 4x12x4 at (40,16) (slim: 3 wide), sleeve
/// (40,32); left arm (32,48), sleeve (48,48); right leg 4x12x4 at (0,16),
/// pants (0,32); left leg (16,48), pants (0,48). Pivots: head at (0,0,0),
/// body at (0,0,0), arms at (+-5, 2, 0), legs at (+-1.9, 12, 0). Rendered at
/// the client's 0.9375 scale; feet at model y = 24.
library;

import '../scene/mc_math.dart';
import 'mc_rig.dart';

const String mcRigPlayer = 'player';

McRig mcPlayerRig({required bool slim}) {
  final double armW = slim ? 3 : 4;
  final double armX = slim ? -2 : -3;
  return McRig(
    id: mcRigPlayer,
    textureWidth: 64,
    textureHeight: 64,
    scale: 0.9375,
    heightBlocks: 1.8,
    eyeHeightBlocks: 1.62,
    parts: <McRigPart>[
      const McRigPart(
        name: 'head',
        pivot: McVec3.zero,
        boxes: <McBox>[
          McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 0, v: 0),
          McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 32, v: 0, inflate: 0.5),
        ],
      ),
      const McRigPart(
        name: 'body',
        pivot: McVec3.zero,
        boxes: <McBox>[
          McBox(origin: McVec3(-4, 0, -2), size: McVec3(8, 12, 4), u: 16, v: 16),
          McBox(origin: McVec3(-4, 0, -2), size: McVec3(8, 12, 4), u: 16, v: 32, inflate: 0.25),
        ],
      ),
      McRigPart(
        name: 'right_arm',
        pivot: const McVec3(-5, 2, 0),
        boxes: <McBox>[
          McBox(origin: McVec3(armX, -2, -2), size: McVec3(armW, 12, 4), u: 40, v: 16),
          McBox(origin: McVec3(armX, -2, -2), size: McVec3(armW, 12, 4), u: 40, v: 32, inflate: 0.25),
        ],
      ),
      McRigPart(
        name: 'left_arm',
        pivot: const McVec3(5, 2, 0),
        boxes: <McBox>[
          McBox(origin: const McVec3(-1, -2, -2), size: McVec3(armW, 12, 4), u: 32, v: 48),
          McBox(origin: const McVec3(-1, -2, -2), size: McVec3(armW, 12, 4), u: 48, v: 48, inflate: 0.25),
        ],
      ),
      const McRigPart(
        name: 'right_leg',
        pivot: McVec3(-1.9, 12, 0),
        boxes: <McBox>[
          McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 0, v: 16),
          // Origin nudged up by the inflate amount so the pants layer's
          // bottom face stays flush with the boot at the feet line (y=24)
          // instead of poking through the floor.
          McBox(origin: McVec3(-2, -0.25, -2), size: McVec3(4, 12, 4), u: 0, v: 32, inflate: 0.25),
        ],
      ),
      const McRigPart(
        name: 'left_leg',
        pivot: McVec3(1.9, 12, 0),
        boxes: <McBox>[
          McBox(origin: McVec3(-2, 0, -2), size: McVec3(4, 12, 4), u: 16, v: 48),
          McBox(origin: McVec3(-2, -0.25, -2), size: McVec3(4, 12, 4), u: 0, v: 48, inflate: 0.25),
        ],
      ),
    ],
  );
}

const String mcRigPlayerHead = 'player_head';

/// The player's head alone, dropped so the head box's bottom sits at y = 0.
///
/// The menu preview draws a player-head icon as this rig rather than as a
/// sprite. `mc_rig_mesher.dart` measures world y down from the feet line at
/// model y 24, so a pivot there puts the 8 px box at 0..0.5 blocks before the
/// client's 0.9375 scale. [slim] is taken for symmetry with [mcPlayerRig] and
/// [mcRigById]; both skin models share one head.
McRig mcHeadRig({required bool slim}) => const McRig(
  id: mcRigPlayerHead,
  textureWidth: 64,
  textureHeight: 64,
  scale: 0.9375,
  heightBlocks: 0.5,
  eyeHeightBlocks: 0.25,
  parts: <McRigPart>[
    McRigPart(
      name: 'head',
      pivot: McVec3(0, 24, 0),
      boxes: <McBox>[
        McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 0, v: 0),
        McBox(origin: McVec3(-4, -8, -4), size: McVec3(8, 8, 8), u: 32, v: 0, inflate: 0.5),
      ],
    ),
  ],
);

/// The cape: one 10x16x1 box hung off the back of the body, tilted 6
/// degrees, on a 64x32 texture at (0, 0).
McRig mcCapeRig() => const McRig(
  id: 'cape',
  textureWidth: 64,
  textureHeight: 32,
  scale: 0.9375,
  heightBlocks: 1.8,
  eyeHeightBlocks: 1.62,
  parts: <McRigPart>[
    McRigPart(
      name: 'cape',
      pivot: McVec3(0, 0, 2),
      rotationDeg: McVec3(6, 180, 0),
      boxes: <McBox>[McBox(origin: McVec3(-5, 0, -1), size: McVec3(10, 16, 1), u: 0, v: 0)],
    ),
  ],
);
