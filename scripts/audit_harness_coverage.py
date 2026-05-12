#!/usr/bin/env python3
"""
audit_harness_coverage.py — Foundation stub for the harness-coverage meta-audit.

Scope: a subset of `docs/harness/components/skill-audit-harness-coverage/SPEC.md`.
Checks that every claimed harness component is implemented where it claims to be,
that every skill/agent/hook parses, and that no SPECs are orphaned.

Usage:
    python3 scripts/audit_harness_coverage.py --source {manual|cron}

Exit codes:
    --source manual: 1 on any BLOCKER, 0 otherwise.
    --source cron:   0 always.

Writes:
    .claude/audits/<YYYY-MM-DD>-harness-coverage.md  (suffix -N if same-day)

Stdlib only.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path
from typing import NamedTuple

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()
AUDIT_DIR = ROOT / ".claude" / "audits"
FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


class Finding(NamedTuple):
    severity: str
    check: str
    target: str
    message: str


def parse_frontmatter(text: str) -> dict[str, str] | None:
    m = FM_RE.match(text)
    if not m:
        return None
    out: dict[str, str] = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            out[k.strip()] = v.strip()
    return out


def check_skills() -> tuple[list[Finding], int]:
    """3.3 Skill discoverability: every .claude/skills/<x>/SKILL.md parses."""
    out: list[Finding] = []
    skills_dir = ROOT / ".claude" / "skills"
    if not skills_dir.is_dir():
        return [Finding("WARNING", "3.3", ".claude/skills/", "directory missing")], 0
    count = 0
    for d in sorted(skills_dir.iterdir()):
        if not d.is_dir():
            continue
        skill_md = d / "SKILL.md"
        if not skill_md.exists():
            out.append(Finding("BLOCKER", "3.3", f"{d.relative_to(ROOT)}/", "missing SKILL.md"))
            continue
        count += 1
        fm = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        if fm is None:
            out.append(Finding("BLOCKER", "3.3", str(skill_md.relative_to(ROOT)), "missing frontmatter"))
            continue
        if "name" not in fm:
            out.append(Finding("BLOCKER", "3.3", str(skill_md.relative_to(ROOT)), "frontmatter missing: name"))
        elif fm["name"] != d.name:
            out.append(Finding("BLOCKER", "3.3", str(skill_md.relative_to(ROOT)),
                               f"frontmatter name '{fm['name']}' does not match dir '{d.name}'"))
        if "description" not in fm:
            out.append(Finding("BLOCKER", "3.3", str(skill_md.relative_to(ROOT)), "frontmatter missing: description"))
    return out, count


def check_agents() -> tuple[list[Finding], int]:
    """3.4 Agent discoverability."""
    out: list[Finding] = []
    agents_dir = ROOT / ".claude" / "agents"
    if not agents_dir.is_dir():
        return [Finding("WARNING", "3.4", ".claude/agents/", "directory missing")], 0
    count = 0
    for f in sorted(agents_dir.glob("*.md")):
        count += 1
        fm = parse_frontmatter(f.read_text(encoding="utf-8"))
        if fm is None:
            out.append(Finding("BLOCKER", "3.4", str(f.relative_to(ROOT)), "missing frontmatter"))
            continue
        for key in ("name", "description", "model"):
            if key not in fm:
                out.append(Finding("BLOCKER", "3.4", str(f.relative_to(ROOT)), f"frontmatter missing: {key}"))
        if "name" in fm and fm["name"] != f.stem:
            out.append(Finding("BLOCKER", "3.4", str(f.relative_to(ROOT)),
                               f"frontmatter name '{fm['name']}' does not match file '{f.stem}'"))
    return out, count


def check_hooks() -> tuple[list[Finding], int]:
    """3.5 Hook discoverability: each .sh has a shebang, executable bit, and a header comment.

    - Shebang missing → BLOCKER (hooks without shebang silently fail when invoked).
    - Executable bit missing → BLOCKER (a hook that's not chmod +x can't be invoked).
    - Header comment block <40 chars of non-shebang `#` lines → WARNING (catches
      hooks with no rationale documentation).
    """
    out: list[Finding] = []
    hooks_dir = ROOT / ".claude" / "hooks"
    if not hooks_dir.is_dir():
        return [Finding("WARNING", "3.5", ".claude/hooks/", "directory missing")], 0
    count = 0
    for f in sorted(hooks_dir.glob("*.sh")):
        count += 1
        try:
            text = f.read_text(encoding="utf-8")
            lines = text.splitlines()
        except (OSError, UnicodeDecodeError):
            out.append(Finding("WARNING", "3.5", str(f.relative_to(ROOT)), "unreadable"))
            continue
        first = lines[0] if lines else ""
        if not first.startswith("#!"):
            out.append(Finding("BLOCKER", "3.5", str(f.relative_to(ROOT)), "missing shebang"))
        # Executable bit check (POSIX: owner-exec bit; mirrors `os.access(..., os.X_OK)`).
        try:
            mode = f.stat().st_mode
            if not (mode & 0o100):
                out.append(Finding("BLOCKER", "3.5", str(f.relative_to(ROOT)),
                                   "executable bit not set (chmod +x required)"))
        except OSError:
            out.append(Finding("WARNING", "3.5", str(f.relative_to(ROOT)), "stat failed"))
        # Header comment length: sum chars on `#`-prefixed lines after the shebang,
        # stopping at the first non-comment / non-blank line.
        header_chars = 0
        for line in lines[1:]:
            stripped = line.strip()
            if stripped.startswith("#"):
                header_chars += len(stripped)
            elif stripped == "":
                continue
            else:
                break
        if header_chars < 40:
            out.append(Finding("WARNING", "3.5", str(f.relative_to(ROOT)),
                               f"header comment too short ({header_chars} chars; expected >=40)"))
    return out, count


def check_settings_wiring() -> list[Finding]:
    """3.5b: every hook wired in settings.json exists on disk."""
    out: list[Finding] = []
    settings = ROOT / ".claude" / "settings.json"
    if not settings.exists():
        return [Finding("WARNING", "3.5b", ".claude/settings.json", "missing")]
    text = settings.read_text(encoding="utf-8")
    for m in re.finditer(r'"command":\s*"\$CLAUDE_PROJECT_DIR/\.claude/hooks/([^"]+)"', text):
        script = m.group(1)
        if not (ROOT / ".claude" / "hooks" / script).exists():
            out.append(Finding("BLOCKER", "3.5b", f".claude/hooks/{script}", "wired in settings.json but file missing"))
    return out


def check_referenced_but_missing() -> list[Finding]:
    """3.6 Reverse check: backtick-quoted references in docs to harness components
    that no longer exist on disk.

    Walks the names of actually-existing skills / agents / hooks, then scans
    documentation bodies (CLAUDE.md, README*.md, docs/harness/**, .claude/**/*.md,
    .claude/settings.json) for backtick-quoted occurrences of those names AND
    for backtick-quoted slash-prefixed names like `/audit-docs`. For each
    occurrence, verify the corresponding file still exists; BLOCKER on miss.

    The intent: catch dangling references after a deletion / rename.
    """
    out: list[Finding] = []
    skills_dir = ROOT / ".claude" / "skills"
    agents_dir = ROOT / ".claude" / "agents"
    hooks_dir = ROOT / ".claude" / "hooks"

    # Build the set of slash-skill names that ARE referenced (any name in the
    # docs preceded by `/`). We can't trust the disk-listing for this — we want
    # to flag references to names that USED to exist and were deleted, so we
    # scan the docs for `/<name>` patterns and check each against the disk.
    scan_files: list[Path] = []
    for rel in ("CLAUDE.md", "README.md", "README.ko.md", "SETUP.md", "TROUBLESHOOTING.md"):
        p = ROOT / rel
        if p.exists():
            scan_files.append(p)
    docs_harness = ROOT / "docs" / "harness"
    if docs_harness.is_dir():
        scan_files.extend(sorted(docs_harness.rglob("*.md")))
    claude_dir = ROOT / ".claude"
    if claude_dir.is_dir():
        # Skip audits/ — those are output, not input.
        for p in sorted(claude_dir.rglob("*.md")):
            if ".claude/audits" in str(p):
                continue
            scan_files.append(p)
    settings = ROOT / ".claude" / "settings.json"
    if settings.exists():
        scan_files.append(settings)

    # Regex for backtick-quoted slash-prefixed names: `/foo-bar`. We require the
    # closing backtick — illustrative forms like `/kill-cron`-style end with
    # `-style` AFTER the closing backtick and so already match the closed form.
    # To avoid flagging those, we also skip when the trailing context is `-style`
    # or `-shape` (illustrative usage in principles / PRDs).
    slash_re = re.compile(r"`/([a-z][a-z0-9-]+)`(-(?:style|shape))?")
    # Allowlist: Claude Code built-in slash commands that are NOT skills on disk.
    builtin_slashes = {"compact", "clear", "help", "config", "model", "init",
                       "review", "loop", "schedule", "exit", "quit", "logout",
                       "login", "pr_comments", "permissions", "memory",
                       "doctor", "status", "cost", "bug", "release-notes"}
    # Regex for backtick-quoted bare names: `foo-bar` (lowercase, hyphens)
    bare_re = re.compile(r"`([a-z][a-z0-9-]+)`")
    # Regex for backtick-quoted hook paths: `.claude/hooks/foo.sh` or `foo.sh`
    hook_path_re = re.compile(r"`\.claude/hooks/([a-z][a-z0-9_-]+\.sh)`")

    # Known existing names (so we only flag references to lowercase-hyphen identifiers
    # that LOOK LIKE harness component names — i.e., that match an actually-existing
    # skill or agent, or that USED to but no longer do).
    existing_skill_names: set[str] = set()
    if skills_dir.is_dir():
        existing_skill_names = {d.name for d in skills_dir.iterdir() if d.is_dir()}
    existing_agent_names: set[str] = set()
    if agents_dir.is_dir():
        existing_agent_names = {f.stem for f in agents_dir.glob("*.md")}
    existing_hook_files: set[str] = set()
    if hooks_dir.is_dir():
        existing_hook_files = {f.name for f in hooks_dir.glob("*.sh")}

    # Names of all currently-living components — we use these to seed pattern
    # detection. To catch DELETED components, we also fall back to "any name
    # backtick-quoted with a `/` prefix" since that's the slash-skill convention.
    # We classify each match by trying the most specific location first.

    # (target_path, target_kind, label) -> set of (file, lineno)
    missing: dict[tuple[str, str, str], list[tuple[str, int]]] = {}

    def add_miss(target_path: str, kind: str, label: str, file_rel: str, lineno: int) -> None:
        key = (target_path, kind, label)
        missing.setdefault(key, []).append((file_rel, lineno))

    for sf in scan_files:
        try:
            text = sf.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        rel = str(sf.relative_to(ROOT))
        for lineno, line in enumerate(text.splitlines(), start=1):
            # Slash-prefixed → expect skill dir.
            for m in slash_re.finditer(line):
                name = m.group(1)
                trailing = m.group(2) or ""
                # Heuristic skip: very short / obvious non-skills.
                if len(name) < 3:
                    continue
                # Skip illustrative usages like `/kill-cron`-style.
                if trailing:
                    continue
                # Skip Claude Code built-in slashes.
                if name in builtin_slashes:
                    continue
                expected = ROOT / ".claude" / "skills" / name / "SKILL.md"
                if not expected.exists():
                    # Only flag if some other doc considers this a skill — to avoid
                    # flagging things like `/usr/local` literal paths or arbitrary
                    # nicknames. The fix is conservative: skip if the name is also
                    # not in any other doc's quoted form. Simpler rule: only flag
                    # if the name pattern matches `<word>-<word>` or has length >= 6.
                    if "-" in name or len(name) >= 6:
                        add_miss(f".claude/skills/{name}/SKILL.md", "skill", f"/{name}", rel, lineno)
            # Hook path explicit reference → expect that hook on disk.
            for m in hook_path_re.finditer(line):
                hook_file = m.group(1)
                expected = ROOT / ".claude" / "hooks" / hook_file
                if not expected.exists():
                    add_miss(f".claude/hooks/{hook_file}", "hook", f".claude/hooks/{hook_file}", rel, lineno)
            # Bare-name backtick references. Match against known agent names ONLY
            # (since agent references typically appear as `code-reviewer` without
            # the slash prefix). For agents that USED to exist and were deleted,
            # we can't detect bare-name references purely deterministically —
            # operator must inspect. We instead detect references that look like
            # agents based on a documented set (in CLAUDE.md / README's reference
            # tables, agents appear inside `[<name>](./.claude/agents/<name>.md)`).
            # So additionally scan for the link-style reference pattern below.
            # First: bare backtick names that match a KNOWN-AGENT name pattern.
            for m in bare_re.finditer(line):
                name = m.group(1)
                # Only consider as an agent reference if a markdown-link to
                # .claude/agents/<name>.md appears anywhere in the same file, OR
                # the name matches an existing agent name (so a TYPO in the bare
                # form would be caught). We focus on detection of DELETION drift,
                # so check: does the doc reference a path like
                # `.claude/agents/<name>.md`, and is that file missing?
                # We handle that explicitly below; skip here.
                pass

            # Path-style references: `.claude/agents/<name>.md` (in backticks or as
            # markdown link targets). Catches deletion drift on agent files.
            for m in re.finditer(r"\.claude/agents/([a-z][a-z0-9_-]+)\.md", line):
                name = m.group(1)
                expected = ROOT / ".claude" / "agents" / f"{name}.md"
                if not expected.exists():
                    add_miss(f".claude/agents/{name}.md", "agent", name, rel, lineno)
            # Path-style references: `.claude/skills/<name>/SKILL.md`.
            for m in re.finditer(r"\.claude/skills/([a-z][a-z0-9_-]+)/SKILL\.md", line):
                name = m.group(1)
                expected = ROOT / ".claude" / "skills" / name / "SKILL.md"
                if not expected.exists():
                    add_miss(f".claude/skills/{name}/SKILL.md", "skill", name, rel, lineno)
            # Path-style references: `.claude/hooks/<name>.sh`.
            for m in re.finditer(r"\.claude/hooks/([a-z][a-z0-9_-]+\.sh)", line):
                hook_file = m.group(1)
                expected = ROOT / ".claude" / "hooks" / hook_file
                if not expected.exists():
                    add_miss(f".claude/hooks/{hook_file}", "hook", hook_file, rel, lineno)

    # Suppress noise: components ARE existing.
    # Emit one BLOCKER per (target, kind) — list the first referring source.
    for (target_path, kind, label), refs in sorted(missing.items()):
        first_ref = refs[0]
        n_refs = len(refs)
        suffix = f" (referenced from {first_ref[0]}:{first_ref[1]}"
        if n_refs > 1:
            suffix += f" and {n_refs - 1} other location(s)"
        suffix += ")"
        out.append(Finding("BLOCKER", "3.6", target_path,
                           f"{kind} '{label}' referenced but missing from disk{suffix}"))
    return out


def check_component_specs() -> tuple[list[Finding], int]:
    """3.1+3.2: every component dir under docs/harness/components/ has at least a SPEC.md."""
    out: list[Finding] = []
    comp_dir = ROOT / "docs" / "harness" / "components"
    if not comp_dir.is_dir():
        return [Finding("WARNING", "3.1", "docs/harness/components/", "directory missing")], 0
    count = 0
    for d in sorted(comp_dir.iterdir()):
        if not d.is_dir():
            continue
        count += 1
        spec = d / "SPEC.md"
        if not spec.exists():
            out.append(Finding("BLOCKER", "3.1", f"{d.relative_to(ROOT)}/", "missing SPEC.md"))
    return out, count


def render_audit(findings: list[Finding], counts: dict[str, int]) -> str:
    today = dt.date.today().isoformat()
    blockers = [f for f in findings if f.severity == "BLOCKER"]
    warnings = [f for f in findings if f.severity == "WARNING"]
    lines = [
        "---",
        "type: AUDIT",
        "status: accepted",
        "owner: harness-coverage-auditor",
        f"last-reviewed: {today}",
        "---",
        "",
        f"# Harness Coverage Audit — {today}",
        "",
        f"Scanned: **{counts['skills']}** skills, **{counts['agents']}** agents, "
        f"**{counts['hooks']}** hooks, **{counts['components']}** component SPECs. "
        f"Found **{len(blockers)}** BLOCKERS, **{len(warnings)}** WARNINGS.",
        "",
    ]
    for label, group in [("BLOCKERS", blockers), ("WARNINGS", warnings)]:
        if not group:
            continue
        lines += [f"## {label}", ""]
        for f in group:
            lines.append(f"- **[{f.check}]** `{f.target}` — {f.message}")
        lines.append("")
    return "\n".join(lines)


def audit_output_path(today: str) -> Path:
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    base = AUDIT_DIR / f"{today}-harness-coverage.md"
    if not base.exists():
        return base
    n = 1
    while True:
        cand = AUDIT_DIR / f"{today}-harness-coverage-{n}.md"
        if not cand.exists():
            return cand
        n += 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["manual", "cron"], required=True)
    args = ap.parse_args()

    today = dt.date.today().isoformat()
    findings: list[Finding] = []
    findings.extend(check_settings_wiring())
    spec_findings, n_components = check_component_specs()
    skill_findings, n_skills = check_skills()
    agent_findings, n_agents = check_agents()
    hook_findings, n_hooks = check_hooks()
    ref_findings = check_referenced_but_missing()
    findings.extend(spec_findings)
    findings.extend(skill_findings)
    findings.extend(agent_findings)
    findings.extend(hook_findings)
    findings.extend(ref_findings)

    counts = {"skills": n_skills, "agents": n_agents, "hooks": n_hooks, "components": n_components}
    out_path = audit_output_path(today)
    out_path.write_text(render_audit(findings, counts), encoding="utf-8")
    blockers = sum(1 for f in findings if f.severity == "BLOCKER")
    warnings = sum(1 for f in findings if f.severity == "WARNING")

    print(f"harness-coverage: {out_path.relative_to(ROOT)} — "
          f"{n_skills} skills, {n_agents} agents, {n_hooks} hooks, {n_components} SPECs scanned, "
          f"{blockers} blockers, {warnings} warnings")
    if args.source == "manual" and blockers > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
