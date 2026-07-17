# RESULTS — bench run log

One row per cell (experiment-log format), appended by `runner/run_batch.sh`.
**Rows before the Phase-4 pre-registration freeze are pilot / dev-task calibration,
not confirmatory data** — the confirmatory matrix runs on the mined task suite after
freeze. `run_dir` paths are ephemeral (per-machine `$TMPDIR`); the durable artifacts
are the per-cell bundles harvested there during the run.

| ts | task | model | arm | hidden_pass | blocks | turns | cost~ | exit | run_dir |
|---|---|---|---|---|---|---|---|---|---|
| 2026-07-17T16:35 | dg01 | claude-sonnet-5 | A2 | True | 0 | 5 | 0.11700210000000001 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_0 |
| 2026-07-17T16:35 | dg01 | claude-sonnet-5 | A0 | True | 0 | 5 | 0.11833969999999999 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_1 |
| 2026-07-17T16:35 | dg01 | claude-haiku-4-5-20251001 | A2 | True | 0 | 4 | 0.0313634 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_2 |
| 2026-07-17T16:35 | dg01 | claude-haiku-4-5-20251001 | A0 | True | 0 | 4 | 0.0323821 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_3 |
| 2026-07-17T16:36 | dg01 | claude-sonnet-5 | A2 | True | 0 | 5 | 0.1160213 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_4 |
| 2026-07-17T16:36 | dg01 | claude-sonnet-5 | A0 | True | 0 | 5 | 0.11822959999999999 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_5 |
| 2026-07-17T16:36 | dg01 | claude-haiku-4-5-20251001 | A2 | True | 0 | 4 | 0.0330592 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_6 |
| 2026-07-17T16:37 | dg01 | claude-haiku-4-5-20251001 | A0 | True | 0 | 7 | 0.0446722 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.H8ZQwV/cell_7 |
