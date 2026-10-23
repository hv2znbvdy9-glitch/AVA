"""Offline tests for the AVA_AUDIO signal-processing prototype."""
from __future__ import annotations

import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path

from ava_voice.engine import VoiceConfig, config_from_json, process_samples, process_wav_file


class VoicePipelineTests(unittest.TestCase):
    def test_no_effects_preserves_samples(self):
        input_samples = [0.0, 0.25, -0.5, 1.0, -1.0]
        cfg = VoiceConfig(pitch_shift=0, echo=False, radio_filter=False, glitch=False, distortion=0)
        self.assertEqual(process_samples(input_samples, 16000, cfg), input_samples)

    def test_effects_are_bounded_and_deterministic(self):
        samples = [0.3 * math.sin(2 * math.pi * 440 * i / 16000) for i in range(16000)]
        cfg = VoiceConfig()
        first = process_samples(samples, 16000, cfg)
        second = process_samples(samples, 16000, cfg)
        self.assertEqual(first, second)
        self.assertTrue(first)
        self.assertTrue(all(-1 <= x <= 1 for x in first))
        self.assertNotEqual(len(first), len(samples))  # pitch resampling affects duration

    def test_rejects_invalid_input_and_configuration(self):
        with self.assertRaises(ValueError):
            process_samples([float("nan")], 16000)
        with self.assertRaises(ValueError):
            process_samples([1.2], 16000)
        with self.assertRaises(ValueError):
            process_samples([0.0], 300)
        with self.assertRaises(ValueError):
            VoiceConfig(pitch_shift=99).validate()

    def test_profile_loads(self):
        profile = Path(__file__).resolve().parents[1] / "profiles" / "AVA_RADIO_01610.json"
        cfg = config_from_json(profile)
        self.assertEqual(cfg.pitch_shift, 3)
        self.assertTrue(cfg.radio_filter)

    def test_wav_processing_does_not_overwrite_source(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source.wav"
            target = Path(temp) / "processed.wav"
            raw = struct.pack("<" + "h" * 320, *[
                int(9000 * math.sin(2 * math.pi * 300 * i / 16000)) for i in range(320)
            ])
            with wave.open(str(source), "wb") as wav:
                wav.setnchannels(1)
                wav.setsampwidth(2)
                wav.setframerate(16000)
                wav.writeframes(raw)
            original = source.read_bytes()
            report = process_wav_file(source, target, VoiceConfig(pitch_shift=0))
            self.assertEqual(source.read_bytes(), original)
            self.assertTrue(target.exists())
            self.assertEqual(report["network_upload"], "disabled")
            with self.assertRaises(ValueError):
                process_wav_file(source, source, VoiceConfig(pitch_shift=0))
            target.write_bytes(b"existing output must survive")
            with self.assertRaises(FileExistsError):
                process_wav_file(source, target, VoiceConfig(pitch_shift=0))
            self.assertEqual(target.read_bytes(), b"existing output must survive")


if __name__ == "__main__":
    unittest.main()
