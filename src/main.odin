package main

import rl "vendor:raylib"
import la "core:math/linalg"
import "core:math/rand"
import "core:math"

// ---------------------------------------------------------------------
// Enemy: a red circle that spawns just off-screen and walks straight
// toward wherever the player currently is, every single frame.
// ---------------------------------------------------------------------
Enemy :: struct {
	pos:    [2]f32,
	speed:  f32,
	radius: f32,
	alive:  bool,
}

// ---------------------------------------------------------------------
// EnemyPlayer: a hostile shooter that spawns rarely, camps near a wall,
// and fires bullets at the player until killed.
// ---------------------------------------------------------------------
EnemyPlayer :: struct {
	pos:      [2]f32,
	rot:      f32, // facing direction in radians (0 = up), used for drawing
	radius:   f32,
	health:   int,
	shoot_cd: f32, // time until next shot
	alive:    bool,
}

// ---------------------------------------------------------------------
// Bullet: fired from the player toward the direction they are facing
// when SPACE is pressed. Travels in a straight line.
// ---------------------------------------------------------------------
Bullet :: struct {
	pos:     [2]f32,
	dir:     [2]f32,
	speed:   f32,
	radius:  f32,
	alive:   bool,
	hostile: bool, // true if fired by an enemy player
}

SCREEN_W :: 1280
SCREEN_H :: 720

BASE_PLAYER_SPEED :: 100.0
MAX_PLAYER_SPEED  :: 300.0
PLAYER_TURN_SPEED :: 3.0 // radians per second
HEAL_COST         :: 20
SPEED_COST        :: 6
SPEED_PER_PURCHASE :: 10.0

BULLET_RADIUS_BASE         :: 2.0
BULLET_RADIUS_MAX          :: 5.0
BULLET_RADIUS_COST         :: 8
BULLET_RADIUS_PER_PURCHASE :: 1.0

COOLDOWN_BASE          :: 1.2
COOLDOWN_MIN           :: 0.2
COOLDOWN_COST          :: 8
COOLDOWN_PER_PURCHASE  :: 0.1

// Bomb: a one-shot purchase that instantly kills every enemy within
// BOMB_RADIUS pixels of the player. Not a permanent stat upgrade like
// the others above - each purchase spends points and detonates once.
BOMB_COST         :: 30
BOMB_RADIUS       :: 80
BOMB_FLASH_TIME   :: 0.25 // how long the explosion ring is drawn for

// Aim line: a faint red line from the player in the direction they face.
AIM_LINE_LEN   :: 160
AIM_LINE_COLOR :: rl.Color{255, 60, 60, 80}

// ---------------- Enemy player settings ----------------
ENEMY_PLAYER_CHECK_INTERVAL :: 10.0  // roll for a spawn every 10 seconds
ENEMY_PLAYER_SPAWN_CHANCE   :: 0.15 // 15% chance per roll
ENEMY_PLAYER_RADIUS         :: 22.0
ENEMY_PLAYER_HEALTH         :: 1     // one shot kills
ENEMY_PLAYER_SHOOT_INTERVAL :: 4.0   // seconds between shots
ENEMY_PLAYER_BULLET_SPEED   :: 200.0 // 1/3 the player's 600 speed
ENEMY_PLAYER_BULLET_RADIUS  :: 3.0
ENEMY_PLAYER_WALL_MARGIN    :: 60.0 // how far from the wall the enemy player camps

// ---------------- Wave / difficulty ramp settings ----------------
KILLS_PER_WAVE          :: 20  // score needed to advance to the next wave
BASE_SPAWN_INTERVAL     :: 2.0
SPAWN_INTERVAL_DECREASE :: 0.2
SPAWN_INTERVAL_MIN      :: 0.5
BASE_ENEMY_SPEED_MIN    :: 40.0
BASE_ENEMY_SPEED_MAX    :: 80.0
ENEMY_SPEED_INCREASE    :: 10.0
ENEMY_SPEED_MIN_CAP     :: 140.0
ENEMY_SPEED_MAX_CAP     :: 180.0

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Odin + Raylib - Square vs Circles")
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	// Precomputed float versions of the screen dimensions. Declared with
	// explicit f32 types so nothing in the file accidentally promotes to f64.
	sw: f32 = 1280
	sh: f32 = 720

	// Player sprite. The source art faces RIGHT by default, so we apply
	// a -90 degree offset at draw time to line it up with player_rot,
	// where a rotation of 0 means "facing up".
	player_tex := rl.LoadTexture("../assets/player.png")
	defer rl.UnloadTexture(player_tex)

	// Enemy sprite, drawn centered on each enemy's position and scaled
	// to fit the same circular footprint used for collision. This art
	// also faces RIGHT by default, so (like the player) we rotate it
	// to match its direction of travel with no extra offset needed -
	// 0 degrees rotation already points right.
	enemy_tex := rl.LoadTexture("../assets/enemy1.png")
	defer rl.UnloadTexture(enemy_tex)

	// Enemy player sprite. Same orientation as the player sprite (faces
	// RIGHT), so we apply the same -90 degree offset at draw time. We
	// also verify it actually loaded; if the asset is missing or corrupt,
	// we fall back to drawing a colored circle instead of a broken texture.
	enemy_player_tex := rl.LoadTexture("../assets/enemy-player.png")
	defer rl.UnloadTexture(enemy_player_tex)
	enemy_player_tex_ok := enemy_player_tex.width > 0 && enemy_player_tex.height > 0

	// Sound effect played each time the player fires.
	gunshot_sfx := rl.LoadSound("../assets/gun-shot.mp3")
	defer rl.UnloadSound(gunshot_sfx)

	// Sound effect played each time a zombie is killed (by a bullet or a bomb).
	zombie_death_sfx := rl.LoadSound("../assets/zombie-death.mp3")
	defer rl.UnloadSound(zombie_death_sfx)

	// ---------------- Player state ----------------
	// player_rot is in radians. 0 means "facing up" (-Y), matching a
	// classic top-down-shooter orientation. It is changed by A/D or
	// left/right arrow keys.
	player_pos:        [2]f32 = {sw / 2, sh / 2}
	player_rot:        f32 = 0
	player_size:       f32 = 25  // half-width of the square, used for drawing + collision
	player_speed:      f32 = 100 // move speed, px/sec
	player_health:     int = 10
	player_hit_timer:  f32 = 0 // >0 while flashing/briefly invincible after a hit

	// Upgradeable weapon stats, purchased in the skills panel.
	bullet_radius:       f32 = 2 // size of each fired bullet
	shoot_cooldown_time: f32 = 1.2 // seconds between shots

	// Bomb visual feedback: >0 for a brief moment right after detonation
	// so we can draw an expanding ring at the player's position.
	bomb_flash_timer: f32 = 0

	// ---------------- Dynamic arrays for spawned objects ----------------
	enemies: [dynamic]Enemy
	bullets: [dynamic]Bullet
	enemy_players: [dynamic]EnemyPlayer
	defer delete(enemies)
	defer delete(bullets)
	defer delete(enemy_players)

	enemy_spawn_timer:    f32 = 0
	enemy_spawn_interval: f32 = 2.0 // seconds between enemy spawns, ramps down per wave
	enemy_speed_min:      f32 = 40.0 // current wave's enemy speed range
	enemy_speed_max:      f32 = 80.0
	shoot_cooldown:       f32 = 0
	score:                int = 0 // kill counter, shown in the HUD
	points:               int = 0 // spendable currency, also goes up on every kill
	wave:                 int = 1 // increases every KILLS_PER_WAVE kills
	game_over := false

	// Timer that periodically rolls for an enemy player spawn.
	enemy_player_spawn_timer: f32 = 10.0

	// Skills menu state. Opening it pauses gameplay (movement, spawning,
	// shooting, enemy/bullet updates) without closing the window.
	skills_open := false

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// =========================================================
		// SKILLS UI LAYOUT - computed once per frame so the same
		// rectangles are used for both click detection and drawing.
		// =========================================================
		skills_btn := rl.Rectangle{sw - 140, 10, 120, 36}

		panel_w: f32 = 480 // widened to comfortably fit the upgrade rows
		panel_h: f32 = 380 // tall enough for the bomb row below cooldown
		panel_x := sw / 2 - panel_w / 2
		panel_y := sh / 2 - panel_h / 2

		heal_btn     := rl.Rectangle{panel_x + panel_w - 110, panel_y + 70, 90, 34}
		speed_btn    := rl.Rectangle{panel_x + panel_w - 110, panel_y + 130, 90, 34}
		bullet_btn   := rl.Rectangle{panel_x + panel_w - 110, panel_y + 190, 90, 34}
		cooldown_btn := rl.Rectangle{panel_x + panel_w - 110, panel_y + 250, 90, 34}
		bomb_btn     := rl.Rectangle{panel_x + panel_w - 110, panel_y + 310, 90, 34}

		// =========================================================
		// RESTART (only checked while the game-over screen is up)
		// =========================================================
		if game_over {
			if rl.IsKeyPressed(.R) {
				player_pos = {sw / 2, sh / 2}
				player_rot = 0
				player_health = 10
				player_speed = 100
				bullet_radius = 2
				shoot_cooldown_time = 1.2
				bomb_flash_timer = 0
				clear(&enemies)
				clear(&bullets)
				clear(&enemy_players)
				score = 0
				points = 0
				wave = 1
				enemy_spawn_interval = 2.0
				enemy_speed_min = 40.0
				enemy_speed_max = 80.0
				enemy_player_spawn_timer = 10.0
				skills_open = false
				game_over = false
			}
		} else {
			// =====================================================
			// SKILLS TOGGLE - either the button click or the P key.
			// Checked even while the panel is open, since that's how
			// the player closes it.
			// =====================================================
			if rl.IsKeyPressed(.P) {
				skills_open = !skills_open
			}

			if rl.IsMouseButtonPressed(.LEFT) {
				mouse := rl.GetMousePosition()

				if rl.CheckCollisionPointRec(mouse, skills_btn) {
					skills_open = !skills_open
				} else if skills_open {
					// Heal: spend 20 points for +1 HP, no upper limit.
					if rl.CheckCollisionPointRec(mouse, heal_btn) && points >= HEAL_COST {
						points -= HEAL_COST
						player_health += 1
					}
					// Speed: spend points for +10 walking speed, up to a cap.
					if rl.CheckCollisionPointRec(mouse, speed_btn) &&
					   points >= SPEED_COST && player_speed < MAX_PLAYER_SPEED {
						points -= SPEED_COST
						player_speed = min(player_speed + SPEED_PER_PURCHASE, MAX_PLAYER_SPEED)
					}
					// Bullet radius: spend points for +1 bullet size, up to a cap.
					if rl.CheckCollisionPointRec(mouse, bullet_btn) &&
					   points >= BULLET_RADIUS_COST && bullet_radius < BULLET_RADIUS_MAX {
						points -= BULLET_RADIUS_COST
						bullet_radius = min(bullet_radius + BULLET_RADIUS_PER_PURCHASE, BULLET_RADIUS_MAX)
					}
					// Fire rate: spend points to cut the cooldown, down to a floor.
					if rl.CheckCollisionPointRec(mouse, cooldown_btn) &&
					   points >= COOLDOWN_COST && shoot_cooldown_time > COOLDOWN_MIN {
						points -= COOLDOWN_COST
						shoot_cooldown_time = max(shoot_cooldown_time - COOLDOWN_PER_PURCHASE, COOLDOWN_MIN)
					}
					// Bomb: spend points to instantly kill every enemy
					// within BOMB_RADIUS of the player. Consumable, not a
					// permanent upgrade, so it can be bought again and again.
					if rl.CheckCollisionPointRec(mouse, bomb_btn) && points >= BOMB_COST {
						points -= BOMB_COST
						bomb_flash_timer = BOMB_FLASH_TIME

						bomb_kills := 0 // how many zombies this bomb killed (for the sound)
						for i in 0 ..< len(enemies) {
							enemy := &enemies[i]
							if !enemy.alive do continue
							dist := la.length(enemy.pos - player_pos)
							if dist < BOMB_RADIUS + enemy.radius {
								enemy.alive = false
								score += 1
								points += 1
								bomb_kills += 1

								if score % KILLS_PER_WAVE == 0 {
									wave += 1
									player_health += 2
									enemy_speed_min = min(enemy_speed_min + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MIN_CAP)
									enemy_speed_max = min(enemy_speed_max + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MAX_CAP)
									enemy_spawn_interval = max(enemy_spawn_interval - SPAWN_INTERVAL_DECREASE, SPAWN_INTERVAL_MIN)
								}
							}
						}

						// Bomb also damages enemy players in range (one hit = one
						// point of damage, so a 3-HP enemy player needs 3 bombs
						// unless they're already wounded).
						for i in 0 ..< len(enemy_players) {
							ep := &enemy_players[i]
							if !ep.alive do continue
							dist := la.length(ep.pos - player_pos)
							if dist < BOMB_RADIUS + ep.radius {
								ep.health -= 1
								if ep.health <= 0 {
									ep.alive = false
									score += 1
									points += 1
									bomb_kills += 1

									if score % KILLS_PER_WAVE == 0 {
										wave += 1
										player_health += 2
										enemy_speed_min = min(enemy_speed_min + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MIN_CAP)
										enemy_speed_max = min(enemy_speed_max + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MAX_CAP)
										enemy_spawn_interval = max(enemy_spawn_interval - SPAWN_INTERVAL_DECREASE, SPAWN_INTERVAL_MIN)
									}
								}
							}
						}

						// Play the death sound once per bomb (not once per zombie),
						// so a big blast doesn't stack into a wall of noise.
						if bomb_kills > 0 {
							rl.PlaySound(zombie_death_sfx)
						}
					}
				}
			}

			// While the skills panel is open, gameplay is fully paused:
			// no movement, shooting, spawning, or enemy/bullet updates.
			if !skills_open {
				// =================================================
				// ROTATION - A/D or left/right arrows turn the player.
				// 0 radians = facing up (-Y). Increasing player_rot
				// rotates clockwise on screen.
				// =================================================
				if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
					player_rot -= PLAYER_TURN_SPEED * dt
				}
				if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
					player_rot += PLAYER_TURN_SPEED * dt
				}

				// Forward vector derived from player_rot.
				forward: [2]f32 = {math.sin(player_rot), -math.cos(player_rot)}

				// =================================================
				// MOVEMENT - W/up moves forward, S/down moves backward.
				// =================================================
				move_amount: f32 = 0
				if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
					move_amount += 1
				}
				if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
					move_amount -= 1
				}

				player_pos += forward * move_amount * player_speed * dt

				// Keep the player fully inside the window.
				player_pos.x = clamp(player_pos.x, player_size, sw - player_size)
				player_pos.y = clamp(player_pos.y, player_size, sh - player_size)

				// =================================================
				// SHOOTING - hold SPACE to fire at a fixed rate, aimed
				// in the direction the player is facing.
				// =================================================
				shoot_cooldown -= dt
				if rl.IsKeyDown(.SPACE) && shoot_cooldown <= 0 {
					append(&bullets, Bullet{
						pos     = player_pos,
						dir     = forward,
						speed   = 600.0,
						radius  = bullet_radius,
						alive   = true,
						hostile = false,
					})
					rl.PlaySound(gunshot_sfx) // fire-and-forget; raylib mixes overlapping plays itself
					shoot_cooldown = shoot_cooldown_time
				}

				// =================================================
				// ENEMY SPAWNING - every `enemy_spawn_interval` seconds,
				// drop a new circle just outside a random edge of the
				// screen (top, bottom, left, or right). Speed is drawn
				// from the current wave's [enemy_speed_min, enemy_speed_max]
				// range, which widens as waves advance.
				// =================================================
				enemy_spawn_timer -= dt
				if enemy_spawn_timer <= 0 {
					enemy_spawn_timer = enemy_spawn_interval

					side := rand.int31_max(4)
					spawn_pos: [2]f32
					switch side {
					case 0: // top edge
						spawn_pos = {rand.float32_range(0, sw), -30}
					case 1: // bottom edge
						spawn_pos = {rand.float32_range(0, sw), sh + 30}
					case 2: // left edge
						spawn_pos = {-30, rand.float32_range(0, sh)}
					case: // right edge
						spawn_pos = {sw + 30, rand.float32_range(0, sh)}
					}

					append(&enemies, Enemy{
						pos    = spawn_pos,
						speed  = rand.float32_range(enemy_speed_min, enemy_speed_max),
						radius = 25,
						alive  = true,
					})
				}

				// =================================================
				// ENEMY PLAYER SPAWNING - every ENEMY_PLAYER_CHECK_INTERVAL
				// seconds, roll for a 10% chance to spawn an enemy player.
				// They appear near one of the four walls and stay there.
				// =================================================
				enemy_player_spawn_timer -= dt
				if enemy_player_spawn_timer <= 0 {
					enemy_player_spawn_timer = 10.0

					if rand.float32() < 0.15 {
						side := rand.int31_max(4)
						spawn_pos: [2]f32
						margin: f32 = 60
						lo_x: f32 = margin
						hi_x: f32 = sw - margin
						lo_y: f32 = margin
						hi_y: f32 = sh - margin
						switch side {
						case 0: // top wall
							spawn_pos = {rand.float32_range(lo_x, hi_x), lo_y}
						case 1: // bottom wall
							spawn_pos = {rand.float32_range(lo_x, hi_x), hi_y}
						case 2: // left wall
							spawn_pos = {lo_x, rand.float32_range(lo_y, hi_y)}
						case: // right wall
							spawn_pos = {hi_x, rand.float32_range(lo_y, hi_y)}
						}

						append(&enemy_players, EnemyPlayer{
							pos      = spawn_pos,
							rot      = 0,
							radius   = ENEMY_PLAYER_RADIUS,
							health   = ENEMY_PLAYER_HEALTH,
							shoot_cd = ENEMY_PLAYER_SHOOT_INTERVAL,
							alive    = true,
						})
					}
				}

				// =================================================
				// UPDATE ENEMIES - each one just walks straight at
				// wherever the player is *right now*, so they'll curve
				// in as the player moves.
				// =================================================
				for i in 0 ..< len(enemies) {
					enemy := &enemies[i] // index-based pointer, safe on any Odin version
					if !enemy.alive do continue

					dir := la.normalize0(player_pos - enemy.pos)
					enemy.pos += dir * enemy.speed * dt

					// Enemy-vs-player hit check. The square player is
					// approximated as a circle here to keep the math simple.
					dist := la.length(enemy.pos - player_pos)
					if dist < enemy.radius + player_size * 0.7 {
						enemy.alive = false // enemy is consumed on contact
						if player_hit_timer <= 0 {
							player_health -= 1
							player_hit_timer = 0.5 // ~1 sec of flash/invincibility
							if player_health <= 0 {
								game_over = true
							}
						}
					}
				}

				// =================================================
				// UPDATE ENEMY PLAYERS - they stay camped near their
				// spawn wall, face the player, and fire on a cooldown.
				// =================================================
				for i in 0 ..< len(enemy_players) {
					ep := &enemy_players[i]
					if !ep.alive do continue

					// Face the player.
					to_player := player_pos - ep.pos
					if la.length(to_player) > 0.001 {
						ep.rot = math.atan2(to_player.x, -to_player.y)
					}
					dir := la.normalize0(to_player)

					// Fire on a cooldown. Bullets are aimed at the player's
					// current position (no leading), same as the player's
					// own shots, so dodging is possible.
					ep.shoot_cd -= dt
					if ep.shoot_cd <= 0 {
						ep.shoot_cd = ENEMY_PLAYER_SHOOT_INTERVAL
						append(&bullets, Bullet{
							pos     = ep.pos,
							dir     = dir,
							speed   = ENEMY_PLAYER_BULLET_SPEED,
							radius  = ENEMY_PLAYER_BULLET_RADIUS,
							alive   = true,
							hostile = true,
						})
					}
				}

				if player_hit_timer > 0 {
					player_hit_timer -= dt
				}

				// =================================================
				// UPDATE BULLETS + bullet-vs-target collision
				// =================================================
				for bi in 0 ..< len(bullets) {
					bullet := &bullets[bi]
					if !bullet.alive do continue
					bullet.pos += bullet.dir * bullet.speed * dt

					// Bullets that leave the screen are discarded.
					if bullet.pos.x < 0 || bullet.pos.x > sw ||
					   bullet.pos.y < 0 || bullet.pos.y > sh {
						bullet.alive = false
						continue
					}

					if bullet.hostile {
						// Hostile bullet: check against the player only.
						dist := la.length(bullet.pos - player_pos)
						if dist < bullet.radius + player_size * 0.7 {
							bullet.alive = false
							if player_hit_timer <= 0 {
								player_health -= 1
								player_hit_timer = 0.5
								if player_health <= 0 {
									game_over = true
								}
							}
						}
						continue
					}

					// Friendly bullet: check against enemies first.
					hit_something := false
					for ei in 0 ..< len(enemies) {
						enemy := &enemies[ei]
						if !enemy.alive do continue
						dist := la.length(bullet.pos - enemy.pos)
						if dist < bullet.radius + enemy.radius {
							enemy.alive = false
							bullet.alive = false
							hit_something = true
							score += 1
							points += 1 // earn currency to spend in the skills panel
							rl.PlaySound(zombie_death_sfx) // zombie killed by a bullet

							if score % KILLS_PER_WAVE == 0 {
								wave += 1
								player_health += 2
								enemy_speed_min = min(enemy_speed_min + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MIN_CAP)
								enemy_speed_max = min(enemy_speed_max + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MAX_CAP)
								enemy_spawn_interval = max(enemy_spawn_interval - SPAWN_INTERVAL_DECREASE, SPAWN_INTERVAL_MIN)
							}
							break
						}
					}
					if hit_something do continue

					// Then against enemy players.
					for ei in 0 ..< len(enemy_players) {
						ep := &enemy_players[ei]
						if !ep.alive do continue
						dist := la.length(bullet.pos - ep.pos)
						if dist < bullet.radius + ep.radius {
							bullet.alive = false
							ep.health -= 1
							if ep.health <= 0 {
								ep.alive = false
								score += 1
								points += 1
								rl.PlaySound(zombie_death_sfx)

								if score % KILLS_PER_WAVE == 0 {
									wave += 1
									player_health += 2
									enemy_speed_min = min(enemy_speed_min + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MIN_CAP)
									enemy_speed_max = min(enemy_speed_max + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MAX_CAP)
									enemy_spawn_interval = max(enemy_spawn_interval - SPAWN_INTERVAL_DECREASE, SPAWN_INTERVAL_MIN)
								}
							}
							break
						}
					}
				}

				// =================================================
				// CLEANUP - remove dead enemies/bullets/enemy players so
				// the arrays don't grow without bound. unordered_remove
				// is O(1) since we don't care about ordering here.
				// =================================================
				for i := len(enemies) - 1; i >= 0; i -= 1 {
					if !enemies[i].alive {
						unordered_remove(&enemies, i)
					}
				}
				for i := len(bullets) - 1; i >= 0; i -= 1 {
					if !bullets[i].alive {
						unordered_remove(&bullets, i)
					}
				}
				for i := len(enemy_players) - 1; i >= 0; i -= 1 {
					if !enemy_players[i].alive {
						unordered_remove(&enemy_players, i)
					}
				}
			}

			// Bomb flash countdown runs regardless of pause state so it
			// finishes fading out even if the skills panel stays open.
			if bomb_flash_timer > 0 {
				bomb_flash_timer -= dt
			}
		}

		// =============================================================
		// DRAW
		// =============================================================
		rl.BeginDrawing()
		rl.ClearBackground({20, 20, 30, 255})

		if !game_over {
			// Enemies: the loaded sprite, centered on each enemy's
			// position and scaled to fit the same circular footprint
			// (radius) used for collision. The art faces RIGHT by
			// default, so rotating it to the angle of travel (toward
			// the player) with no extra offset lines it up correctly -
			// unlike the player sprite, which needs a -90 correction.
			enemy_source := rl.Rectangle{0, 0, f32(enemy_tex.width), f32(enemy_tex.height)}
			for enemy in enemies {
				enemy_dir := la.normalize0(player_pos - enemy.pos)
				enemy_rot := math.atan2(enemy_dir.y, enemy_dir.x) * rl.RAD2DEG

				enemy_dest := rl.Rectangle{enemy.pos.x, enemy.pos.y, enemy.radius * 2, enemy.radius * 2}
				enemy_origin := rl.Vector2{enemy.radius, enemy.radius} // center of dest rect, so it rotates in place
				rl.DrawTexturePro(enemy_tex, enemy_source, enemy_dest, enemy_origin, enemy_rot, rl.WHITE)
			}

			// Enemy players. If the sprite loaded correctly, draw it with
			// the same -90 correction as the player sprite and tint it red
			// so it reads as hostile. If the asset is missing or corrupt,
			// fall back to a red circle so the enemy is still visible.
			for ep in enemy_players {
				if enemy_player_tex_ok {
					ep_source := rl.Rectangle{0, 0, f32(enemy_player_tex.width), f32(enemy_player_tex.height)}
					ep_dest := rl.Rectangle{ep.pos.x, ep.pos.y, ep.radius * 2, ep.radius * 2}
					ep_origin := rl.Vector2{ep.radius, ep.radius}
					rl.DrawTexturePro(
						enemy_player_tex,
						ep_source,
						ep_dest,
						ep_origin,
						ep.rot * rl.RAD2DEG - 90,
						rl.Color{255, 120, 120, 255},
					)
				} else {
					rl.DrawCircleV(ep.pos, ep.radius, rl.Color{220, 60, 60, 255})
					rl.DrawCircleLinesV(ep.pos, ep.radius, rl.RED)
				}
			}

			// Bullets: yellow for the player, orange-red for enemy players.
			for bullet in bullets {
				color := rl.YELLOW if !bullet.hostile else rl.Color{255, 100, 60, 255}
				rl.DrawCircleV(bullet.pos, bullet.radius, color)
			}

			// Faint red aim line from the player in the direction they face.
			// Drawn before the player sprite so the sprite sits on top.
			forward: [2]f32 = {math.sin(player_rot), -math.cos(player_rot)}
			aim_end := player_pos + forward * AIM_LINE_LEN
			rl.DrawLineEx(player_pos, aim_end, 2, AIM_LINE_COLOR)

			// Player: the loaded sprite, rotated to match player_rot and
			// scaled to fit the same square footprint used for collision.
			// Flashes red briefly right after taking a hit.
			player_tint := rl.WHITE
			if player_hit_timer > 0 && math.mod(player_hit_timer, 0.2) > 0.1 {
				player_tint = rl.RED
			}

			player_source := rl.Rectangle{0, 0, f32(player_tex.width), f32(player_tex.height)}
			player_dest := rl.Rectangle{player_pos.x, player_pos.y, player_size * 2, player_size * 2}
			player_origin := rl.Vector2{player_size, player_size} // center of dest rect, so it rotates in place

			// -90 corrects for the source art facing right instead of up.
			rl.DrawTexturePro(
				player_tex,
				player_source,
				player_dest,
				player_origin,
				player_rot * rl.RAD2DEG - 90,
				player_tint,
			)

			// Bomb explosion ring - fades out over BOMB_FLASH_TIME seconds
			// right after a bomb is detonated.
			if bomb_flash_timer > 0 {
				alpha := u8(255.0 * (bomb_flash_timer / BOMB_FLASH_TIME))
				rl.DrawCircleLinesV(player_pos, BOMB_RADIUS, rl.Color{255, 165, 0, alpha})
			}

			// HUD
			rl.DrawText(rl.TextFormat("HP: %d", player_health), 10, 10, 24, rl.WHITE)
			rl.DrawText(rl.TextFormat("Score: %d", score), 10, 40, 24, rl.WHITE)
			rl.DrawText(rl.TextFormat("Points: %d", points), 10, 70, 24, rl.YELLOW)
			rl.DrawText(rl.TextFormat("Wave: %d", wave), 10, 100, 24, rl.SKYBLUE)
			rl.DrawText("Move: W/S or up/down    Turn: A/D or left/right    Shoot: Space    Skills: P", SCREEN_W / 2, SCREEN_H - 24, 10, rl.SKYBLUE)

			// =========================================================
			// SKILLS BUTTON - top right corner, toggles the panel below.
			// =========================================================
			rl.DrawRectangleRec(skills_btn, rl.DARKGRAY)
			rl.DrawRectangleLinesEx(skills_btn, 2, rl.WHITE)
			rl.DrawText("Skills", i32(skills_btn.x) + 20, i32(skills_btn.y) + 8, 20, rl.WHITE)

			// =========================================================
			// SKILLS PANEL - only drawn (and only clickable, per the
			// input block above) while skills_open is true.
			// =========================================================
			if skills_open {
				// Dim the game behind the panel so it reads as paused.
				rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 150})

				rl.DrawRectangleRec(rl.Rectangle{panel_x, panel_y, panel_w, panel_h}, rl.Color{30, 30, 40, 255})
				rl.DrawRectangleLinesEx(rl.Rectangle{panel_x, panel_y, panel_w, panel_h}, 2, rl.WHITE)

				rl.DrawText("Skills", i32(panel_x) + 16, i32(panel_y) + 12, 24, rl.WHITE)
				rl.DrawText(rl.TextFormat("Points: %d", points), i32(panel_x) + 16, i32(panel_y) + 44, 20, rl.YELLOW)

				// --- Heal row ---
				rl.DrawText(rl.TextFormat("+1 HP  (currently %d) - %d pts", player_health, HEAL_COST),
					i32(panel_x) + 16, i32(panel_y) + 80, 18, rl.WHITE)
				heal_color := rl.GREEN if points >= HEAL_COST else rl.GRAY
				rl.DrawRectangleRec(heal_btn, heal_color)
				rl.DrawText("Buy", i32(heal_btn.x) + 22, i32(heal_btn.y) + 8, 18, rl.BLACK)

				// --- Speed row ---
				speed_maxed := player_speed >= MAX_PLAYER_SPEED
				rl.DrawText(rl.TextFormat("+10 Speed (max %.0f) - now %.0f - %d pts",
					MAX_PLAYER_SPEED, player_speed, SPEED_COST),
					i32(panel_x) + 16, i32(panel_y) + 140, 18, rl.WHITE)
				speed_can_buy := points >= SPEED_COST && !speed_maxed
				speed_color := rl.GREEN if speed_can_buy else rl.GRAY
				rl.DrawRectangleRec(speed_btn, speed_color)
				speed_label: cstring = "MAX" if speed_maxed else "Buy"
				rl.DrawText(speed_label, i32(speed_btn.x) + 22, i32(speed_btn.y) + 8, 18, rl.BLACK)

				// --- Bullet radius row ---
				bullet_maxed := bullet_radius >= BULLET_RADIUS_MAX
				rl.DrawText(rl.TextFormat("+1 Bullet size (max %.0f) - now %.0f - %d pts",
					BULLET_RADIUS_MAX, bullet_radius, BULLET_RADIUS_COST),
					i32(panel_x) + 16, i32(panel_y) + 200, 18, rl.WHITE)
				bullet_can_buy := points >= BULLET_RADIUS_COST && !bullet_maxed
				bullet_color := rl.GREEN if bullet_can_buy else rl.GRAY
				rl.DrawRectangleRec(bullet_btn, bullet_color)
				bullet_label: cstring = "MAX" if bullet_maxed else "Buy"
				rl.DrawText(bullet_label, i32(bullet_btn.x) + 22, i32(bullet_btn.y) + 8, 18, rl.BLACK)

				// --- Fire rate row ---
				cooldown_maxed := shoot_cooldown_time <= COOLDOWN_MIN
				rl.DrawText(rl.TextFormat("-0.1s Cooldown (min %.1f) - now %.1f - %d pts",
					COOLDOWN_MIN, shoot_cooldown_time, COOLDOWN_COST),
					i32(panel_x) + 16, i32(panel_y) + 260, 18, rl.WHITE)
				cooldown_can_buy := points >= COOLDOWN_COST && !cooldown_maxed
				cooldown_color := rl.GREEN if cooldown_can_buy else rl.GRAY
				rl.DrawRectangleRec(cooldown_btn, cooldown_color)
				cooldown_label: cstring = "MAX" if cooldown_maxed else "Buy"
				rl.DrawText(cooldown_label, i32(cooldown_btn.x) + 22, i32(cooldown_btn.y) + 8, 18, rl.BLACK)

				// --- Bomb row --- (consumable, no max/cap - can be bought repeatedly)
				rl.DrawText(rl.TextFormat("Bomb: kill enemies within %.0f px - %d pts",
					f32(BOMB_RADIUS), BOMB_COST),
					i32(panel_x) + 16, i32(panel_y) + 320, 18, rl.WHITE)
				bomb_can_buy := points >= BOMB_COST
				bomb_color := rl.GREEN if bomb_can_buy else rl.GRAY
				rl.DrawRectangleRec(bomb_btn, bomb_color)
				rl.DrawText("Buy", i32(bomb_btn.x) + 22, i32(bomb_btn.y) + 8, 18, rl.BLACK)

				rl.DrawText("Click Skills or press P to close", i32(panel_x) + 16, i32(panel_y + panel_h) - 28, 16, rl.GRAY)
			}
		} else {
			// Game-over screen.
			msg :: "GAME OVER - press R to restart"
			text_w := rl.MeasureText(msg, 30)
			rl.DrawText(msg, SCREEN_W / 2 - text_w / 2, SCREEN_H / 2 - 15, 30, rl.WHITE)

			score_msg := rl.TextFormat("Final Score: %d", score)
			score_w := rl.MeasureText(score_msg, 24)
			rl.DrawText(score_msg, SCREEN_W / 2 - score_w / 2, SCREEN_H / 2 + 30, 24, rl.WHITE)
		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}