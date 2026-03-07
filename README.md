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
npx ava --color
```

Use `--color` to print the AVA brand color and exit.

### As a library

```js
const { run, brandColor } = require('ava');

const result = run('echo hello', { silent: true });
console.log(result.stdout); // "hello\n"
console.log(result.stderr); // ""
console.log(result.exitCode); // 0
console.log(brandColor); // "#0969DA"
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
