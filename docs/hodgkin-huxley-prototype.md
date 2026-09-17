# AVA Hodgkin-Huxley neuron prototype

This module is a small, deterministic research and teaching prototype of the
classic single-compartment Hodgkin-Huxley membrane model. It is an incremental
step beyond a leaky integrate-and-fire point neuron, not a full implementation
of the multi-compartment Layer-5 pyramidal-cell models discussed in the source
analysis.

## Scope

Implemented:

- sodium, potassium, and leak currents;
- voltage-dependent m, h, and n gates;
- numerically stable rate functions at their removable singularities;
- bounded input validation and explicit-Euler integration;
- deterministic tests for rest stability and a current-evoked action potential.

Not implemented:

- reconstructed 3D morphology or electrically coupled compartments;
- dendritic spines, NMDA or calcium spikes;
- synaptic plasticity, neuromodulation, metabolism, gene expression, or glia;
- learning, agency, consciousness, or an autonomous "Jarvis" system.

The scientific distinction matters: biological detail is not the same as
intelligence. This module produces a membrane-voltage simulation only.

## Usage

```js
const { simulate } = require('./src/neuron/hodgkin-huxley');

const trace = simulate({
  durationMs: 30,
  dt: 0.01,
  current: timeMs => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

console.log(Math.max(...trace.map(sample => sample.voltage)));
```

Units follow the conventional Hodgkin-Huxley formulation: time in ms, voltage
in mV, capacitance in uF/cm2, conductance in mS/cm2, and current density in
uA/cm2. The integrator limits `dt` to 0.1 ms; `0.01` ms is the tested value.

## Validation and limitations

The tests verify finite rates at -40 mV and -55 mV, near-rest behavior, a
positive spike under a 10 uA/cm2 pulse, invalid-step rejection, and finite
output. They are regression checks, not experimental validation.

A future multi-compartment extension should first define morphology and
coupling data, select validated channel distributions, adopt a more suitable
ODE solver, record parameter provenance, compare against published traces, and
include uncertainty and convergence analyses.

## Sources behind the attached analysis

- Hay et al. (2011), *Models of Neocortical Layer 5b Pyramidal Cells Capturing
  a Wide Range of Dendritic and Perisomatic Active Properties*:
  https://doi.org/10.1371/journal.pcbi.1002107
- A GPU-based framework with explicit dendritic spines (2023):
  https://doi.org/10.1038/s41467-023-41553-7
- Cortical microcircuit reliability study (2019):
  https://doi.org/10.1038/s41467-019-11633-8

The 2026 "reference-grade neuron models" citation in the supplied text should
be independently verified before it is used as an implementation requirement.
