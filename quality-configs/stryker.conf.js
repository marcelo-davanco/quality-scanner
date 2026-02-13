// Stryker — Mutation Testing
// Verifica se os testes realmente detectam bugs, não só cobertura de linhas
// Rodar: npx stryker run
// Docs: https://stryker-mutator.io
/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
module.exports = {
  // Pacote de mutação para TypeScript
  mutator: {
    plugins: ['@stryker-mutator/typescript-checker'],
  },
  // Arquivos a mutar (código fonte, não testes)
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
  // TypeScript checker — valida que mutações compilam
  checkers: ['typescript'],
  tsconfigFile: 'tsconfig.json',
  // Reporters
  reporters: ['html', 'clear-text', 'progress'],
  htmlReporter: {
    fileName: 'reports/mutation/mutation-report.html',
  },
  // Thresholds — score mínimo de mutação
  thresholds: {
    high: 80,
    low: 60,
    break: 50, // falha se score < 50%
  },
  // Performance
  concurrency: 4,
  timeoutMS: 30000,
  // Cobertura incremental — só muta arquivos alterados
  incremental: true,
  incrementalFile: '.stryker-tmp/incremental.json',
};
