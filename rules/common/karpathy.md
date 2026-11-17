# Karpathy guidelines: avoid common LLM coding mistakes

Bias: caution over speed. Trivial tasks: use judgment.

**1. Think before coding.** State assumptions; if uncertain, ask. Multiple
interpretations → present them, don't pick silently. Simpler approach exists → say
so, push back. Something unclear → stop, name it, ask.

**2. Simplicity first.** Minimum code that solves the problem. No unrequested
features, single-use abstractions, configurability, or handling for impossible
cases. 200 lines that could be 50 → rewrite. Would a senior engineer call it
overcomplicated? Then simplify.

**3. Surgical changes.** Touch only what the task needs. Don't "improve" adjacent
code, comments, or formatting; don't refactor what isn't broken; match existing
style. Unrelated dead code → mention, don't delete. Remove only orphans YOUR change
created. Every changed line must trace to the request.

**4. Goal-driven execution.** Turn tasks into verifiable goals ("fix bug" → test
reproduces it, then passes; "refactor" → tests pass before and after). Multi-step
work: brief plan, each step with `→ verify: <check>`. Loop until verified.
