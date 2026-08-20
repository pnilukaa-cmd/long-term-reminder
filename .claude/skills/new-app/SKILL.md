---
name: new-app
description: Bootstrap a brand-new app project from this pipeline template — copies all nine team agent definitions (the six pre-launch roles, retrospective, and the post-release-only growth/insights pair) and the orchestration skill into a fresh project repo, records where the template came from, and kicks off the researcher agent with the new app's one-line pitch. Use when the user wants to start an entirely new app using this team pattern (e.g. "/new-app <name> <pitch>").
---

# /new-app — bootstrap a new project from this template

## Input

A project name and a one-line pitch, e.g.:

```
/new-app grocery-list "A grocery list app that groups items by aisle automatically"
```

If the user invokes this with just a name and no pitch, ask for a one-line pitch before proceeding — the researcher agent needs something concrete to start from, and guessing at the idea yourself defeats the point of a team-driven process.

## What you do, step by step

1. **Locate this template repository.** You're reading this file from inside it — note its path or git remote URL now, you'll need to record it in the new project.

2. **Create the new project directory**, sibling to (not inside) this template repo, named after the project (e.g. `../grocery-list/`).

3. **Copy the team into the new project:**
   - `.claude/agents/*.md` (all nine: researcher, product-manager, ux-designer, business-analyst, developer, qa-tester, retrospective, growth, insights) — copy verbatim, don't edit them. They're already written generically; app-specific context belongs in the new project's own `CLAUDE.md`, not baked into the agent files. Note that `growth` and `insights` are post-release-only — see the `pipeline` skill's "Post-release phase" section — so don't spawn them as part of this bootstrap step or the initial pipeline cycle; they're copied in now so they're ready once something actually ships.
   - `.claude/skills/pipeline/SKILL.md` and `.claude/skills/new-app/SKILL.md` — copy verbatim, so the new project can also bootstrap *its own* future sibling projects if it's ever used as a template in turn.

4. **Write the new project's root `CLAUDE.md`**, filling in the parameterized parts — this is where all the app-specific context goes that the template's agent files deliberately don't contain:
   - Project name and one-line pitch (from the input).
   - **Template provenance** — a clearly-labeled section recording where this project's team pattern came from (the template repo's path or URL) and, if a git remote exists, its URL — this is how the `retrospective` agent finds where to send future improvements. Something like:
     ```markdown
     ## Template provenance
     This project's `.claude/agents/` and orchestration skill were bootstrapped from
     <template repo URL or path>. The `retrospective` agent proposes improvements
     back to that repository, not this one.
     ```
   - Team roles and their responsibilities — a short summary is fine, the agent files themselves are the source of truth; don't duplicate their full content here.
   - A placeholder "Stack" section for the developer/QA agents to fill in as soon as a first technical decision is made (framework, language, state management, toolchain) — leave it explicitly marked as "not yet decided" rather than guessing a stack the user didn't ask for.
   - The workspace-wide working agreements worth carrying forward as *starting defaults*, not permanent laws — the new project's team can revise them as it learns what actually matters for this specific app:
     - A feature isn't done until it actually runs (a real toolchain run, not a code read-through).
     - Design before requirements, requirements before code, for anything with a real UI surface.
     - Evidence over guesswork — loop in research before locking a plan when a decision would benefit from it.
     - Every screen handles four states: loading, empty, error, success.

5. **Initialize git** in the new project directory (`git init`), stage everything, and make an initial commit (something like `Bootstrap project from agent-pipeline-template`). Do not push anywhere yet — that's the user's call, same as any other new repo.

6. **Kick off the researcher agent** with the new app's one-line pitch as its input — ask it to research the problem space: what comparable products exist, what established patterns apply, what a first tester might expect. This is the first real step of the `pipeline` skill's sequence (see that skill for what happens next: researcher's findings feed product-manager's initial scoping brief).

7. **Report back** to the user: the new project's location, a one-line confirmation of what was copied in, and that the researcher agent is running — invite them to review its findings before product-manager locks a v1 scope, same as the normal pipeline sequence.

## What you don't do

- You don't invent app-specific requirements, features, or a v1 scope yourself — that's the whole team's job, starting with researcher and product-manager, not something this bootstrap step should pre-decide.
- You don't skip the template-provenance note in the new project's `CLAUDE.md` — without it, the `retrospective` agent has nowhere to send future improvements, and that link is the entire point of this template existing as a separate, versioned repository instead of being copy-pasted ad hoc per project.
- You don't push the new project's repo to a remote automatically — creating and pushing a new remote repository is the kind of action to confirm with the user first, not assume.
