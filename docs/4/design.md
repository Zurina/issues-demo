# Busybox hello-world workflow

> **Status:** Proposed for review

## 1. Executive summary

The repository has no CI and no container build. Issue 4 asks for a GitHub workflow that builds
a busybox image which prints `hello world` for ten seconds and then stops. We will add a
`Dockerfile` at the repository root and one manually dispatched workflow that builds the image,
runs it, and fails unless the container printed the expected output and exited on its own within
the expected time. Nothing is pushed to a registry, so no secrets are involved.

The downside is that the check asserts on wall-clock timing and so depends on a shared runner
behaving reasonably. We use a generous upper bound rather than a tight one, which catches a
container that never stops but not one that runs slightly long.

## 2. Context and scope

The repository contains only `README.md` and `CLAUDE.md`: no `.github/workflows/` directory, no
Dockerfile, no automated check of any kind. After this ships, a person with write access can
dispatch the workflow from the Actions tab and watch it build the image, run the container, and
report pass or fail. It is self-contained: no secrets, no registry account, no state carried
between runs. Publishing the image, non-manual triggers, and any other use of the image are
outside the boundary.

## 3. Proposed design

### How it works

A person dispatches the workflow. The job checks out the repository, builds the image from the
root `Dockerfile`, then runs the container in the foreground while recording its output and how
long it took. The container prints `hello world` once per second, ten times, and exits. The job
then checks that the container exited with status 0, that the output holds exactly ten
`hello world` lines, and that the duration fell inside the accepted window. Any failed check
fails the job with the recorded output in the log.

### Components and responsibilities

**`Dockerfile` (repository root).** Owns the image contents and the default command, which is the
only thing defining the ten-second behaviour. It does not own when the image is built, how it is
tagged, or whether it is run.

**`.github/workflows/busybox-hello.yml`.** Owns the trigger, the build, the run, and the
assertions. It does not own the container's behaviour: if the timing or the message changes that
belongs in the `Dockerfile`, and the workflow only notices.

### Decisions

**Print once per second rather than print once and sleep.** The brief settles that the container
prints for ten seconds and then stops, so ten prints spaced a second apart matches the intent and
is also observable: the assertion counts lines instead of only trusting a stopwatch. The cost is
that the real duration is ten seconds and slightly more, so the timing assertion needs a window.

**Build locally and discard.** The brief settles that the image is not pushed and that Docker Hub
is where busybox comes from, so the only registry interaction is pulling the base image and
nothing outlives the runner. The cost is that no artefact survives the run; the log is the record.

**Pin the base image to a busybox version tag, not `latest`.** A run six months from now should
fail for a real reason rather than because upstream moved. The cost is a manual bump as it ages.

## 4. Invariants and requirements

- `INV-1`: The workflow never pushes an image and never references a registry credential or secret.
- `INV-2`: The workflow grants `contents: read` and nothing more.
- `INV-3`: The container always terminates. The run step wraps it in a hard timeout above the
  expected duration; if that fires, the container is killed and the job fails rather than hanging.

The workflow runs only on manual dispatch, takes no inputs, and finishes well inside a two-minute
job timeout.

## 5. Interfaces

**`Dockerfile`** at the repository root. Base image is busybox at a pinned version tag. Its default
command prints the literal string `hello world` ten times, once per second, then exits 0. No build
arguments, volumes, ports, or environment configuration.

**`.github/workflows/busybox-hello.yml`.** Trigger: `workflow_dispatch` only, no inputs. One job on
`ubuntu-latest` with a job-level timeout. Steps: checkout, build, run and record, assert.

**Image identity.** The image is tagged locally as `busybox-hello:<commit sha>` from the run's
commit, so the build and run steps name the same thing and the log shows which commit was
exercised. It is never pushed, so no collision or rename case exists.

## 6. Failure behavior

A failed base-image pull, a failed build, a non-zero container exit, a wrong number of
`hello world` lines, or a duration outside the window all fail the job. There is no retry and no
recovery path: the trigger is manual, so a person reruns it. Docker Hub's anonymous pull rate
limit is the one shared resource the job depends on, and hitting it surfaces as a pull failure in
the log rather than as a mysterious timeout.

## 7. Acceptance criteria

- `AC-1`: Dispatching the workflow from the Actions tab starts a run; no push, pull request, or
  schedule event starts one.
- `AC-2`: The build step produces an image from the root `Dockerfile` and the job proceeds.
- `AC-3`: The captured output contains exactly ten lines equal to `hello world`.
- `AC-4`: The container exits with status 0 on its own, and the measured wall-clock duration is at
  least 10 seconds and at most 25 seconds.
- `AC-5`: If the line count or the duration is wrong, the job fails and the captured output is
  printed in the log.

## 8. Test approach

`AC-2`, `AC-3`, and `AC-4` are proved locally first by building the image, running the container,
counting lines, and timing the run, then all five end to end by dispatching the workflow once on
the branch and reading the log. `AC-5` is proved by changing the printed string in a scratch commit
and confirming the job fails with the output visible. `INV-1` and `INV-2` are proved by reading the
workflow file for push, login, secret, or wider permissions usage; `INV-3` by checking the run
step's hard timeout is present and above the 25-second bound of `AC-4`.

## 9. Open questions

- The registry answer reads as "not pushed; Docker Hub is where busybox comes from", which is how
  this design takes it. Non-blocking, but worth one word at the gate.

## 10. Out of scope

- Publishing the image, automatic triggers, multi-arch builds, scanning, and any other CI.
