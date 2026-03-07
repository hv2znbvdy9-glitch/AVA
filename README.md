# AVA

A simple CLI task runner.

## Installation

```bash
npm install
```

## Usage

### As a CLI

```bash
npx ava "echo hello"
```

### As a library

```js
const { run, runAll } = require('ava');

const result = run('echo hello', { silent: true });
console.log(result.stdout); // "hello\n"
console.log(result.stderr); // ""
console.log(result.exitCode); // 0
```

### Running a battery of commands

`runAll` executes an array of commands and returns a Promise that resolves to an array of results (one per command). Use the `concurrency` option to run multiple commands in parallel.

```js
const { runAll } = require('ava');

const results = await runAll(['echo foo', 'echo bar'], { silent: true, concurrency: 2 });
// [
//   { command: 'echo foo', stdout: 'foo\n', exitCode: 0 },
//   { command: 'echo bar', stdout: 'bar\n', exitCode: 0 },
// ]
```

### Options

| Option        | Type    | Default         | Description                                        |
|---------------|---------|-----------------|---------------------------------------------------|
| `silent`      | boolean | `false`         | Suppress stdout/stderr output                      |
| `cwd`         | string  | `process.cwd()` | Working directory for the command                  |
| `concurrency` | number  | `1`             | (`runAll` only) Max commands to run in parallel    |

## Testing

```bash
npm test
```
