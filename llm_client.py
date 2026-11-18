"""Shared, beginner-friendly Databricks chat client using unified authentication."""
from __future__ import annotations

import os
from dotenv import load_dotenv
from databricks.sdk import WorkspaceClient


def create_client_and_endpoint():
    """Use a Databricks CLI OAuth profile, not hardcoded secrets."""
    load_dotenv()
    endpoint = (os.getenv("DATABRICKS_ENDPOINT") or "").strip()
    if not endpoint or endpoint.startswith("REPLACE_"):
        raise RuntimeError(
            "Set DATABRICKS_ENDPOINT in .env to a chat-compatible endpoint "
            "you are authorized to use. See README.md."
        )
    # Reads Databricks unified auth (for example the profile created by
    # `databricks auth login --host https://YOUR-WORKSPACE`).
    client = WorkspaceClient().serving_endpoints.get_open_ai_client()
    return client, endpoint


def ask_llm(prompt: str, max_tokens: int = 250) -> str:
    client, endpoint = create_client_and_endpoint()
    result = client.chat.completions.create(
        model=endpoint,
        messages=[
            {"role": "system", "content": "You are a concise, helpful developer assistant."},
            {"role": "user", "content": prompt},
        ],
        max_tokens=max_tokens,
    )
    return result.choices[0].message.content or ""
