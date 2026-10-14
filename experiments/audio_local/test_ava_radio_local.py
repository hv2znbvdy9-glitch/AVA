import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path

from ava_radio_local import AudioInputError, process_wav, radio_filter_pcm16


class AudioRadioPrototypeTests(unittest.TestCase):
    def make_wav(self, path: Path, *, channels=1, sample_width=2, sample_rate=16000, seconds=0.1):
        frames = []
        count = int(sample_rate * seconds)
        for i in range(count):
            sample = round(0.5 * 32767 * math.sin(2 * math.pi * 800 * i / sample_rate))
            for _ in range(channels):
                frames.append(sample)
        raw = struct.pack("<" + ("h" * len(frames)), *frames) if sample_width == 2 else bytes([128] * len(frames))
        with wave.open(str(path), "wb") as wav:
            wav.setnchannels(channels)
            wav.setsampwidth(sample_width)
            wav.setframerate(sample_rate)
            wav.writeframes(raw)

    def test_filters_pcm16_and_preserves_frame_length(self):
        raw = struct.pack("<hhhh", 0, 10000, -10000, 0)
        result = radio_filter_pcm16(raw, channels=1, sample_rate=16000)
        self.assertEqual(len(result), len(raw))
        self.assertNotEqual(result, raw)

    def test_local_file_roundtrip_and_source_unchanged(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = Path(tmp) / "in.wav", Path(tmp) / "out.wav"
            self.make_wav(src)
            original = src.read_bytes()
            report = process_wav(src, dst)
            self.assertEqual(src.read_bytes(), original)
            self.assertTrue(dst.exists())
            self.assertFalse(report["microphone_used"])
            self.assertFalse(report["network_access"])
            with wave.open(str(dst), "rb") as wav:
                self.assertEqual(wav.getsampwidth(), 2)
                self.assertEqual(wav.getframerate(), 16000)

    def test_refuses_to_overwrite_input_or_existing_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = Path(tmp) / "in.wav", Path(tmp) / "out.wav"
            self.make_wav(src)
            with self.assertRaises(AudioInputError):
                process_wav(src, src)
            dst.write_bytes(b"keep")
            with self.assertRaises(FileExistsError):
                process_wav(src, dst)
            self.assertEqual(dst.read_bytes(), b"keep")

    def test_rejects_non_pcm16_wav(self):
        with tempfile.TemporaryDirectory() as tmp:
            src, dst = Path(tmp) / "in8.wav", Path(tmp) / "out.wav"
            self.make_wav(src, sample_width=1)
            with self.assertRaises(AudioInputError):
                process_wav(src, dst)

    def test_rejects_invalid_channels_and_sample_rate(self):
        with self.assertRaises(AudioInputError):
            radio_filter_pcm16(b"\\x00\\x00", channels=3, sample_rate=16000)
        with self.assertRaises(AudioInputError):
            radio_filter_pcm16(b"\\x00\\x00", channels=1, sample_rate=1000)


if __name__ == "__main__":
    unittest.main()
