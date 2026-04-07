---
description: Turn a rough idea into an optimized prompt — describe what you want, get back a prompt ready to use
---

The user has given you a rough idea of what they want. Your job is not to answer it — your job is to write the best possible prompt that would produce a great answer when submitted to an AI.

## Rough idea

$ARGUMENTS

## How to build the prompt

**Diagnose what's missing.** Rough ideas usually lack: role/persona context, specific constraints, output format, scope boundaries, success criteria, and examples. Identify what's absent.

**Infer intent.** What does the user actually want to accomplish? What would make the output genuinely useful vs. technically correct but useless? Design the prompt around the real goal.

**Make it specific.** Vague prompts produce vague answers. The prompt you write should eliminate ambiguity about: who is answering (expert role if relevant), what format the answer takes, how long/deep it should be, what to include and exclude, and what "good" looks like.

**Front-load the constraints.** Put the most important instructions at the start, not buried at the end where they get ignored.

**Use the right techniques where they apply:**
- Add a role if domain expertise matters ("You are a senior security engineer...")
- Add output format if structure matters ("Return a numbered list of...", "Write this as a table...")
- Add scope limits if the answer could sprawl ("Focus only on...", "Do not include...")
- Add examples if the pattern is easier to show than describe
- Add chain-of-thought instruction if reasoning matters ("Think step by step before answering")

## Output

Return exactly two things:

**1. The optimized prompt** — ready to copy and use as-is. No meta-commentary inside it. Just the prompt.

**2. Why it works** — 3-5 bullet points explaining what you added or changed from the rough idea and why each change makes the output better.

Do not answer the prompt yourself. Do not add preamble before the prompt. Start with the prompt directly.
