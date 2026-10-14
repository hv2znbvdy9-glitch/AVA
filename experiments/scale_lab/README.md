# AVA / AVO 01610 — Scale Lab

## Purpose
A reproducible, local-only first experiment for the 690,000,000 logical-node
research target. It calculates an aggregate estimate from a configurable
per-node memory assumption; it does **not** provision servers, create a
690-million-object simulation, contact cloud services, or transmit via satellite.

## Run
Requires Python 3.10+; standard library only.

```sh
python experiments/scale_lab/node_simulator.py
python -m unittest discover -s experiments/scale_lab -p 'test_*.py' -v
```

The default 256 bytes per logical node is an illustrative assumption, not a
measured AVA footprint. Change `--bytes-per-node` to explore assumptions.
A sample is bounded to 1,000,000 nodes; the target is represented with arithmetic
only. Output explicitly labels itself as an aggregate estimate.

## Evidence boundary
A green unit-test workflow proves only that these model checks passed on the
runner. It does not prove real-world scalability, deployment, or physical servers.
