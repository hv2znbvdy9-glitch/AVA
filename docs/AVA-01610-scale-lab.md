# AVA / AVO 01610-1 — Scale Lab

## Objective

Explore the capacity implications of a theoretical topology of up to **690,000,000 logical nodes** using a reproducible analytical model plus a deterministic, bounded sample.

## Safety boundary

The experiment does **not** create physical or cloud servers, node processes, workers, network connections, accounts, or external resources. Only up to 100,000 pseudo-random sample observations are computed. The logical node count is handled by arithmetic.

## Model assumptions

Defaults are declared in `src/scale-lab.js`: 512 bytes of logical state per node, six messages per node per hour, a 128-byte payload, and a 0.1% assumed per-node failure probability. They are illustrative inputs, not measured AVA production data.

The report estimates logical state size, messages per second, payload bandwidth, and a rough daily event-log volume that includes a fixed 96-byte event overhead. Outputs scale directly from the assumptions and do not account for protocol framing, replication, compression, retries, topology, or physical infrastructure overhead.

Energy is not measured. An optional `--energy-watts-per-node` input calculates a what-if figure only and is clearly labeled as an assumption. A “virtual node” is not a physical machine, so this number must not be treated as a real power estimate without a hardware mapping. There is no medical or therapeutic model in this experiment.

## Run

```bash
node src/scale-lab.js --nodes 690000000 --sample-size 10000 --seed 1610
node test/scale-lab.test.js
npm test
```

The fixed seed makes sampled failure counts reproducible. `createdAt` changes between runs; compare the numeric fields for reproducibility. The CLI writes JSON to stdout and does not persist or upload it automatically.

## Evidence labels

- **Modelled:** values calculated from declared assumptions.
- **Sampled:** bounded failure observations using a deterministic PRNG.
- **Not measured:** real throughput, latency, energy, physical failures, or recovery time.
- **Not performed:** server provisioning, cloud deployment, satellite transmission, medical assessment, or external network calls.

Workflow execution status must be verified separately from this local test result.
