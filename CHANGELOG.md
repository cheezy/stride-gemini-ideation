# Changelog

All notable changes to the Stride Ideation extension for Gemini CLI are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-07-05

Review-queue quality and shipping-attribution enhancements — the decomposer, validator, and `/stridify` pipeline now steer toward tasks that score well in the Stride review queue, and shipped goals are attributed to the agent that created them. Eight changes across new behavior, fixture calibration, and documentation cleanup.

### Added

- **Validator advisory warnings** — `lib/validate_batch.py` now emits **non-fatal** advisory warnings to stderr (exit code stays 0) after the five structural checks pass: (1) any task missing one of the five review-queue scored fields (`testing_strategy`, `security_considerations`, `patterns_to_follow`, `pitfalls`, `acceptance_criteria`); (2) any length-limited field exceeding Stride's 255 code-point `varchar` limit — the five scalar `varchar(255)` fields (incl. `title`) or an element of the `varchar(255)[]` array fields (incl. `security_considerations`). The five structural checks stay fatal; warnings never change the exit code, so a valid-but-under-scored batch is not blocked. Field lists mirror the canonical Stride task schema; code-point counting matches the server's changeset guard. Covered in lockstep by `lib/test-validate-batch.{sh,ps1}`.
- **`created_by_agent` stamping in `/stridify`** — `commands/stridify.toml` Step 8 now stamps `created_by_agent` onto every goal before the `POST /api/tasks/batch`, so shipped goals are attributed to the agent on Stride's `/agents` "created" view instead of `?` (the field is not backfillable via PATCH). It is a real API field kept **off** `lib/strip_audit_fields.py`'s `LOCAL_AUDIT_FIELDS`, and a `created_by_agent`-survives-stripping test was added to `lib/test-ship-helpers.{sh,ps1}`.

### Changed

- **Decomposer contract enumerates and exemplifies all five scored fields** — `agents/requirements-decomposer.md` adds `security_considerations` to the canonical skeleton task block, populates all five review-queue scored fields on a fully-worked task in each of the three examples, and adds a "five review-queue scored fields" subsection instructing that every emitted task carry them.
- **Calibration fixtures carry all five scored fields** — every task across the three `fixtures/*-stride-batch.json` calibration fixtures (5 + 16 + 14 tasks) now includes `testing_strategy`, `security_considerations`, `patterns_to_follow`, and `pitfalls` with realistic, domain-specific values, so the reference for "good decomposer output" models fully-scored tasks.

### Fixed

- **Reviewer check-count contradiction and `/ideate` enforcement-list omission** — `agents/requirements-reviewer.md` said "All three checks" where five profile-aware checks exist ("three" → "five"), and `commands/ideate.toml`'s enforcement list omitted the mandatory Round-5 MVP-design batch (`profile=lean-startup` only); a bullet was added.
- **Stale `/decompose` and `/ship` command references** — the removed commands (merged into `/stridify`) were corrected to `/stridify` (or the correct current behavior) in `lib/test-stamping.sh`, `lib/test-ship-helpers.sh`, `lib/filename.sh`, and the notifications requirements fixture; the paired batch's `source_spec_sha256` was re-stamped to keep the audit pair consistent.
- **Copilot-port residue in the fixtures docs** — `fixtures/README.md` and `fixtures/SMOKE-TEST-NOTE.md` were rewritten to name Gemini CLI, the real `/ideate` and `/stridify` commands, and the single `stride-ideation` skill (dropping the nonexistent `stride-ideation-stridify`/`stride-ideation-ideate` skill names and the `Copilot CLI` phrasing); the smoke-test note now reports the actual **14 assertions across six stages** result (was a stale "10 passed") and cites `commands/stridify.toml` as the response-render source.
- **Orphaned drift check documented** — `/stridify` intentionally omits the `source_spec` drift check (`commands/stridify.toml` Step 8d), so the smoke runners' `/stride-ideation:ship` self-description was corrected to `/stridify` and `lib/drift_check.py` is now documented as a standalone fixture-integrity utility (exercised by the smoke test's Stage 2 and `test-drift-check`), not a pipeline step.

### Notes

- **No marketplace pin.** `stride-gemini-ideation` is published on no marketplace (there is no `marketplace.json` in the repo), so this release is a git tag + GitHub release on the `stride-gemini-ideation` repo only — no marketplace catalog update is required or performed.

## [0.3.0] - 2026-06-26

### Added

- **Challenge gate** — a mandatory, profile-independent design stress-test ported from the canonical `cheezy/stride-ideation` plugin. After the round-4 premortem (and the Round-5 MVP-design batch under `lean-startup`) and before the reviewer pass, `/ideate` runs a gate over the assembled draft with four components: (1) an **assumption-confidence audit** that rates every assumption `high`/`medium`/`low`; (2) a **blind-spot scan** for unstated dependencies, omitted stakeholders, untested edge cases, and failure modes the premortem missed; (3) **two distinct alternative approaches** to the proposed design; and (4) a **cost/risk/complexity/timeline trade-off comparison** against those alternatives. The gate is surfaced through Gemini CLI's question UI (never Claude Code's `AskUserQuestion`) as a single multi-select decision with an explicit "Challenge nothing — write as-is" option, and is **advisory — it never blocks the write**. Confidence ratings fold into the `## Assumptions` entries in place; the blind spots, the two alternatives, and the trade-off table fold into a new optional `## Design challenge` section (not one of the seven hard-gated sections, and never surfaced in the round recap). It runs under every profile, including `--continue` sessions. Documented in `skills/stride-ideation/SKILL.md`, surfaced in `commands/ideate.toml`, described in the README, and regression-guarded by a new `lib/test-challenge-gate.{sh,ps1}` unit suite, a Stage 6 check in both smoke runners, and a calibration fixture (`fixtures/2026-05-12T120300-saved-filters-challenge-gate-requirements.md`).

## [0.2.1] - 2026-06-26

### Security

- **Audit: the installer does not overwrite a user's project-root `GEMINI.md` (no fix needed).** Reviewed `install.sh` and `install.ps1` for the `AGENTS.md`-overwrite class of bug found in the OpenCode/Codex ideation installers. Both installers copy `GEMINI.md` — and every other file — only into the Gemini **extension directory** (`.gemini/extensions/stride-gemini-ideation/` in project mode, or `~/.gemini/extensions/stride-gemini-ideation/` globally), never the project root. No installer line writes a context file to the project root, so a user-authored project-root `GEMINI.md` is never clobbered. The Gemini extension model keeps the bundled `GEMINI.md` self-contained within the extension dir, so the managed-block guard applied to the OpenCode/Codex installers is unnecessary here and was intentionally not added.

## [0.2.0] - 2026-06-17

Human-interaction improvements ported from [`cheezy/stride-ideation`](https://github.com/cheezy/stride-ideation) (G235) — the lower-friction, higher-confidence ideation flow, adapted to Gemini CLI.

### Added

- **Section-completeness round recap** — before every question round, a display-only recap of the seven hard-gated sections (solid/thin/empty) plus the round's target sections. Never an extra question; never changes the gate, round order, or per-round question budget.
- **"I'm not sure — propose candidates" uncertainty path** — every gated-section and forcing question offers a first-class uncertainty option that flips into teaching mode (2–4 topic-tailored candidates with rationales). A candidate can never satisfy the hard gate without explicit human confirmation.
- **Profile recommendation** — when `--profile` is omitted, `/ideate` recommends a profile (recommended-first, `lean` default) before the rounds instead of silently defaulting. No recommendation runs when `--profile` is explicit; resolved-`lean` behavior is unchanged.
- **`--input <file>` brain-dump seed** — seed the session from a freeform notes file (read-only): it pre-fills draft sections and focuses the rounds on the gaps. Distinct from `--continue`; the input file is never modified, moved, or committed, and all gates still run.
- **Intra-session draft autosave & resume** — the in-progress draft autosaves to a gitignored `.stride/` scratch file after every round and is offered for resume on the next same-slug session; the scratch file is cleared after a successful commit. New `lib/draft.{sh,ps1}` helpers with `lib/test-draft.{sh,ps1}` suites.
- **Advisory reviewer findings as an explicit decision** — the `requirements-reviewer` findings are surfaced to the human as a single multi-select decision (with an explicit "Address none — write as-is") feeding the at-most-one refinement round. A clean approval shows no prompt; the reviewer never blocks the write.
- **Stridify preview + approval gate** — before the `POST /api/tasks/batch`, `/stridify` renders the decomposed goal/task tree and requires explicit human approval; `--yes` / `--auto-approve` bypasses the gate for scripted use. On decline, the committed batch JSON is left on disk and no POST is attempted. New `lib/test-stridify-preview.{sh,ps1}` suites.

### Notes

- Protocol content stays faithful to the Claude Code source; these are interaction-surface improvements only. Platform adaptations: Gemini CLI's question UI (never Claude Code's `AskUserQuestion`), Gemini tool vocabulary, and `.ps1` Windows-parity mirrors for every new `.sh`.

## [0.1.0] - 2026-06-05

Initial release — Gemini CLI port of [`cheezy/stride-ideation`](https://github.com/cheezy/stride-ideation) (Claude Code).

### Added

- **`/ideate`** native slash command (`commands/ideate.toml`) — drives the round-based ideation loop and commits a timestamped requirements markdown document. Supports `--continue <path>` and `--profile <lean|product|discovery|lean-startup>`.
- **`/stridify`** native slash command (`commands/stridify.toml`) — validates a requirements doc, preflights `.stride_auth.md`, dispatches the decomposer, stamps `source_spec` + `source_spec_sha256`, commits a sibling batch JSON, and POSTs to `/api/tasks/batch`. Supports `--goal <name|index>` and the four-layer resilience model (preflight advisory, per-surface dispatch, bounded retry with backoff, prompt-file fallback).
- **`stride-ideation`** skill — the protocol contract: the seven hard-gated sections, the shape requirements on Assumptions and Success Metrics, the round structure / framing checkpoint / premortem, the four profiles, and the terminal state.
- **`requirements-reviewer`** custom agent — advisory, report-only gap review of a draft requirements document.
- **`requirements-decomposer`** custom agent — turns a committed requirements document into a single fenced batch JSON matching `POST /api/tasks/batch`.
- **`lib/`** helper suite — `validate_batch.py`, `drift_check.py`, `read_auth.py`, `strip_audit_fields.py`, `filename.{sh,ps1}`, `run_smoke_test.{sh,ps1}`, and the `test-*.{sh,ps1}` suite (bash + PowerShell mirrors for cross-platform parity).
- **`fixtures/`** — three requirements + batch calibration pairs plus README and SMOKE-TEST-NOTE, exercised by the smoke test.
- **`GEMINI.md`** context file, `gemini-extension.json` manifest, `install.sh` / `install.ps1`, `.gitignore`, and `LICENSE`.

### Notes

- Ported faithfully from the Claude Code source; protocol content (sections, rounds, premortem, profiles, resilience model) is preserved verbatim. Platform adaptations only: native Gemini TOML commands, Gemini tool-name vocabulary, and inline option comparisons (Gemini has no preview-pane tool).
- No lifecycle hooks (`hooks.json`) — ideation has none. The companion [`stride-gemini`](https://github.com/cheezy/stride-gemini) extension covers the task lifecycle.
