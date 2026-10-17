# AVA_AUDIO — AVA_RADIO_01610 v0.1.0

An original synthetic radio-style offline audio-effects prototype. It is not a copy of a real person's voice or an impersonation profile.

## Current scope

- Reads an explicitly supplied mono, uncompressed 16-bit PCM WAV file.
- Applies simple pitch-by-resampling, a basic radio band-pass, echo, periodic glitch dropouts, and soft clipping.
- Writes a separate output WAV and prints a small processing summary.
- Uses only the Python standard library; tests do not need microphone hardware.

## Run on Windows (PowerShell)

From the AVA repository root:

    $env:PYTHONPATH = "ava_audio"
    python -m ava_voice.cli .\input.wav .\output_ava_radio.wav
    python -m unittest discover -s .\ava_audio\tests -v

Use your own permitted WAV file as the input. The output path must differ from the source. The default profile is ava_audio/profiles/AVA_RADIO_01610.json.

## Privacy and limitations

No microphone capture, always-on listener, autostart, installation, network upload, or remote control is implemented. The input file is only read when the command is run; the output is written to the explicit output path. Keep personal recordings private and do not upload them to CI. Pitch shifting is basic resampling, so it changes playback duration; this is a prototype, not a real-time voice changer or a production DSP implementation.

## Evidence boundary

The unit tests verify local signal-processing behavior and WAV handling only. They do not demonstrate actual live microphone transformation, identity concealment, neural training, real-world system scaling, or deployment to a Windows laptop. GitHub Actions is configured to test the package when the workflow is introduced through a pull request or when manually dispatched.
