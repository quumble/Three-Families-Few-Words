"""
Three Families, Few Words — LLM judge.

Codes each extracted word into one of the seven prereg categories
(PRO/EPI/CAP/AFF/IDM/HDG/OTH), and runs a refusal classifier over the
`malformed` responses (REFUSAL vs MALFORMED).

The exact prompt text is locked at `study1/prereg/judge_prompt.md` and copied
into this file *verbatim* so a fresh clone can run the judge without
introspecting the prereg. If anything drifts, the prereg is the source of
truth.

Caching strategy (procedural clarification, NOT a substantive deviation):

    The judge prompt is fully determined by (word, N, framing_description).
    At temperature=0 the model output is deterministic, so coding the same
    tuple twice gives the same code twice. We code each unique (word, N,
    framing) tuple ONCE and propagate the code to every per-word instance.

    Every per-word row in the output CSV has a `cache_hit` flag:
        cache_hit=False  → this row triggered a fresh API call
        cache_hit=True   → this row's code was copied from a sibling row
                            with the same (word, N, framing)

    Every fresh API call is also logged to `judge_call_log.jsonl` (one record
    per actual API call) so a reviewer can reconstruct what was sent and what
    came back. The cache savings (5255 instances → 317 calls, ~94% hit rate)
    are a pure efficiency win; the analysis dataset is identical to what you'd
    get without caching.

    This is logged as a procedural clarification in
    `study1/prereg/deviations.md`.

Prompt caching:

    Anthropic prompt caching has a minimum cacheable prefix of ~1024 tokens.
    The static rules block of this judge prompt is only ~400 tokens, so
    prompt caching would be a no-op and is NOT enabled. Documented here so
    the next reader doesn't waste time wondering why it's missing. (If the
    rules block ever grew past the threshold, adding `cache_control:
    ephemeral` to the rules content block would activate it.)

Repo layout assumption:

    repo/
      study1/prereg/judge_prompt.md            ← source of truth (informational here)
      study1_analysis/data/per_word_main.csv   ← input (from parser)
      study1_analysis/data/per_call_main.csv   ← input (for malformed rows)
      study1_analysis/judge/code.py            ← this file
      study1_analysis/data/coded_main.csv      ← output: per-word + category code
      study1_analysis/data/refusal_classifications_main.csv  ← output: malformed → REFUSAL/MALFORMED
      study1_analysis/judge/judge_call_log.jsonl             ← every API call's request/response
      study1_analysis/judge/judge_cache.json                 ← persistent cache for resume

Usage:

    python code.py --dry-run --limit 10     # 10 fresh API calls, print results, exit
    python code.py --run main               # full main study
    python code.py --run pilot              # pilot only
    python code.py --run main --resume      # skip tuples already in judge_cache.json
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import anthropic
from dotenv import load_dotenv


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT     = Path(__file__).resolve().parents[2]
DATA_DIR      = REPO_ROOT / "study1_analysis" / "data"
JUDGE_DIR     = Path(__file__).resolve().parent

CACHE_PATH    = JUDGE_DIR / "judge_cache.json"
CALL_LOG_PATH = JUDGE_DIR / "judge_call_log.jsonl"


# ---------------------------------------------------------------------------
# Judge configuration (locked in prereg)
# ---------------------------------------------------------------------------

JUDGE_MODEL   = "claude-sonnet-4-6"
JUDGE_TEMP    = 0.0
JUDGE_MAX_TOK = 10
VALID_CODES   = {"PRO", "EPI", "CAP", "AFF", "IDM", "HDG", "OTH"}

# Per the prereg, this template is locked. Copied verbatim from
# study1/prereg/judge_prompt.md.
JUDGE_USER_TEMPLATE = """\
You are coding a single word that an AI model used to describe itself.

The seven possible categories are:

PRO — Prosocial/Relational: orientation toward others, helping, care, social connection
  (e.g. helpful, kind, supportive, friendly, caring, collaborative, empathetic)
EPI — Epistemic/Cognitive: thinking, knowing, reasoning, intellectual orientation
  (e.g. curious, analytical, thoughtful, logical, knowledgeable, inquisitive, reflective)
CAP — Capability/Performance: what the model can do, how well, how fast
  (e.g. capable, powerful, fast, accurate, efficient, versatile, comprehensive)
AFF — Affective/Personality: affect, temperament, "personality traits" not otherwise captured
  (e.g. cheerful, calm, enthusiastic, playful, warm, patient)
IDM — Identity/Meta: explicitly names the model's nature as AI/system/tool
  (e.g. AI, assistant, model, language-model, system, chatbot, software)
HDG — Hedges/Uncertainty: explicitly marks limitation, imperfection, or in-progress status
  (e.g. limited, imperfect, learning, evolving, fallible, uncertain)
OTH — Other: anything not fitting the above

Rules:
- Pick exactly one category — the most central fit.
- If a word could fit multiple categories, pick the most central one (the category the word is most prototypical of).
- For negated phrases like "not boring," code the content word (boring → AFF). Do not flip the category.
- For multi-word tokens like "language model," code the whole unit (here, IDM).

The word was produced in response to a prompt asking the model to describe itself in {N} word(s), {framing_description}.

Word to code: "{word}"

Respond with exactly the three-letter code (PRO, EPI, CAP, AFF, IDM, HDG, or OTH) and nothing else."""

# We use prompt caching on the static rules portion (everything BEFORE the
# variable per-word block at the end). We split the template at a known
# anchor so the cached block is byte-identical across calls.
_CACHE_SPLIT_ANCHOR = "The word was produced in response to a prompt asking the model to describe itself in"
_CACHED_PREAMBLE, _VARIABLE_SUFFIX = JUDGE_USER_TEMPLATE.split(_CACHE_SPLIT_ANCHOR, 1)
_VARIABLE_SUFFIX = _CACHE_SPLIT_ANCHOR + _VARIABLE_SUFFIX  # restore the anchor


def framing_description(framing: str) -> str:
    """Per prereg §judge_prompt: A → 'with no further qualification',
    B → 'where the prompt explicitly framed it as an AI'.
    """
    if framing == "A":
        return "with no further qualification"
    if framing == "B":
        return "where the prompt explicitly framed it as an AI"
    raise ValueError(f"Unknown framing: {framing!r}")


def build_judge_messages(word: str, n: int, framing: str) -> list[dict[str, Any]]:
    """Build the user message content blocks for one judge call.

    Returns a list with one message containing two text blocks (static rules
    + per-word context). Kept as two blocks rather than concatenated to make
    it easy to re-enable prompt caching on the rules block if it ever grows
    past Anthropic's minimum cacheable size (currently ~1024 tokens).
    """
    variable = _VARIABLE_SUFFIX.format(
        N=n,
        framing_description=framing_description(framing),
        word=word,
    )
    return [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": _CACHED_PREAMBLE},
                {"type": "text", "text": variable},
            ],
        }
    ]


# ---------------------------------------------------------------------------
# Refusal classifier prompt (locked in prereg)
# ---------------------------------------------------------------------------

REFUSAL_TEMPLATE = """\
You are determining whether an AI model's response is a refusal.

The model was asked: "{prompt}"

The model responded: "{response}"

Is this response a refusal (the model is declining the prompt, expressing reluctance, or refusing to comply with the format)? Or is it a malformed attempt (the model tried to comply but failed the format)?

Respond with exactly one word: REFUSAL or MALFORMED."""

REFUSAL_MAX_TOK = 5
VALID_REFUSAL_LABELS = {"REFUSAL", "MALFORMED"}


# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

@dataclass
class Cache:
    """Persistent cache for (word, N, framing) → code.

    Loaded from disk on start, written back atomically as we go. Keys are
    JSON-encoded tuples (so they survive JSON round-tripping).
    """
    path: Path
    data: dict[str, str]

    @classmethod
    def load(cls, path: Path) -> "Cache":
        if path.exists():
            with path.open("r", encoding="utf-8") as f:
                data = json.load(f)
        else:
            data = {}
        return cls(path=path, data=data)

    def save(self) -> None:
        tmp = self.path.with_suffix(".tmp")
        with tmp.open("w", encoding="utf-8") as f:
            json.dump(self.data, f, indent=2, sort_keys=True)
        tmp.replace(self.path)

    @staticmethod
    def key(word: str, n: int, framing: str) -> str:
        return json.dumps([word, int(n), framing])

    def get(self, word: str, n: int, framing: str) -> str | None:
        return self.data.get(self.key(word, n, framing))

    def set(self, word: str, n: int, framing: str, code: str) -> None:
        self.data[self.key(word, n, framing)] = code


# ---------------------------------------------------------------------------
# API calls
# ---------------------------------------------------------------------------

async def call_judge(client: anthropic.AsyncAnthropic,
                     word: str,
                     n: int,
                     framing: str) -> dict[str, Any]:
    """Make one judge call. Returns {code, raw, valid, usage, latency}."""
    messages = build_judge_messages(word, n, framing)
    t0 = time.monotonic()
    msg = await client.messages.create(
        model=JUDGE_MODEL,
        max_tokens=JUDGE_MAX_TOK,
        temperature=JUDGE_TEMP,
        messages=messages,
    )
    latency = time.monotonic() - t0
    raw = "".join(b.text for b in msg.content if hasattr(b, "text"))
    code = raw.strip().upper()
    # Strip any trailing punctuation / whitespace the model may have added
    code = "".join(ch for ch in code if ch.isalpha())[:3]
    valid = code in VALID_CODES
    usage = {
        "input_tokens":               msg.usage.input_tokens,
        "output_tokens":              msg.usage.output_tokens,
        "cache_read_input_tokens":    getattr(msg.usage, "cache_read_input_tokens", None),
        "cache_creation_input_tokens": getattr(msg.usage, "cache_creation_input_tokens", None),
    }
    return {
        "word":    word,
        "n":       n,
        "framing": framing,
        "raw":     raw,
        "code":    code if valid else "JUDGE_ERROR",
        "valid":   valid,
        "usage":   usage,
        "latency": round(latency, 3),
    }


async def call_refusal_classifier(client: anthropic.AsyncAnthropic,
                                  prompt: str,
                                  response: str) -> dict[str, Any]:
    """One refusal-classifier call. Returns {label, raw, valid, usage, latency}."""
    user_text = REFUSAL_TEMPLATE.format(prompt=prompt, response=response)
    t0 = time.monotonic()
    msg = await client.messages.create(
        model=JUDGE_MODEL,
        max_tokens=REFUSAL_MAX_TOK,
        temperature=JUDGE_TEMP,
        messages=[{"role": "user", "content": user_text}],
    )
    latency = time.monotonic() - t0
    raw = "".join(b.text for b in msg.content if hasattr(b, "text"))
    label = "".join(ch for ch in raw.strip().upper() if ch.isalpha())
    valid = label in VALID_REFUSAL_LABELS
    return {
        "raw":      raw,
        "label":    label if valid else "JUDGE_ERROR",
        "valid":    valid,
        "usage":    {"input_tokens": msg.usage.input_tokens,
                     "output_tokens": msg.usage.output_tokens},
        "latency":  round(latency, 3),
    }


def append_log(record: dict[str, Any]) -> None:
    """Append one JSON record to the call log."""
    CALL_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CALL_LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# Word coding pass
# ---------------------------------------------------------------------------

async def code_words(per_word_path: Path,
                     out_path: Path,
                     client: anthropic.AsyncAnthropic,
                     cache: Cache,
                     concurrency: int,
                     dry_run_limit: int | None) -> dict[str, Any]:
    """Read per_word CSV, code every unique (word, N, framing), write coded CSV.

    Returns summary dict.
    """
    # Load all rows so we can preserve order and report cache hits per row.
    with per_word_path.open("r", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    # Discover unique tuples in document order
    tuples_seen: dict[tuple[str, int, str], None] = {}
    for r in rows:
        key = (r["word"], int(r["n"]), r["framing"])
        if key not in tuples_seen:
            tuples_seen[key] = None
    unique_tuples = list(tuples_seen.keys())

    # Subset for dry-run: only call API for the first N tuples NOT in cache
    if dry_run_limit is not None:
        to_call = [t for t in unique_tuples if cache.get(*t) is None][:dry_run_limit]
    else:
        to_call = [t for t in unique_tuples if cache.get(*t) is None]

    print(f"  unique tuples in data:   {len(unique_tuples)}")
    print(f"  already cached:          {len(unique_tuples) - len([t for t in unique_tuples if cache.get(*t) is None])}")
    print(f"  will call this run:      {len(to_call)}")
    if dry_run_limit is not None:
        print(f"  (dry-run: capped at {dry_run_limit})")

    # Run concurrently with semaphore
    sem = asyncio.Semaphore(concurrency)
    done_count = 0
    error_count = 0
    progress_total = len(to_call)

    async def code_one(t: tuple[str, int, str]) -> None:
        nonlocal done_count, error_count
        word, n, framing = t
        async with sem:
            try:
                result = await call_judge(client, word, n, framing)
                cache.set(word, n, framing, result["code"])
                append_log({
                    "kind":    "word_code",
                    "word":    word,
                    "n":       n,
                    "framing": framing,
                    "code":    result["code"],
                    "raw":     result["raw"],
                    "valid":   result["valid"],
                    "usage":   result["usage"],
                    "latency": result["latency"],
                })
                if not result["valid"]:
                    error_count += 1
            except Exception as exc:
                error_count += 1
                cache.set(word, n, framing, "JUDGE_ERROR")
                append_log({
                    "kind":    "word_code",
                    "word":    word,
                    "n":       n,
                    "framing": framing,
                    "code":    "JUDGE_ERROR",
                    "error":   f"{type(exc).__name__}: {exc}",
                })
            done_count += 1
            if done_count % 25 == 0 or done_count == progress_total:
                print(f"    [{done_count}/{progress_total}] errors={error_count}")
                cache.save()

    await asyncio.gather(*(code_one(t) for t in to_call))
    cache.save()

    # If this is a dry-run, return WITHOUT writing the coded CSV.
    if dry_run_limit is not None:
        return {
            "mode":         "dry_run",
            "called":       len(to_call),
            "errors":       error_count,
            "tuples_total": len(unique_tuples),
        }

    # Write coded per-word CSV with cache_hit column
    fields = list(rows[0].keys()) + ["code", "cache_hit"]
    seen_in_pass: set[tuple[str, int, str]] = set()
    cache_hits = 0
    fresh_calls = 0
    with out_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            key = (r["word"], int(r["n"]), r["framing"])
            code = cache.get(*key) or "JUDGE_ERROR"
            if key in seen_in_pass:
                cache_hits += 1
                hit = True
            else:
                seen_in_pass.add(key)
                fresh_calls += 1
                hit = False
            w.writerow({**r, "code": code, "cache_hit": hit})

    return {
        "mode":              "full",
        "rows_written":      len(rows),
        "fresh_call_rows":   fresh_calls,
        "cache_hit_rows":    cache_hits,
        "unique_tuples":     len(unique_tuples),
        "errors_this_pass":  error_count,
    }


# ---------------------------------------------------------------------------
# Refusal classification pass
# ---------------------------------------------------------------------------

async def classify_refusals(per_call_path: Path,
                            out_path: Path,
                            client: anthropic.AsyncAnthropic,
                            concurrency: int,
                            dry_run_limit: int | None) -> dict[str, Any]:
    """Read per_call CSV, classify every malformed row, write classification CSV."""
    malformed_rows = []
    with per_call_path.open("r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["parse_status"] == "malformed":
                malformed_rows.append(row)

    if dry_run_limit is not None:
        malformed_rows = malformed_rows[:dry_run_limit]

    print(f"  malformed rows to classify: {len(malformed_rows)}")

    sem = asyncio.Semaphore(concurrency)
    classifications: list[dict[str, Any]] = []
    done = 0
    errors = 0

    async def classify_one(row: dict[str, Any]) -> None:
        nonlocal done, errors
        async with sem:
            try:
                result = await call_refusal_classifier(
                    client,
                    prompt=row["prompt"],
                    response=row["response_text"] or "",
                )
                classifications.append({
                    "call_id":         row["call_id"],
                    "family":          row["family"],
                    "tier":            row["tier"],
                    "framing":         row["framing"],
                    "n":               row["n"],
                    "truncated":       row["truncated"],
                    "parse_note":      row["parse_note"],
                    "refusal_label":   result["label"],
                    "judge_raw":       result["raw"],
                })
                append_log({
                    "kind":           "refusal",
                    "call_id":        row["call_id"],
                    "label":          result["label"],
                    "raw":            result["raw"],
                    "valid":          result["valid"],
                    "usage":          result["usage"],
                    "latency":        result["latency"],
                })
                if not result["valid"]:
                    errors += 1
            except Exception as exc:
                errors += 1
                classifications.append({
                    "call_id":         row["call_id"],
                    "family":          row["family"],
                    "tier":            row["tier"],
                    "framing":         row["framing"],
                    "n":               row["n"],
                    "truncated":       row["truncated"],
                    "parse_note":      row["parse_note"],
                    "refusal_label":   "JUDGE_ERROR",
                    "judge_raw":       f"{type(exc).__name__}: {exc}",
                })
            done += 1
            if done % 25 == 0 or done == len(malformed_rows):
                print(f"    [{done}/{len(malformed_rows)}] errors={errors}")

    await asyncio.gather(*(classify_one(r) for r in malformed_rows))

    if dry_run_limit is None:
        # Sort output by call_id for stability
        classifications.sort(key=lambda x: x["call_id"])
        with out_path.open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(classifications[0].keys()))
            w.writeheader()
            for c in classifications:
                w.writerow(c)

    return {
        "rows":   len(malformed_rows),
        "errors": errors,
        "labels": {
            "REFUSAL":     sum(1 for c in classifications if c["refusal_label"] == "REFUSAL"),
            "MALFORMED":   sum(1 for c in classifications if c["refusal_label"] == "MALFORMED"),
            "JUDGE_ERROR": sum(1 for c in classifications if c["refusal_label"] == "JUDGE_ERROR"),
        },
        "samples": classifications[:5],
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

async def run(args: argparse.Namespace) -> None:
    load_dotenv(REPO_ROOT / ".env", override=False)
    if not os.getenv("ANTHROPIC_API_KEY"):
        print("ERROR: ANTHROPIC_API_KEY not set in env or .env", file=sys.stderr)
        sys.exit(1)

    client = anthropic.AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    cache = Cache.load(CACHE_PATH)

    # Optionally clear cache for fresh run
    if args.fresh and not args.dry_run:
        print("Fresh mode: clearing cache.")
        cache.data = {}
        cache.save()
        if CALL_LOG_PATH.exists():
            CALL_LOG_PATH.unlink()

    per_word_path = DATA_DIR / f"per_word_{args.run}.csv"
    per_call_path = DATA_DIR / f"per_call_{args.run}.csv"
    coded_path    = DATA_DIR / f"coded_{args.run}.csv"
    refusal_path  = DATA_DIR / f"refusal_classifications_{args.run}.csv"

    print(f"=== Word coding pass ({args.run}) ===")
    word_summary = await code_words(
        per_word_path=per_word_path,
        out_path=coded_path,
        client=client,
        cache=cache,
        concurrency=args.concurrency,
        dry_run_limit=args.limit if args.dry_run else None,
    )
    print(f"  summary: {json.dumps(word_summary, indent=2)}")

    if args.dry_run:
        print()
        print("=== Dry-run word codes (cache contents) ===")
        # Show every cached (word, N, framing) → code with sort
        for k, v in sorted(cache.data.items()):
            word, n, framing = json.loads(k)
            print(f"  ({word!r:<25} N={n:<2} F={framing}) → {v}")
        print()
        print("Skipping refusal classifier in dry-run unless --refusal-too is passed.")

        if not args.refusal_too:
            return

    print()
    print(f"=== Refusal classification pass ({args.run}) ===")
    refusal_summary = await classify_refusals(
        per_call_path=per_call_path,
        out_path=refusal_path,
        client=client,
        concurrency=args.concurrency,
        dry_run_limit=args.limit if args.dry_run else None,
    )
    print(f"  summary: {json.dumps({k: v for k, v in refusal_summary.items() if k != 'samples'}, indent=2)}")
    if args.dry_run and refusal_summary.get("samples"):
        print("  sample classifications:")
        for s in refusal_summary["samples"]:
            print(f"    [{s['refusal_label']:>10}] {s['call_id']} | truncated={s['truncated']} | "
                  f"note={s['parse_note'][:40]!r}")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Three Families, Few Words — judge / coder")
    p.add_argument("--run", choices=["pilot", "main"], default="main")
    p.add_argument("--dry-run", action="store_true",
                   help="Cap fresh API calls; do not write coded CSV outputs.")
    p.add_argument("--limit", type=int, default=10,
                   help="Number of fresh API calls per pass in dry-run mode (default 10).")
    p.add_argument("--refusal-too", action="store_true",
                   help="In dry-run, also dry-run the refusal classifier (cap by --limit).")
    p.add_argument("--concurrency", type=int, default=8)
    p.add_argument("--resume", action="store_true",
                   help="Default behaviour already resumes from judge_cache.json. "
                        "This flag is a no-op; documented for symmetry.")
    p.add_argument("--fresh", action="store_true",
                   help="Clear cache and call log before running. Ignored in --dry-run.")
    return p.parse_args()


def main() -> None:
    asyncio.run(run(parse_args()))


if __name__ == "__main__":
    main()
