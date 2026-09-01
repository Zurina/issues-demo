# House rules for the ticket-to-PR chain

Drop this into the root of the repository you are working in, as `CLAUDE.md`.
It layers on top of the `design` / `plan` / `task-to-pr` / `test` / `review` skills
without editing them, so upstream updates stay safe to pull.

---

## The chain

Work starts from a ticket and moves through fixed stages. The order matters and
the gates are deliberate.

```
triage → fetch-ticket → design → [HUMAN GATE] → plan → task-to-pr → [MERGE GATE]
```

Two gates need a person. Everything between them can run unattended.

## Gate 1 — the spec gate

`design` stops with a proposed design and does not continue. A human approves the
acceptance criteria before any implementation begins.

- Approving the spec approves the tests. Every `AC-n` becomes a test later.
- Sending a spec back is cheap and expected. Do not treat rejection as failure.
- After a spec is approved, its `AC-n` and `INV-n` IDs are fixed. Nothing downstream
  may renumber, reword, or reinterpret them.

## Gate 2 — the merge gate

A human merges. Agents open pull requests; they never push to a protected branch
and never merge.

---

## Escalation: implementation back to the spec

**If implementation reveals that an approved acceptance criterion is wrong,
impossible, or ambiguous — stop and return to the spec gate.**

Do not reinterpret the criterion to fit what the code can do. Do not quietly
implement the nearest achievable thing. Do not adjust the criterion so the tests
pass.

Report which `AC-n` is affected, what was discovered, and the options. The person
who approved the spec decides. This is the only backward edge from implementation,
and it is the reason the acceptance criteria mean anything.

## Conventions

Before designing, read `docs/conventions.md` if it exists, and follow it. It records
decisions this team has already settled; re-litigating them wastes a review cycle.

When a design or review is sent back for a reason that will recur, offer to record
it with the `convention` skill. A correction given once in conversation is lost;
a rule written down applies to every future run.

## Sizing

When `plan` produces tasks, include a rough size for each: `S` (under a day),
`M` (one to three days), `L` (more than three days, consider splitting).

A person approving a spec should know whether they are approving three days or
three weeks. Sizes are estimates, not commitments — say so.

## Context

Before designing, read `ARCHITECTURE.md` if it exists, and any prior design under
`docs/*/design.md` touching the same area. Designs that contradict earlier decisions
are more expensive than designs that are merely late.

## Tracker

The tracker is the source of truth for anyone not in this terminal.

- When `design` raises a blocking question, offer to post it to the ticket with
  `ticket-sync` so the reporter can answer asynchronously.
- When pull requests are opened, offer to post the links and which `AC-n` each satisfies.
- Never change ticket status, assignee, or priority. Comments only.

## Artefacts

Everything the chain produces lives under `docs/<ticket-id>/`:

```
docs/PROJ-418/
  brief.md     ← fetch-ticket
  design.md    ← design, approved at gate 1
  tasks.md     ← plan
```

Never write chain artefacts outside that directory.

**Commit them with the code.** Every pull request must include the `docs/<ticket-id>/`
directory alongside the implementation. A reviewer should be able to open the PR and
read the brief that started it, the design that was approved, and the tasks it was
split into — without leaving the diff.

This is what makes the acceptance criteria auditable after the fact. A PR that says
it satisfies `AC-2` and does not carry the document defining `AC-2` is not traceable,
whatever the commit message claims.

## Worktrees

Each issue is worked in its own git worktree on its own branch:

```
.worktrees/issue-<n>     ← working tree, branch issue-<n>
```

Do not work two issues in the same tree. Artefacts written under a worktree land on
that issue's branch, which is what carries them into the pull request.

`.worktrees/` is gitignored — the worktrees themselves are never committed.
