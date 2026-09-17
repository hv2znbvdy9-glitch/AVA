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
npx ava --neuron-sim
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
const {simulateNeuron} = require('ava');

const trace = simulateNeuron({
  durationMs: 30,
  dt: 0.01,
  current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

console.log(Math.max(...trace.map((sample) => sample.voltage)));
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

## Scientific prototypes

- [Neuron-model analysis](docs/biologisch-plausible-neuronenmodelle.md) -
  source-grounded comparison of detailed biological neuron models.
- [Hodgkin-Huxley teaching prototype](docs/hodgkin-huxley-prototype.md) -
  deterministic single-compartment membrane simulation with bounded inputs and
  regression tests.
- [AVA 01610 multi-compartment Neuro-HH prototype](docs/AVA_NEURO_HH_IMPLEMENTATION.md) -
  deterministic seven-compartment Layer-5-style integration model with axial
  coupling, bounded inputs and immutable SHA-256 evidence directories.

Both are scientific prototypes, not experimentally fitted full pyramidal-cell
models, learning systems, or autonomous AVA/JARVIS agents. On Windows, start the
multi-compartment model without administrator rights using
`scripts\START_AVA_NEURO_HH_WINDOWS.cmd`.

## Security reference examples

- [Hardened C++ gRPC server](examples/grpc-secure/README.md) - mandatory mTLS,
  certificate-identity authorization, bounded resources, rate limiting, and
  signal-safe graceful shutdown.
