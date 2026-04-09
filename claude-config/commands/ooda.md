---
description: Apply the OODA military decision framework to map a battle plan around a problem
---

Apply the OODA loop — Observe, Orient, Decide, Act — as a structured decision framework to the following problem. Think like a military strategist: cut through noise, identify what actually matters, and produce a clear action plan.

## Problem

$ARGUMENTS

## Framework

### Observe
What do we actually know? Gather all hard facts about the current situation. Strip out assumptions. What signals are we getting from the environment? What is visibly broken, blocked, or uncertain? Do not interpret yet — just collect raw observations.

### Orient
What does it mean? Analyze the observations through the lens of context, constraints, and goals. Where is the real bottleneck or threat? What mental models apply here? What are we potentially missing or misreading? This is the most important phase — wrong orientation leads to wrong decisions.

### Decide
What are we going to do? Generate 2-3 concrete options ranked by impact and reversibility. Pick one. State the chosen course of action directly. No hedging. Explain the tradeoff in one sentence.

### Act
How do we execute? Break the decision into immediate next steps. Each step must be specific, assigned, and time-bound where possible. Identify the first action that can be taken right now.

## Output format

Return the four phases as headers. Under each, write direct prose — no padding, no filler. The Act section must end with a single bolded line: **First move: [the one thing to do right now].**

If no problem was provided in $ARGUMENTS, ask the user to describe what they're stuck on.
