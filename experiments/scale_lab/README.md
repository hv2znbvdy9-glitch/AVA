# AVO / AVA 690M Scale Lab (bounded simulation)

## Purpose
Model 690,000,000 **logical nodes** without creating cloud resources, contacting external systems, or allocating one object per node. This is a capacity-estimation experiment, not evidence that real servers exist.

## Safety and limits
- Offline and deterministic; no network calls, cloud provisioning, subprocesses, or system changes.
- Never materializes the full logical population. Computes estimates arithmetically and samples at most the configured sample size.
- Sample size is capped at 1,000,000; invalid values are rejected.
- Memory figures are lower-bound payload estimates only; Python/object/transport overhead is not included.
- No continuous loop. Each invocation ends after returning a report.

## Run locally
```powershell
python -m unittest discover -s experiments/scale_lab/tests -v
python experiments/scale_lab/node_simulator.py --nodes 690000000 --sample-size 100000
```

## Evidence
Save console output only after reviewing it for local paths or other sensitive details. A successful unit test proves only that the model's arithmetic and guardrails pass; it does not prove infrastructure capacity or create servers.
