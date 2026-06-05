# Changelog

All notable changes to the Stride Ideation extension for Gemini CLI are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
