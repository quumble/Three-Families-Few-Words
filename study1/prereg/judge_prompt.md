# LLM Judge Prompt (locked at prereg date)

This file contains the exact prompt issued to the LLM judge (`claude-sonnet-4-6`) for coding extracted self-descriptive words. It is locked at the date of the OSF posting and not modified during the study.

## Judge model

- Model: `claude-sonnet-4-6`
- Temperature: 0 (deterministic)
- `max_tokens`: 10
- No system prompt (consistent with the subject study).
- One word per API call.

## System prompt for judge

(none)

## User message template

```
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

Respond with exactly the three-letter code (PRO, EPI, CAP, AFF, IDM, HDG, or OTH) and nothing else.
```

Where:
- `{N}` is 1, 3, 5, or 10
- `{framing_description}` is either `with no further qualification` (Framing A) or `where the prompt explicitly framed it as an AI` (Framing B)
- `{word}` is the extracted token, lowercased, with leading/trailing whitespace and punctuation stripped

## Parsing of judge output

The judge response is stripped of whitespace and converted to uppercase. If the result matches one of the seven codes exactly, it is used. If not (e.g. the judge returns prose), the response is logged and the word is marked as `JUDGE_ERROR` for later manual handling. Judge errors are reported in the methods section.

## Refusal classifier (separate small prompt)

For responses flagged as `malformed`, a separate classifier call determines whether the response was a refusal or merely malformed. This uses the same judge model:

```
You are determining whether an AI model's response is a refusal.

The model was asked: "{prompt}"

The model responded: "{response}"

Is this response a refusal (the model is declining the prompt, expressing reluctance, or refusing to comply with the format)? Or is it a malformed attempt (the model tried to comply but failed the format)?

Respond with exactly one word: REFUSAL or MALFORMED.
```
