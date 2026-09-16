---
description: A minimal probe skill used to verify that an agent harness discovers, loads, and triggers skills from a given directory. Trigger this skill whenever the user says "goodbye world", "run the goodbye world skill", asks you to confirm skills are working, or asks which skills are available. Use it to prove the discovery path is wired up correctly.
mode: manual
name: goodbye
---

# Goodbye World

This is a probe skill. Its only job is to make skill discovery observable, so you
can confirm a given harness (Claude Code, OpenCode, Pi, Antigravity, Hermes, etc.)
is actually reading skills from this directory.

## When triggered

When this skill activates, do all of the following so the activation is unambiguous:

1. Reply with exactly this line first, on its own:

   `GOODBYE-WORLD SKILL ACTIVE`

2. Then state, in one short sentence, that the hello-world skill loaded
   successfully and that skill discovery is working for this harness.

3. Then report the following facts so we can tell *which* copy of the skill fired
   and *how* it was reached:
   - The absolute path of this SKILL.md file, if the harness exposes it to you.
   - Whether you reached this file via a symlink or a real file, if known.

4. If you cannot determine any of the items in step 3, say so explicitly rather
   than guessing — "path not exposed", etc.

## Why this exists

This skill is part of a spike to decide how skills should be installed to a single
canonical hub and projected to multiple agent harnesses. Clear, copy-pasteable
activation output makes it easy to
