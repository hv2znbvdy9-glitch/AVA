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
npm run neuron:model
```

```bash
npm run neuron:sim
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

The npm scripts above deliberately use the repository-local CLI. This avoids
accidentally resolving an unrelated npm package with the common name `ava`.

## Scientific prototypes


- [AVA 01610 neuron-model analysis](docs/biologisch-plausible-neuronenmodelle.md) -
  German, source-grounded separation of the implemented prototype from future
  multi-compartment targets.
- [German narration script](docs/ava-01610-neuron-sprechtext.md) -
  complete spoken version prepared for MP3 production.
- [Hodgkin-Huxley teaching prototype](docs/hodgkin-huxley-prototype.md) -
  deterministic single-compartment membrane simulation with bounded inputs and
  regression tests. It is not a full pyramidal-cell model, learning system, or
  autonomous AVA/JARVIS agent.
- [AVA 01610 quantum which-path module](docs/ava-01610-quantum-which-path.md) -
  source-grounded German reference on which-path distinguishability,
  interference, quantum erasers and delayed choice, with explicit separation
  between measured effects, interpretation and unsupported consciousness or
  retrocausality claims.

## Security reference examples

- [Hardened C++ gRPC server](examples/grpc-secure/README.md) - mandatory mTLS,
  certificate-identity authorization, bounded resources, rate limiting, and
  signal-safe graceful shutdown.
