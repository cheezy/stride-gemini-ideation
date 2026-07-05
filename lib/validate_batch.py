#!/usr/bin/env python3
"""Validate a Stride batch JSON document produced by /stridify.

Usage:
    python3 lib/validate_batch.py <path-to-stride-batch.json>

Exits 0 when the document passes the structural checks (advisory warnings, if
any, are printed to stderr but do NOT change the exit code).
Exits 1 on the first structural violation, printing a single line of the form:

    stride-ideation: <error message naming the failing JSON path>

The named FATAL error variants are exactly the five the task contract calls out:

  (a) parse_error           - input is not valid JSON
  (b) wrong_root_key        - root has 'tasks' or any key other than 'goals'
  (c) empty_goals           - 'goals' is missing, not an array, or empty
  (d) goal_missing_field    - a goal entry lacks title, type, or tasks
  (e) bad_dependency_index  - a task's dependencies[] index references an
                              array slot that does not exist OR points to a
                              task at or after the referencing task's own
                              position (forward reference)

In addition, once the structural checks pass, the validator emits NON-FATAL
advisory warnings to stderr while still exiting 0. Warnings never change the
exit code: /stridify Step 8a exits on a non-zero validator, so a fatal warning
would block an otherwise valid batch. Warning lines are prefixed
'stride-ideation: warning: '. Two advisory checks run:

  (1) scored_field_missing  - a task omits one of the five review-queue scored
                              fields (testing_strategy, security_considerations,
                              patterns_to_follow, pitfalls, acceptance_criteria);
                              such tasks score poorly in the review queue.
  (2) varchar_255_overflow  - a length-limited field exceeds Stride's 255
                              code-point varchar limit: the five scalar
                              varchar(255) fields (incl. title) or an element of
                              the varchar(255)[] array fields (incl.
                              security_considerations). Stride rejects these with
                              an HTTP 422 at POST time.

The validator does NOT enforce per-task Stride-API field shapes
(pitfalls-as-array-of-strings, verification_steps-as-objects, etc.). Those
are the decomposer agent's responsibility; /stridify surfaces the API's own
error if anything slips through.
"""

import json
import sys
from typing import Any


# The five per-task fields the Stride review queue scores. Decomposer output
# that omits any of them ships tasks that score poorly, so their absence is an
# advisory (non-fatal) warning rather than a structural error.
SCORED_FIELDS = (
    "testing_strategy",
    "security_considerations",
    "patterns_to_follow",
    "pitfalls",
    "acceptance_criteria",
)

VARCHAR_255_MAX = 255

# Free-text scalar columns stored as Postgres varchar(255) in Stride's task
# schema (Kanban.Tasks.Task @varchar_255_fields). Oversized values are rejected
# by the changeset with an HTTP 422, so warn before /stridify POSTs them.
VARCHAR_255_SCALAR_FIELDS = (
    "title",
    "estimated_files",
    "telemetry_event",
    "created_by_agent",
    "completed_by_agent",
)

# varchar(255)[] array columns whose ELEMENTS are each capped at 255 code points
# (Kanban.Tasks.Task @varchar_255_array_fields). Only string elements are
# length-bound; integer array-index dependencies are not strings and are skipped.
VARCHAR_255_ARRAY_FIELDS = (
    "security_considerations",
    "dependencies",
    "required_capabilities",
)


def fail(message: str) -> "None":
    sys.stderr.write(f"stride-ideation: {message}\n")
    sys.exit(1)


def warn(message: str) -> "None":
    # Advisory only — writes to stderr but never changes the exit code.
    sys.stderr.write(f"stride-ideation: warning: {message}\n")


def _codepoint_length(value: str) -> int:
    # Postgres varchar(n) bounds by Unicode code points, and Python's len() on a
    # str is a code-point count too (not bytes, not graphemes) — matching
    # Kanban.Tasks.Task.codepoint_length/1 exactly.
    return len(value)


def _scored_field_missing(task: "dict[str, Any]", field: str) -> bool:
    value = task.get(field)
    if field == "testing_strategy":
        return not (isinstance(value, dict) and len(value) > 0)
    if field in ("security_considerations", "pitfalls"):
        return not (isinstance(value, list) and len(value) > 0)
    # patterns_to_follow and acceptance_criteria are newline-separated strings.
    return not (isinstance(value, str) and value.strip() != "")


def _collect_length_warnings(
    where: str, obj: "dict[str, Any]", warnings: "list[str]"
) -> "None":
    for field in VARCHAR_255_SCALAR_FIELDS:
        value = obj.get(field)
        if isinstance(value, str) and _codepoint_length(value) > VARCHAR_255_MAX:
            warnings.append(
                f"{where}.{field} is {_codepoint_length(value)} code points, over "
                f"the 255 varchar limit — Stride will reject it with an HTTP 422"
            )
    for field in VARCHAR_255_ARRAY_FIELDS:
        value = obj.get(field)
        if not isinstance(value, list):
            continue
        for elem_pos, element in enumerate(value):
            if (
                isinstance(element, str)
                and _codepoint_length(element) > VARCHAR_255_MAX
            ):
                warnings.append(
                    f"{where}.{field}[{elem_pos}] is {_codepoint_length(element)} "
                    f"code points, over the 255 varchar limit — Stride will "
                    f"reject it with an HTTP 422"
                )


def validate(path: str) -> "None":
    try:
        with open(path, "r", encoding="utf-8") as fp:
            text = fp.read()
    except OSError as exc:
        fail(f"could not read {path}: {exc}")

    # (a) parse_error
    try:
        doc = json.loads(text)
    except json.JSONDecodeError as exc:
        fail(
            f"JSON parse failed at line {exc.lineno} col {exc.colno} "
            f"(char {exc.pos}): {exc.msg}"
        )

    if not isinstance(doc, dict):
        fail(
            f"top-level JSON value must be an object, got {type(doc).__name__}"
        )

    # (b) wrong_root_key
    if "goals" not in doc:
        if "tasks" in doc:
            fail(
                "root key 'tasks' is the most common batch-API mistake — "
                "Stride's POST /api/tasks/batch requires root key 'goals'. "
                "Rename 'tasks' to 'goals' at the JSON root and retry."
            )
        # Surface whatever non-'goals' key the agent picked instead.
        unexpected = [k for k in doc.keys() if k not in (
            "source_spec",
            "source_spec_sha256",
            "decomposition_notes",
        )]
        if unexpected:
            fail(
                f"root object is missing the required 'goals' array "
                f"(saw unexpected key(s): {sorted(unexpected)})"
            )
        fail("root object is missing the required 'goals' array")

    # (c) empty_goals
    goals = doc["goals"]
    if not isinstance(goals, list):
        fail(
            f"root.goals must be an array, got {type(goals).__name__}"
        )
    if len(goals) == 0:
        fail(
            "root.goals is an empty array — the decomposer returned no goals; "
            "check the requirements doc for under-specification"
        )

    # (d) goal_missing_field
    for goal_idx, goal in enumerate(goals):
        if not isinstance(goal, dict):
            fail(
                f"goals[{goal_idx}] must be an object, "
                f"got {type(goal).__name__}"
            )
        for required in ("title", "type", "tasks"):
            if required not in goal:
                fail(
                    f"goals[{goal_idx}] is missing required field '{required}'"
                )
        if not isinstance(goal["title"], str) or not goal["title"].strip():
            fail(f"goals[{goal_idx}].title must be a non-empty string")
        if goal["type"] != "goal":
            fail(
                f"goals[{goal_idx}].type must be 'goal', "
                f"got {goal['type']!r}"
            )
        if not isinstance(goal["tasks"], list):
            fail(
                f"goals[{goal_idx}].tasks must be an array, "
                f"got {type(goal['tasks']).__name__}"
            )
        if len(goal["tasks"]) == 0:
            fail(
                f"goals[{goal_idx}].tasks is empty — every goal must "
                f"own at least one task"
            )

        # (e) bad_dependency_index
        for task_idx, task in enumerate(goal["tasks"]):
            if not isinstance(task, dict):
                fail(
                    f"goals[{goal_idx}].tasks[{task_idx}] must be an object, "
                    f"got {type(task).__name__}"
                )
            deps = task.get("dependencies", [])
            if not isinstance(deps, list):
                fail(
                    f"goals[{goal_idx}].tasks[{task_idx}].dependencies must "
                    f"be an array, got {type(deps).__name__}"
                )
            for dep_pos, dep in enumerate(deps):
                # String identifiers (e.g. 'W47') reference pre-existing tasks
                # outside the batch — they are not validated here.
                if isinstance(dep, str):
                    continue
                if not isinstance(dep, int) or isinstance(dep, bool):
                    fail(
                        f"goals[{goal_idx}].tasks[{task_idx}]"
                        f".dependencies[{dep_pos}] must be a non-negative "
                        f"integer index or a string identifier, "
                        f"got {dep!r}"
                    )
                if dep < 0:
                    fail(
                        f"goals[{goal_idx}].tasks[{task_idx}]"
                        f".dependencies[{dep_pos}] = {dep} is negative"
                    )
                if dep >= len(goal["tasks"]):
                    fail(
                        f"goals[{goal_idx}].tasks[{task_idx}]"
                        f".dependencies references index {dep} but goal "
                        f"only has {len(goal['tasks'])} tasks "
                        f"(valid indices 0..{len(goal['tasks']) - 1})"
                    )
                if dep >= task_idx:
                    # Self-reference or forward reference — both are invalid;
                    # array-index dependencies must point to a task that
                    # appears EARLIER in the same goal's tasks array.
                    fail(
                        f"goals[{goal_idx}].tasks[{task_idx}]"
                        f".dependencies references index {dep} which is at "
                        f"or after the referencing task's own position "
                        f"{task_idx} — array-index dependencies must point "
                        f"to an earlier sibling"
                    )

    # All FATAL structural checks passed. Now emit non-fatal advisory warnings.
    #
    # These run only after the structural checks succeed (fail() would have
    # exited otherwise), so goals/tasks are known to be well-formed here. They
    # surface issues that otherwise appear late — as poor review-queue scores
    # (missing scored fields) or an HTTP 422 at POST time (a field overflowing
    # Stride's varchar(255) columns). They MUST NOT change the exit code:
    # /stridify Step 8a exits on a non-zero validator, so a fatal warning would
    # block an otherwise valid batch.
    warnings: "list[str]" = []
    for goal_idx, goal in enumerate(goals):
        _collect_length_warnings(f"goals[{goal_idx}]", goal, warnings)
        for task_idx, task in enumerate(goal["tasks"]):
            where = f"goals[{goal_idx}].tasks[{task_idx}]"
            title = task.get("title")
            label = f' ("{title}")' if isinstance(title, str) and title.strip() else ""
            for field in SCORED_FIELDS:
                if _scored_field_missing(task, field):
                    warnings.append(
                        f"{where}{label} is missing scored field '{field}' — the "
                        f"review queue scores this field; tasks that omit it "
                        f"score poorly"
                    )
            _collect_length_warnings(where, task, warnings)

    for message in warnings:
        warn(message)


def main(argv: "list[str]") -> "None":
    if len(argv) != 2:
        sys.stderr.write(
            "usage: validate_batch.py <path-to-stride-batch.json>\n"
        )
        sys.exit(2)
    validate(argv[1])


if __name__ == "__main__":
    main(sys.argv)
