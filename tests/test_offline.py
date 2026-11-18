"""Offline tests; requires only Python stdlib. No Databricks credentials."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ralph", ROOT / "02_ralph_game.py")
# This module imports llm_client, which needs databricks-sdk. Install requirements
# before running these tests, or just run the game and skip tests.


class OfflineGameTests(unittest.TestCase):
    def test_starter_has_basics(self):
        html = (ROOT / "game" / "starter.html").read_text(encoding="utf-8")
        for required in ["<canvas", "requestAnimationFrame", "keydown", "restart", "score", "Space"]:
            self.assertIn(required, html)

    def test_plan_is_present(self):
        text = (ROOT / "PLAN.md").read_text(encoding="utf-8")
        self.assertIn("high score", text)
        self.assertIn("pause", text)


if __name__ == "__main__":
    unittest.main()
