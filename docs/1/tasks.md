# Tasks — issue 1

Source: [docs/1/design.md](design.md) (branch `issue-1`)

One task. See "Why this is not split" at the end.

---

## Print a hello world container's logs on every GitHub Actions run

### What are we building?

This repository has no automation at all — pushing a commit does nothing, and there
is no `.github/` directory. We will add one workflow and one small Dockerfile so that
every push, every pull request, and a manual trigger builds a tiny Ubuntu 26.04 image,
runs it as a container, and shows what that container printed in the run log.

### Why?

The repository gets a visible, working CI signal, and anyone adding a build or test
job later has a container job in this repository to copy instead of an empty page.

### Done when

- Pushing to any branch, opening a pull request, or triggering the workflow by hand
  from the Actions tab each start a run of `hello-container` on the `ubuntu-26.04`
  runner. (`AC-1`, `AC-6`, `AC-7`, `INV-1`)
- The job log contains a collapsible group titled `container logs` holding both the
  line the container wrote to stdout and the line it wrote to stderr, obtained by
  running `docker logs` after the container stopped. That text appears nowhere else
  in the log. (`AC-2`, `AC-3`, `INV-2`)
- The job's result follows the container's exit code: exit 0 gives a green job, any
  non-zero exit gives a red one, and the failure is attributed to the step that
  reports the code. (`AC-4`, `INV-3`)
- A container that never exits is killed after a 120-second wait, and the job fails
  with a message naming that cap rather than GitHub's job timeout. (`AC-5`)
- The logs are printed and the container removed even when the container fails, when
  it is killed at the cap, and when the run is cancelled. `docker inspect` on the
  container name finds nothing after cleanup. (`AC-8`, `INV-4`, `INV-5`)
- The workflow file references no secret and declares `permissions: contents: read`.
  (`AC-9`, `INV-6`)
- The pull request carries `docs/1/` alongside the two new files.

### How to check

Static, before spending a runner:

```bash
actionlint .github/workflows/hello-container.yml
grep -n 'secrets\.' .github/workflows/hello-container.yml   # expect no match
```

Happy path — push the branch and read the job log for the runner image line and the
`container logs` group; then dispatch the workflow from the Actions tab; then open a
draft pull request and confirm the run reports on its checks. The container name is
printed by the start step, which is where `INV-4` is read off.

Failure paths — two throwaway commits that change only the Dockerfile's `CMD`:

- `exit 3` → the run fails, the failure is attributed to the exit-code step, and the
  `container logs` group is still present and populated.
- `sleep infinity` → the run fails between 120 and 180 seconds after the container
  starts, measured from the job log timestamps, and the message names the wait cap.

For `AC-8`, add a temporary step after cleanup that runs `docker inspect` on the
container name and asserts a non-zero result; run it once on the passing case and
once on the `exit 3` case.

Revert both throwaway commits and remove the temporary `docker inspect` step before
the pull request is ready. The merged Dockerfile is the passing one.

### Agent notes

- **Size:** `S` (under a day). An estimate, not a commitment — most of the elapsed
  time is waiting on real Actions runs, and the `ubuntu-26.04` runner is a preview
  image that GitHub warns may queue.
- **Depends on:** None.
- **Source:** [docs/1/design.md](design.md) on branch `issue-1` — invariants in §5,
  failure behavior in §7, acceptance criteria in §9. Read it; do not re-derive the
  decisions from the ticket.
- **First, confirm two assumptions the design did not verify:** that `ubuntu:26.04`
  exists on Docker Hub, and that `ubuntu-26.04` is an accepted GitHub-hosted runner
  label. `INV-1` fixes both. If either is missing, stop and return to the spec gate
  with what you found and the options — do not substitute `ubuntu-24.04`, the
  `resolute` codename tag, or another base on your own.
- Container name is `hello-<github.run_id>-<github.run_attempt>`, set once as a
  job-level `env` entry so every step refers to the same value. Image tag is
  `hello-container:<github.sha>`, used only to hand the image between steps.
- Run the container detached and read its output back with `docker logs`. Not a
  foreground `docker run`, and not `jobs.<id>.container` — §4 explains why both were
  rejected.
- The 120-second wait cap sits inside `timeout-minutes: 10` so the friendly failure
  always beats GitHub's blunt one.
- The log and remove steps run under `if: always()`. The final step exits with the
  code recorded by the wait step.
- The design names `actions/checkout@v7`. Check that tag resolves; if it does not,
  use the latest published major. No acceptance criterion pins the version.
- No registry push, no registry login, no secret.

### Out of scope

- Publishing the image to GHCR or any other registry.
- A reusable `action.yml` for other repositories to consume.
- Caching the Docker build, a runner matrix, or the `ubuntu-26.04-arm` label.
- Branch protection or required status checks wired to this workflow.
- Leaving the `AC-8` `docker inspect` step or either throwaway failure commit in the
  merged branch.

---

## Why this is not split

Splitting the Dockerfile from the workflow would split one working behavior along a
file boundary. Splitting the failure paths (`AC-4`, `AC-5`, `AC-8`) into a second
task would produce no merged diff — those checks are proved by throwaway commits that
are reverted, against control flow that lives in the same workflow file. Either split
would make two tasks answer the same question.
