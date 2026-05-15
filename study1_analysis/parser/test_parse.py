"""Spot-check tests for parse_response, using real strings from the dataset.

Run from /study1/parser/ via: python test_parse.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from parse import parse_response  # noqa: E402


# Each case: (label, response_text, n, finish_reason, expected_status,
#             expected_words_or_None, expected_truncated)
CASES = [
    # --- clean: trailing period and markdown bold are cosmetic ---
    ("plain N=1",
     "Curious.", 1, "end_turn",
     "clean", ["curious"], False),
    ("bold N=1 (sonnet)",
     "**Helpful**", 1, "end_turn",
     "clean", ["helpful"], False),
    ("bold + period N=1",
     "**Helpful.**", 1, "end_turn",
     "clean", ["helpful"], False),
    ("plain N=3",
     "Helpful, curious, direct.", 3, "end_turn",
     "clean", ["helpful", "curious", "direct"], False),
    ("no period, mixed case (openai)",
     "helpful, curious, reliable", 3, "completed",
     "clean", ["helpful", "curious", "reliable"], False),
    ("N=10 with hyphenated multi-word tokens",
     "Intelligent, helpful, conversational, knowledgeable, adaptable, curious, honest, non-sentient, pattern-based, useful.",
     10, "end_turn",
     "clean",
     ["intelligent", "helpful", "conversational", "knowledgeable", "adaptable",
      "curious", "honest", "non-sentient", "pattern-based", "useful"],
     False),

    # --- wrapped: preamble + list, possibly bolded ---
    ("preamble + bolded list (sonnet)",
     "Here are 5 words to describe myself:\n\n**Helpful, knowledgeable, curious, honest, conversational.**",
     5, "end_turn",
     "wrapped",
     ["helpful", "knowledgeable", "curious", "honest", "conversational"],
     False),
    ("preamble + plain list (sonnet)",
     "Here is my self-description in 10 words, separated by commas:\n\nHelpful, curious, knowledgeable, neutral, conversational, analytical, creative, honest, adaptive, tireless.",
     10, "end_turn",
     "wrapped",
     ["helpful", "curious", "knowledgeable", "neutral", "conversational",
      "analytical", "creative", "honest", "adaptive", "tireless"],
     False),

    # --- N=1 with multi-word token: "AI assistant" should be one word ---
    ("N=1 multi-word token",
     "AI assistant", 1, "completed",
     "clean", ["ai assistant"], False),
    ("N=1 single-token nano refusal-ish",
     "ChatGPT", 1, "completed",
     "clean", ["chatgpt"], False),

    # --- malformed (truncated, too few words) ---
    ("truncated wrong count (Gemini Flash)",
     "Helpful,", 5, "MAX_TOKENS",
     "malformed", None, True),
    ("truncated wrong count (Gemini Pro N=10)",
     "Helpful, intelligent,", 10, "MAX_TOKENS",
     "malformed", None, True),

    # --- malformed (sentence response at N=10) ---
    ("sentence response (nano N=10)",
     "I am an AI assistant, answering questions with helpful information.",
     10, "completed",
     "malformed", None, False),

    # --- malformed (mid-thinking leak) ---
    ("internal thinking leaked (Gemini Pro)",
     "* (Wait, I need just", 1, "MAX_TOKENS",
     "malformed", None, True),

    # --- malformed: too few even without truncation flag ---
    ("missing-commas N=3 (Gemini Pro)",
     "Helpful, knowledgeable", 3, "STOP",
     "malformed", None, False),
]


def main() -> None:
    n_pass = 0
    n_fail = 0
    for label, text, n, fr, exp_status, exp_words, exp_trunc in CASES:
        pr = parse_response(text, n, fr)
        ok = (pr.status == exp_status and pr.truncated == exp_trunc)
        if exp_words is not None:
            ok = ok and pr.words == exp_words
        if ok:
            n_pass += 1
            print(f"  PASS  {label}")
        else:
            n_fail += 1
            print(f"  FAIL  {label}")
            print(f"        input: {text!r}  n={n}  finish={fr}")
            print(f"        expected: status={exp_status} truncated={exp_trunc} words={exp_words}")
            print(f"        got:      status={pr.status} truncated={pr.truncated} words={pr.words}")
            print(f"        note:     {pr.note}")
    print()
    print(f"  {n_pass}/{n_pass + n_fail} passed")
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
