// Knip — Dead code detection, unused exports, orphan dependencies
// Run: npx knip
// Docs: https://knip.dev
import type { KnipConfig } from 'knip';

const config: KnipConfig = {
  entry: ['src/main.ts', 'src/index.ts'],
  project: ['src/**/*.ts'],
  ignore: [
    'src/test/**',
    'src/**/*.spec.ts',
    'src/**/*.test.ts',
    'src/**/*.mock.ts',
    'src/**/*.dto.ts',
    'dist/**',
  ],
  ignoreDependencies: [
    'ts-jest',        // used via config, not direct import
    'tsconfig-paths',
    '@types/*',
  ],
  // NestJS uses decorators and DI — knip cannot detect usage via reflection
  ignoreExportsUsedInFile: true,
  // Framework plugins
  nestjs: true,
  jest: true,
};

export default config;
