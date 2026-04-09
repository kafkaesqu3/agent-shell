---
description: Disable depth filters — surface every edge case, tradeoff, nuance, and counterargument normally left out
---

Before answering, disengage the filters that normally keep responses tidy and comfortable. The goal is not a clean answer — it's a complete one.

## What to include that you'd normally leave out

**Edge cases.** Not just the obvious ones. Include the failure modes that only show up at scale, under adversarial conditions, or in specific environment configurations. Include the "shouldn't happen but does" cases.

**Counterarguments to your own answer.** If you're recommending X, steelman Y and Z. What would a smart person who disagrees with you say? Where are they right?

**The things experts argue about.** If there's genuine disagreement in the field — say so, name the camps, explain what each side gets right.

**What the docs don't tell you.** Undocumented behavior, known gotchas, things that look fine in theory but break in practice, community workarounds that shouldn't be necessary but are.

**Second and third-order effects.** Don't just answer the question as asked. What does this decision affect downstream? What does it make harder six months from now? What does it lock you into?

**The uncomfortable tradeoffs.** Don't paper over them. If the right answer has a real cost, name the cost. If every option is bad in some way, say so and explain which bad you'd choose and why.

**What you'd actually do.** Not what's theoretically correct. What would you do if this were your system, your codebase, your decision, with real consequences.

## What to drop

- Reassurances that everything will probably be fine
- Caveats that exist only to hedge liability ("results may vary", "test in your environment")
- The optimistic summary at the end that glosses over what you just said
- Any softening of a position that's actually firm

## Format

Follow the content, not a template. Long if it needs to be long. No artificial brevity, no artificial padding. The answer is done when the ground is covered.

## Prompt

$ARGUMENTS
