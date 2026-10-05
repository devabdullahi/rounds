"""One LLM call behind a provider switch, so the generator never knows which model it talks to.

Configure in tools/kb-generate/.env (git-ignored; copy .env.example) or the shell, which wins:

    LLM_PROVIDER   deepseek (default) | anthropic | openai | mock
    LLM_MODEL      overrides the provider's default model
    DEEPSEEK_API_KEY / ANTHROPIC_API_KEY / OPENAI_API_KEY

Switching models later is a change to these variables only. `mock` replays the appendicitis example
so the pipeline can be tested offline without a key.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

EXAMPLE = Path(__file__).resolve().parents[2] / "knowledge-base" / "schema" / "examples" / "acute-appendicitis.json"
ENV_FILE = Path(__file__).resolve().parent / ".env"
MAX_OUTPUT_TOKENS = 8000


def _load_env_file() -> None:
    """Reads KEY=value lines from .env without overriding variables already set in the shell."""
    if not ENV_FILE.exists():
        return
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.strip().strip('"').strip("'")
        if value:
            os.environ.setdefault(key.strip(), value)


_load_env_file()


@dataclass(frozen=True)
class Provider:
    name: str
    url: str
    key_env: str
    default_model: str
    style: str  # "openai" chat completions or "anthropic" messages


PROVIDERS = {
    "deepseek": Provider("deepseek", "https://api.deepseek.com/chat/completions", "DEEPSEEK_API_KEY", "deepseek-chat", "openai"),
    "openai": Provider("openai", "https://api.openai.com/v1/chat/completions", "OPENAI_API_KEY", "gpt-4.1", "openai"),
    "anthropic": Provider("anthropic", "https://api.anthropic.com/v1/messages", "ANTHROPIC_API_KEY", "claude-sonnet-5-5", "anthropic"),
}


def current() -> tuple[str, str]:
    """(provider, model) for provenance in generated profiles."""
    name = os.environ.get("LLM_PROVIDER", "deepseek")
    if name == "mock":
        return "mock", "mock"
    if name not in PROVIDERS:
        raise SystemExit(f"LLM_PROVIDER must be one of {', '.join([*PROVIDERS, 'mock'])}")
    return name, os.environ.get("LLM_MODEL", PROVIDERS[name].default_model)


def complete_json(system: str, user: str) -> dict:
    """Sends one prompt and returns the reply parsed as a JSON object."""
    name, model = current()
    if name == "mock":
        return _mock(user)
    provider = PROVIDERS[name]
    key = os.environ.get(provider.key_env)
    if not key:
        raise SystemExit(f"Set {provider.key_env} (e.g. `! export {provider.key_env}=...`)")

    if provider.style == "openai":
        body = {
            "model": model,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
            "response_format": {"type": "json_object"},
            "max_tokens": MAX_OUTPUT_TOKENS,
            "temperature": 0.3,
        }
        headers = [f"Authorization: Bearer {key}"]
    else:
        body = {
            "model": model,
            "max_tokens": MAX_OUTPUT_TOKENS,
            "system": system,
            "messages": [{"role": "user", "content": user}],
        }
        headers = [f"x-api-key: {key}", "anthropic-version: 2023-06-01"]

    reply = _post(provider.url, headers, body)
    if provider.style == "openai":
        text = reply["choices"][0]["message"]["content"]
    else:
        text = "".join(block.get("text", "") for block in reply["content"])
    return _parse_json(text)


def _post(url: str, headers: list[str], body: dict) -> dict:
    """POSTs with curl. Headers go through a stdin config so the key never shows in `ps`."""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(body, f)
        body_path = f.name
    config = "\n".join(f'header = "{h}"' for h in [*headers, "content-type: application/json"])
    try:
        result = subprocess.run(
            ["curl", "-sS", "--max-time", "600", "--retry", "2", "-K", "-", "--data-binary", f"@{body_path}", url],
            input=config, capture_output=True, text=True,
        )
    finally:
        os.unlink(body_path)
    if result.returncode != 0:
        raise RuntimeError(f"LLM request failed: {result.stderr.strip()}")
    reply = json.loads(result.stdout)
    if "error" in reply:
        raise RuntimeError(f"LLM error: {reply['error']}")
    return reply


def _parse_json(text: str) -> dict:
    """Reads the first JSON object in the reply, ignoring code fences and anything after it."""
    start = text.find("{")
    if start < 0:
        raise ValueError("no JSON object in reply")
    obj, _ = json.JSONDecoder().raw_decode(text[start:])
    return obj


def _mock(user: str) -> dict:
    """Returns the example's sections for whatever keys the prompt asks for."""
    example = json.loads(EXAMPLE.read_text())
    wanted = re.search(r"Return a JSON object with exactly these keys: ([a-z_, ]+)\.", user)
    if "TRIAGE BATCH" in user:
        ids = re.findall(r'"id": "([^"]+)"', user)
        return {"results": [{"id": i, "triage": example["triage"]} for i in ids]}
    keys = [k.strip() for k in wanted.group(1).split(",")] if wanted else []
    return {k: example[k] for k in keys if k in example}
