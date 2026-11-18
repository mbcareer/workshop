# One-iteration prompt for Galaxy Defender

Read `GAME_SPEC.md`, `PLAN.md`, `PROGRESS.md`, and `game/index.html`.
Do exactly one unfinished task from PLAN.md. Preserve all existing features.
Produce a complete updated `game/index.html` with inline HTML, CSS and JS.
Do not call external resources, install packages, or write code that sends data
anywhere. The harness will validate the candidate and mark the task done only
if its automated checks pass. Each iteration is a fresh LLM request that reads
state back from these files. Stop after a limited number of iterations.

This is a small, bounded teaching example of the Ralph pattern, not an
unrestricted autonomous coding agent.
