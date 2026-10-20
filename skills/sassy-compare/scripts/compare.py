#!/usr/bin/env python3
"""Run one prompt against two models in isolated git worktrees and compare."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from difflib import unified_diff
from pathlib import Path

REPORT_DIFF_LINES = 400
REPORT_DIFF_CHARS = 60_000


def git(args: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=cwd, text=True, capture_output=True, check=check)


def git_text(args: list[str], cwd: Path) -> str:
    return git(args, cwd).stdout.strip()


def truncate(text: str, lines: int = REPORT_DIFF_LINES, chars: int = REPORT_DIFF_CHARS) -> str:
    if not text:
        return ""
    out: list[str] = []
    used = 0
    for line in text.splitlines():
        if len(out) >= lines or used + len(line) + 1 > chars:
            out.append("\n[... truncated; see the full artifact file ...]")
            break
        out.append(line)
        used += len(line) + 1
    return "\n".join(out)


def fmt_ms(ms: int) -> str:
    if ms < 60_000:
        return f"{ms / 1000:.1f}s"
    return f"{ms / 60_000:.1f}m"


def parse_events(path: Path) -> dict:
    out = {
        "turns": 0,
        "model_ms": 0,
        "tool_ms": 0,
        "errors": 0,
        "retries": 0,
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_read_tokens": 0,
        "cache_write_tokens": 0,
        "reasoning_tokens": 0,
        "cost": 0.0,
        "aborted": False,
        "stop_reason": None,
        "actual_model": None,
        "output_text": "",
    }
    last_text = ""
    saw_tool_execution_end = False
    tool_result_ms = 0
    tool_execution_ms = 0

    if not path.exists():
        return out

    for line in path.read_text(errors="replace").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = event.get("type")

        if kind == "message_end":
            message = event.get("message") or {}
            role = message.get("role")
            if role == "assistant":
                out["turns"] += 1
                out["model_ms"] += int(message.get("durationMs") or 0)
                usage = message.get("usage") or {}
                out["input_tokens"] += int(usage.get("input") or 0)
                out["output_tokens"] += int(usage.get("output") or 0)
                out["cache_read_tokens"] += int(usage.get("cacheRead") or 0)
                out["cache_write_tokens"] += int(usage.get("cacheWrite") or 0)
                out["reasoning_tokens"] += int(usage.get("reasoning") or 0)
                cost = usage.get("cost")
                if isinstance(cost, dict):
                    out["cost"] += float(cost.get("total") or 0)
                elif isinstance(cost, (int, float)):
                    out["cost"] += float(cost)
                if message.get("stopReason") == "error" or message.get("errorMessage"):
                    out["errors"] += 1
                if message.get("stopReason"):
                    out["stop_reason"] = message.get("stopReason")
                if message.get("model"):
                    out["actual_model"] = f"{message.get('provider', '')}/{message.get('model')}".strip("/")
                text = "".join(
                    part.get("text", "")
                    for part in message.get("content", [])
                    if isinstance(part, dict) and part.get("type") == "text"
                )
                if text:
                    last_text = text
            elif role == "toolResult":
                tool_result_ms += int(message.get("durationMs") or 0)

        elif kind == "tool_execution_end":
            saw_tool_execution_end = True
            tool_execution_ms += int(event.get("durationMs") or 0)
        elif kind == "auto_retry_start":
            out["retries"] += 1
        elif kind == "agent_settled":
            out["aborted"] = bool(event.get("aborted"))
        elif kind == "agent_end" and not last_text:
            for message in reversed(event.get("messages") or []):
                if message.get("role") == "assistant":
                    text = "".join(
                        part.get("text", "")
                        for part in message.get("content", [])
                        if isinstance(part, dict) and part.get("type") == "text"
                    )
                    if text:
                        last_text = text
                        break

    out["tool_ms"] = tool_execution_ms if saw_tool_execution_end else tool_result_ms
    out["output_text"] = last_text
    return out


def run_model(
    label: str,
    model: str,
    thinking: str | None,
    worktree: Path,
    out_dir: Path,
    prompt: str,
    args,
) -> dict:
    events_path = out_dir / "events.jsonl"
    stderr_path = out_dir / "stderr.txt"
    cmd = [args.pi_bin, "--mode", "json", "--no-session"]
    if thinking:
        cmd += ["--thinking", thinking]
    cmd += ["--model", model, "--", prompt]

    started = time.time()
    timed_out = False
    exit_code = -1
    with events_path.open("w") as events_file, stderr_path.open("w") as stderr_file:
        proc = subprocess.Popen(
            cmd,
            cwd=worktree,
            stdout=events_file,
            stderr=stderr_file,
            text=True,
            start_new_session=True,
        )
        try:
            exit_code = proc.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait()
            exit_code = proc.returncode if proc.returncode is not None else -1

    wall_ms = int((time.time() - started) * 1000)
    summary = parse_events(events_path)
    total_cost = summary.pop("cost")
    output_text = summary.pop("output_text")
    (out_dir / "output.txt").write_text(output_text + "\n")

    # Capture committed and uncommitted changes together. `-N` makes untracked
    # files visible to `git diff` without staging their contents.
    git(["add", "-A", "-N"], cwd=worktree, check=False)
    changes = git(["diff", "--binary", args.base_sha], cwd=worktree, check=False).stdout
    (out_dir / "changes.diff").write_text(changes)
    (out_dir / "changes.stat").write_text(
        git(["diff", "--stat", args.base_sha], cwd=worktree, check=False).stdout
    )
    (out_dir / "files.txt").write_text(
        git(["diff", "--name-status", args.base_sha], cwd=worktree, check=False).stdout
    )
    (out_dir / "status.txt").write_text(
        git(["status", "--porcelain"], cwd=worktree, check=False).stdout
    )
    (out_dir / "commits.txt").write_text(
        git(["log", "--oneline", f"{args.base_sha}..HEAD"], cwd=worktree, check=False).stdout
    )

    stderr_text = stderr_path.read_text(errors="replace") if stderr_path.exists() else ""
    summary.update(
        {
            "label": label,
            "requested_model": model,
            "thinking": thinking,
            "wall_ms": wall_ms,
            "exit_code": exit_code,
            "timed_out": timed_out,
            "cost": total_cost,
            "stderr_tail": stderr_text[-4000:],
        }
    )
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def write_report(
    run_root: Path,
    model_a: str,
    model_b: str,
    thinking_a: str | None,
    thinking_b: str | None,
    prompt: str,
    base: str,
    worktree_a: Path,
    worktree_b: Path,
    summary_a: dict,
    summary_b: dict,
    dry_run: bool,
) -> Path:
    lines: list[str] = []
    lines.append("# sassy-compare report")
    lines.append("")
    lines.append(f"- Base: `{base}`")
    lines.append(f"- model-a: `{model_a}` (thinking: `{thinking_a or 'model default'}`)")
    lines.append(f"- model-b: `{model_b}` (thinking: `{thinking_b or 'model default'}`)")
    lines.append(f"- Prompt: {prompt.strip()[:2000]}")
    lines.append("")

    if dry_run:
        lines.append("Dry run only: no model was invoked.")
        lines.append("")

    header = ["Metric", f"model-a ({model_a})", f"model-b ({model_b})"]
    rows = [
        ("Thinking level", thinking_a or "model default", thinking_b or "model default"),
        ("Wall time", fmt_ms(summary_a.get("wall_ms", 0)), fmt_ms(summary_b.get("wall_ms", 0))),
        ("Exit code", str(summary_a.get("exit_code")), str(summary_b.get("exit_code"))),
        ("Timed out", "yes" if summary_a.get("timed_out") else "no", "yes" if summary_b.get("timed_out") else "no"),
        ("Turns", str(summary_a.get("turns", 0)), str(summary_b.get("turns", 0))),
        ("Model time", fmt_ms(summary_a.get("model_ms", 0)), fmt_ms(summary_b.get("model_ms", 0))),
        ("Tool time", fmt_ms(summary_a.get("tool_ms", 0)), fmt_ms(summary_b.get("tool_ms", 0))),
        ("Output tokens", str(summary_a.get("output_tokens", 0)), str(summary_b.get("output_tokens", 0))),
        ("Cost", f"${summary_a.get('cost', 0):.4f}", f"${summary_b.get('cost', 0):.4f}"),
        ("Error turns", str(summary_a.get("errors", 0)), str(summary_b.get("errors", 0))),
        ("Retries", str(summary_a.get("retries", 0)), str(summary_b.get("retries", 0))),
        ("Aborted", "yes" if summary_a.get("aborted") else "no", "yes" if summary_b.get("aborted") else "no"),
    ]
    lines.append("## Summary")
    lines.append("")
    lines.append("| " + " | ".join(header) + " |")
    lines.append("|" + "|".join(["---"] * len(header)) + "|")
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")

    for label, summary in (("model-a", summary_a), ("model-b", summary_b)):
        lines.append(f"### {label} files")
        lines.append("")
        files = (run_root / "artifacts" / label / "files.txt").read_text(errors="replace").strip()
        lines.append("```text")
        lines.append(files or "(no file changes)")
        lines.append("```")
        if summary.get("stderr_tail", "").strip():
            lines.append("")
            lines.append(f"### {label} stderr tail")
            lines.append("")
            lines.append("```text")
            lines.append(truncate(summary["stderr_tail"], lines=80, chars=8000))
            lines.append("```")
        lines.append("")

    output_a = (run_root / "artifacts" / "model-a" / "output.txt").read_text(errors="replace")
    output_b = (run_root / "artifacts" / "model-b" / "output.txt").read_text(errors="replace")
    output_diff = "".join(
        unified_diff(
            output_a.splitlines(keepends=True),
            output_b.splitlines(keepends=True),
            fromfile="model-a/output.txt",
            tofile="model-b/output.txt",
        )
    )
    (run_root / "output.diff").write_text(output_diff)
    lines.append("## Final output diff")
    lines.append("")
    if output_diff:
        lines.append("```diff")
        lines.append(truncate(output_diff))
        lines.append("```")
    else:
        lines.append("No difference in final assistant text.")
    lines.append("")

    code_diff = subprocess.run(
        ["diff", "-ruN", "--exclude=.git", str(worktree_a), str(worktree_b)],
        text=True,
        capture_output=True,
        check=False,
    )
    (run_root / "code.diff").write_text(code_diff.stdout)
    lines.append("## Code diff")
    lines.append("")
    if code_diff.stdout.strip():
        lines.append("```diff")
        lines.append(truncate(code_diff.stdout))
        lines.append("```")
    elif code_diff.returncode == 0:
        lines.append("No difference between the two worktrees.")
    else:
        lines.append("Could not compute the worktree diff; see the artifacts.")
    lines.append("")

    lines.append("## Artifacts")
    lines.append("")
    lines.append(f"- Run directory: `{run_root}`")
    lines.append(f"- model-a output: `{run_root / 'artifacts' / 'model-a' / 'output.txt'}`")
    lines.append(f"- model-a changes: `{run_root / 'artifacts' / 'model-a' / 'changes.diff'}`")
    lines.append(f"- model-b output: `{run_root / 'artifacts' / 'model-b' / 'output.txt'}`")
    lines.append(f"- model-b changes: `{run_root / 'artifacts' / 'model-b' / 'changes.diff'}`")
    lines.append(f"- Full output diff: `{run_root / 'output.diff'}`")
    lines.append(f"- Full code diff: `{run_root / 'code.diff'}`")
    lines.append("")

    report_path = run_root / "report.md"
    report_path.write_text("\n".join(lines) + "\n")
    return report_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two models on the same prompt in isolated worktrees.")
    parser.add_argument("--model-a", required=True, help="Model for the first worktree.")
    parser.add_argument("--model-b", required=True, help="Model for the second worktree.")
    parser.add_argument(
        "--thinking-a",
        choices=["off", "minimal", "low", "medium", "high", "xhigh", "max"],
        help="Thinking level for model-a. Overrides a :level suffix on the model name.",
    )
    parser.add_argument(
        "--thinking-b",
        choices=["off", "minimal", "low", "medium", "high", "xhigh", "max"],
        help="Thinking level for model-b. Overrides a :level suffix on the model name.",
    )
    parser.add_argument("--prompt", help="Prompt to run in both worktrees.")
    parser.add_argument("--prompt-file", help="Read the prompt from this file instead.")
    parser.add_argument("--base", default="HEAD", help="Git ref to branch both worktrees from (default: HEAD).")
    parser.add_argument("--timeout", type=int, default=1800, help="Per-model timeout in seconds (default: 1800).")
    parser.add_argument("--keep", action="store_true", help="Keep the worktrees after the run.")
    parser.add_argument("--dry-run", action="store_true", help="Create/tear down worktrees without invoking pi.")
    parser.add_argument("--pi-bin", default=os.environ.get("PI_BIN", "pi"), help="pi executable (default: pi).")
    args = parser.parse_args()

    if args.prompt_file:
        args.prompt = Path(args.prompt_file).read_text()
    if not args.prompt or not args.prompt.strip():
        parser.error("provide --prompt or --prompt-file")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    pi_bin = shutil.which(args.pi_bin) or (args.pi_bin if Path(args.pi_bin).exists() else None)
    if not pi_bin:
        print(f"error: pi executable not found: {args.pi_bin}", file=sys.stderr)
        return 2
    args.pi_bin = pi_bin

    try:
        repo_root = Path(git_text(["rev-parse", "--show-toplevel"], Path.cwd()))
    except subprocess.CalledProcessError:
        print("error: run sassy-compare from inside a git repository", file=sys.stderr)
        return 2

    try:
        args.base_sha = git_text(["rev-parse", "--verify", f"{args.base}^{{commit}}"], repo_root)
    except subprocess.CalledProcessError:
        print(f"error: base ref not found: {args.base}", file=sys.stderr)
        return 2

    dirty = git_text(["status", "--porcelain"], repo_root)
    if dirty:
        print(
            "warning: the repository has uncommitted changes; both worktrees use "
            f"{args.base} and will not include them",
            file=sys.stderr,
        )

    run_id = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + f"-{os.getpid()}"
    compare_root = Path(os.environ.get("SASSY_COMPARE_DIR", Path.home() / ".pi" / "compare"))
    run_root = compare_root / run_id
    worktrees = run_root / "worktrees"
    artifacts = run_root / "artifacts"
    worktree_a = worktrees / "model-a"
    worktree_b = worktrees / "model-b"

    created: list[Path] = []
    try:
        for label in ("model-a", "model-b"):
            out_dir = artifacts / label
            out_dir.mkdir(parents=True, exist_ok=True)
        worktrees.mkdir(parents=True, exist_ok=True)

        for worktree in (worktree_a, worktree_b):
            result = git(["worktree", "add", "--detach", str(worktree), args.base_sha], cwd=repo_root, check=False)
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or f"git worktree add failed for {worktree}")
            created.append(worktree)

        if args.dry_run:
            summary_a = {"wall_ms": 0, "exit_code": 0, "timed_out": False, "turns": 0, "model_ms": 0,
                         "tool_ms": 0, "output_tokens": 0, "cost": 0.0, "errors": 0, "retries": 0,
                         "aborted": False, "stderr_tail": "", "thinking": args.thinking_a}
            summary_b = {**summary_a, "thinking": args.thinking_b}
            (artifacts / "model-a" / "output.txt").write_text("")
            (artifacts / "model-b" / "output.txt").write_text("")
            (artifacts / "model-a" / "files.txt").write_text("")
            (artifacts / "model-b" / "files.txt").write_text("")
        else:
            summary_a = run_model(
                "model-a", args.model_a, args.thinking_a, worktree_a, artifacts / "model-a", args.prompt, args
            )
            summary_b = run_model(
                "model-b", args.model_b, args.thinking_b, worktree_b, artifacts / "model-b", args.prompt, args
            )

        report = write_report(
            run_root,
            args.model_a,
            args.model_b,
            args.thinking_a,
            args.thinking_b,
            args.prompt,
            args.base,
            worktree_a,
            worktree_b,
            summary_a,
            summary_b,
            args.dry_run,
        )

        if args.dry_run:
            print("dry run complete; no models invoked")
        else:
            print(
                f"model-a {args.model_a}: {fmt_ms(summary_a['wall_ms'])}, "
                f"{summary_a['turns']} turns, {summary_a['errors']} error turns"
            )
            print(
                f"model-b {args.model_b}: {fmt_ms(summary_b['wall_ms'])}, "
                f"{summary_b['turns']} turns, {summary_b['errors']} error turns"
            )
        print(f"report: {report}")
        if args.keep:
            print(f"worktrees kept: {worktree_a} {worktree_b}")
        return 0
    finally:
        if not args.keep:
            for worktree in created:
                git(["worktree", "remove", "--force", str(worktree)], cwd=repo_root, check=False)
            git(["worktree", "prune"], cwd=repo_root, check=False)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        raise SystemExit(130)
