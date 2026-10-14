# AVA_RADIO_01610 — Offline Audio Prototype

This is a deliberately small, local-only prototype for a synthetic radio-style effect. It processes an **existing WAV file** and writes a separate output file.

## Scope and safety

- No microphone or input-device capture; no recording daemon or background task.
- No network, cloud service, GitHub API, or telemetry from the module.
- The input file is not modified. Existing output paths are not overwritten unless `--overwrite` is explicitly supplied.
- No voice cloning or imitation of a real individual; this is a generic band-limited, softly saturated filter.
- Limits: uncompressed PCM16 mono/stereo WAV, 8–192 kHz, 5 minutes maximum, 50 MiB maximum file size.
- Standard library only. No installation of packages or OS-wide changes.

## Usage

```sh
python experiments/audio_local/ava_radio_local.py input.wav output_radio.wav
python -m unittest discover -s experiments/audio_local -p 'test_*.py' -v
```

To replace an existing *output* file deliberately, pass `--overwrite`. Never use the input path as the output path.

## Evidence boundary

Unit tests cover input validation, output/source separation, frame length, and offline-only report flags. Passing tests do not prove audio quality across every recording or imply any system-wide installation.
