import type { MovementRule } from "./movement-rule";
import type { PieceType } from "./piece-type";
import { SlideMovement } from "./slide-movement";
import { StepMovement } from "./step-movement";
import { StillMovement } from "./still-movement";

const STEP = new StepMovement({ mayAttack: true });

const SPECIAL_RULES: Partial<Readonly<Record<PieceType, MovementRule>>> = {
	monster: new StillMovement(),
	buffoon: new SlideMovement(),
	princess: new StepMovement({ mayAttack: false }),
};

/** Which MovementRule each Piece Type follows: every other Piece Type steps. */
export function movementRuleFor(type: PieceType): MovementRule {
	return SPECIAL_RULES[type] ?? STEP;
}
