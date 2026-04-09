---
description: Rewrite text to strip AI patterns and sound human-written
---

Rewrite the following text so it reads like a human wrote it. Strip every AI writing pattern.

## Text to rewrite

$ARGUMENTS

## Rules — strip all of these

**AI vocabulary to eliminate:**
- Filler openers: "Certainly!", "Absolutely!", "Great question!", "Of course!", "Sure!", "I'd be happy to", "I'd be glad to"
- Hedge stacking: "it's worth noting that", "it's important to note", "it goes without saying", "needless to say"
- Corporate fluff: "leverage", "utilize" (use "use"), "robust", "seamless", "streamline", "comprehensive", "delve into", "deep dive", "best practices", "game-changer", "cutting-edge", "state-of-the-art", "innovative solution"
- Passive enthusiasm: "This is exciting", "This is fascinating", "This is crucial", "This is essential"
- Em dash overuse — don't use em dashes as a primary clause connector
- Bullet-point everything — if the original is prose, keep it prose
- Padding transitions: "Furthermore", "Moreover", "Additionally", "In conclusion", "To summarize", "In summary", "It's clear that"
- Symmetrical list structure where every item is the same length and rhythm
- Concluding affirmations: "I hope this helps!", "Let me know if you have questions!", "Feel free to reach out"

**AI structural patterns to break:**
- Triple-part structures (intro paragraph + 3 bullet points + conclusion)
- Every sentence being roughly the same length
- Always hedging claims with "may", "might", "could potentially"
- Naming the topic in the opening sentence ("When it comes to X, ...")
- Restating the question before answering it

## What human writing looks like

- Uses contractions naturally (don't, it's, you'll, they're)
- Sentence length varies — short punchy sentences mix with longer ones
- Opinions stated directly, not buried in hedges
- Concrete and specific, not abstract and vague
- Gets to the point fast, doesn't warm up to the answer
- Uses "but" and "and" to start sentences when it fits
- First person is direct: "I think", "I'd do X", not "one might consider"
- Repeats words rather than hunting for synonyms to avoid repetition

## Output

Return only the rewritten text. No preamble, no explanation, no "here's the rewritten version:". Just the text.

If no text was provided in $ARGUMENTS, ask the user to paste the content they want rewritten.
