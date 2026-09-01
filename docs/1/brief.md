# 1 — Build GH action that spins up a hello world container and prints out the logs from it

Source: https://github.com/Zurina/issues-demo/issues/1
State: OPEN · Reporter: @Zurina · Labels: none

## Stated goal

> Build GH action that spins up a hello world container and prints out the logs from it
>
> Use ubuntu 26-04

## Context from the discussion

None. The issue has no comments.

## Linked work

None. The issue references no other issues or pull requests.

## Acceptance hints

- A GitHub Actions workflow/action exists and runs a container.
  Source: "Build GH action that spins up a hello world container"
- The logs produced by that container are printed in the run output.
  Source: "and prints out the logs from it"
- Ubuntu 26.04 is used.
  Source: "Use ubuntu 26-04"

## Unresolved

- Does "GH action" mean a workflow in `.github/workflows/`, or a reusable custom action (`action.yml`, e.g. a Docker container action)? The wording covers both.
- Does "ubuntu 26-04" apply to the runner image (`runs-on: ubuntu-26.04`), the container's base image, or both? The ticket does not say.
- Is `ubuntu-26.04` actually available as a GitHub-hosted runner label? If not, the ticket's constraint cannot be met as literally written and a substitute has to be chosen.
- Which container counts as "a hello world container" — the `hello-world` Docker image, an Ubuntu 26.04 image running an echo, or a purpose-built image in this repo?
- What triggers the workflow (`push`, `pull_request`, `workflow_dispatch`, schedule)?
- "prints out the logs from it" — is `docker logs` on a finished container required specifically, or is any capture of the container's stdout in the job output acceptable?
- Is the run expected to fail the job if the container exits non-zero?
- No repository exists yet beyond `docs/`; is anything else (a Dockerfile, an app) in scope, or only the CI definition?