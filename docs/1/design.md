# Hello world container workflow on Ubuntu 26.04

> **Status:** Proposed for review

## 1. Executive summary

This repository has no automation at all. It contains one directory, `docs/`, and not a single commit. There is no proof that GitHub Actions works here, no proof that a container can be built and run in CI, and nothing for later work to copy.

Anyone who wants to add a build, a test, or a container job feels this. They have to start from an empty page and guess whether the runner they picked can build images.

We will add one GitHub Actions workflow and one small Dockerfile. On every push, on every pull request, and on demand, the workflow builds a tiny image from `ubuntu:26.04`, runs it as a container, waits for it to exit, and prints everything the container wrote using `docker logs`. If the container exits non-zero, the job fails with the same code.

The main downside is the runner. The ticket asks for Ubuntu 26.04, and `ubuntu-26.04` exists as a GitHub-hosted label, but GitHub still labels it a preview image and warns about queueing while capacity is being balanced. So this workflow may sit in a queue longer than one on `ubuntu-24.04`, and preview software may break under us. We accept that because the ticket names the version explicitly.

## 2. Context and scope

Today the repository is empty apart from `docs/1/brief.md`. Pushing a commit does nothing. There is no `.github/` directory.

After this ships, pushing a commit runs a job that prints a hello world line produced inside a container, and the run is visible in the Actions tab. A reader can open the run and see the container's own output, clearly separated from the workflow's own step output.

This design covers the workflow definition, the Dockerfile, and the behavior of the job. It does not cover any application code, any deployment, any registry push, or any reusable action published for other repositories to consume.

## 3. System context

The change touches only files in this repository. Everything else is an outside system we call and do not control.

```
  push / pull_request / manual dispatch
                 |
                 v
      +--------------------------+
      |  GitHub Actions          |
      |  workflow: hello-        |
      |  container.yml           |
      +--------------------------+
                 | schedules job
                 v
      +--------------------------+          +---------------+
      |  GitHub-hosted runner    |  pull    |  Docker Hub   |
      |  runs-on: ubuntu-26.04   |--------->|  ubuntu:26.04 |
      |  (Docker 29.4.2 present) |          +---------------+
      +--------------------------+
                 | docker build, docker run, docker logs
                 v
      +--------------------------+
      |  hello world container   |
      |  FROM ubuntu:26.04       |
      +--------------------------+
```

Two boundaries must be preserved. The workflow reads the repository and nothing else, so it needs no secret and no write permission. The container is a leaf: nothing else in the system depends on it, and it talks to no network service.

## 4. Proposed design

### How it works

A developer pushes a commit. GitHub matches the push against the `on:` block of `.github/workflows/hello-container.yml` and queues one job on a `ubuntu-26.04` runner.

The job checks out the repository. It builds an image from `Dockerfile` at the repository root and tags it `hello-container:<commit sha>`. The build pulls `ubuntu:26.04` from Docker Hub.

The job then starts one container in the background with `docker run --detach`, giving it a name built from the run: `hello-<run_id>-<run_attempt>`. Starting detached means the step gets the container back immediately instead of inheriting its output stream.

The job waits for the container to finish, with a hard cap of 120 seconds. If the container is still running at the cap, the job kills it and treats that as a failure.

Whatever happened, the job then runs `docker logs` against the finished container and prints the result into the job log, wrapped in a collapsible group titled `container logs`. The container wrote one line to stdout and one line to stderr, so both appear, which proves the capture is complete and not just stdout.

Finally the job removes the container, and exits with the container's own exit code. A developer opening the run sees the hello world text under `container logs`, and a green check when the container exited 0.

### Components and responsibilities

**`Dockerfile` (repository root).** Owns the container's base image and the text it prints. It depends on the `ubuntu:26.04` image on Docker Hub. It does not own how the container is started, named, waited on, or cleaned up, and it installs no packages, so a change to it can never break the workflow's control flow.

**`.github/workflows/hello-container.yml`.** Owns the triggers, the runner label, the container lifecycle (build, run, wait, log, remove), and the mapping from container exit code to job conclusion. It depends on the Dockerfile existing at the repository root and on Docker being preinstalled on the runner. It does not own what the container prints, and it does not push images anywhere.

### Decisions

**A workflow, not a published custom action.** The ticket says "GH action", which in everyday use means a workflow file, and which could also mean a reusable `action.yml`. We are building a workflow. A reusable action only pays for itself when another repository consumes it, and no such consumer exists or is named in the ticket. If one appears later, the workflow's steps lift into an `action.yml` almost unchanged. The cost of being wrong is small, roughly an hour of rework, which is why this is not a blocking question.

**Ubuntu 26.04 in both places.** The ticket says "Use ubuntu 26-04" without saying whether it means the runner or the container. We use it for both: `runs-on: ubuntu-26.04` and `FROM ubuntu:26.04`. This satisfies either reading, so no interpretation can turn out to be wrong. The cost is that we take on the preview runner's instability even if the reporter only meant the container image.

**Detached run plus `docker logs`, not a foreground run.** Running `docker run` in the foreground is one line shorter and the container's output lands in the job log by itself. We run detached and read the logs back instead, for two reasons. The ticket asks specifically for the logs to be printed "from it", and reading them back is the literal reading. More practically, a foreground run mixes the container's output into the step's output with no boundary, so a reader cannot tell which line came from where. The cost is three extra steps and the need to handle a container that never exits.

**Not `jobs.<id>.container`.** GitHub Actions can run all of a job's steps inside a container using the `container:` key. We reject it because that container is the job's execution environment, not a subject we can observe. There is no finished container to call `docker logs` on, and its output is the job's own output, which defeats the point of the ticket.

**No image registry.** The image is built on the runner, used, and thrown away with the runner. Pushing it to the GitHub Container Registry (GHCR) would need a write permission and add a failure mode for zero benefit at this scope.

## 5. Invariants and requirements

### Invariants

- `INV-1`: The job runs on the `ubuntu-26.04` runner label and the container image is built `FROM ubuntu:26.04`.
- `INV-2`: The complete stdout and stderr of the container appear in the job log, obtained by running `docker logs` after the container has stopped.
- `INV-3`: The job's conclusion follows the container's exit code. Exit 0 gives a successful job, any non-zero exit gives a failed job, and the workflow never fails for a reason it did not report in the log.
- `INV-4`: At most one container exists per workflow run attempt. Its name is `hello-<github.run_id>-<github.run_attempt>`.
- `INV-5`: The container's logs are printed and the container is removed even when the container fails, even when it is killed at the wait cap, and even when the job is cancelled.
- `INV-6`: The workflow requires no repository secret, no registry login, and no permission beyond `contents: read`.

### Requirements

The workflow triggers on `push` to any branch, on `pull_request` targeting any branch, and on `workflow_dispatch`. A person with read access to the repository can open a run and read the container's output without downloading an artifact or expanding more than one group. The whole job finishes in under ten minutes or is stopped by GitHub.

## 6. Interfaces and data

There is no API and no stored data. The interface is the two files and the workflow's triggers.

`Dockerfile` at the repository root:

```dockerfile
FROM ubuntu:26.04
CMD ["/bin/sh", "-c", "echo 'Hello, world from Ubuntu 26.04'; echo 'this line came from stderr' >&2"]
```

`.github/workflows/hello-container.yml` in outline:

```yaml
name: hello-container
on:
  push:
  pull_request:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  hello-container:
    runs-on: ubuntu-26.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7
      - name: Build image
        run: docker build --tag "hello-container:${{ github.sha }}" .
      - name: Start container
        run: docker run --detach --name "$CONTAINER_NAME" "hello-container:${{ github.sha }}"
      - name: Wait for container
        run: # bounded wait, records exit code, kills on timeout
      - name: Print container logs
        if: always()
        run: # docker logs inside a ::group:: block
      - name: Remove container
        if: always()
        run: docker rm --force "$CONTAINER_NAME" || true
      - name: Report container exit code
        run: # exits with the recorded code
```

`CONTAINER_NAME` is set once at job level as an `env` entry so every step refers to the same value.

There is nothing to migrate and nothing to keep compatible. The repository has no prior workflow.

### Naming and identity

Two names are stored, both for the length of one job.

The container name is `hello-<github.run_id>-<github.run_attempt>`. Both parts are supplied by GitHub and are always present, so the name cannot fail to be computed. The pair is unique across the repository's history, including reruns, which is why the attempt number is included: a rerun of a failed job would otherwise collide with the container from the first attempt if anything survived. Nothing outside the job reads this name, so it can change freely later.

The image tag is `hello-container:<github.sha>`. On a `pull_request` event `github.sha` is the merge commit rather than the head commit. That is fine here, because the tag is only used to hand the image from the build step to the run step within one job, and is never published or looked up again.

Neither name is written to disk, so there is no data that outlives a change to how the names are built.

## 7. Failure behavior and lifecycle

**The runner is unavailable or queued.** `ubuntu-26.04` is a preview image and GitHub warns about capacity. The job sits in the queue. GitHub's own limits eventually cancel it. We do not retry, because a retry would join the same queue.

**The base image pull fails.** Docker Hub is down, or the anonymous pull is rate limited. `docker build` fails, the job fails at that step, and no container was ever created, so the log and cleanup steps have nothing to do and pass without output. We do not retry. A retry hides a real outage behind a longer red build, and rerunning the job by hand is one click.

**The build fails for any other reason.** Same shape as above. The job fails at the build step with Docker's own error in the log.

**The container exits non-zero.** This is a normal outcome, not an error. The wait step records the code, the log step prints the output, the cleanup step removes the container, and the final step exits with the same code so the job goes red. This is `INV-3` and `INV-5` working together.

**The container never exits.** The wait is capped at 120 seconds. At the cap the job kills the container, which forces it to exit, and then follows the same path as a non-zero exit: logs printed, container removed, job failed. The 120 second cap sits well inside the job's `timeout-minutes: 10`, so the friendly failure always wins over GitHub's blunt one.

**`docker logs` itself fails.** The log step reports the error and does not mask it, but it does not stop the cleanup step, because cleanup runs under `if: always()`.

**Everything fails at once.** If the runner starts but Docker is broken, every Docker step fails in order, each printing its own error, and the job goes red with no container leaked because none was created.

**Cancellation and shutdown.** If a developer cancels the run, GitHub sends a cancellation to the job. The log and cleanup steps still run because of `if: always()`. Any container left behind dies with the runner, which is destroyed after every job, so a leak cannot outlive one run.

**Configuration changes.** There is no configuration to reload. Changing either file takes effect on the next run that uses the changed commit. Turning the workflow off means disabling it in the Actions tab or deleting the file; runs already in flight finish normally.

## 8. Security, privacy, and operations

The trust boundary is the repository. Everything the job runs comes from the checked out commit, and the only outside content is the `ubuntu:26.04` image from Docker Hub.

Authorization is GitHub's. The job declares `permissions: contents: read`, so even if a step were compromised it holds a token that cannot write to the repository. No secret is read, which means a fork's pull request cannot use this workflow to exfiltrate anything, because there is nothing to exfiltrate. This is `INV-6`.

There is no untrusted input. Nothing from the event payload is interpolated into a shell command, so the usual script injection through a branch name or pull request title does not apply here. The container name is built from `github.run_id` and `github.run_attempt`, both of which are integers generated by GitHub.

No personal data is handled. The only output is a fixed string written by the container, and it lands in the job log, which follows the repository's visibility.

On shared limits: each run performs at most one anonymous Docker Hub pull, and Docker Hub rate limits anonymous pulls per source address, which runners share. At that limit `docker build` fails with Docker Hub's own rate limit message and the job goes red; the fix, if it ever becomes routine, is to add a Docker Hub login or mirror the base image into GHCR. Each run also consumes GitHub Actions minutes, roughly one minute per run, which is free for a public repository. Disk and memory use are a few hundred megabytes on a runner that has tens of gigabytes, so neither is a real constraint.

## 9. Acceptance criteria

- `AC-1`: Pushing a commit to any branch starts a run of `hello-container`, and the run's job log shows `Runner Image: ubuntu-26.04` and a `container logs` group containing `Hello, world from Ubuntu 26.04`.
- `AC-2`: That same group also contains `this line came from stderr`, proving both streams were captured.
- `AC-3`: The hello world text appears only inside the `container logs` group and is produced by a `docker logs` invocation, not by the foreground output of `docker run`.
- `AC-4`: With the Dockerfile temporarily changed so the container exits with code 3, the run fails, the job's failure is attributed to the exit code step, and the `container logs` group is still present and populated.
- `AC-5`: With the Dockerfile temporarily changed so the container sleeps indefinitely, the run fails between 120 and 180 seconds after the container starts, the `container logs` group is still present, and the failure message names the wait cap rather than GitHub's job timeout.
- `AC-6`: Triggering the workflow manually from the Actions tab produces the same result as `AC-1`.
- `AC-7`: Opening a pull request produces a run whose result is reported on the pull request's checks.
- `AC-8`: `docker inspect` of the container name immediately after the cleanup step reports that no such container exists, in both the passing case and the `AC-4` failing case.
- `AC-9`: The workflow file contains no `secrets.` reference and declares `permissions: contents: read`.

## 10. Test approach

This change is a CI definition, so most of it is proved by running it and reading the result. The plan is three passes on a branch before merging.

Static checks come first. Running `actionlint` over `.github/workflows/hello-container.yml` catches schema and shell quoting mistakes without spending a runner, and reading the file proves `AC-9` and `INV-6`.

The happy path pass covers `AC-1`, `AC-2`, `AC-3`, `AC-6`, and `AC-7`, and with them `INV-1` and `INV-2`. Push the branch, read the job log, then dispatch the workflow by hand, then open a draft pull request. `INV-4` is read off the same log, which prints the container name in the start step.

The failure pass covers `AC-4` and `AC-5`, and with them `INV-3` and `INV-5`. Each needs a throwaway commit that changes only the Dockerfile's `CMD`, one to `exit 3` and one to `sleep infinity`. Both commits are reverted before the branch merges, so the merged Dockerfile is the passing one. `AC-5` is the reason the wait cap is a number and not the word "eventually": the assertion is a measured duration read from the job log timestamps.

`AC-8` needs a temporary extra step that runs `docker inspect` after cleanup and asserts a non-zero result. It is added for the two verification runs and removed before merge, because keeping it would mean the workflow tests itself forever for a leak that cannot outlive an ephemeral runner.

## 11. Risks and tradeoffs

- The `ubuntu-26.04` runner is a preview image. GitHub warns that software on it may be unstable and that jobs may queue while capacity is balanced. Mitigation: the workflow uses only Docker and `actions/checkout`, which are the least likely parts to break, and switching to `ubuntu-24.04` is a one line change if the preview proves unusable. That switch would break `INV-1` and needs the reporter's agreement.
- The official `ubuntu:26.04` tag on Docker Hub was not verified while writing this design, so it is an assumption rather than a checked fact. Ubuntu 26.04 is an LTS release and the official images normally carry the version tag, so the assumption is a safe one, and if it is wrong the build fails immediately and obviously. Mitigation: confirm the tag as the first step of implementation; the fallbacks are the `resolute` codename tag or a different base, and the latter would need the reporter's agreement.
- Running on every push to every branch costs a run per push. On a demo repository this is free and useful. If the repository grows busy, narrowing the `push` trigger to the default branch is a small change.
- Anonymous Docker Hub pulls share a rate limit across GitHub's runners. A busy day elsewhere can fail our build for reasons we did not cause. Mitigation is described in section 8 and is not worth building now.

## 12. Open questions

- Did the reporter mean a workflow or a reusable `action.yml`? We are building a workflow, for the reasons in section 4. This does not block work; if the answer is `action.yml`, the steps move across mostly unchanged. Yes.
- Should the workflow run on every push, or only on the default branch and pull requests? We propose every push, because the point of this ticket is a visible signal that CI works. Does not block work. Yes
- Is 120 seconds the right wait cap? It is generous for a container that echoes one line and finishes in well under a second. Does not block work. Yes
- Should the job also run on `ubuntu-26.04-arm`, which exists as a separate label? We propose not to, since the ticket names one platform and a matrix doubles the queueing exposure. Does not block work. Yes

Nothing here blocks starting the work.

## 13. Out of scope

- Publishing the image to GHCR or any other registry.
- A reusable `action.yml` for other repositories to consume.
- Any application code, service, or deployment.
- A matrix across runner architectures or Ubuntu versions.
- Caching the Docker build, which would save a few seconds and add a cache to reason about.
- Branch protection or required status checks wired to this workflow.
