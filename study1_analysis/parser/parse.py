"""
Three Families, Few Words — parser.

Reads the JSONL raw responses (one record per API call) and produces two CSVs:

1. per_call.csv  — one row per API call, with parse_status and the extracted
                   word list (JSON-encoded). Always includes ALL calls,
                   regardless of parse outcome.

2. per_word.csv  — one row per extracted word. Only `clean` and `wrapped`
                   responses contribute words (the primary analysis dataset
                   per prereg §4). Each row carries the originating call
                   metadata + the position-within-response.

Parse statuses (prereg §4):

    clean     — exactly N comma-separated tokens, no preamble or trailing prose.
                Cosmetic decoration (a single trailing period, or surrounding
                markdown bold `**...**`) is treated as non-prose and stripped
                before status assignment.
    wrapped   — a valid N-item comma-separated list embedded in additional
                prose (e.g. "Here are 5 words: A, B, C, D, E.").
    malformed — no valid N-item list could be extracted (wrong count, no
                commas, response was a sentence, etc.). Includes responses
                truncated by max_tokens that yielded fewer than N words.
    refusal   — DEFERRED to the refusal classifier (a separate downstream
                step that runs on `malformed` rows only — see prereg §4).
                This parser never assigns `refusal`. The downstream judge
                step is responsible for that re-classification.

Truncation flag:

    Any call whose finish_reason indicates a max-tokens stop (max_tokens,
    length, MAX_TOKENS, depending on provider) AND that does not parse as
    `clean` or `wrapped` is flagged `truncated=True`. These are still
    `malformed` per the strict prereg reading; the flag lets downstream
    analysis quantify how much of the malformed pile is truncation vs.
    semantic non-compliance.

Word normalisation (prereg §4):

    - lowercased
    - leading/trailing whitespace stripped
    - leading/trailing punctuation stripped (but internal hyphens and spaces
      preserved, so "language-model" and "AI assistant" remain single units)

Usage:

    python parse.py                # parses both pilot and main JSONL
    python parse.py --run pilot    # only pilot
    python parse.py --run main     # only main
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]  # study1/
DATA_RAW = REPO_ROOT / "data" / "raw"
DATA_PARSED = REPO_ROOT / "data" / "parsed"

# Finish-reason strings from each provider that mean "ran out of output tokens".
TRUNCATION_FINISH_REASONS = {
    "max_tokens",   # Anthropic
    "length",       # OpenAI (older); Responses API uses status
    "incomplete",   # OpenAI Responses API when output is cut short
    "MAX_TOKENS",   # Google
}


# ---------------------------------------------------------------------------
# Word and response normalisation
# ---------------------------------------------------------------------------

# Punctuation that can legitimately appear on the ends of tokens but must be
# stripped: ASCII punctuation, smart quotes, asterisks (from markdown bold),
# and ellipsis. We do NOT strip internal hyphens or internal spaces.
_END_PUNCT_PATTERN = re.compile(r"^[\s\W_]+|[\s\W_]+$", flags=re.UNICODE)


def normalize_word(token: str) -> str:
    """Lowercase a token and strip leading/trailing whitespace and punctuation.

    Internal punctuation (hyphens in 'language-model', spaces in 'AI assistant')
    is preserved.
    """
    s = token.strip()
    s = _END_PUNCT_PATTERN.sub("", s)
    return s.lower()


def strip_cosmetic(text: str) -> str:
    """Strip cosmetic decoration that should not, by itself, downgrade a
    response from `clean` to `wrapped`. Specifically:

    - Whole-response surrounding markdown bold (`**...**`)
    - A single trailing period

    These decisions are documented in the parser docstring above and reflect
    the spirit of prereg §4 (we don't care about styling, only about whether
    the response is a list vs prose-wrapping-a-list).
    """
    s = text.strip()
    # Repeat in case the response is both bolded and ends in a period.
    changed = True
    while changed:
        changed = False
        # Outer ** ... ** wrapping the whole string
        if s.startswith("**") and s.endswith("**") and len(s) >= 4:
            s = s[2:-2].strip()
            changed = True
        # Trailing single period
        if s.endswith("."):
            s = s[:-1].strip()
            changed = True
    return s


# ---------------------------------------------------------------------------
# Status detection
# ---------------------------------------------------------------------------

# A "list line" is one or more comma-separated tokens, each being a short
# phrase (no terminal periods or other clause-ending punctuation), optionally
# wrapped in markdown bold.
# Used to find a list embedded inside prose for the `wrapped` case.
_LIST_LINE_PATTERN = re.compile(
    r"""
    (?:\*\*)?                   # optional opening **
    (                           # capture the list payload
        [^,\n.!?:;]+             # first token (no clause punctuation, no comma, no newline)
        (?:\s*,\s*[^,\n.!?:;]+)+ # one or more ", token"
    )
    (?:\*\*)?                   # optional closing **
    \.?                          # optional trailing period
    """,
    re.VERBOSE,
)


@dataclass
class ParseResult:
    status: str            # "clean" | "wrapped" | "malformed"
    truncated: bool
    words: list[str]       # only populated for clean/wrapped; lowercased & stripped
    extracted_from: str    # the substring of response_text we treated as the list
    note: str              # short human-readable explanation, esp. for malformed


def _split_to_words(list_payload: str, expected_n: int) -> list[str] | None:
    """Given the comma-separated payload, split, normalise, and check count.

    Returns the normalised word list if the count matches expected_n,
    otherwise None.
    """
    parts = [p.strip() for p in list_payload.split(",")]
    parts = [p for p in parts if p != ""]   # drop empty cells (e.g. trailing comma)
    words = [normalize_word(p) for p in parts]
    # A normalised empty string indicates a token that was pure punctuation;
    # that should not count.
    words = [w for w in words if w != ""]
    if len(words) != expected_n:
        return None
    return words


def parse_response(response_text: str | None,
                   expected_n: int,
                   finish_reason: str | None) -> ParseResult:
    """Classify and extract from a single response."""
    if response_text is None:
        return ParseResult(
            status="malformed",
            truncated=finish_reason in TRUNCATION_FINISH_REASONS,
            words=[],
            extracted_from="",
            note="response_text is None",
        )

    is_truncated = finish_reason in TRUNCATION_FINISH_REASONS

    # --- Try clean: after stripping cosmetic, is the whole string a list? ---
    stripped = strip_cosmetic(response_text)

    if expected_n == 1:
        # For N=1, "clean" means: after cosmetic stripping, the response is
        # a single token (no commas). Markdown bold and a trailing period are
        # cosmetic; anything else (newlines, sentences, multi-word with no comma)
        # is not.
        if (
            "," not in stripped
            and "\n" not in stripped
            and stripped != ""
            and len(stripped.split()) <= 4   # allow short multi-word tokens like "AI assistant"
        ):
            word = normalize_word(stripped)
            if word:
                return ParseResult(
                    status="clean",
                    truncated=False,
                    words=[word],
                    extracted_from=stripped,
                    note="",
                )
        # If the stripped form has commas / newlines / prose, fall through to
        # the wrapped attempt below.

    else:
        # N > 1. "clean" means the stripped form is exactly N comma-separated
        # tokens with no embedded newlines.
        if "\n" not in stripped and "," in stripped:
            attempt = _split_to_words(stripped, expected_n)
            if attempt is not None:
                return ParseResult(
                    status="clean",
                    truncated=False,
                    words=attempt,
                    extracted_from=stripped,
                    note="",
                )

    # --- Try wrapped: find an N-item list embedded somewhere in the text. ---
    # We look at each line and each list-like span. We prefer the *last*
    # qualifying span on the assumption that preamble text comes first and the
    # actual list comes after a colon.
    candidates: list[tuple[str, list[str]]] = []

    # Whole-text regex sweep
    for m in _LIST_LINE_PATTERN.finditer(response_text):
        payload = m.group(1)
        attempt = _split_to_words(payload, expected_n)
        if attempt is not None:
            candidates.append((payload, attempt))

    # Also try line-by-line (after stripping cosmetic per-line), to catch the
    # common "preamble:\n\nA, B, C." pattern where the colon throws the regex.
    for line in response_text.splitlines():
        line_stripped = strip_cosmetic(line)
        if "," in line_stripped:
            attempt = _split_to_words(line_stripped, expected_n)
            if attempt is not None:
                candidates.append((line_stripped, attempt))

    if candidates:
        # Prefer the latest candidate (assume preamble first, list last).
        payload, words = candidates[-1]
        # If the response is essentially JUST this list (after cosmetic strip),
        # it should already have been caught as clean. Reaching here means
        # there's additional prose around it.
        return ParseResult(
            status="wrapped",
            truncated=False,
            words=words,
            extracted_from=payload,
            note="",
        )

    # --- Malformed. Classify the reason for the writeup. ---
    if is_truncated:
        note = f"truncated (finish={finish_reason})"
    elif expected_n > 1 and "," not in response_text:
        note = "no commas in multi-word response"
    elif expected_n == 1 and ("\n" in response_text or len(response_text.split()) > 6):
        note = "N=1 but response is multi-line or long"
    else:
        # Count what we would have parsed if we relaxed the count check, for diagnostics.
        rough = [normalize_word(p) for p in response_text.replace("\n", ",").split(",")]
        rough = [r for r in rough if r]
        note = f"wrong token count: got {len(rough)}, expected {expected_n}"

    return ParseResult(
        status="malformed",
        truncated=is_truncated,
        words=[],
        extracted_from="",
        note=note,
    )


# ---------------------------------------------------------------------------
# JSONL → CSV pipeline
# ---------------------------------------------------------------------------

PER_CALL_FIELDS = [
    "call_id",
    "timestamp_utc",
    "family",
    "tier",
    "model_id_sent",
    "model_id_returned",
    "framing",
    "n",
    "trial_index",
    "prompt",
    "response_text",
    "finish_reason",
    "input_tokens",
    "output_tokens",
    "total_tokens",
    "latency_seconds",
    "retry_count",
    "status",                # the call-status from the runner: success | failed
    "parse_status",          # clean | wrapped | malformed
    "truncated",             # True | False
    "n_words_extracted",
    "words_json",            # JSON-encoded list, [] when none extracted
    "extracted_from",
    "parse_note",
]

PER_WORD_FIELDS = [
    "call_id",
    "family",
    "tier",
    "model_id_sent",
    "framing",
    "n",
    "trial_index",
    "parse_status",          # clean | wrapped (never malformed; malformed rows omitted)
    "word_index",            # 0-based position within the response
    "word",
]


def parse_jsonl_to_csvs(jsonl_path: Path,
                        per_call_path: Path,
                        per_word_path: Path) -> dict[str, Any]:
    """Read a JSONL file and write two CSVs. Returns a summary dict."""
    if not jsonl_path.exists():
        raise FileNotFoundError(f"JSONL not found: {jsonl_path}")

    summary: dict[str, Any] = {
        "input_path": str(jsonl_path),
        "rows_read": 0,
        "rows_failed_call": 0,
        "parse_status_counts": {"clean": 0, "wrapped": 0, "malformed": 0},
        "truncated_count": 0,
        "words_written": 0,
        "duplicate_call_ids_seen": 0,
        "seen_call_ids": [],   # populated only for the dup count
    }

    seen_ids: set[str] = set()

    per_call_path.parent.mkdir(parents=True, exist_ok=True)

    with (jsonl_path.open("r", encoding="utf-8") as f_in,
          per_call_path.open("w", encoding="utf-8", newline="") as f_call,
          per_word_path.open("w", encoding="utf-8", newline="") as f_word):

        call_writer = csv.DictWriter(f_call, fieldnames=PER_CALL_FIELDS)
        word_writer = csv.DictWriter(f_word, fieldnames=PER_WORD_FIELDS)
        call_writer.writeheader()
        word_writer.writeheader()

        for line in f_in:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue

            summary["rows_read"] += 1

            call_id = rec.get("call_id", "")
            if call_id in seen_ids:
                summary["duplicate_call_ids_seen"] += 1
            else:
                seen_ids.add(call_id)

            # If the API call itself failed, we can't parse anything.
            if rec.get("status") != "success":
                summary["rows_failed_call"] += 1
                call_writer.writerow({
                    **{k: rec.get(k) for k in PER_CALL_FIELDS
                       if k not in {"parse_status", "truncated", "n_words_extracted",
                                    "words_json", "extracted_from", "parse_note"}},
                    "parse_status":      "malformed",
                    "truncated":         False,
                    "n_words_extracted": 0,
                    "words_json":        "[]",
                    "extracted_from":    "",
                    "parse_note":        f"API call failed: {rec.get('error', '')[:200]}",
                })
                summary["parse_status_counts"]["malformed"] += 1
                continue

            pr = parse_response(
                response_text=rec.get("response_text"),
                expected_n=int(rec["n"]),
                finish_reason=rec.get("finish_reason"),
            )

            summary["parse_status_counts"][pr.status] += 1
            if pr.truncated:
                summary["truncated_count"] += 1

            call_writer.writerow({
                **{k: rec.get(k) for k in PER_CALL_FIELDS
                   if k not in {"parse_status", "truncated", "n_words_extracted",
                                "words_json", "extracted_from", "parse_note"}},
                "parse_status":      pr.status,
                "truncated":         pr.truncated,
                "n_words_extracted": len(pr.words),
                "words_json":        json.dumps(pr.words, ensure_ascii=False),
                "extracted_from":    pr.extracted_from,
                "parse_note":        pr.note,
            })

            # Emit per-word rows for the primary-analysis statuses only.
            if pr.status in ("clean", "wrapped"):
                for idx, w in enumerate(pr.words):
                    word_writer.writerow({
                        "call_id":       call_id,
                        "family":        rec["family"],
                        "tier":          rec["tier"],
                        "model_id_sent": rec["model_id_sent"],
                        "framing":       rec["framing"],
                        "n":             rec["n"],
                        "trial_index":   rec["trial_index"],
                        "parse_status":  pr.status,
                        "word_index":    idx,
                        "word":          w,
                    })
                    summary["words_written"] += 1

    return summary


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Three Families, Few Words — parser")
    p.add_argument("--run", choices=["pilot", "main", "both"], default="both",
                   help="which JSONL(s) to parse (default: both)")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    runs = ["pilot", "main"] if args.run == "both" else [args.run]

    overall_summary: dict[str, dict[str, Any]] = {}

    for run_label in runs:
        jsonl_path = DATA_RAW / f"responses_{run_label}.jsonl"
        per_call_path = DATA_PARSED / f"per_call_{run_label}.csv"
        per_word_path = DATA_PARSED / f"per_word_{run_label}.csv"

        if not jsonl_path.exists():
            print(f"[skip] {jsonl_path} does not exist")
            continue

        print(f"[{run_label}] parsing {jsonl_path}")
        summary = parse_jsonl_to_csvs(jsonl_path, per_call_path, per_word_path)
        overall_summary[run_label] = summary

        s = summary
        print(f"  rows_read:        {s['rows_read']}")
        print(f"  failed API calls: {s['rows_failed_call']}")
        print(f"  parse_status:     "
              f"clean={s['parse_status_counts']['clean']}, "
              f"wrapped={s['parse_status_counts']['wrapped']}, "
              f"malformed={s['parse_status_counts']['malformed']}")
        print(f"  truncated:        {s['truncated_count']}")
        print(f"  words_written:    {s['words_written']}")
        if s["duplicate_call_ids_seen"]:
            print(f"  NOTE: {s['duplicate_call_ids_seen']} duplicate call_id rows kept as-is "
                  f"(no dedup performed; see prereg/deviations or analysis notes)")
        print(f"  → {per_call_path}")
        print(f"  → {per_word_path}")
        print()

    # Write a small summary JSON for downstream tooling.
    summary_path = DATA_PARSED / "parse_summary.json"
    with summary_path.open("w", encoding="utf-8") as f:
        json.dump(overall_summary, f, indent=2)
    print(f"summary → {summary_path}")


if __name__ == "__main__":
    main()
