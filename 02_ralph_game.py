"""Hands-on #2: a bounded, Ralph-style iterative game-building demo.

Each pass is a NEW Databricks LLM request. The model reads durable files,
performs ONE improvement, returns the full HTML, and exits. The harness checks
it and records progress on disk. It never executes model-generated commands.

This is a teaching example of Ralph's iterate/verify/persist pattern, NOT an
unrestricted coding agent or a drop-in replacement for Claude/Codex CLI loops.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent
GAME = ROOT / "game" / "index.html"
STARTER = ROOT / "game" / "starter.html"
PLAN = ROOT / "PLAN.md"
PROGRESS = ROOT / "PROGRESS.md"
SPEC = ROOT / "GAME_SPEC.md"
PROMPT = ROOT / "PROMPT.md"


def unfinished_task():
    for line in PLAN.read_text(encoding="utf-8").splitlines():
        if line.startswith("- [ ] "):
            return line[6:]
    return None


def normalize_html(text: str) -> str:
    text = text.strip()
    # Accept complete documents wrapped in markdown fences, as some models do.
    match = re.match(r"^```(?:html)?\s*([\s\S]*?)\s*```\s*$", text, flags=re.I)
    if match:
        text = match.group(1).strip()
    return text


def check_candidate(html: str, task: str):
    """Fast mechanical backpressure; people still need to play-test the game."""
    problems = []
    if len(html) < 2000 or len(html) > 85000:
        problems.append("Document size out of expected range")
    required = ["<!doctype html", "<html", "</html>", "<canvas", "<script", "</script>", "requestAnimationFrame", "keydown", 'id="game"']
    for marker in required:
        if marker.lower() not in html.lower():
            problems.append(f"Missing {marker}")
    for forbidden in [r"https?://", r"\bfetch\s*\(", r"XMLHttpRequest", r"<script[^>]*\bsrc\s*=", r"\beval\s*\(", r"\bimport\s*\("]:
        if re.search(forbidden, html, flags=re.I):
            problems.append(f"Unapproved external/dynamic behavior: {forbidden}")
    if "high score" in task.lower():
        if "localStorage" not in html or "high" not in html.lower():
            problems.append("High-score task appears incomplete")
    if "pause" in task.lower():
        if "pause" not in html.lower() or not ("KeyP" in html or '"p"' in html or "'p'" in html):
            problems.append("Pause/resume task appears incomplete")

    scripts = re.findall(r"<script(?:\s[^>]*)?>([\s\S]*?)</script>", html, flags=re.I)
    if not scripts:
        problems.append("No inline JavaScript found")
    elif shutil.which("node"):
        with tempfile.TemporaryDirectory() as tmp:
            filename = Path(tmp) / "game.js"
            filename.write_text("\n".join(scripts), encoding="utf-8")
            check = subprocess.run(["node", "--check", str(filename)], capture_output=True, text=True, timeout=10)
            if check.returncode != 0:
                problems.append("JavaScript syntax check failed: " + (check.stderr or "").strip()[:230])
    return problems


def mark_completed(task: str):
    content = PLAN.read_text(encoding="utf-8")
    old = "- [ ] " + task
    if old not in content:
        raise RuntimeError("Task changed unexpectedly; PLAN.md was not updated.")
    PLAN.write_text(content.replace(old, "- [x] " + task, 1), encoding="utf-8")


def log(message: str):
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    with PROGRESS.open("a", encoding="utf-8") as file:
        file.write(f"\n- {timestamp}: {message}\n")


def make_prompt(task: str):
    current_game = GAME.read_text(encoding="utf-8")
    return "\n\n".join([
        "You are a careful frontend coding assistant working in a bounded training loop.",
        "Each pass has fresh LLM context. Only the on-disk files below carry state.",
        "Perform EXACTLY ONE item: " + task,
        "Output ONLY the FULL replacement HTML document for game/index.html: no explanations and no markdown fences.",
        "Keep existing gameplay and appearance. No external libraries, external URLs, network requests, or secrets.",
        "Do not introduce new files. The browser must run it offline with HTML/CSS/JS only.",
        "Prompt guide:\n" + PROMPT.read_text(encoding="utf-8"),
        "Specification:\n" + SPEC.read_text(encoding="utf-8"),
        "Current plan:\n" + PLAN.read_text(encoding="utf-8"),
        "Previous feedback:\n" + PROGRESS.read_text(encoding="utf-8")[-2200:],
        "Existing game/index.html:\n" + current_game,
    ])


def run(max_iterations: int, dry_run: bool):
    task = unfinished_task()
    if task is None:
        print("All tasks complete. Run python 03_play_game.py to play the result.")
        return 0
    if dry_run:
        print("Dry run: no API calls or code changes.")
        print("Next task:", task)
        print("Game:", GAME)
        print("Remaining:", PLAN.read_text(encoding="utf-8"))
        return 0

    # Import the Databricks SDK helper only when making a real API call.
    # This keeps --dry-run and --reset useful without installed cloud dependencies.
    try:
        from llm_client import create_client_and_endpoint
        client, endpoint = create_client_and_endpoint()
    except Exception as exc:
        print(f"Setup error: {exc}")
        print("You can play the working starter: python 03_play_game.py")
        return 1

    print(f"Using approved Databricks endpoint: {endpoint}")
    print(f"At most {max_iterations} model requests. Existing game is preserved on failure.")
    for iteration in range(1, max_iterations+1):
        task = unfinished_task()
        if task is None:
            print("All improvement tasks completed.")
            return 0
        print(f"\nIteration {iteration}/{max_iterations}: {task}")
        try:
            response = client.chat.completions.create(
                model=endpoint,
                messages=[
                    {"role": "system", "content": "You output complete, standalone HTML for a tiny browser game. No explanations."},
                    {"role": "user", "content": make_prompt(task)},
                ],
                max_tokens=5000,
            )
            raw = response.choices[0].message.content or ""
            candidate = normalize_html(raw)
            errors = check_candidate(candidate, task)
            if errors:
                print("Rejected candidate:", "; ".join(errors))
                log(f"Pass {iteration} rejected for '{task}': {'; '.join(errors)}")
                continue
            GAME.write_text(candidate + "\n", encoding="utf-8")
            mark_completed(task)
            log(f"Pass {iteration} accepted: {task}")
            print("PASS. New game saved at game/index.html")
        except Exception as exc:
            print(f"API/validation error: {type(exc).__name__}: {exc}")
            log(f"Pass {iteration} failed with {type(exc).__name__}: {str(exc)[:200]}")
            print("Your previously working game has not been overwritten.")
            return 1
    if unfinished_task():
        print("\nIteration limit reached. This is intentional; review PLAN.md and rerun if approved.")
    else:
        print("\nAll tasks complete. Congrats!")
    print("Play and manually test: python 03_play_game.py")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Bounded, Ralph-style game improver")
    parser.add_argument("--max-iterations", type=int, default=2, help="Number of billable model calls (1-3)")
    parser.add_argument("--dry-run", action="store_true", help="Preview next task; do not call model")
    parser.add_argument("--reset", action="store_true", help="Restore starter, plan and progress; no model calls")
    args = parser.parse_args()
    if args.reset:
        GAME.write_text(STARTER.read_text(encoding="utf-8"), encoding="utf-8")
        PLAN.write_text("# Current plan (files carry state between iterations)\n\n- [ ] Add a visible, persistent localStorage high score.\n- [ ] Add P-key pause/resume and a PAUSED overlay.\n", encoding="utf-8")
        PROGRESS.write_text("# Ralph-style progress log\n\nNo model passes have been run. The starter game is already playable.\n", encoding="utf-8")
        print("Starter restored. Run --dry-run to see the next task.")
    else:
        if not 1 <= args.max_iterations <= 3:
            parser.error("Use an iteration limit between 1 and 3 for this workshop.")
        raise SystemExit(run(args.max_iterations, args.dry_run))
