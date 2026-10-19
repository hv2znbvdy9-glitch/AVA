# AVA 01610-15 — Reproducible genetic-algorithm experiment

## Purpose

A small offline teaching experiment evolves candidate strings toward `PYTHON IS AWESOME`. It demonstrates fitness scoring, selection, single-point crossover, mutation, elitism, and bounded stopping.

## Reproducibility

The default seed is `1610`. The same Python version and the same arguments produce the same report. The report includes a generation-by-generation best-fitness trace and a stop reason (`target_reached` or `max_generations`).

## Model details

- Fitness is the number of characters matching the target at the same positions.
- The default population is 200 candidates; the 20 best candidates are retained as elites.
- Children are formed by single-point crossover of selected elites.
- Each character has a 3% chance of mutation to a different printable ASCII character.
- The default generation limit is 1,000.
- Elitism preserves the best-so-far candidate, so best fitness cannot decrease between recorded generations.

The target is not guaranteed to be reached within the generation limit. The algorithm reports failure to reach it instead of presenting a partial match as success. Fitness is a deliberately simple teaching metric, not a measure of intelligence or a claim about biological evolution.

## Run from the repository root

```powershell
python -m unittest discover -s .\tests -p "test_ava_genetic_algorithm.py" -v
python -m ava.genetic_algorithm --seed 1610 --population-size 200 --elite-count 20 --mutation-rate 0.03 --max-generations 1000
```

To save a local report explicitly:

```powershell
python -m ava.genetic_algorithm --seed 1610 > .\ava-genetic-algorithm-report.json
```

The program writes JSON to standard output and does not create files unless the caller redirects output. It does not access the network, create servers or workers, or change system configuration. The particle-sphere artwork is a conceptual visualization only and does not demonstrate real infrastructure or energy transfer.

## Evidence labels

- **Modelled:** candidate strings, fitness scores, crossover, and mutation.
- **Reproducible:** pseudorandom choices controlled by the seed.
- **Not guaranteed:** reaching the exact target before the generation limit.
- **Not performed by this module:** Windows system changes, cloud provisioning, satellite transmission, or external network activity.
