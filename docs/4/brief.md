# 4 — Build a github action that builds a busybox image that lasts for 10 seconds printing hello world or something

Source: https://github.com/Zurina/issues-demo/issues/4
State: OPEN · Reporter: @Zurina · Labels: none

## Stated goal

> Build a github action that builds a busybox image that lasts for 10 seconds printing hello world or something

## Context from the discussion

No comments on the issue. Nothing beyond the description.

## Linked work

None. The issue references no other issues or pull requests.

## Acceptance hints

- A GitHub Action exists and builds an image. Source: "Build a github action that builds a busybox image".
- The image is based on busybox. Source: "builds a busybox image".
- The container runs for 10 seconds. Source: "that lasts for 10 seconds".
- The container prints "hello world" (or similar) while running. Source: "printing hello world or something".

## Unresolved

- Does "build a github action" mean a reusable action (`action.yml`, composite/Docker action) or a workflow file under `.github/workflows/`?
  **Answered:** latter
- Should the workflow only build the image, or also run it and assert the 10-second/output behaviour? The title says "builds", but the runtime behaviour is only observable by running it.
  **Answered:** latter
- Is the image pushed anywhere (GHCR, Docker Hub) or built locally in the job and discarded?
  **Answered:** nope, just use dockerhup
- What triggers the workflow — push, pull_request, workflow_dispatch, schedule?
  **Answered:** dispatch
- Is "lasts for 10 seconds" a `sleep 10` after printing once, or printing repeatedly for 10 seconds (e.g. once per second)?
  **Answered:** print something for 10 seconds, then stop the contaienr
- Exact output string: literal `hello world`, or is any message acceptable? ("or something" leaves this open.)
  **Answered:** hello world
- Where should the Dockerfile live in the repo, and what should the image be named/tagged?
  **Answered:** root
- Any platform/architecture requirements (amd64 only vs multi-arch)?
  **Answered:** nope
