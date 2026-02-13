// Knip — Detecção de código morto, exports não usados, dependências órfãs
// Rodar: npx knip
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
    'ts-jest',        // usado via config, não import direto
    'tsconfig-paths',
    '@types/*',
  ],
  // NestJS usa decorators e DI — knip não detecta uso via reflection
  ignoreExportsUsedInFile: true,
  // Plugins para frameworks
  nestjs: true,
  jest: true,
};

export default config;
