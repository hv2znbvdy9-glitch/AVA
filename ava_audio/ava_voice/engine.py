"""Offline audio effects for explicitly supplied mono PCM16 WAV files.

This prototype does not capture a microphone, access a network, or install
itself. Pitch shifting here is simple resampling and therefore changes duration.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
import math
from pathlib import Path
import struct
import wave
from typing import Iterable


@dataclass(frozen=True)
class VoiceConfig:
    pitch_shift: float = 3.0
    echo: bool = True
    radio_filter: bool = True
    glitch: bool = True
    distortion: float = 0.15
    echo_delay_seconds: float = 0.085
    echo_gain: float = 0.22
    glitch_every_seconds: float = 1.7
    glitch_burst_seconds: float = 0.015

    def validate(self) -> None:
        if isinstance(self.pitch_shift, bool) or not math.isfinite(self.pitch_shift) or not -12 <= self.pitch_shift <= 12:
            raise ValueError("pitch_shift must be finite and between -12 and 12 semitones")
        if isinstance(self.distortion, bool) or not math.isfinite(self.distortion) or not 0 <= self.distortion <= 1:
            raise ValueError("distortion must be finite and between 0 and 1")
        if not math.isfinite(self.echo_delay_seconds) or not 0.001 <= self.echo_delay_seconds <= 1:
            raise ValueError("echo_delay_seconds must be between 0.001 and 1 second")
        if not math.isfinite(self.echo_gain) or not 0 <= self.echo_gain <= 0.8:
            raise ValueError("echo_gain must be between 0 and 0.8")
        if not math.isfinite(self.glitch_every_seconds) or self.glitch_every_seconds <= 0:
            raise ValueError("glitch_every_seconds must be positive")
        if not math.isfinite(self.glitch_burst_seconds) or not 0 <= self.glitch_burst_seconds <= 0.2:
            raise ValueError("glitch_burst_seconds must be between 0 and 0.2 seconds")


def config_from_json(path: str | Path) -> VoiceConfig:
    """Load effect settings from JSON, ignoring non-effect metadata keys."""
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    effects = raw.get("effects", raw)
    if not isinstance(effects, dict):
        raise ValueError("profile must contain an 'effects' object")
    permitted = set(VoiceConfig.__dataclass_fields__)
    cfg = VoiceConfig(**{key: value for key, value in effects.items() if key in permitted})
    cfg.validate()
    return cfg


def _resample_pitch(samples: list[float], semitones: float) -> list[float]:
    if not samples or semitones == 0:
        return samples.copy()
    factor = 2.0 ** (semitones / 12.0)
    out_len = max(1, round(len(samples) / factor))
    if len(samples) == 1:
        return samples.copy()
    result: list[float] = []
    for i in range(out_len):
        source = min(i * factor, len(samples) - 1)
        left = int(source)
        right = min(left + 1, len(samples) - 1)
        fraction = source - left
        result.append(samples[left] * (1.0 - fraction) + samples[right] * fraction)
    return result


def _radio_bandpass(samples: list[float], sample_rate: int) -> list[float]:
    # First-order high-pass at ~300 Hz followed by low-pass at ~3.4 kHz.
    dt = 1.0 / sample_rate
    hp_rc = 1.0 / (2.0 * math.pi * 300.0)
    hp_alpha = hp_rc / (hp_rc + dt)
    lp_rc = 1.0 / (2.0 * math.pi * 3400.0)
    lp_alpha = dt / (lp_rc + dt)
    high: list[float] = []
    previous_input = 0.0
    previous_output = 0.0
    for x in samples:
        y = hp_alpha * (previous_output + x - previous_input)
        high.append(y)
        previous_input, previous_output = x, y
    low: list[float] = []
    state = 0.0
    for x in high:
        state += lp_alpha * (x - state)
        low.append(state)
    return low


def process_samples(samples: Iterable[float], sample_rate: int, config: VoiceConfig | None = None) -> list[float]:
    """Apply deterministic effects to normalized float samples in [-1, 1]."""
    if isinstance(sample_rate, bool) or not isinstance(sample_rate, int) or not 1000 <= sample_rate <= 192000:
        raise ValueError("sample_rate must be an integer in [1000, 192000]")
    source = list(samples)
    if any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) for x in source):
        raise ValueError("samples must be finite numeric values")
    if any(x < -1.0 or x > 1.0 for x in source):
        raise ValueError("samples must be normalized to [-1, 1]")
    cfg = config or VoiceConfig()
    cfg.validate()
    out = _resample_pitch([float(x) for x in source], cfg.pitch_shift)
    if cfg.radio_filter and out:
        out = _radio_bandpass(out, sample_rate)
    if cfg.echo and out:
        delay = max(1, round(sample_rate * cfg.echo_delay_seconds))
        for i in range(delay, len(out)):
            out[i] += cfg.echo_gain * out[i - delay]
    if cfg.glitch and out:
        period = max(1, round(sample_rate * cfg.glitch_every_seconds))
        burst = round(sample_rate * cfg.glitch_burst_seconds)
        if burst:
            for start in range(period, len(out), period):
                stop = min(len(out), start + burst)
                for i in range(start, stop):
                    out[i] = 0.0
    if cfg.distortion > 0 and out:
        drive = 1.0 + 12.0 * cfg.distortion
        normalizer = math.tanh(drive)
        out = [math.tanh(max(-1.0, min(1.0, x)) * drive) / normalizer for x in out]
    return [max(-1.0, min(1.0, float(x))) for x in out]


def _read_mono_pcm16(path: Path) -> tuple[int, list[float]]:
    with wave.open(str(path), "rb") as src:
        if src.getnchannels() != 1:
            raise ValueError("only mono WAV input is supported")
        if src.getsampwidth() != 2 or src.getcomptype() != "NONE":
            raise ValueError("only uncompressed 16-bit PCM WAV input is supported")
        rate = src.getframerate()
        raw = src.readframes(src.getnframes())
    if len(raw) % 2:
        raise ValueError("invalid PCM16 frame length")
    integers = struct.unpack("<" + "h" * (len(raw) // 2), raw)
    return rate, [n / 32768.0 for n in integers]


def _write_mono_pcm16(path: Path, sample_rate: int, samples: Iterable[float]) -> None:
    values = list(samples)
    raw = bytearray()
    for x in values:
        clipped = max(-1.0, min(1.0, float(x)))
        integer = max(-32768, min(32767, round(clipped * 32767.0)))
        raw.extend(struct.pack("<h", integer))
    # Exclusive creation ("xb") prevents a race from truncating a file that
    # appears after process_wav_file checks target.exists().
    with path.open("xb") as raw_file:
        with wave.open(raw_file, "wb") as dst:
            dst.setnchannels(1)
            dst.setsampwidth(2)
            dst.setframerate(sample_rate)
            dst.writeframes(bytes(raw))


def process_wav_file(input_path: str | Path, output_path: str | Path, config: VoiceConfig | None = None) -> dict[str, int | str]:
    """Process one local WAV file; refuse to overwrite the input file."""
    source = Path(input_path).expanduser().resolve()
    target = Path(output_path).expanduser().resolve()
    if source == target:
        raise ValueError("output_path must differ from input_path; source is never overwritten")
    if target.exists():
        raise FileExistsError(f"output WAV already exists; refusing to overwrite: {target}")
    if not source.is_file():
        raise FileNotFoundError(f"input WAV not found: {source}")
    rate, samples = _read_mono_pcm16(source)
    processed = process_samples(samples, rate, config)
    _write_mono_pcm16(target, rate, processed)
    return {
        "input": str(source),
        "output": str(target),
        "sample_rate": rate,
        "input_samples": len(samples),
        "output_samples": len(processed),
        "real_time_microphone_capture": "disabled",
        "network_upload": "disabled",
    }
