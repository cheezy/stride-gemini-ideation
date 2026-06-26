# Stride Ideation for Gemini CLI

Turn an idea into shipped Stride tasks — from Gemini CLI.

This extension provides brainstorming and ideation commands for projects that use [Stride](https://www.stridelikeaboss.com). It is the Gemini CLI port of [`cheezy/stride-ideation`](https://github.com/cheezy/stride-ideation) (Claude Code). Run `/ideate` to drive an interactive ideation session that produces a committed requirements markdown document. Stop there if you just want a written spec — or run `/stridify` to decompose the requirements into a Stride batch JSON, commit it for audit, and POST it to the Stride API in a single invocation.

> **GitHub Topic:** This repo should be tagged with `gemini-cli-extension` for auto-indexing in the Gemini extension gallery.

## Overview

The two native slash commands:

```text
/ideate [<topic>] [--continue <path>] [--profile <lean|product|discovery|lean-startup>]
  Interactive ideation session. Drives a Q&A loop with you to produce a
  timestamped requirements markdown doc. Stop here if you only want a spec.

/stridify <path-to-requirements.md> [--goal <name|index>]
  End-to-end pipeline: validates the requirements doc, preflights auth,
  dispatches the decomposer agent, stamps audit metadata, writes and
  commits a sibling Stride batch JSON, then POSTs it to /api/tasks/batch
  on your Stride instance and renders the created G/W identifiers.
  --goal scopes the dispatch to one surface from the doc's
  ## Decomposition seams section (see "Resilience model" below).
```

`/ideate` is hard-gated on seven required sections (Goal, Problem, Outcome, Assumptions, Constraints, Non-goals, Success Metrics) plus shape requirements on Assumptions (ranked, riskiest marked, premortem-derived) and Success Metrics (both leading and lagging indicators). `/stridify` is gated on a passing structural validation of the decomposer's output before it commits or POSTs anything.

## Installation

### Recommended: install as a Gemini CLI extension

```bash
gemini extensions install https://github.com/cheezy/stride-gemini-ideation
```

Gemini CLI clones the extension, auto-loads `GEMINI.md`, registers the `commands/*.toml` slash commands (`/ideate`, `/stridify`), and discovers the `skills/` and `agents/` directories.

### Manual install (fallback)

Clone the repo and copy the extension into your Gemini extensions directory:

```bash
git clone https://github.com/cheezy/stride-gemini-ideation.git

# Global (all projects): ~/.gemini/extensions/stride-gemini-ideation/
./stride-gemini-ideation/install.sh

# Project-local: .gemini/extensions/stride-gemini-ideation/
./stride-gemini-ideation/install.sh --project
```

On Windows, use the PowerShell installer:

```powershell
.\stride-gemini-ideation\install.ps1            # global
.\stride-gemini-ideation\install.ps1 -Project   # project-local
```

The installers copy `gemini-extension.json`, `GEMINI.md`, and the `commands/`, `skills/`, `agents/`, `lib/`, and `fixtures/` directories into the target extension location.

## Setup

`/stridify` needs Stride API credentials. Create `.stride_auth.md` in your project root:

```markdown
- **API URL:** `https://www.stridelikeaboss.com`
- **API Token:** `stride_...`
- **User Email:** `you@example.com`
```

Add `.stride_auth.md` to your `.gitignore` — it holds a secret token. The bundled `.gitignore` already excludes it. `/ideate` needs no credentials.

## Commands

### /ideate

Drives the round-based ideation loop defined by the `stride-ideation` skill: Rounds 1–2 capture Goal/Problem/Outcome and the boundary conditions; Round 3 is a mandatory framing checkpoint; Round 4 is a mandatory premortem that folds failure modes into the Assumptions section and ranks them; the `lean-startup` profile adds a Round 5 MVP-design batch. After the premortem (and the Round-5 batch under `lean-startup`) and before the reviewer pass, a mandatory, profile-independent **challenge gate** stress-tests the design via four components — an assumption-confidence audit (rate every assumption `high`/`medium`/`low`), a blind-spot scan, two distinct alternative approaches, and a cost/risk/complexity/timeline trade-off comparison — surfaced through Gemini CLI's question UI (not Claude Code's `AskUserQuestion`) as a single multi-select decision with an explicit "Challenge nothing — write as-is" choice. The gate is advisory and never blocks the write: the confidence ratings fold into the Assumptions entries in place, and the blind spots, the two alternatives, and the trade-off comparison fold into a new optional `## Design challenge` section (not one of the seven gated sections). After all seven sections have content, the `requirements-reviewer` agent runs an advisory pass, then the doc is written and committed. The terminal state is the written document — `/ideate` never auto-invokes `/stridify`.

Profiles: `lean` (default), `product` (adds JTBD framing + Concrete Example section), `discovery` (adds Why-now + Alternatives), `lean-startup` (adds the Round-5 MVP / Validation experiment section).

### /stridify

Validates the requirements doc's seven sections, preflights `.stride_auth.md`, and dispatches the `requirements-decomposer` agent to produce a Stride batch JSON. It stamps `source_spec` + `source_spec_sha256` at the JSON root for audit, writes and commits a timestamped sibling batch JSON, strips the audit fields from the POST payload, then POSTs to `/api/tasks/batch` and renders the created G/W identifiers.

#### Resilience model

- **Preflight advisory** when a doc enumerates more than 3 surfaces under `## Decomposition seams`.
- **`--goal <name|index>`** scopes the dispatch to a single surface from `## Decomposition seams`, partitioning a many-surface doc into one dispatch per surface.
- **Bounded decomposer-dispatch retry** — 3 attempts with ~30s / ~90s backoff on HTTP 529 / network / "overloaded" failures.
- **Fallback** — on retry exhaustion the assembled prompt is written to a sibling `*-decomposer-prompt.md` file. The Stride API POST itself is not retried; re-invoke on a 4xx/5xx.

## Skill and Agents

- **`stride-ideation`** skill — the protocol contract (required sections, shape requirements, rounds, premortem, challenge gate, profiles, terminal state).
- **`requirements-reviewer`** agent — advisory gap review of a draft doc; reports only, never edits.
- **`requirements-decomposer`** agent — turns a committed doc into a single fenced batch JSON; no prose.

## How this relates to `stride-gemini`

[`stride-gemini`](https://github.com/cheezy/stride-gemini) covers the **task lifecycle** (claiming, hook execution, completion). This extension covers **ideation** — turning a fuzzy idea into a requirements doc and seeding a Stride backlog from it. A typical full loop installs both: `/ideate` → `/stridify` here, then claim and ship the resulting tasks with `stride-gemini`.

## License

MIT — see [LICENSE](LICENSE).
