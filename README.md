# OutBreak Survival

A top-down survival shooter where you move a player, shoot the zombies that chase you, and spend points on upgrades. Every 20 kills the next wave is faster and denser.

## The game

- Zombies spawn off-screen and walk straight at you. Touching one costs 1 HP.
- Enemy players camp near a wall. Each one locks its aim, shows a red telegraph line for 0.6 seconds, then fires a slow bullet along that line.
- Kills earn score and points. Every 20 kills starts a new wave: faster zombies, a shorter spawn interval, and +2 HP.
- The game ends when your HP reaches 0. Press R to restart.

## Controls

| key | action |
|---|---|
| W / S or Up / Down | move forward / backward |
| A / D or Left / Right | turn |
| Space (hold) | shoot |
| B (hold, then release) | see the bomb radius, then drop the bomb |
| P or the Skills button | open or close the Skills shop (pauses the game) |
| R | restart after game over |

## Rules

| event | effect |
|---|---|
| Kill a zombie | +1 score, +1 point |
| Kill an enemy player | +1 score, +4 points |
| Take damage | -1 HP, -5 points |
| Reach a multiple of 20 score | new wave, +2 HP |

### Skills shop

| upgrade | cost | effect |
|---|--:|---|
| Heal | 20 | +1 HP |
| Speed | 6 | +10 walking speed |
| Bullet size | 6 | +1 bullet radius |
| Cooldown | 8 | -0.1 s between shots |
| Bomb radius | 8 | +20 blast radius |
| Bomb | 15 | adds one bomb to your inventory |

## Stack

- Language: [Odin]
- Graphics, input and audio: Raylib, through Odin's `vendor:raylib`

## Running

```
cd src
odin run .
```

## Resources

- Odin: https://odin-lang.org/docs/
- Raylib cheatsheet: https://www.raylib.com/cheatsheet/cheatsheet.html
- Odin's Raylib bindings: `vendor:raylib` in the Odin standard distribution
- Claude-code
- DeepSeek