## Build and test

Build, test, run in the simulator or install on the iPhone: see `docs/agents/build.md`.

## Ticket loop

`/loop Run one pass of the ticket loop in docs/agents/ticket-loop.md` works through the `ready-for-agent` issues unattended. This section is its standing authorization, and replaces design-first approval for its tickets: branch, commit, push, open and update PRs, and comment on, assign and relabel issues without asking. The design goes in an issue comment. The user merges every PR.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on Angh84/LogNLoad, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
