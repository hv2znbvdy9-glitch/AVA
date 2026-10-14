"""Offline, file-only AVA radio-style audio filter prototype.

This module processes existing PCM WAV files only. It does not open a microphone,
record from a device, access the network, clone a voice, or modify the input file.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
import wave
from pathlib import Path


MAX_INPUT_BYTES = 50 * 1024 * 1024
MAX_DURATION_SECONDS = 300
SUPPORTED_SAMPLE_WIDTH = 2  # PCM signed 16-bit little-endian
SUPPORTED_CHANNELS = {1, 2}
LOW_CUTOFF_HZ = 300.0
HIGH_CUTOFF_HZ = 3400.0


class AudioInputError(ValueError):
    """Raised when the input WAV is outside the prototype's safe limits."""


def radio_filter_pcm16(raw_frames: bytes, channels: int, sample_rate: int) -> bytes:
    """Apply a mild band-limited, softly saturated radio effect to PCM16 frames.

    Samples are filtered in a single pass with per-channel filter state, avoiding
    large per-sample Python lists. The only full-sized buffers are input and output.
    """
    if channels not in SUPPORTED_CHANNELS:
        raise AudioInputError("only mono or stereo WAV input is supported")
    if not 8_000 <= sample_rate <= 192_000:
        raise AudioInputError("sample rate must be between 8 kHz and 192 kHz")
    if len(raw_frames) % (SUPPORTED_SAMPLE_WIDTH * channels):
        raise AudioInputError("audio frame data is incomplete")

    hp_rc = 1.0 / (2.0 * math.pi * LOW_CUTOFF_HZ)
    dt = 1.0 / sample_rate
    hp_alpha = hp_rc / (hp_rc + dt)
    lp_rc = 1.0 / (2.0 * math.pi * HIGH_CUTOFF_HZ)
    lp_alpha = dt / (lp_rc + dt)
    previous_x = [0.0] * channels
    previous_hp_y = [0.0] * channels
    previous_lp_y = [0.0] * channels
    output = bytearray(len(raw_frames))

    for index, (sample_int,) in enumerate(struct.iter_unpack("<h", raw_frames)):
        channel = index % channels
        x = sample_int / 32768.0
        hp_y = hp_alpha * (previous_hp_y[channel] + x - previous_x[channel])
        previous_x[channel] = x
        previous_hp_y[channel] = hp_y
        lp_y = previous_lp_y[channel] + lp_alpha * (hp_y - previous_lp_y[channel])
        previous_lp_y[channel] = lp_y
        # Mild drive makes the result read as a generic radio effect.
        result = max(-32768, min(32767, round(math.tanh(lp_y * 2.0) * 0.92 * 32767)))
        struct.pack_into("<h", output, index * 2, result)
    return bytes(output)


def process_wav(input_path: str | Path, output_path: str | Path, *, overwrite: bool = False) -> dict[str, object]:
    """Filter a local PCM16 WAV and write a separate WAV output."""
    src = Path(input_path).expanduser().resolve(strict=True)
    dst = Path(output_path).expanduser().resolve(strict=False)
    if not src.is_file():
        raise AudioInputError("input path is not a regular file")
    if src == dst:
        raise AudioInputError("input and output paths must be different; source is never overwritten")
    if src.stat().st_size > MAX_INPUT_BYTES:
        raise AudioInputError(f"input file exceeds {MAX_INPUT_BYTES} byte limit")
    if dst.exists() and not overwrite:
        raise FileExistsError(f"output already exists: {dst}; choose another path or pass --overwrite")

    dst.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(src), "rb") as wav_in:
        channels = wav_in.getnchannels()
        sample_width = wav_in.getsampwidth()
        sample_rate = wav_in.getframerate()
        frame_count = wav_in.getnframes()
        compression = wav_in.getcomptype()
        if channels not in SUPPORTED_CHANNELS:
            raise AudioInputError("only mono or stereo WAV input is supported")
        if sample_width != SUPPORTED_SAMPLE_WIDTH:
            raise AudioInputError("input must be uncompressed 16-bit PCM WAV")
        if compression != "NONE":
            raise AudioInputError("compressed WAV input is not supported")
        if not 8_000 <= sample_rate <= 192_000:
            raise AudioInputError("sample rate must be between 8 kHz and 192 kHz")
        if frame_count / sample_rate > MAX_DURATION_SECONDS:
            raise AudioInputError(f"audio exceeds {MAX_DURATION_SECONDS} second limit")
        raw = wav_in.readframes(frame_count)

    filtered = radio_filter_pcm16(raw, channels, sample_rate)
    created_new_output = False
    try:
        if overwrite:
            with wave.open(str(dst), "wb") as wav_out:
                wav_out.setnchannels(channels)
                wav_out.setsampwidth(SUPPORTED_SAMPLE_WIDTH)
                wav_out.setframerate(sample_rate)
                wav_out.writeframes(filtered)
        else:
            # Create exclusively first so a race cannot silently overwrite another file.
            with dst.open("xb") as raw_out:
                created_new_output = True
                with wave.open(raw_out, "wb") as wav_out:
                    wav_out.setnchannels(channels)
                    wav_out.setsampwidth(SUPPORTED_SAMPLE_WIDTH)
                    wav_out.setframerate(sample_rate)
                    wav_out.writeframes(filtered)
    except Exception:
        # Remove only a new partial output created by this invocation; never delete a pre-existing file.
        if created_new_output:
            try:
                dst.unlink(missing_ok=True)
            except OSError:
                pass
        raise

    return {
        "status": "processed_locally",
        "input": str(src),
        "output": str(dst),
        "sample_rate_hz": sample_rate,
        "channels": channels,
        "duration_seconds": round(frame_count / sample_rate, 3),
        "effect": "band_limited_soft_saturation",
        "microphone_used": False,
        "network_access": False,
        "input_modified": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_wav", help="Existing local 16-bit PCM WAV file")
    parser.add_argument("output_wav", help="New output WAV path; not overwritten by default")
    parser.add_argument("--overwrite", action="store_true", help="Allow replacing the output path only")
    args = parser.parse_args()
    try:
        print(json.dumps(process_wav(args.input_wav, args.output_wav, overwrite=args.overwrite), indent=2))
    except (AudioInputError, FileExistsError, OSError, wave.Error) as exc:
        parser.exit(2, f"AVA audio prototype stopped safely: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
