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

```bash
npx ava --safe-local-node
```

### As a library

```js
const { run } = require('ava');

// Successful command
const result = run('echo hello', { silent: true });
console.log(result.stdout);   // "hello\n"
console.log(result.stderr);   // ""
console.log(result.exitCode); // 0

// Failed command — stderr is captured
const failed = run('node -e "process.stderr.write(\'oops\\n\'); process.exit(1)"', { silent: true });
console.log(failed.stdout);   // ""
console.log(failed.stderr);   // "oops\n"
console.log(failed.exitCode); // 1
```

```js
const { runSafeLocalNode } = require('ava');

const result = runSafeLocalNode();
console.log(result.paths.snapshotJson);
console.log(result.paths.portalHtml);
```

### Options

| Option   | Type    | Default         | Description                      |
|----------|---------|-----------------|----------------------------------|
| `silent` | boolean | `false`         | Suppress stdout output           |
| `cwd`    | string  | `process.cwd()` | Working directory for the command |

## Testing

```bash
npm test
```
