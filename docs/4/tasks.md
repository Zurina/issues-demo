# Tasks — issue 4

Source design: `docs/4/design.md` (approved at gate 1). Brief: `docs/4/brief.md`.

One task. The Dockerfile and the workflow are a single working result: neither is
checkable on its own, and splitting them would produce a pull request nobody can review
against an acceptance criterion.

---

## Add a manually run check that a busybox container prints hello world for ten seconds

### What are we building?

The repository has no continuous integration and no container build at all. After this
task, a person with write access can start a check from the repository's Actions tab that
builds a small container image, runs it, and reports pass or fail based on what the
container printed and how long it ran.

### Why?

It gives the repository its first automated check and a working example of building and
running a container image here, without needing a registry account, credentials, or any
setup beyond clicking a button.

### Done when

- A `Dockerfile` at the repository root builds an image whose default command prints the
  literal line `hello world` ten times, once per second, then exits with status 0. Its
  base image is busybox at a pinned version tag, never `latest` (`AC-2`).
- A workflow at `.github/workflows/busybox-hello.yml` runs only when a person starts it
  manually. No push, pull request, or schedule event starts it, and it takes no inputs
  (`AC-1`).
- The workflow builds the image from the root `Dockerfile`, tags it locally as
  `busybox-hello:<commit sha>`, and runs it while capturing its output and timing it.
- The job passes only when the container exits with status 0, the captured output is
  exactly ten lines each equal to `hello world`, and the measured wall-clock duration is
  between 10 and 25 seconds inclusive (`AC-3`, `AC-4`).
- When the line count or the duration is wrong, the job fails and the captured output
  appears in the log (`AC-5`).
- The workflow contains no image push, no registry login, no reference to a secret, and
  grants `contents: read` and nothing else (`INV-1`, `INV-2`).
- The run step wraps the container in a hard timeout above 25 seconds, so a container
  that never stops is killed and fails the job instead of hanging (`INV-3`). The job also
  carries a job-level timeout of two minutes.
- `docs/4/` is committed alongside the two files in the same pull request.

### How to check

Locally, from the repository root:

```bash
docker build -t busybox-hello:local .
start=$(date +%s); out=$(timeout 30s docker run --rm busybox-hello:local); rc=$?; end=$(date +%s)
printf '%s\n' "$out" | grep -cx 'hello world'   # must print 10
printf '%s\n' "$out" | wc -l                    # must print 10
echo "exit=$rc duration=$((end - start))"       # exit=0, duration between 10 and 25
```

For `AC-5`, temporarily change the printed string in the `Dockerfile`, rerun the same
commands, and confirm the line-count check fails and the output is visible. Revert.

Read `.github/workflows/busybox-hello.yml` and confirm by eye: `workflow_dispatch` is the
only trigger, `permissions:` is `contents: read`, there is no `docker push`,
`docker login`, `secrets.`, or registry reference anywhere, and the run step's hard
timeout is greater than 25 seconds.

End to end (`AC-1` and the CI form of `AC-5`) requires the workflow to exist on the
default branch — see Agent notes. Once it does:

```bash
gh workflow run busybox-hello.yml && gh run watch
```

### Agent notes

- Depends on: None
- Source: `docs/4/design.md`, approved. Sections 4, 5, and 7 hold the invariants,
  interface shape, and full `AC-n` wording.
- Size: S
- The ten-second behaviour lives entirely in the `Dockerfile`'s default command. The
  workflow must not reimplement the timing or the message; it only observes them.
- Timing is asserted as a window, not a point. A shared runner is allowed to be slow, so
  the upper bound is deliberately loose at 25 seconds.
- Assert on lines equal to `hello world`, not lines containing it, so a stray prefix or
  suffix fails.
- **Dispatch cannot be triggered before merge.** GitHub only offers a `workflow_dispatch`
  workflow in the Actions tab and to `gh workflow run` once the file exists on the default
  branch. Everything except the live dispatch is provable on the branch by the local
  commands above; prove `AC-1` by reading the trigger block, and run the real dispatch
  immediately after merge. Report the run link rather than treating the criterion as met
  on the branch.
- Choose the busybox version tag when writing the `Dockerfile` and state which one in the
  pull request, so the eventual bump is a visible decision.

### Out of scope

- Pushing the image to any registry, GHCR or Docker Hub. Docker Hub is only where the
  busybox base image is pulled from.
- Automatic triggers, multi-arch builds, image scanning, and any other CI workflow.
- Reusable or composite actions. This is a workflow file, settled in the brief.
