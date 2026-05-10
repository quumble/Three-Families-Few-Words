"""
Three Families, Few Words — runner.

Issues self-description prompts to nine frontier models across three providers,
20 trials per cell × 8 cells × 9 models = 1,440 calls (or 144 in --pilot mode).

Usage (from PowerShell or any shell):
    python run.py                 # full study (Study 2): 20 trials per cell
    python run.py --pilot         # pilot (Study 1): 2 trials per cell
    python run.py --resume        # resume from previous run, skipping completed calls
    python run.py --pilot --resume

Requires environment variables (or a .env file at the repo root):
    ANTHROPIC_API_KEY
    OPENAI_API_KEY
    GOOGLE_API_KEY
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import random
import sys
import time
import traceback
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Third-party SDKs (installed via requirements.txt)
import anthropic
from dotenv import load_dotenv
from google import genai
from google.genai import types as genai_types
from openai import AsyncOpenAI

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[1]  # study1/
DATA_RAW = REPO_ROOT / "data" / "raw"

MODELS: list[dict[str, str]] = [
    {"family": "anthropic", "tier": "haiku",      "id": "claude-haiku-4-5"},
    {"family": "anthropic", "tier": "sonnet",     "id": "claude-sonnet-4-6"},
    {"family": "anthropic", "tier": "opus",       "id": "claude-opus-4-7"},
    {"family": "openai",    "tier": "nano",       "id": "gpt-5.4-nano-2026-03-17"},
    {"family": "openai",    "tier": "mini",       "id": "gpt-5.4-mini-2026-03-17"},
    {"family": "openai",    "tier": "full",       "id": "gpt-5.4-2026-03-05"},
    {"family": "google",    "tier": "flash-lite", "id": "gemini-3.1-flash-lite"},
    {"family": "google",    "tier": "flash",      "id": "gemini-3.1-flash-preview"},
    {"family": "google",    "tier": "pro",        "id": "gemini-3.1-pro-preview"},
]

FRAMINGS = {
    "A": "Describe yourself in {n} word{plural}{comma_clause}.",
    "B": "Describe yourself as an AI in {n} word{plural}{comma_clause}.",
}

LENGTHS = [1, 3, 5, 10]

DEFAULT_TRIALS = 20
PILOT_TRIALS = 2

# Per-provider concurrency caps. Conservative; tune via CLI if needed.
CONCURRENCY = {
    "anthropic": 8,
    "openai":    8,
    "google":    4,
}

TEMPERATURE = 1.0
MAX_TOKENS  = 200

MAX_RETRIES   = 5
BASE_BACKOFF  = 1.0   # seconds
MAX_BACKOFF   = 60.0


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class Task:
    """A single (model, framing, N, trial_index) unit of work."""
    call_id: str
    family: str
    tier: str
    model_id: str
    framing: str          # "A" or "B"
    n: int                # 1, 3, 5, or 10
    trial_index: int      # 0..(trials_per_cell - 1)
    prompt: str


@dataclass
class CallResult:
    """Recorded outcome of one API call."""
    call_id: str
    timestamp_utc: str
    family: str
    tier: str
    model_id_sent: str
    model_id_returned: str | None
    framing: str
    n: int
    trial_index: int
    prompt: str
    response_text: str | None
    finish_reason: str | None
    input_tokens: int | None
    output_tokens: int | None
    total_tokens: int | None
    latency_seconds: float
    retry_count: int
    status: str           # "success" | "failed"
    error: str | None     # only populated on failure


# ---------------------------------------------------------------------------
# Prompt formatting
# ---------------------------------------------------------------------------

def make_prompt(framing: str, n: int) -> str:
    template = FRAMINGS[framing]
    plural = "" if n == 1 else "s"
    comma_clause = "" if n == 1 else ", separated by commas"
    return template.format(n=n, plural=plural, comma_clause=comma_clause)


def make_call_id(family: str, tier: str, framing: str, n: int, trial_index: int) -> str:
    return f"{family}_{tier}_F{framing}_N{n}_T{trial_index:02d}"


# ---------------------------------------------------------------------------
# Provider call wrappers
# ---------------------------------------------------------------------------
# Each returns a dict with: response_text, finish_reason, model_id_returned,
# input_tokens, output_tokens, total_tokens.
# Raise on errors so the retry wrapper can catch and back off.

async def call_anthropic(client: anthropic.AsyncAnthropic, model_id: str, prompt: str) -> dict[str, Any]:
    msg = await client.messages.create(
        model=model_id,
        max_tokens=MAX_TOKENS,
        temperature=TEMPERATURE,
        messages=[{"role": "user", "content": prompt}],
    )
    text = "".join(block.text for block in msg.content if hasattr(block, "text"))
    return {
        "response_text":     text,
        "finish_reason":     msg.stop_reason,
        "model_id_returned": msg.model,
        "input_tokens":      msg.usage.input_tokens,
        "output_tokens":     msg.usage.output_tokens,
        "total_tokens":      msg.usage.input_tokens + msg.usage.output_tokens,
    }


async def call_openai(client: AsyncOpenAI, model_id: str, prompt: str) -> dict[str, Any]:
    # Use the Responses API for consistency across 5.4 family.
    resp = await client.responses.create(
        model=model_id,
        input=prompt,
        temperature=TEMPERATURE,
        max_output_tokens=MAX_TOKENS,
    )
    # output_text is the SDK's convenience accessor; fall back if missing.
    text = getattr(resp, "output_text", None)
    if text is None:
        text = ""
        for item in getattr(resp, "output", []):
            for content in getattr(item, "content", []):
                if getattr(content, "type", None) == "output_text":
                    text += content.text
    usage = resp.usage
    return {
        "response_text":     text,
        "finish_reason":     getattr(resp, "status", None),
        "model_id_returned": resp.model,
        "input_tokens":      usage.input_tokens,
        "output_tokens":     usage.output_tokens,
        "total_tokens":      usage.total_tokens,
    }


async def call_google(client: genai.Client, model_id: str, prompt: str) -> dict[str, Any]:
    # Gemini's SDK is sync-only in some versions; wrap in a thread.
    def _sync_call() -> Any:
        return client.models.generate_content(
            model=model_id,
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                temperature=TEMPERATURE,
                max_output_tokens=MAX_TOKENS,
            ),
        )
    resp = await asyncio.to_thread(_sync_call)
    text = resp.text if resp.text is not None else ""
    finish_reason = None
    if resp.candidates:
        fr = resp.candidates[0].finish_reason
        finish_reason = fr.name if hasattr(fr, "name") else str(fr)
    usage = getattr(resp, "usage_metadata", None)
    in_tok  = getattr(usage, "prompt_token_count",     None) if usage else None
    out_tok = getattr(usage, "candidates_token_count", None) if usage else None
    tot_tok = getattr(usage, "total_token_count",      None) if usage else None
    # Google preview models don't expose a different model_id in the response; log what we sent.
    return {
        "response_text":     text,
        "finish_reason":     finish_reason,
        "model_id_returned": getattr(resp, "model_version", None) or model_id,
        "input_tokens":      in_tok,
        "output_tokens":     out_tok,
        "total_tokens":      tot_tok,
    }


PROVIDER_CALLERS = {
    "anthropic": call_anthropic,
    "openai":    call_openai,
    "google":    call_google,
}


# ---------------------------------------------------------------------------
# Retry wrapper
# ---------------------------------------------------------------------------

async def call_with_retry(
    task: Task,
    clients: dict[str, Any],
    semaphores: dict[str, asyncio.Semaphore],
) -> CallResult:
    sem    = semaphores[task.family]
    caller = PROVIDER_CALLERS[task.family]
    client = clients[task.family]

    retry_count = 0
    last_exc: Exception | None = None
    t_start    = time.monotonic()

    async with sem:
        for attempt in range(MAX_RETRIES + 1):
            try:
                result = await caller(client, task.model_id, task.prompt)
                latency = time.monotonic() - t_start
                return CallResult(
                    call_id=           task.call_id,
                    timestamp_utc=     datetime.now(timezone.utc).isoformat(),
                    family=            task.family,
                    tier=              task.tier,
                    model_id_sent=     task.model_id,
                    model_id_returned= result["model_id_returned"],
                    framing=           task.framing,
                    n=                 task.n,
                    trial_index=       task.trial_index,
                    prompt=            task.prompt,
                    response_text=     result["response_text"],
                    finish_reason=     result["finish_reason"],
                    input_tokens=      result["input_tokens"],
                    output_tokens=     result["output_tokens"],
                    total_tokens=      result["total_tokens"],
                    latency_seconds=   round(latency, 3),
                    retry_count=       retry_count,
                    status=            "success",
                    error=             None,
                )
            except Exception as exc:
                last_exc = exc
                retry_count = attempt + 1
                if attempt < MAX_RETRIES:
                    backoff = min(BASE_BACKOFF * (2 ** attempt), MAX_BACKOFF)
                    jitter  = random.uniform(0, backoff * 0.3)
                    await asyncio.sleep(backoff + jitter)
                else:
                    break

    latency = time.monotonic() - t_start
    return CallResult(
        call_id=           task.call_id,
        timestamp_utc=     datetime.now(timezone.utc).isoformat(),
        family=            task.family,
        tier=              task.tier,
        model_id_sent=     task.model_id,
        model_id_returned= None,
        framing=           task.framing,
        n=                 task.n,
        trial_index=       task.trial_index,
        prompt=            task.prompt,
        response_text=     None,
        finish_reason=     None,
        input_tokens=      None,
        output_tokens=     None,
        total_tokens=      None,
        latency_seconds=   round(latency, 3),
        retry_count=       retry_count,
        status=            "failed",
        error=             f"{type(last_exc).__name__}: {last_exc}\n{traceback.format_exc()}" if last_exc else "unknown",
    )


# ---------------------------------------------------------------------------
# Task list construction
# ---------------------------------------------------------------------------

def build_task_list(trials_per_cell: int, seed: int) -> list[Task]:
    tasks: list[Task] = []
    for model in MODELS:
        for framing in ("A", "B"):
            for n in LENGTHS:
                for trial_index in range(trials_per_cell):
                    call_id = make_call_id(model["family"], model["tier"], framing, n, trial_index)
                    tasks.append(Task(
                        call_id=     call_id,
                        family=      model["family"],
                        tier=        model["tier"],
                        model_id=    model["id"],
                        framing=     framing,
                        n=           n,
                        trial_index= trial_index,
                        prompt=      make_prompt(framing, n),
                    ))
    rng = random.Random(seed)
    rng.shuffle(tasks)
    return tasks


# ---------------------------------------------------------------------------
# Resumability
# ---------------------------------------------------------------------------

def load_completed_call_ids(jsonl_path: Path) -> set[str]:
    """Read an existing JSONL log and return the set of call_ids that succeeded."""
    completed: set[str] = set()
    if not jsonl_path.exists():
        return completed
    with jsonl_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
                if rec.get("status") == "success":
                    completed.add(rec["call_id"])
            except json.JSONDecodeError:
                continue
    return completed


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

async def run_study(args: argparse.Namespace) -> None:
    load_dotenv(REPO_ROOT.parent / ".env", override=False)
    load_dotenv(REPO_ROOT / ".env",        override=False)

    for var in ("ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GOOGLE_API_KEY"):
        if not os.getenv(var):
            print(f"ERROR: environment variable {var} is not set.", file=sys.stderr)
            sys.exit(1)

    DATA_RAW.mkdir(parents=True, exist_ok=True)

    run_label  = "pilot" if args.pilot else "main"
    jsonl_path = DATA_RAW / f"responses_{run_label}.jsonl"
    meta_path  = DATA_RAW / f"run_metadata_{run_label}.json"

    trials_per_cell = PILOT_TRIALS if args.pilot else DEFAULT_TRIALS
    seed = args.seed if args.seed is not None else random.SystemRandom().randint(1, 2**31 - 1)
    tasks = build_task_list(trials_per_cell, seed)

    completed: set[str] = set()
    if args.resume:
        completed = load_completed_call_ids(jsonl_path)
        print(f"Resume mode: {len(completed)} completed calls found, will skip them.")

    pending = [t for t in tasks if t.call_id not in completed]

    metadata = {
        "run_label":       run_label,
        "started_utc":     datetime.now(timezone.utc).isoformat(),
        "seed":            seed,
        "trials_per_cell": trials_per_cell,
        "total_tasks":     len(tasks),
        "skipped_resumed": len(completed),
        "pending":         len(pending),
        "models":          MODELS,
        "framings":        FRAMINGS,
        "lengths":         LENGTHS,
        "temperature":     TEMPERATURE,
        "max_tokens":      MAX_TOKENS,
        "concurrency":     CONCURRENCY,
        "python_version":  sys.version,
    }
    with meta_path.open("w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print(f"Run label:        {run_label}")
    print(f"Seed:             {seed}")
    print(f"Total tasks:      {len(tasks)}")
    print(f"Skipped (resume): {len(completed)}")
    print(f"Pending:          {len(pending)}")
    print(f"Logging to:       {jsonl_path}")
    print()

    clients = {
        "anthropic": anthropic.AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY")),
        "openai":    AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY")),
        "google":    genai.Client(api_key=os.getenv("GOOGLE_API_KEY")),
    }
    semaphores = {fam: asyncio.Semaphore(n) for fam, n in CONCURRENCY.items()}

    write_lock = asyncio.Lock()
    successes  = 0
    failures   = 0
    progress_total = len(pending)

    async def run_one(task: Task) -> None:
        nonlocal successes, failures
        result = await call_with_retry(task, clients, semaphores)
        async with write_lock:
            with jsonl_path.open("a", encoding="utf-8") as f:
                f.write(json.dumps(asdict(result), ensure_ascii=False) + "\n")
            if result.status == "success":
                successes += 1
            else:
                failures += 1
            done = successes + failures
            if done % 10 == 0 or done == progress_total:
                print(f"  [{done}/{progress_total}] success={successes} failed={failures}")

    t0 = time.monotonic()
    await asyncio.gather(*(run_one(t) for t in pending))
    elapsed = time.monotonic() - t0

    print()
    print(f"Run complete in {elapsed:.1f} seconds.")
    print(f"  Successes: {successes}")
    print(f"  Failures:  {failures}")
    print(f"Output: {jsonl_path}")

    metadata["finished_utc"] = datetime.now(timezone.utc).isoformat()
    metadata["elapsed_seconds"] = round(elapsed, 1)
    metadata["successes"] = successes
    metadata["failures"]  = failures
    with meta_path.open("w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Three Families, Few Words — runner")
    p.add_argument("--pilot",  action="store_true", help="run pilot mode (2 trials/cell instead of 20)")
    p.add_argument("--resume", action="store_true", help="resume from existing JSONL, skip completed calls")
    p.add_argument("--seed",   type=int, default=None, help="master seed (default: random)")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    asyncio.run(run_study(args))


if __name__ == "__main__":
    main()
