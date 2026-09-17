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

```bash
npx ava --neuron-model
```

```bash
npx ava --neuro-hh --protocol bac-coincidence --output AVA_EVENTS
```

### As a library

```js
const { run } = require('ava');

const result = run('echo hello', { silent: true });
console.log(result.stdout); // "hello\n"
console.log(result.stderr); // ""
console.log(result.exitCode); // 0
```

```js
const { runSafeLocalNode } = require('ava');

const result = runSafeLocalNode();
console.log(result.paths.snapshotJson);
console.log(result.paths.portalHtml);
```

```js
const { neuronModelReport, neuronModelData } = require('ava');

console.log(neuronModelReport());
console.log(neuronModelData().references.length); // 4
```

```js
const {simulateMultiCompartmentHH} = require('ava');

const result = simulateMultiCompartmentHH({protocol: 'somatic-step'});
console.log(result.summary.spike_count);
```

### Options

| Option   | Type    | Default         | Description                      |
|----------|---------|-----------------|----------------------------------|
| `silent` | boolean | `false`         | Suppress stdout output           |
| `cwd`    | string  | `process.cwd()` | Working directory for the command |

## Testing

```bash
npm test
npm run test:neuro
```

## AVA 01610 Neuro-HH

AVA includes a deterministic seven-compartment Hodgkin-Huxley-style Layer-5
pyramidal-cell **prototype** with Na, K, simplified Ca/KCa/HCN conductances,
axial coupling and immutable SHA-256 evidence output. It is an educational and
integration model, not a fitted reproduction of the Hay et al. L5b model.

- [Scientific analysis and model boundary](docs/AVA_NEURO_HH_IMPLEMENTATION.md)
- Windows: `scripts\START_AVA_NEURO_HH_WINDOWS.cmd` (no administrator rights required)

## Security reference examples

- [Hardened C++ gRPC server](examples/grpc-secure/README.md) - mandatory mTLS,
  certificate-identity authorization, bounded resources, rate limiting, and
  signal-safe graceful shutdown.
