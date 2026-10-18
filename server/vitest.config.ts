import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		projects: [
			{ test: { name: "unit", include: ["test/**/*.test.ts"], exclude: ["test/worker/**"] } },
			{ test: { name: "worker", include: ["test/worker/**/*.test.ts"], testTimeout: 30_000, hookTimeout: 120_000 } },
		],
	},
});
