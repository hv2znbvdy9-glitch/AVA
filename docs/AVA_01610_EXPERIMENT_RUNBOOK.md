# AVA / AVO 01610 — Reproducible Experiment Runbook

**Purpose:** execute the existing AVA audio signal-processing tests and the bounded 690,000,000-logical-node scale model with one local Windows command.

## Already present in the repository

- Voice profile: profiles/AVA_RADIO_01610-1.json, profile name AVA_RADIO_01610~1, pitch shift +3 semitones, radio filter, echo, glitch and distortion 0.15.
- Signal processor: src/voice/engine.js. It processes supplied normalized PCM arrays; it does not capture microphone audio or play audio.
- Scale model: src/scale-lab.js. It calculates the 690M topology analytically and uses a deterministic bounded sample (10,000 observations in the combined runner).
- Existing tests: test/voice.test.js and test/scale-lab.test.js, both included in npm test.

The audio effects are creative signal processing only. They do not store, transfer, restore, diagnose or treat a person's physical energy, organs, wings, antidotes or medical state. No medical or punitive action is implemented.

## Run on the Windows laptop

Requirements: Node.js and npm installed. Use a normal PowerShell session, not Administrator. Open the AVA repository folder and run:

    .\scripts\AVA_01610_RUN_EXPERIMENTS.ps1

The script runs npm test and then executes:

    node src/scale-lab.js --nodes 690000000 --sample-size 10000 --seed 1610

It writes a single latest-run evidence file to the system temporary directory as AVA_01610_EXPERIMENT_LATEST.json, overwriting that same file on the next run rather than creating an unbounded sequence. To choose a durable location explicitly:

    .\scripts\AVA_01610_RUN_EXPERIMENTS.ps1 -EvidencePath "$env:USERPROFILE\Documents\AVA_01610_EXPERIMENT_LATEST.json"

The report contains UTC timestamps, runtime versions, individual exit codes, the scale report, and explicit execution boundaries. It does not include the Windows username, computer name, address, microphone data or other device identity. A failed test produces a non-zero script exit code and is recorded as FAIL.

The script does not install packages, change PowerShell policy, request administrator privileges, change OS settings, access a microphone, send network requests, provision cloud resources, or transmit data by satellite.

## Run on GitHub

The existing .github/workflows/ava-run.yml and .github/workflows/ci.yml are configured for pull requests and run repository tests on hosted runners, including Windows. This branch adds a direct deterministic 690M-model command to the Linux, Windows and macOS jobs. Open the associated pull request and inspect actual workflow conclusions and logs; code being committed is not itself proof a test passed.

The read-only monitor workflow is adjusted to use a five-minute schedule, read only recent workflow-run metadata, and write a job summary rather than comments to an issue. A scheduled workflow uses this new schedule only after the change is merged into the default branch.


## Safe-start plan integration

The supplied AVA ALL STARTPLAN is integrated as a separate read-only inventory script: scripts/AVA_01610_SAFE_STARTPLAN.ps1. It checks the six launcher names from the plan in the package root or its scripts subfolder, computes SHA-256 hashes for those present, and writes a privacy-minimized JSON report. Run it against the folder where the package was extracted:

    .\scripts\AVA_01610_SAFE_STARTPLAN.ps1 -PackagePath "C:\path\to\extracted\AVA_SAFE_START"

This inventory does not launch any file. It does not change Windows settings or enable AutoDefense. START_03 remains a manual, risk-reviewed choice because it may add firewall block rules. Package archive hashes in the source plan must not be treated as hashes of individual launcher files.

The new Node test test/ava-safe-startplan.test.js is included in npm test and checks that the inventory script retains its declared read-only safety boundaries. That static test is not a substitute for running the PowerShell script on Windows.

## Evidence labels

- **Tested:** only after a runner actually reports a successful result.
- **Modelled:** calculations derived from assumptions in src/scale-lab.js.
- **Sampled:** up to 10,000 deterministic sample observations.
- **Not measured:** actual hardware throughput, real energy consumption, latency, medical effects or real failure/recovery behavior.
- **Not performed:** physical/cloud server creation, satellite transmission, microphone capture or modifications to the local Windows configuration by this chat.
