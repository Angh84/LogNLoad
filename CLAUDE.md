## Build and test

Build, test, run in the simulator or install on the iPhone: see `docs/agents/build.md`.

## Ticket loop

`/loop /skynet:ticket-loop` works through the `ready-for-agent` issues unattended. This section is its standing authorization in this repo, and replaces design-first approval for its tickets:

- Branch, commit, push, open and update PRs, and comment on, assign and relabel issues without asking. The design goes in an issue comment.
- The user merges every PR. At most 2 loop PRs are open at a time.
- Verify each ticket with the typecheck, its suites and the full suite, then check its screens with Drive the app in `docs/agents/build.md`.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on Angh84/LogNLoad, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
