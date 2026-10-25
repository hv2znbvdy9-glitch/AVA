"""Read-only loader and structural validation for AVA chemistry reference data."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

_DATA_PATH = Path(__file__).with_name("knowledge.json")


def load_knowledge() -> dict[str, Any]:
    """Load bundled educational reference data without performing reactions."""
    with _DATA_PATH.open(encoding="utf-8") as handle:
        data = json.load(handle)
    errors = validate_knowledge(data)
    if errors:
        raise ValueError("Invalid chemistry knowledge: " + "; ".join(errors))
    return data


def validate_knowledge(data: dict[str, Any]) -> list[str]:
    """Return structural/data-integrity errors; this does not validate lab results."""
    errors: list[str] = []
    if data.get("schema_version") != "1.0":
        errors.append("schema_version must be '1.0'")
    elements = data.get("s_block")
    if not isinstance(elements, list):
        errors.append("s_block must be a list")
        elements = []
    seen_numbers: set[int] = set()
    seen_symbols: set[str] = set()
    for index, item in enumerate(elements):
        if not isinstance(item, dict):
            errors.append(f"s_block[{index}] must be an object")
            continue
        for key in ("atomic_number", "symbol", "name", "group", "class"):
            if key not in item:
                errors.append(f"s_block[{index}] missing {key}")
        number, symbol, group = item.get("atomic_number"), item.get("symbol"), item.get("group")
        if isinstance(number, int) and number in seen_numbers:
            errors.append(f"duplicate atomic number: {number}")
        if isinstance(number, int):
            seen_numbers.add(number)
        if isinstance(symbol, str) and symbol in seen_symbols:
            errors.append(f"duplicate symbol: {symbol}")
        if isinstance(symbol, str):
            seen_symbols.add(symbol)
        if group not in (1, 2):
            errors.append(f"s_block[{index}] group must be 1 or 2")
    tests = data.get("cation_tests")
    if not isinstance(tests, list):
        errors.append("cation_tests must be a list")
        tests = []
    seen_ions: set[str] = set()
    for index, item in enumerate(tests):
        if not isinstance(item, dict):
            errors.append(f"cation_tests[{index}] must be an object")
            continue
        for key in ("ion", "reagent", "observation", "product", "requires_confirmation"):
            if key not in item:
                errors.append(f"cation_tests[{index}] missing {key}")
        ion = item.get("ion")
        if isinstance(ion, str):
            if ion in seen_ions:
                errors.append(f"duplicate cation test: {ion}")
            seen_ions.add(ion)
        if item.get("requires_confirmation") is not True:
            errors.append(f"cation_tests[{index}] must require confirmation")
    if not isinstance(data.get("safety"), dict):
        errors.append("safety must be an object")
    elif data["safety"].get("no_experiment_claim") is not True:
        errors.append("safety.no_experiment_claim must be true")
    return errors
