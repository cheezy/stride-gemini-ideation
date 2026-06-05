# Stride Ideation Extension for Gemini CLI

Turns a fuzzy idea into a committed requirements document, and seeds a Stride backlog from it. This extension covers **ideation**; the companion [stride-gemini](https://github.com/cheezy/stride-gemini) extension covers the **task lifecycle** (claiming, hooks, completion).

## Commands

Two native slash commands drive the workflow. The protocol contract they enforce lives in the `stride-ideation` skill — the commands defer to it rather than restating it.

| Command | When to use |
|---------|-------------|
| `/ideate [<topic>] [--continue <path>] [--profile <lean\|product\|discovery\|lean-startup>]` | Brainstorm and scope a fuzzy idea into a committed requirements markdown doc. Drives the round-based question loop, the round-3 framing checkpoint, the round-4 premortem, and (lean-startup) the round-5 MVP batch. Hard-gated on the seven required sections. Terminal state is the written doc — it does NOT auto-invoke `/stridify`. |
| `/stridify <path-to-requirements.md> [--goal <name\|index>]` | Decompose a committed requirements doc into Stride tasks and POST them. Validates the seven sections, preflights `.stride_auth.md`, dispatches the requirements-decomposer agent, stamps `source_spec` + `source_spec_sha256`, writes and commits a timestamped batch JSON, then POSTs to `/api/tasks/batch` and renders the created G/W identifiers. |

`/stridify` is optional — the requirements doc is a deliverable on its own. Run it only when you want the tasks created in Stride.

## Skill

- **`stride-ideation`** — the protocol contract: which seven sections are required (Goal, Problem, Outcome, Assumptions, Constraints, Non-goals, Success Metrics), the shape requirements (premortem-derived + ranked Assumptions with the riskiest marked; leading **and** lagging Success Metrics), the round structure / framing checkpoint / premortem / profile augmentations, and the terminal state. The `/ideate` command drives this skill; `/stridify` references it for the section gate. Readers usually do not activate it directly — the commands do.

## Custom Agents

Two custom agents are dispatched by the commands; they are not invoked directly from a user prompt.

- **requirements-reviewer** — Advisory pass over a draft requirements document. Reports gaps, contradictions, and ambiguous acceptance criteria; **never edits the doc**. Dispatched by `/ideate` after the seven sections have draft content and before the doc is committed.
- **requirements-decomposer** — Reads a committed requirements document end-to-end and emits a single fenced ```json batch document matching `POST /api/tasks/batch`. Dispatched by `/stridify` before the batch JSON is written and committed. Its only output is the fenced JSON — no prose.

Both agents live at `agents/<name>.md` and are auto-discovered by Gemini CLI.

## Workflow Sequence

```
/ideate [topic] [--profile <name>]
  → drives the question loop, gates on the seven required sections,
    dispatches requirements-reviewer, writes and commits the
    requirements doc
  → STOP — the committed doc is a valid terminal state

/stridify <path-to-requirements.md> [--goal <name|index>]
  → validates the seven sections, preflights .stride_auth.md,
    dispatches requirements-decomposer (with bounded retry on
    transient failures), stamps audit metadata, writes and commits
    the batch JSON, POSTs to /api/tasks/batch, renders the created
    G/W identifier table
```

## API Authorization

The `/stridify` command reads `.stride_auth.md` from the project root for `STRIDE_API_URL` and `STRIDE_API_TOKEN`. The user authorizes Stride API calls by initiating the workflow — **never prompt for permission before the POST**. **Never log the token, even in error paths.**

`.stride_auth.md` must be listed in `.gitignore`. The bundled `.gitignore` already excludes it.

## Tool Name Mapping

The skill and agent bodies reference Gemini CLI tool names directly. When porting prompts that originated on another platform (the upstream Claude Code plugin, or the Codex/Copilot ports), use these equivalents:

| Other-platform reference | Gemini Tool |
|--------------------------|-------------|
| `Read` | `read_file` |
| `Grep` | `grep_search` |
| `Glob` | `glob` |
| `Bash` | `run_shell_command` |
| `Edit` | `replace` |
| `Write` | `write_file` |
| `list directory` | `list_directory` |

Gemini CLI has no first-class "preview pane" question tool, so option comparisons are rendered inline (fenced ASCII blocks or short tables) rather than via a preview field.

## How this extension relates to `stride-gemini`

`stride-gemini` covers the **task lifecycle** (claiming, hook execution, completion). This extension covers **ideation** — turning a fuzzy idea into a requirements doc and seeding a Stride backlog from it. A typical full loop installs both: `/ideate` → `/stridify` with this extension, then claim and ship the resulting tasks with `stride-gemini`.
