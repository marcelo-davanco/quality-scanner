// Commitlint — Enforces Conventional Commits
// Format: type(scope): description
// Valid examples:
//   feat(fragrance): add applicator validation
//   fix(auth): handle expired token
//   chore(deps): update nestjs to v10
//   refactor(core): simplify error handling
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Allowed types
    'type-enum': [2, 'always', [
      'feat',     // New feature
      'fix',      // Bug fix
      'docs',     // Documentation
      'style',    // Formatting (no logic change)
      'refactor', // Refactoring (no behavior change)
      'perf',     // Performance improvement
      'test',     // Adding/fixing tests
      'build',    // Build system or dependencies
      'ci',       // CI/CD
      'chore',    // General tasks
      'revert',   // Revert a commit
    ]],
    // Type is required and must be lowercase
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],
    // Subject is required
    'subject-empty': [2, 'never'],
    'subject-case': [2, 'never', ['sentence-case', 'start-case', 'pascal-case', 'upper-case']],
    // Header max 100 characters
    'header-max-length': [2, 'always', 100],
    // Body line max 200 characters
    'body-max-line-length': [2, 'always', 200],
  },
};
