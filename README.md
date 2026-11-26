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
npx ava --repair-windows-system-files
```

```bash
npm run neuron:model
```

```bash
npm run neuron:sim
```

```bash
npm run neuron:multi
```

```bash
npm run map3d:libraries
```

```bash
node bin/cli.js --avatar-01610
```

### As a library

```js
const { avatar01610Report, avatar01610Data } = require('ava');

console.log(avatar01610Report());
console.log(avatar01610Data().cycle);
```

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
const { repairWindowsSystemFilesReport } = require('ava');

console.log(repairWindowsSystemFilesReport());
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
const {simulateMultiCompartment} = require('ava');

const trace = simulateMultiCompartment({
  durationMs: 30,
  dt: 0.01,
  current: (timeMs, index) => (index === 0 && timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

console.log(trace[0].compartments.length); // 3
```

```js
const {map3dLibrariesReport, map3dLibrariesData} = require('ava');

console.log(map3dLibrariesReport());
console.log(map3dLibrariesData().libraries.length); // 16
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

- [AVATAR–01610 DEVITO: Realität ist nicht flach](docs/avatar-01610-devito.md) -
  layered symbolic framework, evidence cycle, and quantum terms explicitly
  framed as metaphor.
- [AVA 01610 neuron-model analysis](docs/biologisch-plausible-neuronenmodelle.md) -
  German, source-grounded separation of the implemented prototype from future
  multi-compartment targets.
- [German narration script](docs/ava-01610-neuron-sprechtext.md) -
  complete spoken version prepared for MP3 production.
- [Hodgkin-Huxley teaching prototype](docs/hodgkin-huxley-prototype.md) -
  deterministic single-compartment membrane simulation with bounded inputs and
  regression tests. It is not a full pyramidal-cell model, learning system, or
  autonomous AVA/JARVIS agent.
- [Multi-compartment Hodgkin-Huxley teaching prototype](docs/multi-compartment-prototype.md) -
  deterministic chain of axially coupled compartments with per-compartment
  stimulus; still not the published Hay L5b model or a NEURON simulation.
- [Open-source 3D map and globe libraries](docs/map3d-libraries.md) - curated
  metadata-only reference list of 16 open-source 3D mapping projects; no
  dependencies and no third-party code.
- [AVA Voice Prototype](docs/ava-voice-prototype.md) - offline PCM effects using
  a creative radio-style profile; it does not capture or play audio.

- [AVA / AVO 01610 Scale Lab](docs/AVA-01610-scale-lab.md) - bounded, reproducible estimates for up to 690 million logical nodes; no infrastructure is created.
- [AVA / AVO 01610 Experiment Runbook](docs/AVA_01610_EXPERIMENT_RUNBOOK.md) - one-command Windows validation, the bounded scale model, and evidence boundaries.
- [AVA 01610 Safe Start Plan](docs/AVA_01610_SAFE_STARTPLAN.md) - read-only launcher inventory, SHA-256 evidence, privacy limits, and explicit AutoDefense guardrails.

## Security reference examples

- [Hardened C++ gRPC server](examples/grpc-secure/README.md) - mandatory mTLS,
  certificate-identity authorization, bounded resources, rate limiting, and
  signal-safe graceful shutdown.

## Windows recovery reference

- [Repair Windows system files from WinRE/WinPE](docs/repair-windows-system-files.md) -
  cautious reboot, BCD check, offline SFC/DISM order, and Startup Repair fallback.
