"""Reproducible, bounded genetic-algorithm teaching experiment for AVA.

This is an offline simulation. It creates in-memory strings only; it does not
access the network, launch workers, or modify system configuration.
"""
from __future__ import annotations

import argparse
import json
import random
import string
from typing import Any

DEFAULT_TARGET = "PYTHON IS AWESOME"
DEFAULT_POPULATION_SIZE = 200
DEFAULT_ELITE_COUNT = 20
DEFAULT_MUTATION_RATE = 0.03
DEFAULT_MAX_GENERATIONS = 1_000
MAX_POPULATION_SIZE = 10_000
MAX_GENERATIONS = 100_000


def fitness(candidate: str, target: str) -> int:
    """Count characters matching the target at the same positions."""
    if len(candidate) != len(target):
        raise ValueError("candidate and target must have equal length")
    return sum(left == right for left, right in zip(candidate, target))


def run_evolution(
    target: str = DEFAULT_TARGET,
    *,
    seed: int = 1610,
    population_size: int = DEFAULT_POPULATION_SIZE,
    elite_count: int = DEFAULT_ELITE_COUNT,
    mutation_rate: float = DEFAULT_MUTATION_RATE,
    max_generations: int = DEFAULT_MAX_GENERATIONS,
) -> dict[str, Any]:
    """Run a bounded, seeded GA and return a JSON-serializable evidence report."""
    if not isinstance(target, str) or not target:
        raise ValueError("target must be a non-empty string")
    if any(ord(char) < 32 or ord(char) > 126 for char in target):
        raise ValueError("target must contain printable ASCII characters only")
    if isinstance(seed, bool) or not isinstance(seed, int) or not 0 <= seed <= 2**32 - 1:
        raise ValueError("seed must be an integer in [0, 2**32 - 1]")
    if isinstance(population_size, bool) or not isinstance(population_size, int) or not 2 <= population_size <= MAX_POPULATION_SIZE:
        raise ValueError(f"population_size must be an integer in [2, {MAX_POPULATION_SIZE}]")
    if isinstance(elite_count, bool) or not isinstance(elite_count, int) or not 1 <= elite_count < population_size:
        raise ValueError("elite_count must be an integer in [1, population_size - 1]")
    if isinstance(mutation_rate, bool) or not isinstance(mutation_rate, (int, float)) or not 0.0 <= mutation_rate <= 1.0:
        raise ValueError("mutation_rate must be a number in [0, 1]")
    if isinstance(max_generations, bool) or not isinstance(max_generations, int) or not 0 <= max_generations <= MAX_GENERATIONS:
        raise ValueError(f"max_generations must be an integer in [0, {MAX_GENERATIONS}]")

    # The alphabet is printable ASCII and includes every target character.
    alphabet = string.ascii_uppercase + string.ascii_lowercase + string.digits + " " + string.punctuation
    alphabet = "".join(dict.fromkeys(alphabet + target))
    rng = random.Random(seed)
    length = len(target)

    def random_candidate() -> str:
        return "".join(rng.choice(alphabet) for _ in range(length))

    def score(candidate: str) -> int:
        return fitness(candidate, target)

    population = [random_candidate() for _ in range(population_size)]
    best = max(population, key=score)
    best_fitness = score(best)
    history: list[dict[str, Any]] = [{"generation": 0, "best_fitness": best_fitness, "best_candidate": best}]
    generations_completed = 0
    stop_reason = "max_generations"

    if best == target:
        stop_reason = "target_reached"
    else:
        for generation in range(1, max_generations + 1):
            ranked = sorted(population, key=score, reverse=True)
            elites = ranked[:elite_count]
            next_population = list(elites)  # elitism: best candidates cannot be lost
            while len(next_population) < population_size:
                parent_a = rng.choice(elites)
                parent_b = rng.choice(elites)
                if length > 1:
                    cut = rng.randrange(1, length)
                    child = parent_a[:cut] + parent_b[cut:]
                else:
                    child = parent_a
                chars = list(child)
                for index in range(length):
                    if rng.random() < mutation_rate:
                        alternatives = alphabet.replace(chars[index], "")
                        if alternatives:
                            chars[index] = rng.choice(alternatives)
                next_population.append("".join(chars))

            population = next_population
            generation_best = max(population, key=score)
            generation_fitness = score(generation_best)
            generations_completed = generation
            if generation_fitness > best_fitness:
                best, best_fitness = generation_best, generation_fitness
            history.append({"generation": generation, "best_fitness": best_fitness, "best_candidate": best})
            if best == target:
                stop_reason = "target_reached"
                break

    return {
        "experiment": "AVA_01610_15_GENETIC_ALGORITHM",
        "mode": "offline_simulation_only",
        "target": target,
        "best_candidate": best,
        "best_fitness": best_fitness,
        "target_length": length,
        "fitness_definition": "number of matching characters at the same positions",
        "seed": seed,
        "population_size": population_size,
        "elite_count": elite_count,
        "mutation_rate": float(mutation_rate),
        "max_generations": max_generations,
        "generations_completed": generations_completed,
        "stop_reason": stop_reason,
        "target_reached": best == target,
        "history": history,
        "evidence_note": "Seeded synthetic search only. No real infrastructure, biological evolution, or external system is involved.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", default=DEFAULT_TARGET)
    parser.add_argument("--seed", type=int, default=1610)
    parser.add_argument("--population-size", type=int, default=DEFAULT_POPULATION_SIZE)
    parser.add_argument("--elite-count", type=int, default=DEFAULT_ELITE_COUNT)
    parser.add_argument("--mutation-rate", type=float, default=DEFAULT_MUTATION_RATE)
    parser.add_argument("--max-generations", type=int, default=DEFAULT_MAX_GENERATIONS)
    args = parser.parse_args()
    try:
        report = run_evolution(
            args.target,
            seed=args.seed,
            population_size=args.population_size,
            elite_count=args.elite_count,
            mutation_rate=args.mutation_rate,
            max_generations=args.max_generations,
        )
    except ValueError as exc:
        parser.error(str(exc))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
