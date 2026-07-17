# RESULTS — bench run log

One row per cell (experiment-log format), appended by `runner/run_batch.sh`.
**Rows before the Phase-4 pre-registration freeze are pilot / dev-task calibration,
not confirmatory data** — the confirmatory matrix runs on the mined task suite after
freeze. `run_dir` paths are ephemeral (per-machine `$TMPDIR`); the durable artifacts
are the per-cell bundles harvested there during the run.

| ts | task | model | arm | hidden_pass | blocks | turns | cost~ | exit | run_dir |
|---|---|---|---|---|---|---|---|---|---|
