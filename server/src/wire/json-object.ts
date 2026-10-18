/** The JSON object [text] holds, or undefined when it is not JSON or not an object. */
export function parseJsonObject(text: string): Record<string, unknown> | undefined {
	let value: unknown;
	try {
		value = JSON.parse(text);
	} catch {
		return undefined;
	}
	return asObject(value);
}

/** [value] as a plain object, or undefined when it is null, an array or not an object. */
export function asObject(value: unknown): Record<string, unknown> | undefined {
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		return undefined;
	}
	return value as Record<string, unknown>;
}
