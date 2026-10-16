import type { MovementRule } from "./movement-rule";
import type { Square } from "./square";

/** Never moves. */
export class StillMovement implements MovementRule {
	destinations(): Square[] {
		return [];
	}
}
