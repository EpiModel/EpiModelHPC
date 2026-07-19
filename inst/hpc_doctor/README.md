# HPC doctor

Companion tooling for SLURM clusters without cgroup containment, where orphaned PSOCK workers survive their launcher and squat on cores SLURM has already re-allocated. See the pull request description for the mechanism and the incident that produced it.

The detector measures CPU utilisation rather than elapsed time. Healthy workers sit near 99%, starved ones near 50%. That signal needs no runtime history and no per-project calibration, and it cannot mistake a legitimately long scenario for a broken one.

## Scripts

| script | role |
|---|---|
| `probe_node_cpu.sh` | node-side; samples `/proc/<pid>/stat` twice and differences it. One ssh per node covers every task on it. Prints `jobid= nproc= med_cpu= dstate=` per task. |
| `degen_watch.sh` | per-task verdict; report-only by default, `--requeue` acts |
| `deploy_doctor.sh` | sweep loop for the life of a campaign, self-terminating |
| `term_orphans.sh` | SIGTERMs genuinely orphaned workers, safe on shared nodes |

Read `dstate=` as a count of processes in uninterruptible sleep, not a flag. `dstate=1` on a nine-process task means one process is blocked, not that the task has one process. That distinction matters for the classifier, below.

## Guardrails, each of which was a bug first

- Sample `/proc/<pid>/stat` twice and difference it. `ps %cpu` is a lifetime average and would hide a task that ran healthy and then got starved, which is the transition being hunted.
- Timestamp each sample from `/proc/uptime`. Dividing by the nominal interval inflates readings about 1.27x and yields impossible values above 100%.
- Report the median with the single lowest sample dropped. A task is one idle master plus N busy workers, so an even process count averages the master in and reads as falsely starved.
- Skip tasks below `MIN_PROC`. Startup and teardown are master-only and legitimately idle.
- Require two strikes separated by `RECHECK`. Transient dips recover and must be spared.
- Requeue, never cancel. A requeued task re-runs its own unit and leaves no gap.
- `ExcNodeList` can only be set on a pending task. The working sequence is requeue, hold, update, release.

## Field evidence, first production campaign

An 5,856-task, eight-family campaign on RSPH, roughly 143 concurrent tasks over a saturated cluster. Two requeues in the first six hours, both on the same node, both genuine in the sense that neither task was making progress. Worth recording because **neither was the orphan-contention mode this tooling was built for.** That mode presents as a full process footprint at roughly 50% CPU with `dstate=0`. It has not yet been observed in the wild here.

**Case 1: a real filesystem stall.** Nine processes, median 43%, with four then seven of them in D-state, persisting past the 300s `IO_RECHECK`. The classification was right. The action is questionable, and self-defeatingly so: the doctor's own conclusion, "filesystem, node not at fault", is the reason a requeue does not help. The task lands on a different node and meets the same filesystem. It discarded 24 minutes of completed work to retry against an unchanged bottleneck. Consider waiting a genuine filesystem stall out for longer, or several `IO_RECHECK` cycles, rather than requeuing on the first one.

**Case 2: right action, wrong reason.** The same task had been correctly spared 36 minutes earlier after recovering from 8% to 99%, which is the two-strike logic working as intended. On the second event it read median 0% CPU across nine processes with **only one** in D-state. Eight of nine processes were idle rather than blocked, so this was a hung task, not a filesystem stall. It was nonetheless routed down the I/O branch, because that branch triggers on `dstate > 0` without reference to how many processes are involved.

That was the substantive finding, and it is now fixed. The classifier previously branched on the presence of any D-state process rather than the fraction of them, so one blocked process among nine at 0% CPU and seven among nine at 43% were labelled identically and given the same grace period. `degen_watch.sh` now weighs `dstate` against `nproc`:

| condition | verdict | action |
|---|---|---|
| `dstate == 0`, CPU below floor | CPU starvation | requeue and exclude the node |
| `dstate >= IO_MIN_FRAC%` of `nproc` | filesystem stall | wait `IO_RECHECK`, requeue only if it persists, never exclude |
| `dstate < IO_MIN_FRAC%` and CPU `<= HUNG_CPU` | hung task | requeue promptly, skip the wait, never exclude |

`IO_MIN_FRAC` defaults to 50 and `HUNG_CPU` to 5. The ambiguous middle (few processes blocked but CPU well above `HUNG_CPU`) deliberately keeps the old behaviour and takes the wait path, so the change only affects the clearly-hung case. A hang does not exclude the node, because a hang is not evidence of contention; `dstate == 0` is what detects that.

**Requeue cost scales with queue depth.** A requeued array task receives a new `SubmitTime` and re-enters the queue behind everything submitted earlier. On this campaign that put both tasks behind a 3,072-task array, so two stragglers that would have finished in 20 minutes instead gated their family's merge step for the whole run. Requeuing is close to free on an empty cluster and expensive on a full one. Being conservative is particularly warranted when a family is nearly complete and a single task gates a barrier or a merge.

Minor: a task that finishes during the `IO_RECHECK` window logs `cleared (gone%)`, where the substitution intends a percentage.
