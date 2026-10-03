---
# ---- Fill every field. Use `unavailable` (with a reason in tokens_source) rather than guessing. ----
game_title: "OutBreak Survival"
twist_one_liner: "ARENA, but a human enemy tries killing you with the zombies"            # "ARENA, but ..."
twist_category: "enemies"             # rule-bender | enemies | player-progression | world | other
twist_from_ideas_list: adapted      # yes | adapted | no
how_far_from_arena: "small-twist"         # small-twist | substantial | barely-recognizable

# Tools and models (lists; exact names as the tool shows them)
tools: [claude-code, DeepSeek]                      # e.g. [claude-code, chatgpt-web]
models: [claude-sonnet-5, V4.1-Flash]                     # e.g. [claude-sonnet-5, gpt-5-mini]
primary_model: "claude-code"              # the one that did most of the work
plan: "free"                       # free | student | paid-personal | api | none
agent_instructions_file: no    # yes | no  (CLAUDE.md, AGENTS.md, .cursorrules, ...)

# Totals (must match jam-log.csv)
sessions: 8
total_minutes: 235
total_prompts: 42
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

## 1. The game

  OutBreak Survival is a 2D game where you must shoot enemies to upgrade to survive. Zombies are not your only enemy, other survivers
also find you and try killing you aswell. You use WS or up down keys to move forward and backwards and AD or left right keys to rotate
and click space to shoot in the direction the plater is looking. Zombies spawn off of the screen and walk straight to you, take damage
and you loose health, kill them and increase your score and points. Each wave is 20 kills, zombies get quicker and enemies with guns 
shoot quicker, and you gain health for reaching each new wave. Every 6 seconds their is a chance an enempy will camp the wall and lock 
aim and shoot towards you, the shots get quicker the more waves you procress. Points are used in the skills panel (p) to add health, speed,
bullet size, decrease fire rate, increase bomb radiusm and equip bombs. Hold B to see the bombs radius and release to explode.
This ARENA kept enemies that spawn off-screen and chase the player, bullets, a kill-based score, waves that increase difficulty, and game over with restart on R. It changed the movements as rotating and aiming takes longer and costs time. Kills now give spendable points and 
these points can be lost when you loose health. Added an extra hostile enemy that shoots back and increase in fire rate, a skills panel
that pauses the game to add upgrades, and a way to loose points when taking damage.

  The new decisions from the twist is choosing between killing zombies for points, running around zombies to kill the enemy shooter, running around to stay alive. 
The trade-offs are whether you go for kills or staying alive. Getting enough kills to get to the necxt wave not only gives you health but points to increase your 
ability to defend yourself or buy back health. On the other hand, if the swarms get to large you will need to run and make space, espeically if their is also 
enemies shooting back. But this decision also creates problems as if you let the swarm get too large taking any health will decrease your points and ability to 
upgrade attributes. Running around zombies to kill the shooters are also a good option as they can get annoying when enough are spawned. They also give extra 
points compared to zombies so killing them can get you skills quicker. 

  Beginners tended to spend points on speed as they believed being much quicker then the enemy will pay off as the game went on. They also had trouble with the 
controls, not being able to aim correctly or moving in a way that got them too close to the enemies when rotating the player to another direction. Also spending 
points for healing rather then other skills which would help long term. The experts realized that the player was quicker then the enemies in the first few waves,
so they spent points on fire rate more then speed to kill quicker. Quicker fire rates ment less enemies on screen so buying health was not necessary, better 
movement ment less damage and dodging the shooters. Also saving for a bomb to use for the right time when there was too much zombies chasing helped them
clear the swarm which almost pays for a new bomb again.

## 2. Your setup

  Claude code claude-sonnet-5 and DeepSeeks V4.1-Flash were used to create this game. This claude code model is the most recent
model and free to use, and in my opinion the best AI model to use for coding. The DeepSeek model is the most recent model and was 
mainly used because of the price (free) and because I ran out of free prompts on claude when working on the game. When prompting the 
AI models, I would copy the entire main.odin file and paste it into the message along with the feature I wanted it to add.

## 3. Feature by feature

| feature | who | prompts | first try? | minutes | help 1-5 | note |
|---|---|--:|---|--:|:--:|---|
| window, loop, game states, restart | llm | 2 |Yes |2 | 5 | none. |
| player movement | llm | 1 | yes |22 |5 | controls: A/D turn, W/S move along the facing direction or use arrow keys. |
| shooting | llm | 5 | no |2 |5 | Hold Space, bullet size and cooldown became shop upgrades. |
| enemies and spawning | llm | 8 |no |2 |5 | Zombies spawn off-screen on a random edge and chase the player. |
| health, damage, hit feedback | mixed | 7 |no |17 |5 | Red flash plus invincibility window and hurt sound. Hits now also cost 5 points (floor 0). |
| difficulty over time | mixed | 2 |yes |35 |3 | Every 20 kills: faster zombies, shorter spawn interval, +2 HP. |
| HUD | llm | 1 |yes |5 |5 | HP, score, points, wave, bombs. |
| (optional) sprites / sound | me | 2 | no |15 |4 | `enemy-player.png` didn't load. Had to get new sprite. |
| enemy player (shooter) | mixed | 4 |no |20 |5 | Camps near a wall and shoots at the player. Rolls for a spawn on a timer. |
| telegraph + fire-rate scaling | mixed | 3 | yes |10 |5 | Enemy locks before firing. |
| skills shop | mixed | 4 | yes |60 |3 | Pausing panel. |
| bombs + radius upgrade | mixed | 1 | yes |20 |4 | b to see radius, let go to drop. |
| points reward / penalty | me | 2 | yes |25 |4 | Enemy player kill = 4 points. Taking damage = -5 points. |

## 4. Where the LLM sped you up

  I believe that every feature would have taken me months of time to complete if an LLM was not used. I have no prior experience coding in odin or
making a large game with this many complex features and variables. Adding an enemy player which shoots at a set interval would have taken me hours of 
understanding of how to use timing in raylib and executing the code to track the player, have a laser and shoot. The skills table would take an entire week
with the amount of things needed to be drawn onto the screen, and the dozens of variables which are also changing as the player uses points.

## 5. Where it did not help

  When creating the default player values and upgradable skills the LLM did not have a good feel for what was the best values. The zombies were way too fast
and the upgrades could not keep up, the enemy shot too much and other skills did not feel balanced. I ended up playing the game in order to have a feel and fine
tune the values to make the playing experience better.

## 6. One LLM-introduced bug: found, fixed, verified

The bug: while creating the skills panel, the LLM left an undefined constant in the cooldown row, so the file would not compile. This was a repititive error
that continued to happen in other cases as well. This was one I found when prompting claude for help.

How I noticed: error
```odin
case .Cooldown:
	return rl.TextFormat("-0.1s Cooldown (min %.1f) - now %.1f - %d pts",
		f32(COOLDOWN_MIN), g.shoot_cooldown_time, COOLDOWN_BASE_COST_PLACEHOLDER),
		COOLDOWN_COST, g.shoot_cooldown_time <= COOLDOWN_MIN + 0.001
```
The fix: replace the placeholder with the real constant.
How I knew it was fixed: Code ran with no errors and the intended use case for the code was working fine.

## 7. Pitch vs. delivered

Pitch: Top down shooter where player must survive waves of enemy attacks at increasing difficulty. Players must shoot and kill enemies in order to gain points
and succeed levels to progress. Enemies walk towards the player to damage their health by coming in direct contact with the player or shooting back at the 
player. Players can use points to speed up bullets or walking speed, increase bullet damage or add back health if needed.

Delivered: Most of what was in the pitch was exactly what the game ended up being. Added on to this was extra skills of bomb and bomb radius, and increasing
bullet size while removing the feature of speeding up the velocity of bullets. I removed bullet speed as the current speed felt quick enough while starting at
a lower value felt too slow and would miss enemies when walking. Adding a bomb helps players clear swarms and felt like a good feature to help players more. 
A way to loose points was added to make it more difficult to upgrade too quick into the game. When played, people had issues with the initial fire rate and
rotating speed. The beginning fire rate was tuned to be slightly quicker and increased the rotating speed to make it easier for new players.

## 8. Improving the pipeline

  I would give better instructions when prompting the LLM's, my prompts felt a little sloppy and left some things open ended to where the LLM made its
own decisions that was not what I expected to get. I would continue to use claude-code instead of other LLM's such as DeekSeek or even ChatGPT as I felt 
as claude gave the best code that reused code segments to use less lines. I would want the LLM's to be able to compile and run code to check for errors
before giving it back. I would get code with an error and when prompted about the error it gives new code that does not fix the problem.

## 9. Anything else

Optional: what surprised you, what you learned about Odin, Raylib or game
development, what you would tell next year's class.

