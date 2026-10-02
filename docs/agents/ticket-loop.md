# Ticket loop

One **pass** per run over the repo's issues, started with `/loop Run one pass of the ticket loop in docs/agents/ticket-loop.md` and no interval, so every pass ends by pacing the next one. The loop's state lives on GitHub, never in the session, so a pass picks up after a crash, a `/clear` or a new session. Its authorization is the Ticket loop section of `CLAUDE.md`.

## The marker

The gh account is the user's, so authorship can't tell the loop's words from the user's. Start every issue comment and PR reply the loop writes with `[ticket-loop]`, and label every loop PR `ticket-loop`, creating the label if it is missing. A comment without the marker is the user's.

## A pass

1. **Resume.** On a `feat/<n>-*` branch with uncommitted or unpushed work, carry that ticket on from Build in step 4, then continue at step 5.
2. **Merges and feedback.** For each `ticket-loop` PR:
   - merged: switch to `main`, `git pull --prune`, and delete its branch with `git branch -d`;
   - open and conflicting with `main`: rebase onto `origin/main`, resolve with `/resolving-merge-conflicts`, rerun the full suite, `git push --force-with-lease`;
   - open with a user comment or review thread that has no loop reply after it: address it, push, and reply on it.
3. **Answers.** For each open `needs-info` issue whose newest comment is the user's: swap `needs-info` for `ready-for-agent`.
4. **Ticket.** With fewer than 2 open `ticket-loop` PRs, take the next **available** ticket: open, labelled `ready-for-agent`, unassigned, and every issue in its "Blocked by" closed. Prefer one whose spec files don't overlap a ticket with an open loop PR, then the lowest number. None available: go to step 5.
   - **Claim.** Assign it to `@me`. Branch `feat/<n>-<slug>` from `origin/main`, or check out and rebase the branch a parked pass pushed for it.
   - **Design.** Comment the design on the issue: the operations, the screens, the tests at the ticket's seam, and the decisions the spec leaves open with the choice taken. The comment informs; carry on.
   - **Build.** Follow `/implement`. The ticket's "Test seam" line is the agreed seam set `/tdd` asks for. Verify with the typecheck, the ticket's suites and the full suite (`docs/agents/build.md`), and check its screens with Drive the app there. Fix the `/review-diff` findings inside the ticket's scope.
   - **Ship.** Commit with `git commit` in `/commit`'s personal format: a conventional subject under 72 characters, a blank line, `Closes #<n>`, and no attribution trailers. `/commit` stops to confirm, so the loop writes the commit itself. Push, and open the PR into `main` with the `ticket-loop` label. Model its body on the last merged PR, listing the open decisions taken and what is left to later tickets. Switch to `main`.
   - **Park** the ticket instead, at any point, when it reaches an **Open** point in the spec, a conflict with an ADR, a behaviour the spec leaves undecided, or tests that stay red after a real attempt. Comment the question or the failure on the issue, swap `ready-for-agent` for `needs-info`, unassign it, push the branch if it has commits and link it in the comment, then switch to `main`.
5. **Pace.** Report the pass in one or two lines, then schedule the next one:
   - a ticket was shipped or parked: in 60 s, since another may be available;
   - waiting only on merges, feedback or answers: in 1800 s;
   - no `ready-for-agent` or `needs-info` issue and no open loop PR left: stop the loop.
