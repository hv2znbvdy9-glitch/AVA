"""Command-line entry point for offline AVA_AUDIO WAV processing."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from .engine import config_from_json, process_wav_file


def main() -> None:
    default_profile = Path(__file__).resolve().parents[1] / "profiles" / "AVA_RADIO_01610.json"
    parser = argparse.ArgumentParser(description="Apply local AVA radio-style effects to a mono PCM16 WAV file.")
    parser.add_argument("input", help="input mono 16-bit PCM WAV file")
    parser.add_argument("output", help="output WAV path (must differ from input)")
    parser.add_argument("--profile", default=str(default_profile), help="effect profile JSON")
    args = parser.parse_args()
    try:
        config = config_from_json(args.profile)
        report = process_wav_file(args.input, args.output, config)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
