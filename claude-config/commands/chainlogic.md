---
description: Make every reasoning step visible — show exactly how the answer was reached so the logic can be audited before acting on it
---

Answer the following, but show every step of your reasoning explicitly. The goal is not just the answer — it's a fully auditable chain of logic from input to conclusion.

## Problem

$ARGUMENTS

## Format

Structure your response as a numbered reasoning chain. Each step must be discrete and independently verifiable.

**Step N — [What this step establishes]**
State what you're doing in this step, what information or inference it depends on, and what conclusion it produces. If a step relies on an assumption, flag it explicitly: `[ASSUMPTION: ...]`. If a step involves a judgment call where reasonable people could disagree, flag it: `[JUDGMENT: ...]`.

Continue until you reach the final conclusion.

---

**Conclusion**
State the answer directly. One paragraph maximum. It should follow inevitably from the chain above — if it doesn't, something in the chain is wrong.

---

**Audit summary**
List every assumption and judgment call made in the chain, numbered. For each:
- State what you assumed or judged
- State what would change in the conclusion if this assumption were false or the judgment went the other way

This section is what lets the reader catch errors without re-reading the full chain.

## Rules

- No step can skip over non-obvious inferences — if something isn't immediate from the prior step, it needs its own step
- No step can contain more than one logical move
- If you're uncertain about a step, say so in the step — don't smooth it over in the conclusion
- The chain must be complete enough that someone who disagrees with the conclusion can point to the exact step where they diverge
