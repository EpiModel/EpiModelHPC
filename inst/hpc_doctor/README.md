# HPC doctor

Companion tooling for SLURM clusters without cgroup containment, where orphaned PSOCK workers survive their launcher and squat on cores SLURM has already re-allocated. See the pull request description for the mechanism and the incident that produced it.

The detector measures CPU utilisation rather than elapsed time. Healthy workers sit near 99%, starved ones near 50%. That signal needs no runtime history and no per-project calibration, and it cannot mistake a legitimately long scenario for a broken one.

## Scripts

| script | role |
|---|---|
| `probe_node_cpu.sh` | node-side; samples `/proc/<pid>/stat` twice and differences it. One ssh per node covers every task on it. Prints `jobid= taskid= nproc= med_cpu= dstate=` per task. |
| `degen_watch.sh` | per-task verdict; report-only by default, `--requeue` acts. `PATTERN` scopes both the nodes probed and the tasks judged. |
| `deploy_doctor.sh` | entry point, `sbatch` this. Sweep loop for the life of a campaign, self-terminating. Carries its own `#SBATCH` defaults. |
| `term_orphans.sh` | SIGTERMs genuinely orphaned workers, safe on shared nodes |

Read `dstate=` as a count of processes in uninterruptible sleep, not a flag. `dstate=1` on a nine-process task means one process is blocked, not that the task has one process. That distinction matters for the classifier, below.

Read `jobid=` and `taskid=` as two different things. `jobid` is `SLURM_JOB_ID`, unique per task and the key for matching a task between probes. `taskid` is the array-qualified `<ArrayJobId>_<TaskId>`, and it is the only id `scontrol` may be given. They differ for exactly one task per array, which is enough to lose an entire iteration; see the third campaign below.

## Running the doctor

`deploy_doctor.sh` is the entry point. It is submitted directly and carries its own `#SBATCH` defaults: 1 CPU, 2G, 3 days, job name `deploy_doctor`, output to `deploy_doctor-<jobid>.out`.

```bash
ROOT=$(Rscript -e 'cat(dirname(EpiModelHPC::hpc_doctor_script("deploy_doctor.sh")))')
PATTERN='doxy-' sbatch --partition=epimodel,week-long-cpu "$ROOT/deploy_doctor.sh"
```

Four things are worth knowing before the first run. The first three each cost a campaign's worth of unprotected runtime to learn.

**`--time` must outlast the campaign, and `--partition` is yours to set.** Submitted with no directives the doctor inherited the partition default and was killed at about 8 hours, against campaigns running one to five days. The bundled default is 3 days; override it if yours run longer. Partition names are cluster-specific, so there is no safe default to ship.

**`ROOT` is where the sibling scripts live, and it must be absolute.** Two launch styles need opposite answers here, so `deploy_doctor.sh` tests each candidate for the siblings rather than trusting one source. Submitted directly, `sbatch` copies the script into the node's spool directory, so `$BASH_SOURCE` lands at `/var/spool/slurmd/job<ID>/` where `degen_watch.sh` is not, and the original path comes from `scontrol show job`. Run by full path from inside a project wrapper job, the reverse holds: `$BASH_SOURCE` is the installed package directory and is correct, while `scontrol` reports the wrapper. Both work without setting `ROOT`; set it explicitly only if the scripts have been copied somewhere else. It has to be on a filesystem the compute nodes share, because `degen_watch.sh` runs `$ROOT/probe_node_cpu.sh` over ssh on every probed node.

**Output goes to the submission directory** as `deploy_doctor-<jobid>.out`, not to a project log directory. A monitoring hint pointing at one will find nothing.

**`PATTERN` is matched against the SLURM job name field** in both scripts, and scopes both the nodes probed and the tasks judged. Anchored (`^doxy-`) and unanchored (`doxy-`) patterns behave identically.

### Every failure in this path used to be silent

The launch-path defects above shared one property: they failed without changing the job's state. The sweep loop kept its schedule, `squeue` showed RUNNING, and the campaign ran unprotected while the log filled with sweeps that did nothing. Four production runs went out believing they had starvation protection they did not have.

The guards are therefore all fail-loud, and all fire before the first sweep rather than during it:

- `deploy_doctor.sh` exits non-zero if `degen_watch.sh` or `probe_node_cpu.sh` is not readable under `ROOT`, so SLURM reports FAILED immediately instead of ten hours of green no-ops.
- `degen_watch.sh` exits non-zero if `probe_node_cpu.sh` is not readable under `ROOT`.
- `degen_watch.sh` treats a sweep in which no node returned any probe output as a broken probe rather than a healthy campaign. Remote stderr is discarded, so a probe that could not run anywhere previously yielded zero suspects and a confident `all tasks healthy`. That is the most dangerous member of this class, because the doctor actively asserts the campaign is fine.

## When the doctor stops

Three signals, in decreasing order of authority.

`add_doctor_teardown_step()` scancels the doctor when the last registered campaign finishes. This is the normal path and it is immediate. Everything below is fallback for when it does not fire: a doctor launched without the watch-list steps, or a workflow that died before reaching its teardown.

`WATCH_DIR`, the same watch list the teardown maintains, passed to the doctor at submit time. It tells the doctor which kind of empty queue it is looking at. With a campaign still registered, an empty queue is a lull between steps, so the doctor waits the full `IDLE_EXIT` (6 sweeps, an hour at the default interval). With nothing registered it exits after `IDLE_FAST` (2 sweeps, 20 minutes). Give it the same path passed to `add_doctor_register_step()`; a relative path is resolved against the submission directory, not against `ROOT`.

The queue itself, which is the backstop. The watch list can only make the doctor more patient, never less, and `IDLE_EXIT` still caps the wait either way. That is deliberate: a workflow killed before its teardown step leaves a marker behind forever, and without the cap that stale marker would hold a doctor open until its three-day walltime, which is worse than the hour this was meant to fix.

The `seen` gate is unchanged and still comes first. A doctor launched at campaign start, before its netsim array exists, never exits on an empty queue no matter what the watch list says, because step 1's renv restore can run 180 minutes.

Measured on a live campaign, 2026-07-27 to 28: 103 sweeps over 20.5 hours, and the matching-task count never once reached zero. Empty-queue states during a running campaign are rare, which is why `IDLE_FAST` can be as small as 2.

## Pending-side barriers

The detector reasons about running tasks. A task that is slow but running reads healthy CPU and is correctly spared; a stalled one reads low CPU or D-state and is caught. A task that is PENDING has neither signal, and it can still be the thing gating everything: slurmworkflow only submits the next slice when the last task of the current one finishes, so one queued straggler stops all netsim progress.

The doctor cannot fix this, and deliberately does not try. Submitting the next slice early is the double-write corruption risk described in `deploy_doctor.sh`'s header. What it now does is stop hiding it. Sweeps with tasks pending and none running are counted, and past `BARRIER_WARN` (3) each one reports the barrier's duration and every pending task's SLURM reason:

```
sweep=57 !! BARRIER matching_tasks=1 (0 running, 1 pending) for 90m -- no netsim progress
    pending 41746874_33     reason=Resources
```

The reason field is what separates a scheduler-starved task from one blocked for another cause, including a task the doctor itself requeued to the back of a deep queue. That last case is real: a requeued array task gets a new `SubmitTime` and re-enters behind everything submitted earlier, so a requeue meant to rescue a slice can become the slice barrier. In the India rollout this ran for nine hours across 55 consecutive sweeps, each logging an ordinary-looking `sweeping` line followed by `no running tasks`.

Counting now uses `squeue -r`, so a collapsed pending range such as `41746874_[46-63]` contributes the 18 tasks it really holds rather than 1. On a live campaign that changed the reported count from 26 to 43. Expect `matching_tasks` to read higher than it used to for the same queue.

## Guardrails, each of which was a bug first

- Sample `/proc/<pid>/stat` twice and difference it. `ps %cpu` is a lifetime average and would hide a task that ran healthy and then got starved, which is the transition being hunted.
- Timestamp each sample from `/proc/uptime`. Dividing by the nominal interval inflates readings about 1.27x and yields impossible values above 100%.
- Report the median with the single lowest sample dropped. A task is one idle master plus N busy workers, so an even process count averages the master in and reads as falsely starved.
- Skip tasks below `MIN_PROC`. Startup and teardown are master-only and legitimately idle.
- Require two strikes separated by `RECHECK`. Transient dips recover and must be spared.
- Requeue, never cancel. A requeued task re-runs its own unit and leaves no gap.
- `ExcNodeList` can only be set on a pending task. The working sequence is requeue, hold, update, release.
- Address array tasks as `<ArrayJobId>_<TaskId>`. A bare `ArrayJobId` given to `scontrol requeue` restarts every task in the array.
- Apply `PATTERN` to tasks, not only to nodes. The probe reports every R process the user owns on a probed node, so a node shared with another of the user's campaigns yields that campaign's tasks too.

## Field evidence, first production campaign

An 5,856-task, eight-family campaign on RSPH, roughly 143 concurrent tasks over a saturated cluster. Several requeues over the run, all but one on a single node (node4). Most were filesystem stalls, and one was a hung task (the case that motivated the classifier fix, below). One, at roughly the six-hour mark, was **the orphan-contention mode this tooling was built for**: a full nine-process footprint at 51% CPU with `dstate=0`. The doctor requeued it and added node4 to its `ExcNodeList`, which is the designed response. That was the first in-the-wild sighting here; the mode is real but, at least on this cluster in this window, rarer than the filesystem stalls that dominate the log.

That node4 produced every intervention in the campaign (four confirmed, across 34 sweeps: three filesystem stalls and the one orphan-contention) is itself the signal. A single filesystem stall does not implicate the node, so the classifier spares it. But four on one node means the node has a genuinely bad mount, and the per-symptom rule keeps letting fresh tasks land there and stall again. The doctor now tracks this: see the offense ledger below.

**Case 1: a real filesystem stall.** Nine processes, median 43%, with four then seven of them in D-state, persisting past the 300s `IO_RECHECK`. The classification was right. The action is questionable, and self-defeatingly so: the doctor's own conclusion, "filesystem, node not at fault", is the reason a requeue does not help. The task lands on a different node and meets the same filesystem. It discarded 24 minutes of completed work to retry against an unchanged bottleneck. Consider waiting a genuine filesystem stall out for longer, or several `IO_RECHECK` cycles, rather than requeuing on the first one.

**Case 2: right action, wrong reason.** The same task had been correctly spared 36 minutes earlier after recovering from 8% to 99%, which is the two-strike logic working as intended. On the second event it read median 0% CPU across nine processes with **only one** in D-state. Eight of nine processes were idle rather than blocked, so this was a hung task, not a filesystem stall. It was nonetheless routed down the I/O branch, because that branch triggers on `dstate > 0` without reference to how many processes are involved.

That was the substantive finding, and it is now fixed. The classifier previously branched on the presence of any D-state process rather than the fraction of them, so one blocked process among nine at 0% CPU and seven among nine at 43% were labelled identically and given the same grace period. `degen_watch.sh` now weighs `dstate` against `nproc`:

| condition | verdict | action |
|---|---|---|
| `dstate == 0`, CPU between `HUNG_CPU` and the floor | CPU starvation | requeue; exclude the node after `NODE_OFFENSE_LIMIT` repeats |
| `dstate == 0`, CPU `<= HUNG_CPU` | hung task | requeue promptly, never exclude (added in the fourth campaign, below) |
| `dstate >= IO_MIN_FRAC%` of `nproc` | filesystem stall | wait up to `IO_MAX_CYCLES` x `IO_RECHECK`, requeue only if still stalled, never exclude |
| `dstate < IO_MIN_FRAC%` and CPU `<= HUNG_CPU` | hung task | requeue promptly, skip the wait, never exclude |

`IO_MIN_FRAC` defaults to 50 and `HUNG_CPU` to 5. The ambiguous middle (few processes blocked but CPU well above `HUNG_CPU`) deliberately keeps the old behaviour and takes the wait path, so the change only affects the clearly-hung case. A hang does not exclude the node, because a hang is not evidence of contention.

**Requeue cost scales with queue depth.** A requeued array task receives a new `SubmitTime` and re-enters the queue behind everything submitted earlier. On this campaign that put both tasks behind a 3,072-task array, so two stragglers that would have finished in 20 minutes instead gated their family's merge step for the whole run. Requeuing is close to free on an empty cluster and expensive on a full one. Being conservative is particularly warranted when a family is nearly complete and a single task gates a barrier or a merge.

## Field evidence, second campaign (overnight, 2026-07-20)

An 11-hour overnight run of a 9-family, 6,240-task campaign, 45 sweeps. **Every one of the four interventions was a filesystem (D-state) stall; not one was the orphan-contention mode the doctor was built for.** Across the two campaigns now, the `dstate=0` CPU-starvation signature has appeared exactly once and PanFS filesystem stalls about seven times. The doctor was designed around orphaned PSOCK workers, but empirically it earns its keep on filesystem stalls. Tune `IO_RECHECK`/`IO_MAX_CYCLES` first; the exclusion logic is the rare path.

Two patterns drove the changes below:

- **Filesystem stalls are transient, so requeuing them on the first recheck is too eager.** Every overnight requeue had a sibling task on the same node that recovered to 98-99% in the same window, and one suspect finished during the wait. A requeue barely helps (PanFS is cluster-wide) and re-queues the task behind the whole array. `degen_watch.sh` now gives a D-state stall `IO_MAX_CYCLES` recheck cycles (default 3) before requeuing, sparing it if it recovers at any cycle.
- **The offense ledger contradicted the classifier.** node3 filesystem-stalled three times over the campaign (suspected more), and on the third the pre-fix ledger escalated and excluded the node (`ExcNodeList=node3`), overriding its own per-stall "NOT excluding node3" verdict. All three were filesystem stalls the classifier had ruled node-not-at-fault, and node3's siblings recovered each time, so the exclusion was wrong. Escalation-to-exclusion is now **gated by classification**: only repeated CPU-starvation events (a node genuinely harbouring orphans) escalate; filesystem-stall events are logged for visibility but never drive exclusion.

What was validated and left unchanged: the two-strike sparing logic (zero false requeues across both campaigns; every dip that recovered was spared) and the hung-vs-stall split (zero misclassifications overnight). The core detection is sound; the gap was purely in the response to a confirmed filesystem stall.

## Field evidence, third campaign (swfcalib, 2026-07-28)

A seven-wave `swfcalib` calibration on RSPH, 64-task step-2 arrays of eight workers each, running alongside a second project's 50-task, 16-CPU campaign on the same partition. Two things separate this campaign from the first two.

**The orphan-contention mode finally dominated.** 109 confirmed CPU-starvation events across 92 sweeps, against one in the first campaign and none in the second. The signature was the designed one, a full nine-process footprint with `dstate=0` at a median of 51%, alongside a harder variant at 0-2% that the classifier correctly routed to CPU starvation rather than to the filesystem branch. Contention with a concurrent campaign is the obvious difference; the two earlier campaigns had the cluster largely to themselves.

**A requeue restarted the whole array, three times, and the log said otherwise.** `scontrol requeue` given a bare `ArrayJobId` acts on every task in the array. Exactly one task per array reports its `SLURM_JOB_ID` as that bare id (SLURM allocates fresh ids to tasks as they are split off the array record, and one of them inherits the original), and the probe reads `SLURM_JOB_ID` out of `/proc/<pid>/environ`. So whenever that one task was the confirmed-starved one, the doctor discarded all 64.

The 07:18:32 sweep is the clean case. The doctor confirmed and requeued a single job, reported `confirmed_starved_requeued=1`, and then logged its other ten suspects as `gone (finished/moved)`. They were not gone. 62 task logs carry `CANCELLED AT 2026-07-28T07:18:32 DUE TO JOB REQUEUE`, to the second. The same thing had happened at 05:05:09 (63 tasks) and 06:12:18 (57 tasks), so one iteration was restarted from zero three times: each round discarded roughly 60 tasks at about an hour each, some 480 core-hours, and the iteration took 8.4 hours against a measured task time of 54 to 58 minutes.

Three properties made it hard to see, and each is now addressed:

- **The doctor's own accounting understated the blast radius about sixtyfold.** It counts the requeues it issues, not the tasks that stop, and there is no reason those should differ.
- **`gone (finished/moved)` is where the collateral damage went.** The recheck cannot distinguish a task that finished from one the previous requeue just killed, so every victim was logged as a normal, healthy outcome.
- **`scontrol requeue` returned nonzero while still acting.** At 06:12 the doctor logged `!! requeue failed` for the array id and skipped its own follow-up, and the array restarted anyway. A partial-failure exit code on a whole-array operation is not a signal that nothing happened.

Only `MAX_RESTARTS` stopped it: after three rounds the tasks reached their restart cap, the doctor logged `restarts exhausted; leaving it`, and the array was finally allowed to finish. That cap was doing work it was never meant to do.

The probe now reads `SLURM_ARRAY_JOB_ID` and `SLURM_ARRAY_TASK_ID` from the same environment block and emits `taskid=`, and every `squeue`/`scontrol` call in `degen_watch.sh` addresses the task by it. Taking the id from the task's own environment rather than resolving it later is the point: PSOCK workers inherit it from their master, so every process of a task agrees, and nothing has to be inferred from a `squeue` line that may describe a sibling. Verified against the successor array while it ran: `jobid=41746875 taskid=41746874_0`, where the raw `SLURM_JOB_ID` and the array id differ by one and neither is guessable from the other. A guard before the destructive call refuses any unqualified id that `scontrol` reports as an array, so the failure mode cannot return by another route.

Two smaller consequences worth keeping in mind. The probe match was a bare `grep jobid=$jid`, which substring-matches any longer id sharing the prefix; it is now anchored on the field boundary, because acting on the wrong task is the one mistake this script must not make. And `Restarts=`, the age lookup, and the `ExcNodeList` read all went through the same unqualified id, so on an array they were reading whichever task `scontrol` or `squeue` happened to list first rather than the one under judgement.

### PATTERN scoped nodes but not tasks

Confirming the fix surfaced a second, independent defect in the same sweep. `PATTERN` selected the nodes to probe, and nothing after that re-checked it. `probe_node_cpu.sh` reports every R process the user owns on a node, so on a shared cluster where one account runs several campaigns, the doctor was classifying, and would have requeued, tasks belonging to a project it was never pointed at. It was visible in the log all along: a `prep-mi` task from a second concurrent campaign appearing in a `/doxy-/` sweep, spared only by the unrelated `nproc < 2` rule.

`degen_watch.sh` now takes the node list and the set of in-scope task ids from a single `squeue` pass and skips anything outside it, before any classification. Out-of-scope tasks are reported when they are themselves below the floor and never otherwise, because a starving co-tenant is the evidence that the node is oversubscribed, which is the context wanted when one of our own tasks on it is starving too.

Verified by inverting the scope against two live campaigns sharing nodes. Pointed at the second project with the floor forced to 100%, the three nine-process tasks of the first on the same node are logged `co-tenant ... (outside /prep-d3/: not judged)` and the sweep ends with zero suspects; pointed back at the first, the second project's tasks get the same treatment. Nothing outside `PATTERN` can now reach the action path from either direction.

The match is also now against the job name field alone rather than the whole `squeue` line. `deploy_doctor.sh` counts against `squeue -o "%j"` while `degen_watch.sh` grepped `%N %j`, so an anchored pattern such as `^doxy-` matched in the wrapper and silently found nothing in the worker: the doctor reported tasks to sweep and then swept nothing, on every sweep, for as long as it ran. Both now match on the name, so anchored and unanchored patterns behave identically in the two scripts.

## Field evidence, fourth campaign (swfcalib, 2026-07-29)

The same `swfcalib` calibration, two days on. 186 sweeps, 127 confirmed events since the array-task fix, 120 requeues across 79 distinct tasks out of 192 run. Two in five tasks needed intervention, which is one to two orders of magnitude above every prior campaign and was the signal that the doctor was diagnosing the wrong thing.

**Most of it was not CPU starvation.** Splitting the confirmed events by their CPU reading:

| reading | events | reads as |
|---|---|---|
| 0-3% | 100 | nine processes alive, nothing blocked, no work |
| 51% | 23 | the orphan-contention signature this tooling was built for |
| other | 4 | 12, 27, 35, 61% |

Every one of the 310 probe readings had `dstate=0`, so the filesystem branch never fired once.

The 51% group is real and is what the doctor is for. The 0-3% group is a different failure wearing the same label, because the classifier defaulted `dstate == 0` to `cpustarv` regardless of level. That default is wrong on its own terms: losing a share of the cores to a competitor reads near 50%, and a task with no competitor and no I/O wait reads near zero. There is no reading at which "starved" means "idle".

Two independent checks confirmed the misdiagnosis. The nodes blamed most (node18, node19, node20, node21, node22) were IDLE with zero processes when checked afterwards, so the exclusions those events wrote rested on nothing. And the requeued tasks had never started work: measuring how much output each had produced when the doctor killed it gave exactly four values across 56 tasks, 59, 126, 193 and 260 lines, which is the same startup banner repeating once per requeue cycle, with 260 the end of package loading. One inspected directly had sat at `Attaching package: 'dplyr'` for 93 minutes.

So these were tasks wedged during R startup, loading a package library off shared storage, being requeued into starting the same load again. Requeue was still the right action and did eventually clear them, one task completing in 1.6 hours after its restart. Blaming the node was not, and it is actively harmful: excluding healthy nodes on false evidence shrinks the pool and concentrates the next attempt onto fewer machines, which makes the real contention worse.

`degen_watch.sh` now separates them. `dstate == 0` with CPU at or below `HUNG_CPU` is classified `hung`, requeued promptly and does not implicate the node, matching what the classifier already did for the same condition when one process happened to be in D-state. `dstate == 0` above `HUNG_CPU` and below the floor stays `cpustarv` and still escalates to exclusion on repeats.

Worth stating plainly, because the doctor cannot fix it: a startup stall is a storage problem. The doctor's job here is to stop the task burning its walltime and to report honestly what it saw. Requeue volume at this level is a symptom to escalate, not a thing to tune away.

## Node-level view (open)

Every overnight stall event had two tasks on the same node go D-state simultaneously, which is a node-level filesystem event rather than independent per-task failures, yet the doctor judges each task in isolation. Aggregating D-state across a node's tasks (most/all blocked at once = node event to wait out; a lone blocked task judged on its own) could implement the patience and the ledger gating more directly. This needs more cross-cluster data before committing to a heuristic and is tracked as a GitHub issue.

Minor fixed: a task that finished during the recheck window logged `cleared (gone%)`, where the substitution intended a percentage.

## Node offense ledger

The classifier decides one task at a time and, by design, spares the node on a filesystem stall or a hung task. That is right for a first occurrence and wrong for the fifth: a node with a bad mount produces stall after stall, and a memoryless per-task rule keeps feeding it fresh tasks. The node4 pattern above was invisible to the doctor and only surfaced by grepping the log.

`degen_watch.sh` now keeps a per-node count of confirmed interventions across the campaign. Past `NODE_OFFENSE_LIMIT` (default 3) a node is a repeat offender: the doctor logs it loudly and, on that requeue, excludes the node even when the proximate symptom would not have (a stall, a hang). Replayed against this campaign, the first two node4 events stay spared, the third (a filesystem stall) escalates to an exclusion, and a lone stall on any other node never escalates.

This is deliberately not a static `--exclude`. A node is rarely intrinsically bad; it is usually squatted on by another job's orphans, which drain when those processes exit. A static exclusion permanently shrinks the pool for a condition that has likely already cleared, and does nothing for the next node to be polluted. The ledger is instead campaign-scoped: `STATE_FILE` is keyed to the doctor's own SLURM job id, so a new campaign starts a clean slate and two concurrent doctors never share a ledger. The escalation is still per-task `ExcNodeList`, the same self-expiring mechanism the classifier already uses, applied on stronger evidence. Add a real static `--exclude` only if a node offends across *separate* campaigns, which this ledger, by resetting each time, will not paper over.
