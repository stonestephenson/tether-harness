# RESULTS — bench run log

One row per cell (experiment-log format), appended by `runner/run_batch.sh`. The
`dg01`/`dg02` rows are the dev-task pilot behind the done-gate null finding
([`FINDINGS.md`](FINDINGS.md)); real-task rows (SWE-bench-Verified) come next.
`run_dir` paths are ephemeral (per-machine `$TMPDIR`); the durable artifacts are the
per-cell bundles harvested there during the run.

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
| 2026-07-17T21:47 | dg02 | claude-haiku-4-5-20251001 | A2 | True | 0 | 3 | 0.028050400000000003 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_0 |
| 2026-07-17T21:47 | dg02 | claude-haiku-4-5-20251001 | A0 | True | 0 | 3 | 0.0272413 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_1 |
| 2026-07-17T21:47 | dg02 | claude-haiku-4-5-20251001 | A0 | True | 0 | 5 | 0.038204300000000004 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_2 |
| 2026-07-17T21:47 | dg02 | claude-haiku-4-5-20251001 | A2 | True | 0 | 3 | 0.028673200000000003 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_3 |
| 2026-07-17T21:48 | dg02 | claude-sonnet-5 | A0 | True | 0 | 5 | 0.1153944 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_4 |
| 2026-07-17T21:48 | dg02 | claude-sonnet-5 | A2 | True | 0 | 5 | 0.1167912 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_5 |
| 2026-07-17T21:48 | dg02 | claude-sonnet-5 | A2 | True | 0 | 5 | 0.11754479999999999 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_6 |
| 2026-07-17T21:48 | dg02 | claude-sonnet-5 | A0 | True | 0 | 6 | 0.1304884 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_7 |
| 2026-07-17T21:49 | dg02 | claude-haiku-4-5-20251001 | A2 | True | 0 | 5 | 0.0373843 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_8 |
| 2026-07-17T21:49 | dg02 | claude-haiku-4-5-20251001 | A0 | True | 0 | 3 | 0.02998 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_9 |
| 2026-07-17T21:49 | dg02 | claude-sonnet-5 | A2 | True | 0 | 5 | 0.1189649 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_10 |
| 2026-07-17T21:50 | dg02 | claude-sonnet-5 | A0 | True | 0 | 5 | 0.1158154 | 0 | /var/folders/yx/s1xdx0nd2s501lk4wsdp0dwc0000gn/T//tether-batch.34iLDU/cell_11 |
