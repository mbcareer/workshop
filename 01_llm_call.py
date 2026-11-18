"""Hands-on #1: Your first local Python -> Databricks chat endpoint request."""
from llm_client import ask_llm

# Change the prompt and run this script again.
question = "Suggest 3 fun names for a tiny space-invaders-style browser game."

try:
    answer = ask_llm(question, max_tokens=150)
except Exception as exc:
    print("Could not complete the LLM call.")
    print("Check login, the endpoint name, CAN QUERY access, and connectivity.")
    print(f"Details: {type(exc).__name__}: {exc}")
    raise SystemExit(1)

print("\nPrompt:", question)
print("\nDatabricks LLM says:\n", answer)
