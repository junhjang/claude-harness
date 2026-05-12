#!/usr/bin/env python3
"""
c1_docs_audit.py — Foundation stub for the docs auditor (cron-c1).

Scope: D1-D4 of the spec (`docs/harness/components/cron-c1-docs-audit/SPEC.md`).
The full SPEC defines D1-D11; this stub covers index reachability, frontmatter
conformance, dead links, and ADR id density. Extend in your consuming repo.

Usage:
    python3 scripts/cron/c1_docs_audit.py --source {manual|cron} [--force]

Exit codes:
    --source manual: 1 on any BLOCKER, 0 otherwise (CI gate).
    --source cron:   0 always (run record carries findings).

Writes:
    .claude/audits/<YYYY-MM-DD>-docs-audit.md   (suffix -N if same-day cached)
    var/<HARNESS_ENV>/cron-c1-runs.jsonl        (one record per tick)

Stdlib only. No external dependencies.
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
ENV = os.environ.get("HARNESS_ENV", "dev")
AUDIT_DIR = ROOT / ".claude" / "audits"
RUN_LOG = ROOT / "var" / ENV / "cron-c1-runs.jsonl"

DOC_ROOTS = ["docs", "CLAUDE.md", "README.md", ".claude"]
# Frontmatter (D2) is enforced ONLY on docs/ — agents/skills/rules use different schemas.
TYPED_DOC_PREFIXES = ("docs/",)
EXCLUDE_PREFIXES = (".claude/audits/",)  # don't audit our own output
VALID_STATUS = {"draft", "accepted", "superseded", "retired"}
VALID_TYPE = {"PRD", "RFC", "ADR", "SPEC", "TDD", "AUDIT", "POSTMORTEM", "README"}
# Navigation indexes — per doc-pattern.md §3 carve-out — are exempt from frontmatter.
NAV_EXEMPT_NAMES = {"README.md"}
NAV_EXEMPT_PATHS = {"CLAUDE.md", "docs/harness/principles.md", "docs/harness/architecture.md",
                    "docs/harness/doc-pattern.md", "docs/harness/behavior-verification.md"}
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


class Finding(NamedTuple):
    severity: str  # "BLOCKER" | "WARNING" | "INFO"
    rule: str
    file: str
    line: int
    message: str


def scan_files() -> list[Path]:
    files: list[Path] = []
    for root in DOC_ROOTS:
        p = ROOT / root
        if p.is_file() and p.suffix == ".md":
            files.append(p)
        elif p.is_dir():
            files.extend(sorted(p.rglob("*.md")))
    out: list[Path] = []
    for f in files:
        rel = str(f.relative_to(ROOT))
        if any(rel.startswith(pref) for pref in EXCLUDE_PREFIXES):
            continue
        out.append(f)
    return out


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


def is_typed_doc(path: Path) -> bool:
    """Frontmatter is enforced only on typed docs (docs/ subtree)."""
    rel = str(path.relative_to(ROOT))
    return any(rel.startswith(pref) for pref in TYPED_DOC_PREFIXES)


def is_nav_exempt(path: Path) -> bool:
    rel = str(path.relative_to(ROOT))
    if rel in NAV_EXEMPT_PATHS:
        return True
    if path.name in NAV_EXEMPT_NAMES:
        return True
    return False


def check_frontmatter(path: Path, text: str) -> list[Finding]:
    out: list[Finding] = []
    rel = str(path.relative_to(ROOT))
    if not is_typed_doc(path) or is_nav_exempt(path):
        return out
    fm = parse_frontmatter(text)
    if fm is None:
        return [Finding("BLOCKER", "D2", rel, 1, "missing frontmatter")]
    for key in ("type", "status", "last-reviewed"):
        if key not in fm:
            out.append(Finding("BLOCKER", "D2", rel, 1, f"frontmatter missing key: {key}"))
    if "status" in fm and fm["status"] not in VALID_STATUS:
        out.append(Finding("BLOCKER", "D2", rel, 1, f"invalid status: {fm['status']}"))
    if "type" in fm and fm["type"] not in VALID_TYPE:
        out.append(Finding("BLOCKER", "D2", rel, 1, f"invalid type: {fm['type']}"))
    if "last-reviewed" in fm:
        try:
            last = dt.date.fromisoformat(fm["last-reviewed"].strip("\"'"))
            age = (dt.date.today() - last).days
            if age > 180:
                out.append(Finding("WARNING", "D2", rel, 1, f"stale: last-reviewed {age}d ago"))
        except ValueError:
            out.append(Finding("WARNING", "D2", rel, 1, "unparseable last-reviewed"))
    return out


def strip_code_fences(text: str) -> str:
    """Blank out fenced code blocks so illustrative `[text](path)` patterns inside them are not parsed as links."""
    out_lines: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out_lines.append("")  # keep line numbering aligned
            continue
        out_lines.append("" if in_fence else line)
    return "\n".join(out_lines)


def check_dead_links(path: Path, text: str) -> list[Finding]:
    out: list[Finding] = []
    rel = str(path.relative_to(ROOT))
    text = strip_code_fences(text)
    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in LINK_RE.finditer(line):
            target = m.group(2).split("#")[0]  # strip anchor
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            if "<" in target or ">" in target:
                continue  # placeholder like `<x>`
            if not target.endswith((".md", ".sh", ".py", ".json", ".yaml", ".yml", ".toml")):
                continue
            resolved = (path.parent / target).resolve()
            try:
                resolved.relative_to(ROOT)
            except ValueError:
                continue  # outside repo, skip
            if not resolved.exists():
                out.append(Finding("BLOCKER", "D3", rel, lineno, f"dead link: {target}"))
    return out


def check_index_reachability(files: list[Path]) -> list[Finding]:
    """D1 stub: every docs/*.md is reachable transitively from CLAUDE.md."""
    out: list[Finding] = []
    claude_md = ROOT / "CLAUDE.md"
    if not claude_md.exists():
        return [Finding("WARNING", "D1", "CLAUDE.md", 0, "CLAUDE.md missing — skipping reachability check")]
    reachable: set[Path] = {claude_md}
    frontier = [claude_md]
    while frontier:
        cur = frontier.pop()
        try:
            text = cur.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for m in LINK_RE.finditer(text):
            target = m.group(2).split("#")[0]
            if not target or target.startswith(("http", "mailto")):
                continue
            resolved = (cur.parent / target).resolve()
            try:
                resolved.relative_to(ROOT)
            except ValueError:
                continue
            # Directory link → treat as a link to its README.md
            if resolved.is_dir():
                readme = resolved / "README.md"
                if readme.exists() and readme not in reachable:
                    reachable.add(readme)
                    frontier.append(readme)
                continue
            if not target.endswith(".md"):
                continue
            if resolved.exists() and resolved not in reachable:
                reachable.add(resolved)
                frontier.append(resolved)
    for f in files:
        if not str(f.relative_to(ROOT)).startswith("docs/"):
            continue
        if f not in reachable:
            out.append(Finding("BLOCKER", "D1", str(f.relative_to(ROOT)), 0, "orphan doc — not reachable from CLAUDE.md"))
    return out


def check_adr_density(files: list[Path]) -> list[Finding]:
    """D5 stub: ADR ids in docs/decisions/ should be dense (no gaps)."""
    out: list[Finding] = []
    decisions = ROOT / "docs" / "decisions"
    if not decisions.is_dir():
        return out  # no ADR subtree, skip
    ids: list[int] = []
    pat = re.compile(r"^\d{4}-\d{2}-\d{2}-(\d{3})-")
    for f in decisions.glob("*.md"):
        m = pat.match(f.name)
        if m:
            ids.append(int(m.group(1)))
    if not ids:
        return out
    ids.sort()
    expected = list(range(1, max(ids) + 1))
    missing = sorted(set(expected) - set(ids))
    for n in missing:
        out.append(Finding("WARNING", "D5", "docs/decisions/", 0, f"gap in ADR id sequence: {n:03d} missing"))
    return out


def render_audit(findings: list[Finding], scanned: int) -> str:
    today = dt.date.today().isoformat()
    blockers = [f for f in findings if f.severity == "BLOCKER"]
    warnings = [f for f in findings if f.severity == "WARNING"]
    infos = [f for f in findings if f.severity == "INFO"]
    lines = [
        "---",
        "type: AUDIT",
        "status: accepted",
        "owner: c1-docs-audit",
        f"last-reviewed: {today}",
        "---",
        "",
        f"# Docs Audit — {today}",
        "",
        f"Scanned **{scanned}** files. Found **{len(blockers)}** BLOCKERS, "
        f"**{len(warnings)}** WARNINGS, **{len(infos)}** INFOS.",
        "",
    ]
    for label, group in [("BLOCKERS", blockers), ("WARNINGS", warnings), ("INFOS", infos)]:
        if not group:
            continue
        lines += [f"## {label}", ""]
        for f in group:
            loc = f"{f.file}:{f.line}" if f.line else f.file
            lines.append(f"- **[{f.rule}]** `{loc}` — {f.message}")
        lines.append("")
    return "\n".join(lines)


def audit_output_path(today: str, force: bool) -> Path:
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    base = AUDIT_DIR / f"{today}-docs-audit.md"
    if not base.exists() or force:
        return base
    # find next -N suffix
    n = 1
    while True:
        cand = AUDIT_DIR / f"{today}-docs-audit-{n}.md"
        if not cand.exists():
            return cand
        n += 1


def write_run_record(record: dict) -> None:
    RUN_LOG.parent.mkdir(parents=True, exist_ok=True)
    with RUN_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["manual", "cron"], required=True)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    today = dt.date.today().isoformat()
    files = scan_files()

    # same-day idempotency
    cached = AUDIT_DIR / f"{today}-docs-audit.md"
    if cached.exists() and not args.force:
        newest_mtime = max((f.stat().st_mtime for f in files), default=0)
        if newest_mtime <= cached.stat().st_mtime:
            print(f"cached audit at {cached.relative_to(ROOT)} is current; skipping run")
            write_run_record({"date": today, "source": args.source, "status": "cached", "out": str(cached.relative_to(ROOT))})
            return 0

    findings: list[Finding] = []
    findings.extend(check_index_reachability(files))
    findings.extend(check_adr_density(files))
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            findings.append(Finding("WARNING", "D0", str(path.relative_to(ROOT)), 0, "unreadable file"))
            continue
        findings.extend(check_frontmatter(path, text))
        findings.extend(check_dead_links(path, text))

    out_path = audit_output_path(today, args.force)
    out_path.write_text(render_audit(findings, len(files)), encoding="utf-8")
    blockers = sum(1 for f in findings if f.severity == "BLOCKER")
    warnings = sum(1 for f in findings if f.severity == "WARNING")

    write_run_record({
        "date": today,
        "source": args.source,
        "status": "ran",
        "out": str(out_path.relative_to(ROOT)),
        "scanned": len(files),
        "blockers": blockers,
        "warnings": warnings,
    })

    print(f"audit: {out_path.relative_to(ROOT)} — {len(files)} scanned, {blockers} blockers, {warnings} warnings")
    if args.source == "manual" and blockers > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
