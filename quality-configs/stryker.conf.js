// Stryker — Mutation Testing
// Verifies that tests actually detect bugs, not just line coverage
// Run: npx stryker run
// Docs: https://stryker-mutator.io
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
module.exports = {
  // Mutation package for TypeScript
  mutator: {
    plugins: ['@stryker-mutator/typescript-checker'],
  },
  // Files to mutate (source code, not tests)
  mutate: [
    'src/**/*.ts',
    '!src/**/*.spec.ts',
    '!src/**/*.test.ts',
    '!src/**/*.module.ts',
    '!src/**/*.interface.ts',
    '!src/**/*.dto.ts',
    '!src/**/*.mock.ts',
    '!src/index.ts',
    '!src/main.ts',
    '!src/test/**',
    '!src/common/db/**',
  ],
  // Test runner
  testRunner: 'jest',
  jest: {
    configFile: 'jest.config.js',
  },
  // TypeScript checker — validates that mutations compile
  checkers: ['typescript'],
  tsconfigFile: 'tsconfig.json',
  // Reporters
  reporters: ['html', 'clear-text', 'progress'],
  htmlReporter: {
    fileName: 'reports/mutation/mutation-report.html',
  },
  // Thresholds — minimum mutation score
  thresholds: {
    high: 80,
    low: 60,
    break: 50, // fail if score < 50%
  },
  // Performance
  concurrency: 4,
  timeoutMS: 30000,
  // Incremental coverage — only mutates changed files
  incremental: true,
  incrementalFile: '.stryker-tmp/incremental.json',
};
