---
# ---- Fill every field. Use `unavailable` (with a reason in tokens_source) rather than guessing. ----
game_title: "OutBreak Survival"
twist_one_liner: "ARENA, but a human enemy tries killing you with the zombies"            # "ARENA, but ..."
twist_category: "enemies"             # rule-bender | enemies | player-progression | world | other
twist_from_ideas_list: no      # yes | adapted | no
how_far_from_arena: "small-twist"         # small-twist | substantial | barely-recognizable

# Tools and models (lists; exact names as the tool shows them)
tools: [claude-code, DeepSeek]                      # e.g. [claude-code, chatgpt-web]
models: [claude-sonnet-5, V4.1-Flash]                     # e.g. [claude-sonnet-5, gpt-5-mini]
primary_model: "claude-code"              # the one that did most of the work
plan: "free"                       # free | student | paid-personal | api | none
agent_instructions_file: no    # yes | no  (CLAUDE.md, AGENTS.md, .cursorrules, ...)

# Totals (must match jam-log.csv)
sessions: 4
total_minutes: 200
total_prompts: 36
total_tokens_in: unavailable            # or unavailable
total_tokens_out: unavailable            # or unavailable
tokens_source: "ccusage dsusage"              # ccusage | cost-command | dashboard | cli-summary | estimated | unavailable (+ why)

# Your estimate of who wrote the code in the final build (should add to 100)
code_share_llm_pct: 90          # accepted from an LLM with little or no change
code_share_mixed_pct: 6        # LLM-generated then substantially edited by you
code_share_hand_pct: 4         # written by you

# Before this jam
odin_experience_before: "none"     # none | under-10h | 10-50h | over-50h
llm_coding_before: "occasional"          # never | occasional | weekly | daily
gamedev_experience_before: "a-few-small-games"  # none | a-tutorial | a-few-small-games | shipped-something

transcripts_shared: no         # yes | no  (optional, ungraded)
---

# Postmortem — <OutBreak Survival>

> Your own words. Grammar and spelling help from a tool is fine; the argument
> and the evidence are yours. Aim for 1-2 pages plus the table.

## 1. The game

One paragraph: what your game is and how to play it. Then what you **kept**,
**changed**, **removed** and **added** compared with ARENA.

**Where is the depth?** Answer the three questions from the README: the new
**decision** the twist creates, the **trade-off** behind it, and what an
**expert** does differently from a beginner. Use what you saw players do at
the Monday showcase as evidence.

## 2. Your setup

Which tools and models, and **why** those (cost, familiarity, a friend's
advice...). Did you give the agent a project instruction file, the Raylib
binding, docs, example code? Paste the instruction file, or its key lines, if
you used one.

## 3. Feature by feature

One row per feature you built. The first rows are ARENA's parts; drop the ones
you removed, and add a row for each feature of your own.
`who` = `llm`, `mixed` or `me`. `first try` = did the first LLM answer work
without changes? `help` = 1 (got in the way) - 5 (did it well).

| feature | who | prompts | first try? | minutes | help 1-5 | note |
|---|---|--:|---|--:|:--:|---|
| window, loop, game states, restart |llm | | | | | |
| player movement | llm| | | | | |
| shooting |llm | | | | | |
| enemies and spawning | llm| | | | | |
| health, damage, hit feedback | mixed| | | | | |
| difficulty over time | mixed | | | | | |
| HUD | me | | | | | |
| (optional) sprites / sound | me | | | | | |
| *your feature* | | | | | | |
| *your feature* | | | | | | |
| *your feature* | | | | | | |

## 4. Where the LLM sped you up

The easy parts. Name the features, the session number from `jam-log.csv` or
the commit, and estimate how long it would have taken you without it.

## 5. Where it did not help

The hard parts. What was the problem, what did you try (prompts, other models,
docs, a classmate, doing it by hand), and what finally worked? Was the
difficulty Odin, Raylib, game design, tuning the feel, or the tool itself?

## 6. One LLM-introduced bug: found, fixed, verified

- **The bug**: what it did wrong, and the code (a short excerpt or a commit link).
- **How you noticed**.
- **The fix**: the code after.
- **How you know it is fixed**: the evidence (debug draw, printed values, a
  test, a before/after clip or screenshot in the repo).

## 7. Pitch vs. delivered

Paste your Wednesday pitch. What survived, what was cut, what was added, and why.
What did you change after the Monday showcase, based on how people played it?

## 8. Improving the pipeline

If you did another jam next week with the same tools, what would you change?
Be concrete: setup, instruction files, prompting habits, when to use the LLM
and when not, commit rhythm, how you verify, which model for which job.
What would you want **from the tools** that they do not do today?

## 9. Anything else

Optional: what surprised you, what you learned about Odin, Raylib or game
development, what you would tell next year's class.

