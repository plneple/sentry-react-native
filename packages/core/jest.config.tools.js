module.exports = {
  collectCoverage: true,
  preset: 'ts-jest',
  setupFilesAfterEnv: ['jest-extended/all', '<rootDir>/test/mockConsole.ts'],
  globals: {
    __DEV__: true,
  },
  testMatch: ['**/test/tools/**/*.ts'],
  transform: {
    '^.+\\.(ts|tsx)$': [
      'ts-jest',
      {
        tsconfig: './tsconfig.build.tools.json',
        diagnostics: false,
      },
    ],
  },
};
