import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/** The shared, language-neutral rule cases. See spec/rules/README.md for the format. */
export const SPEC_DIRECTORY = fileURLToPath(new URL("../../spec/rules/", import.meta.url));

export type SideName = "red" | "green";

export interface ExpectedFight {
	readonly attacker: string;
	readonly defender: string;
	readonly outcome: string;
}

export interface PlayExpectations {
	readonly legal_moves?: Readonly<Record<string, readonly string[]>>;
	readonly illegal_moves?: readonly string[];
	readonly board?: readonly string[];
	readonly fight?: ExpectedFight;
	readonly status?: string;
	readonly reason?: string;
}

export const EXPECTATION_KEYS: readonly (keyof PlayExpectations)[] = [
	"legal_moves",
	"illegal_moves",
	"board",
	"fight",
	"status",
	"reason",
];

export interface PlayCase {
	readonly name: string;
	readonly board: readonly string[];
	readonly to_move: SideName;
	readonly plies_without_fight?: number;
	readonly moves?: readonly string[];
	readonly expect: PlayExpectations;
}

export interface SetupCase {
	readonly name: string;
	readonly side: SideName;
	readonly rows: readonly string[];
	readonly valid: boolean;
}

export type RuleCase = PlayCase | SetupCase;

export interface CaseFile {
	readonly fileName: string;
	readonly cases: readonly RuleCase[];
}

/** Every *.json case file of the spec directory, so a new file or case is picked up without code changes. */
export function loadCaseFiles(): CaseFile[] {
	return readdirSync(SPEC_DIRECTORY)
		.filter((fileName) => fileName.endsWith(".json"))
		.sort()
		.map((fileName) => ({ fileName, cases: readCases(join(SPEC_DIRECTORY, fileName)) }));
}

export function isSetupCase(ruleCase: RuleCase): ruleCase is SetupCase {
	return "valid" in ruleCase;
}

function readCases(path: string): RuleCase[] {
	const root: unknown = JSON.parse(readFileSync(path, "utf8"));
	if (typeof root !== "object" || root === null || !Array.isArray((root as { cases?: unknown }).cases)) {
		throw new Error(`${path} must hold { "cases": [ ... ] }`);
	}
	return (root as { cases: RuleCase[] }).cases;
}
