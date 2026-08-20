---
name: pipeline
description: Run a full multi-agent development cycle (research → product-manager → ux-designer → business-analyst → developer → qa-tester → retrospective) for a feature or release, with each stage isolated in its own git worktree, reviewed, merged into the main branch, and cleaned up before the next stage begins. Use whenever a feature or release is substantial enough to warrant the whole team, not a single quick edit.
---

# Pipeline: running the team

This skill is for **you, the orchestrating session** (the "conductor") — it is not itself an agent. You read this, then you spawn the six team agents (plus the retrospective agent) in sequence, reviewing and merging each one's work before starting the next. This document exists because that pattern — worktree isolation, review, merge, cleanup, repeated per stage — worked well across several real releases and is worth reusing exactly, not reinventing per project.

## When to use this

A new feature, a scoped release, or a "build as much as fits in N hours" cycle that's big enough to benefit from research, design, and requirements happening before code — not a one-line fix or a single unambiguous bug report (just fix those directly).

## The stage sequence

1. **Researcher** (optional — skip if there's no real feedback to process and no external precedent worth checking). Turns raw feedback or an open question into cited findings.
2. **Product Manager.** Takes the researcher's findings (if any) plus the ask, and produces a **locked scope document** — not a proposal. See "Time-boxed releases" below for what a good one looks like.
3. **UX Designer.** Produces mockups for anything with a real UI surface, against the *locked* scope from step 2. Give this stage genuinely protected time when the ask calls for real design depth (see "Protecting a stage's time" below) — don't compress it into a rushed parallel slice by default.
4. **Business Analyst.** Expands the locked scope and the agreed mockups into numbered, Given/When/Then requirements. Normally sequential after UX (BA needs to write requirements against an actual design, not a guess). A parallel UX/BA deviation is only safe when a product-manager document has *fully* locked the feature's *behavior* already, and UX is choosing presentation, not deciding open interaction questions — state explicitly when you're making this call and why, since it's a deviation from the default, not the default itself.
5. **Developer.** Implements against the requirements. Verifies the build/lint/test suite passes before handing off — don't just trust a "looks right" self-report, re-run it yourself after merging too (see "Verification is the conductor's job too" below).
6. **QA Tester.** Writes and runs tests against the requirements, does a real toolchain run, adversarially probes beyond the stated acceptance criteria, and is explicit about what's structurally impossible to verify without a real device/environment.
7. **Senior-dev review (optional, time-permitting).** A read-only, advisory code-quality pass — different from QA. QA proves the code *works*; a code-quality review asks whether it's *well-built* (subtle logic bugs that pass every test, architecture, maintainability). Worth doing whenever there's real time slack left in a time-boxed release; skip it first if behind schedule. Route any real findings back through developer as a small, targeted fix — don't let the reviewer edit code directly, and don't skip re-verifying (analyze/test/build) after the fix pass.
8. **Retrospective.** The final phase of every cycle, not just the ones where something visibly broke. Its output goes to the *template repository*, not the app's own repo — see the `retrospective` agent's own file for what it does. Always run this, even briefly — a "nothing worth changing" verdict is a valid, useful output.

## The worktree-per-stage pattern

Every stage from Product Manager onward that touches files works like this:

1. **Spawn the agent with worktree isolation.** Use the Agent tool with `isolation: "worktree"`. This gives the agent its own copy of the repo on its own branch, so it can't collide with your own working copy or with any other stage. (You, the conductor, should also be in your own isolated worktree if you're a background/long-running session with shared-checkout protections — check your own environment's guidance on this.)
2. **Let it work, then read its output before merging — don't merge blind.** Skim the actual diff or the produced files, not just the agent's own summary of what it did. Its summary describes intent; the diff is what actually happened. This has caught real issues more than once (an agent writing to the wrong path, a design decision the summary glossed over, a test that was weaker than described).
3. **Merge into the main branch.** Prefer a fast-forward merge (`git merge <branch> --ff-only`) when nothing else has landed since the agent's worktree was created. If the main branch has moved on (another stage's work merged in the meantime, or you made a direct small fix), a fast-forward will fail — use an explicit merge commit (`git merge <branch> --no-ff -m "..."`) instead of force-pushing or rebasing.
4. **Clean up the worktree.** Remove the worktree directory and delete its branch once merged. Worktree removal sometimes fails with a file-lock error (a lingering process still has a handle on a file inside it — a build daemon, an editor, a leftover `Read` from you). Retry once; if it still fails, prune the git-level registration (`git worktree prune`) and move on — a stray empty directory on disk is harmless and can be cleaned up later, it does not block the pipeline.
5. **Watch for the isolation fallback.** Some agents (notably ones without a `Bash` tool in their tool list) sometimes end up writing directly into the shared checkout instead of their assigned worktree, and will tell you so plainly ("I don't have Bash access, I couldn't commit"). When this happens: check `git status` in the shared checkout for the uncommitted changes, review them the same way you'd review a worktree diff, then commit them yourself directly. Don't treat this as a failure — plan for it as a normal outcome for tool-limited agents.

## Handling agent failures

Two failure modes come up regularly and both usually just need a resume, not a restart:

- **A transient API error mid-stream** ("response stalled," a session/usage limit that resets shortly). Check whether the agent's worktree has real partial progress (`git status`/`git log` in its worktree path) before assuming anything was lost — it usually wasn't. Resume the same agent (send it a message addressed to its name) rather than spawning a fresh one; it keeps full context of what it already built and just continues.
- **A stall with no progress for several minutes.** Often caused by resource contention on the machine running the agent (see "Environment gotchas" below), not a bug in the agent's own work. Same fix: check for partial progress, resume rather than restart.

Never assume lost work without checking. Losing an agent's actual progress by restarting from scratch is far more expensive than a quick `git status` check.

## Protecting a stage's time

When a stage is given a hard time-box (see below) but the ask genuinely calls for depth in one particular stage (e.g. "I want real design thinking here, not a rushed pass"), write that protection into the schedule as an *enforceable rule*, not a hope:

- State the protected stage's time as a floor, not a target — later stages may not reclaim it if they run long.
- Say explicitly which default sequencing shortcut (e.g. a parallel-stages deviation) is *not* available this cycle.
- Confirm the protected stage has zero blocking dependencies at its start time, so it never sits idle waiting on something else.
- If the protected stage needs more time than budgeted, it gets to take it — cut *scope* to compensate, not the protected stage's time.

## Time-boxed releases

When the ask includes a real deadline ("ship something working by tonight," "as much as fits in N hours"), have Product Manager write the locked scope document with these parts, not just a feature list:

- **What's in, explicitly, with sizing.** Not a wishlist — a closed list.
- **What's explicitly out**, so nothing ambiguous gets built by accident.
- **A phase-by-phase time budget** (clock times or percentages of the window), each with a checkpoint: "if we're not done by X, act on the cut order below."
- **A pre-authorized cut order** — what gets dropped first, second, third if the team falls behind, decided *now* so nobody has to stop and debate it at the worst possible time. The last line of the cut order should always be the non-negotiable floor: a real, verified, working build — a smaller thing that's actually done beats a bigger thing that's rushed or broken.
- **Success criteria** stated as a checklist, so "are we done" has an unambiguous answer.

If a later stage needs a fast decision the scope document didn't cover, route it back to Product Manager for a quick, tightly-scoped ruling rather than spinning up a full re-scoping pass — keep the ask narrow ("just this one yes/no, with reasoning") so it doesn't eat the schedule it's trying to protect.

## Verification is the conductor's job too

Don't just trust a developer or QA agent's self-reported "tests pass, build succeeds." After merging their work into the main branch, re-run the real toolchain commands yourself (lint/analyze, test, build) against the actual merged state. Agents sometimes report results from their own worktree just before a merge that turns out non-trivial (a merge commit, not a fast-forward) — re-verifying after the merge is the only way to be sure the *merged* state, not just the pre-merge branch, is actually good.

## Environment gotchas worth knowing before you hit them

These are the kinds of things that eat real time if you don't expect them:

- **Running an emulator/simulator and a build at the same time can starve memory and cause builds to silently crawl or hang** on a resource-constrained machine. Check for and stop competing processes before kicking off a build if you've seen this happen before on this environment.
- **A nearly-full disk causes exactly this kind of slow, hard-to-diagnose failure too.** Regenerable build output directories (a `build/` folder, `.dart_tool/`, similar) are almost always safe to delete to reclaim space — a real dependency cache (Gradle, a package manager's global cache) usually isn't worth clearing, since it just means a slower re-download next time, not a functional problem.
- **A background/long-running shell command can be killed by an external watchdog** for reasons unrelated to whether it's actually making progress (e.g. producing no new stdout for a long stretch during a silent compile phase). If a command that should have worked gets killed, check whether the underlying process might actually still be running or already finished before assuming it failed — sometimes a quick, separate follow-up check reveals it succeeded.

## What "done" means for this whole cycle

A cycle isn't complete when code is merged — it's complete when: the real toolchain has been run against the merged state with output you've actually seen (not assumed), the retrospective phase has run (even if its answer is "no change needed"), and — if the ask was to get something onto a real device — that install has actually been attempted, with an honest report of whether it succeeded, not just a build artifact sitting unverified.

## Post-release phase (optional — Growth and Insights, only after something is actually live)

Two more agents, Growth and Insights, exist for what happens *after* the 8-stage cycle above ships — they are not part of the standard sequence and should not be spawned as part of a normal feature/release cycle. Their defining gate is the same for both: **something has to actually be live for real users** — a real device install a tester can use, or a live URL — not a merged build sitting in a repo. Don't spawn either one before that's true; there's nothing for them to work from yet.

- **Growth**, once something is live (or pre-launch if the human explicitly wants an early positioning/channel gut-check): turns the shipped product's real, verified capabilities into store-listing copy, landing-page copy, and distribution-channel picks. Feed it the current product brief, requirements, and QA results so its copy is grounded in what's actually true, not the original pitch.
- **Insights**, once something is live with real users: defines what to measure (respecting whatever privacy/architecture constraints the product already locked — never assume telemetry is free to add) and mines whatever feedback channels exist (reviews, a survey, support messages) into structured findings for product-manager and researcher. Unlike a one-time pipeline stage, Insights is meant to be re-invoked on a recurring cadence as more real-world signal accumulates, not run once and done.

Both hand findings to product-manager, the same as every other agent — neither one decides scope, roadmap, or ships anything itself.
