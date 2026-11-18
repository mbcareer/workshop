# From VS Code to Databricks LLMs to a tiny arcade game

A 30-minute hands-on demo with a separate 30-minute Q&A. The two wins are:
1. Run a local Python call to an approved Databricks chat serving endpoint.
2. Use a **small, bounded Ralph-style loop** to improve a playable browser game.

**Important distinction:** A genuine Ralph coding-agent workflow restarts an agent
with fresh context and persists progress in code, plan files, and tests. This
training's `02_ralph_game.py` demonstrates the same iterative pattern using
fresh requests to a Databricks LLM and a controlled replacement of ONE HTML
file. It is not a full autonomous agent and does not execute model-supplied
shell commands or install software.

**Fastest Windows setup:** From the **repository root** (one level above
this folder), run `.\setup.ps1` in PowerShell. It uses `uv` to install Python
and dependencies, creates local `.env` if absent, runs offline tests, and
optionally guides you through approved Databricks sign-in. You do not need
`python`, `py`, or `node` installed on PATH. The manual steps below are a fallback.

**Using the public GitHub repository?** Clone it or choose **Code > Download ZIP**
on the repository page, then open the `workshop/` directory in VS Code.
The PowerPoint is in the sibling `slides/` directory.

## Before the session (organizer checklist)

- [ ] Confirm attendees have VS Code and an approved way to use **uv** (which downloads Python 3.12) or an existing Python 3.10+, plus package access.
- [ ] Confirm the Databricks CLI is installed (`databricks -v`).
- [ ] Provide the approved Databricks workspace URL and an **accessible chat-completions-compatible serving endpoint name**. Do not distribute a token.
- [ ] Confirm each attendee has `CAN QUERY` access to the endpoint and that it accepts chat-completions messages. A workspace login alone does not grant endpoint permission.
- [ ] Confirm the organization's preferred authentication path. The demo uses the Databricks CLI's OAuth U2M profile, not hardcoded PATs.
- [ ] Test both scripts once with the exact permitted endpoint, network policy, and model token limits. The game generator is a larger model call than the first demo.
- [ ] Verify a coding model capable of returning complete HTML is available and permitted for this experiment.
- [ ] If endpoints are unavailable, use the offline game (`uv run 03_play_game.py` or `python 03_play_game.py`), demo the code, and explain expected output.

## Hands-on setup (complete before the session, if possible)

If `.\setup.ps1` already completed successfully, skip these manual setup steps. Otherwise, open a terminal in this folder (`workshop/`). **If you have `uv` but no `python`, `py`, or `node` command, use Option A below**. On Windows, PowerShell is fine. If using regular Python, `py` can replace `python` where appropriate.

1. Install/verify the official Databricks CLI. See https://docs.databricks.com/aws/en/dev-tools/cli/install
2. Sign in with an approved user-to-machine OAuth flow:

   ```shell
   databricks auth login --host https://YOUR-WORKSPACE-HOST
   databricks auth profiles
   ```

3. Choose **one** way to create the local environment:

   **Option A (recommended on managed Windows laptops): `uv`**, which installs
   Python and dependencies without requiring a separate `python` command:

   ```powershell
   uv --version
   uv python install 3.12
   uv venv --python 3.12
   uv pip install -r requirements.txt
   ```

   `uv run` below uses the resulting `.venv` automatically; activation is not
   required. See the [full `uv` guide](../docs/UV_SETUP.md) for Windows setup,
   corporate network restrictions, and all exercise commands.

   **Option B: existing Python installation:**

   ```shell
   python -m venv .venv
   # Windows PowerShell: .venv\Scripts\Activate.ps1
   # macOS/Linux: source .venv/bin/activate
   python -m pip install -r requirements.txt
   ```

4. Copy `.env.example` to `.env`. Set `DATABRICKS_ENDPOINT` to the approved
   **endpoint name** (not a URL). If you have multiple auth profiles, add
   `DATABRICKS_CONFIG_PROFILE=YOUR_PROFILE_NAME`.
   `.env` contains no secrets and is git-ignored. The Databricks CLI manages
   OAuth credentials on your device.

## Exercise 1: First model call (5 minutes)

With `uv`:

```powershell
uv run 01_llm_call.py
```

With an activated regular Python environment, `python 01_llm_call.py` also works.

Expected: 3 proposed names for a tiny arcade shooter.
Modify `question` in `01_llm_call.py` and run it a second time.
The code is local Python; Databricks hosts the chat-serving endpoint.

## Exercise 2: A bounded Ralph-style loop (5-7 minutes)

Before calling a model, play the already functional starter game:

```powershell
uv run 03_play_game.py
```

Open the displayed URL if your browser doesn't launch automatically. Use arrows/A/D
for movement and Space to shoot. Ctrl+C ends the local server.

In another terminal, preview the next planned improvement:

```powershell
uv run 02_ralph_game.py --dry-run
```

Then run at most **2** model iterations:

```powershell
uv run 02_ralph_game.py --max-iterations 2
```

Open/reload the browser game. Inspect `PLAN.md`, `PROGRESS.md`, and
`game/index.html`. The same endpoint is used, but each iteration receives
fresh context assembled from files. A passing check marks one task complete.

**Without Node.js:** The game and model loop still run, but JavaScript syntax preflight is skipped. Manually inspect browser console/errors and play-test generated HTML.

**Model output is untrusted:** the harness performs basic structural and
JavaScript syntax checks (when Node.js is available). It blocks common network
and dynamic-code patterns but does *not* prove the game is safe or functional.
Review generated HTML before opening it; manually test controls, scoring,
high score, pause, and restart. Never run arbitrary generated shell commands.

**No access or generation failure?** The starter still works. Play it and
choose one small change to make manually (e.g. increase ship speed from `330`
to `440`, then refresh). That still demonstrates a feedback-driven development
loop without requiring an endpoint.

Reset between demos:

```powershell
uv run 02_ralph_game.py --reset
```

## Troubleshooting

| Symptom | First check |
|---|---|
| `DATABRICKS_ENDPOINT` missing | Copy `.env.example` to `.env` and replace placeholder |
| No credentials / auth error | `databricks auth profiles`; sign in using approved OAuth flow |
| 403 / permission denied | Ask the endpoint owner for `CAN QUERY` permission |
| 404 / model not found | Verify endpoint name and workspace/profile combination |
| 429 / rate limit | Stop repeated calls; ask the host about permitted usage limits |
| Context / output token limit | Use a model/endpoint that supports code output; reduce game scope |
| Browser game won't open | Run `uv run 03_play_game.py` (or `python 03_play_game.py`) from `workshop/`; use `http://127.0.0.1:8765/index.html` |
| Candidate rejected | Inspect `PROGRESS.md`; original game was preserved |
| Node.js is absent | JavaScript syntax preflight is skipped; inspect and play-test generated HTML in the browser |

## Useful reading

- Databricks unified authentication: https://docs.databricks.com/aws/en/dev-tools/auth/unified-auth
- Databricks CLI OAuth login: https://docs.databricks.com/aws/en/dev-tools/auth/oauth-u2m
- Databricks VS Code extension: https://docs.databricks.com/aws/en/dev-tools/vscode-ext/
- Query a chat model: https://docs.databricks.com/aws/en/machine-learning/model-serving/query-chat-models
- Geoffrey Huntley's Ralph technique: https://ghuntley.com/ralph/
- Ralph loop walkthrough: https://github.com/ghuntley/how-to-ralph-wiggum
