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
npx ava run "echo hello"
```

#### CLI Flags

| Flag          | Description                                      |
|---------------|--------------------------------------------------|
| `--color`     | Print the AVA brand color (`#0969DA`) and exit   |
| `--overview`  | Print the AVA session overview text and exit     |

### As a library

```js
const { run, runAll } = require('ava');

// Run a single command
const result = run('echo hello', { silent: true });
console.log(result.stdout);   // "hello\n"
console.log(result.stderr);   // ""
console.log(result.exitCode); // 0

// Run multiple commands sequentially
const results = runAll(['echo hello', 'echo world'], { silent: true });
console.log(results[0].stdout); // "hello\n"
console.log(results[1].stdout); // "world\n"
```

#### Color utilities

```js
const { AVA_COLOR, hexToRgb, colorize, ava } = require('ava');

console.log(AVA_COLOR);               // "#0969DA"
console.log(hexToRgb('#0969DA'));      // { r: 9, g: 105, b: 218 }
console.log(colorize('hello', '#0969DA')); // ANSI-colored "hello"
console.log(ava());                   // ANSI-colored "AVA <2"
```

#### Session overview

```js
const { overview, OVERVIEW_TEXT } = require('ava');

console.log(overview()); // prints the AVA session overview text
```

### Options

| Option   | Type    | Default         | Description                       |
|----------|---------|-----------------|-----------------------------------|
| `silent` | boolean | `false`         | Suppress stdout output            |
| `cwd`    | string  | `process.cwd()` | Working directory for the command |

## Testing

```bash
npm test
```
