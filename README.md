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

### Options

| Option   | Type    | Default         | Description                      |
|----------|---------|-----------------|----------------------------------|
| `silent` | boolean | `false`         | Suppress stdout output           |
| `cwd`    | string  | `process.cwd()` | Working directory for the command |

## Testing

```bash
npm test
```

## Scientific prototypes

- [Neuron-model analysis](docs/biologisch-plausible-neuronenmodelle.md) -
  source-grounded comparison of detailed biological neuron models.
- [Hodgkin-Huxley teaching prototype](docs/hodgkin-huxley-prototype.md) -
  deterministic single-compartment membrane simulation with bounded inputs and
  regression tests. It is not a full pyramidal-cell model, learning system, or
  autonomous AVA/JARVIS agent.

## Security reference examples

- [Hardened C++ gRPC server](examples/grpc-secure/README.md) - mandatory mTLS,
  certificate-identity authorization, bounded resources, rate limiting, and
  signal-safe graceful shutdown.
