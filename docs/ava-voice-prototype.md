# AVA Voice Prototype

The dependency-free v0.1 prototype applies the `AVA_RADIO_01610~1` creative
audio profile to mono, normalized PCM samples. It supports pitch/speed shifting,
a radio-style filter, deterministic glitch repeats, echo, and soft-clipping
distortion.

```js
const {processAudio} = require('ava');

const output = processAudio(inputSamples, {sampleRate: 48000});
```

`inputSamples` must be an array or `Float32Array` with finite values from -1 to
1. The output is a new `Float32Array`; the input is not modified. A positive
pitch shift raises pitch by resampling and therefore shortens playback duration.
This is an offline signal-processing function: it does not capture a microphone,
play audio, write files, or install itself on a device.

These are creative sound effects only, not medical or therapeutic effects.
