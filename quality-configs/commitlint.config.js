// Commitlint — Força Conventional Commits
// Formato: type(scope): description
// Exemplos válidos:
//   feat(fragrance): add applicator validation
//   fix(auth): handle expired token
//   chore(deps): update nestjs to v10
//   refactor(core): simplify error handling
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Tipos permitidos
    'type-enum': [2, 'always', [
      'feat',     // Nova funcionalidade
      'fix',      // Correção de bug
      'docs',     // Documentação
      'style',    // Formatação (não altera lógica)
      'refactor', // Refatoração (não altera comportamento)
      'perf',     // Melhoria de performance
      'test',     // Adição/correção de testes
      'build',    // Build system ou dependências
      'ci',       // CI/CD
      'chore',    // Tarefas gerais
      'revert',   // Reverter commit
    ]],
    // Tipo obrigatório e em minúsculo
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],
    // Subject obrigatório
    'subject-empty': [2, 'never'],
    'subject-case': [2, 'never', ['sentence-case', 'start-case', 'pascal-case', 'upper-case']],
    // Header max 100 caracteres
    'header-max-length': [2, 'always', 100],
    // Body line max 200 caracteres
    'body-max-line-length': [2, 'always', 200],
  },
};
