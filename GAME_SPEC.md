# Galaxy Defender: small game, small improvements

The starter is a working, local, one-file HTML/CSS/JavaScript arcade shooter.
The player moves left/right, fires with Space, earns points, loses lives,
and can restart. It needs no network calls or external JavaScript libraries.

## Acceptance criteria for every iteration

- Preserve the existing playable game and controls.
- Keep everything in `game/index.html`. Do not add dependencies or network requests.
- Work on exactly ONE incomplete task listed in PLAN.md per iteration.
- Update only `game/index.html` and the relevant task status (the harness updates PLAN.md).
- Be robust if the player presses several keys or restarts mid-game.
- Keep all browser code independent from credentials and Databricks configuration.

## Improvement tasks

1. **High score**: Add a visible high-score display near the current score. Persist it using browser localStorage. Initialize safely even if storage is unavailable.
2. **Pause/resume**: Press `P` to pause/resume the game. While paused, gameplay stops and a clear PAUSED overlay appears. The restart button still works.

## How to verify manually

- Run `python 03_play_game.py` and open the local URL.
- Move with arrow keys or A/D; fire with Space.
- Shoot invaders and confirm score increments; lose and restart.
- If high score is implemented: score points, restart or refresh, and confirm the high score persists.
- If pause is implemented: press P, confirm gameplay freezes, then press P again.
