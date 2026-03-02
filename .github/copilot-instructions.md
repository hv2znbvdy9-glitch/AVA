# Copilot Instructions

## Project Overview

AVA is a simple CLI task runner built with Node.js. It executes shell commands in child processes and can be used both as a CLI tool and as a library.

## Tech Stack

- **Runtime**: Node.js
- **Module system**: CommonJS (`require`/`module.exports`)
- **Testing**: Custom lightweight test runner using Node.js built-in `assert` module
- **Dependencies**: None (zero external dependencies)

## Project Structure

```
bin/cli.js        # CLI entry point
src/index.js      # Library entry point (re-exports from src/run.js)
src/run.js        # Core logic — the `run()` function
test/run.test.js  # Tests for the run module
package.json      # Project metadata and scripts
```

## Commands

- `npm test` — Run the test suite
- `npm start` — Run the main entry point
- `npx ava "<command>"` — Execute a command via the CLI

## Coding Guidelines

- Use `'use strict';` at the top of every file.
- Use tabs for indentation.
- Use single quotes for strings.
- Use CommonJS (`require`/`module.exports`) — do not use ES module syntax (`import`/`export`).
- Keep the project dependency-free; avoid adding external packages unless absolutely necessary.
- Follow the existing code style: use `const` over `let` where possible, and avoid `var`.

## Testing

- Tests live in the `test/` directory using the naming convention `<module>.test.js`.
- Tests use Node.js built-in `assert` module — do not introduce external test frameworks.
- Run tests with `npm test`.
- All new functionality must include corresponding tests.

## Boundaries

- Do not commit secrets, credentials, or environment variables.
- Do not modify `package.json` fields (name, version, license) unless explicitly asked.
- Do not convert the project to ES modules or TypeScript unless explicitly asked.
