# AVA Hodgkin-Huxley teaching prototype

This module is a deterministic implementation of the classic
single-compartment Hodgkin-Huxley membrane model. It is an executable,
dependency-free starting point for the broader neuron-model analysis in
[`biologisch-plausible-neuronenmodelle.md`](biologisch-plausible-neuronenmodelle.md).

It is deliberately **not** presented as the Hay L5b model, DeepDendrite, a
learning system, consciousness, or an autonomous AVA/JARVIS agent.

## Implemented scope

- sodium, potassium, and leak currents;
- voltage-dependent `m`, `h`, and `n` gates;
- stable rate functions at the removable singularities;
- finite-value, timestep, conductance, gate, and total-step validation;
- deterministic regression checks for rest and a current-evoked spike;
- a bounded CLI demonstration that prints only a summary.

Not implemented are reconstructed morphology, coupled dendritic compartments,
spines, synapses, calcium or NMDA spikes, plasticity, metabolism, gene
expression, glia, learning, or agency.

## Run the bounded demonstration

```bash
npx ava --neuron-sim
```

The same command works as `npx ava neuron-sim`. It runs for 30 ms with a tested
`0.01 ms` step and reports the peak voltage and whether the trace crossed 0 mV.
It performs no network, operating-system, persistence, or device action.

## Library usage

```js
const {simulateNeuron} = require('ava');

const trace = simulateNeuron({
	durationMs: 30,
	dt: 0.01,
	current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

console.log(Math.max(...trace.map((sample) => sample.voltage)));
```

Units follow the conventional formulation: time in ms, voltage in mV,
capacitance in uF/cm2, conductance in mS/cm2, and current density in uA/cm2.
The explicit-Euler integrator accepts at most `0.1 ms`; `0.01 ms` is the tested
value. Runs above 1,000,000 steps are rejected to keep memory and runtime
bounded.

## Scientific boundary

The regression tests demonstrate internal numerical behavior only. They are
not experimental validation. A real multi-compartment extension must define
morphology and axial coupling, select validated channel distributions, use a
suitable ODE solver, record parameter provenance, compare against published
traces, and include convergence, sensitivity, and uncertainty analyses.

Relevant primary literature:

- Hay et al. (2011), DOI `10.1371/journal.pcbi.1002107`;
- Zhang et al. (2023), DOI `10.1038/s41467-023-41553-7`;
- Nolte et al. (2019), DOI `10.1038/s41467-019-11633-8`;
- Korngreen (2026), DOI `10.1038/s42003-026-10561-w`.
