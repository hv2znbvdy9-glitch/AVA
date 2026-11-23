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
const { run, evaluateEpisode, buildTrend } = require('ava');

const result = run('echo hello', { silent: true });
console.log(result.stdout); // "hello\n"
console.log(result.stderr); // ""
console.log(result.exitCode); // 0

const episode = {
	timestamp: new Date().toISOString(),
	durationMinutes: 8,
	sleepHours: 6,
	stressLevel: 7,
	earPressure: true,
	headache: 'mild',
	medicationsSubstances: 'none',
	pulse: 76,
	immediateContext: 'after stressful call',
	changes: {speech: false, strength: false, vision: false, orientation: false},
	notes: 'short control-loss feeling',
	foreignControlFeeling: true,
};

const evaluation = evaluateEpisode(episode, []);
console.log(evaluation.status); // 'beobachten'

const trend = buildTrend([episode]);
console.log(trend.totalEpisodes); // 1
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

## AVA MVP safety/event APIs

The library now includes an evidence-first MVP layer for structured episode logging:

- `createEpisode(input)` — validates required observation fields.
- `evaluateEpisode(episode, history)` — returns one status:
	- `ruhig`
	- `beobachten`
	- `ärztlich zeitnah`
	- `Notfall`
- `enterProtectionMode()` — enforces the rule:
	`Keine Aktion gegen andere, erst objektive Prüfung.`
- `summarizeEpisode(episode, evaluation)` — compact per-episode VIV summary.
- `buildTrend(episodes)` — frequency, trigger patterns, symptom combinations.

Scope limits:
- No diagnosis output.
- No claims about unverified causes.
