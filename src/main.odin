package main

import rl "vendor:raylib"
import la "core:math/linalg"
import "core:math/rand"
import "core:math"

// ---------------------------------------------------------------------
// Entities
// ---------------------------------------------------------------------
Enemy :: struct {
	pos:    [2]f32,
	speed:  f32,
	radius: f32,
	alive:  bool,
}

EnemyPlayer :: struct {
	pos:      [2]f32,
	rot:      f32, // facing direction in radians (0 = up), used for drawing
	radius:   f32,
	health:   int,
	shoot_cd: f32,    // time until the next telegraph starts
	windup:   f32,    // >0 while telegraphing a shot
	aim_dir:  [2]f32, // direction locked in when the telegraph starts
	alive:    bool,
}

Bullet :: struct {
	pos:     [2]f32,
	dir:     [2]f32,
	speed:   f32,
	radius:  f32,
	alive:   bool,
	hostile: bool, // true if fired by an enemy player
}

// ---------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------
SCREEN_W :: 1280
SCREEN_H :: 720

// ---------------- Player ----------------
PLAYER_SIZE         :: 25.0 // half-width of the sprite
PLAYER_HIT_RADIUS   :: PLAYER_SIZE * 0.7
PLAYER_START_HEALTH :: 10
PLAYER_TURN_SPEED   :: 3.0 // radians per second
PLAYER_BULLET_SPEED :: 600.0
DAMAGE_POINT_PENALTY :: 5 // points lost whenever the player takes damage

BASE_PLAYER_SPEED  :: 100.0
MAX_PLAYER_SPEED   :: 300.0
SPEED_PER_PURCHASE :: 10.0

// ---------------- Shop costs / caps ----------------
HEAL_COST  :: 8
SPEED_COST :: 6

BULLET_RADIUS_BASE         :: 2.0
BULLET_RADIUS_MAX          :: 5.0
BULLET_RADIUS_COST         :: 6
BULLET_RADIUS_PER_PURCHASE :: 1.0

COOLDOWN_BASE         :: 1.0
COOLDOWN_MIN          :: 0.2
COOLDOWN_COST         :: 8
COOLDOWN_PER_PURCHASE :: 0.1

// Bombs: buy one to add it to your inventory, then hold B to preview the
// blast radius and release B to drop it. The radius is a permanent upgrade.
BOMB_COST                 :: 15
BOMB_RADIUS_BASE          :: 80.0
BOMB_RADIUS_MAX           :: 160.0
BOMB_RADIUS_COST          :: 8
BOMB_RADIUS_PER_PURCHASE  :: 20.0
BOMB_FLASH_TIME           :: 0.25 // how long the explosion ring is drawn for

// Aim line: a faint red line from the player in the direction they face.
AIM_LINE_LEN   :: 160
AIM_LINE_COLOR :: rl.Color{255, 60, 60, 80}

// ---------------- Enemy player ----------------
ENEMY_PLAYER_CHECK_INTERVAL :: 5.0  // roll for a spawn this often (seconds)
ENEMY_PLAYER_SPAWN_CHANCE   :: 0.30 // chance per roll
ENEMY_PLAYER_RADIUS         :: 22.0
ENEMY_PLAYER_HEALTH         :: 1
ENEMY_PLAYER_BULLET_SPEED   :: 200.0
ENEMY_PLAYER_BULLET_RADIUS  :: 3.0
ENEMY_PLAYER_WALL_MARGIN    :: 60.0 // how far from the wall the enemy player camps
ENEMY_PLAYER_KILL_REWARD    :: 4    // points for killing one

// Telegraph: the aim locks and a red line fades in for this long before the shot.
ENEMY_PLAYER_WINDUP :: 0.6
ENEMY_PLAYER_LINE_LEN :: 1500.0

// Fire rate: the cooldown between shots starts at 4s and drops by 1s every
// 4 waves, down to a minimum of 1s.
ENEMY_PLAYER_SHOOT_INTERVAL :: 4.0
ENEMY_PLAYER_INTERVAL_STEP  :: 1.0
ENEMY_PLAYER_MIN_INTERVAL   :: 1.0
ENEMY_PLAYER_WAVES_PER_STEP :: 4

// ---------------- Waves / difficulty ----------------
KILLS_PER_WAVE          :: 20
BASE_SPAWN_INTERVAL     :: 2.0
SPAWN_INTERVAL_DECREASE :: 0.2
SPAWN_INTERVAL_MIN      :: 0.2
BASE_ENEMY_SPEED_MIN    :: 40.0
BASE_ENEMY_SPEED_MAX    :: 80.0
ENEMY_SPEED_INCREASE    :: 10.0
ENEMY_SPEED_MIN_CAP     :: 140.0
ENEMY_SPEED_MAX_CAP     :: 180.0
ENEMY_RADIUS            :: 25.0

// ---------------- Skills UI layout ----------------
SKILLS_BTN :: rl.Rectangle{SCREEN_W - 140, 10, 120, 36}
PANEL_W    :: 520.0
PANEL_H    :: 460.0
PANEL_X    :: (SCREEN_W - PANEL_W) / 2
PANEL_Y    :: (SCREEN_H - PANEL_H) / 2

// ---------------------------------------------------------------------
// Game state: everything that resets on restart lives here.
// ---------------------------------------------------------------------
Game :: struct {
	// player
	player_pos:          [2]f32,
	player_rot:          f32,
	player_health:       int,
	player_speed:        f32,
	player_hit_timer:    f32, // >0 while flashing / briefly invincible
	bullet_radius:       f32,
	shoot_cooldown_time: f32, // upgradeable: seconds between shots
	shoot_cooldown:      f32, // current countdown

	// bombs
	bombs:             int, // bombs in inventory
	bomb_radius:       f32, // upgradeable blast radius
	bomb_flash_timer:  f32,
	bomb_flash_pos:    [2]f32,
	bomb_flash_radius: f32,

	// difficulty
	enemy_spawn_timer:        f32,
	enemy_spawn_interval:     f32,
	enemy_speed_min:          f32,
	enemy_speed_max:          f32,
	enemy_player_spawn_timer: f32,

	// progress
	score:     int, // kill counter
	points:    int, // spendable currency
	wave:      int,
	game_over: bool,

	enemies:       [dynamic]Enemy,
	bullets:       [dynamic]Bullet,
	enemy_players: [dynamic]EnemyPlayer,
}

Sfx :: struct {
	gunshot, enemy_hurt, player_hurt, zombie_death: rl.Sound,
}
sfx: Sfx

reset_game :: proc(g: ^Game) {
	// Keep the dynamic arrays (and their memory), reset everything else.
	enemies, bullets, enemy_players := g.enemies, g.bullets, g.enemy_players
	g^ = Game{
		player_pos               = {SCREEN_W / 2, SCREEN_H / 2},
		player_health            = PLAYER_START_HEALTH,
		player_speed             = BASE_PLAYER_SPEED,
		bullet_radius            = BULLET_RADIUS_BASE,
		shoot_cooldown_time      = COOLDOWN_BASE,
		bomb_radius              = BOMB_RADIUS_BASE,
		enemy_spawn_interval     = BASE_SPAWN_INTERVAL,
		enemy_speed_min          = BASE_ENEMY_SPEED_MIN,
		enemy_speed_max          = BASE_ENEMY_SPEED_MAX,
		enemy_player_spawn_timer = ENEMY_PLAYER_CHECK_INTERVAL,
		wave                     = 1,
		enemies                  = enemies,
		bullets                  = bullets,
		enemy_players            = enemy_players,
	}
	clear(&g.enemies)
	clear(&g.bullets)
	clear(&g.enemy_players)
}

// ---------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------
forward_vec :: proc(rot: f32) -> [2]f32 {
	return {math.sin(rot), -math.cos(rot)}
}

// Random point on one of the four edges of the given rectangle.
random_edge_pos :: proc(lo_x, hi_x, lo_y, hi_y: f32) -> [2]f32 {
	switch rand.int31_max(4) {
	case 0:  return {rand.float32_range(lo_x, hi_x), lo_y} // top
	case 1:  return {rand.float32_range(lo_x, hi_x), hi_y} // bottom
	case 2:  return {lo_x, rand.float32_range(lo_y, hi_y)} // left
	case:    return {hi_x, rand.float32_range(lo_y, hi_y)} // right
	}
}

// Seconds between enemy player shots for the given wave: 4s for waves 1-4,
// 3s for waves 5-8, 2s for waves 9-12, then 1s from wave 13 on.
enemy_player_interval :: proc(wave: int) -> f32 {
	steps := f32((wave - 1) / ENEMY_PLAYER_WAVES_PER_STEP)
	return max(ENEMY_PLAYER_SHOOT_INTERVAL - steps * ENEMY_PLAYER_INTERVAL_STEP, ENEMY_PLAYER_MIN_INTERVAL)
}

// Every kill (bullet or bomb) goes through here: score, currency, and
// the wave ramp-up all live in one place. `value` is the points awarded.
register_kill :: proc(g: ^Game, value := 1) {
	g.score += 1
	g.points += value
	if g.score % KILLS_PER_WAVE == 0 {
		g.wave += 1
		g.player_health += 2
		g.enemy_speed_min = min(g.enemy_speed_min + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MIN_CAP)
		g.enemy_speed_max = min(g.enemy_speed_max + ENEMY_SPEED_INCREASE, ENEMY_SPEED_MAX_CAP)
		g.enemy_spawn_interval = max(g.enemy_spawn_interval - SPAWN_INTERVAL_DECREASE, SPAWN_INTERVAL_MIN)
	}
}

// Damages the player unless they're still in their invincibility window.
// Every real hit also costs points (never below zero).
hurt_player :: proc(g: ^Game, invincible_for: f32) {
	if g.player_hit_timer > 0 do return
	g.player_health -= 1
	g.player_hit_timer = invincible_for
	g.points = max(g.points - DAMAGE_POINT_PENALTY, 0)
	rl.PlaySound(sfx.player_hurt)
	if g.player_health <= 0 {
		g.game_over = true
	}
}

remove_dead :: proc(arr: ^[dynamic]$T) {
	for i := len(arr^) - 1; i >= 0; i -= 1 {
		if !arr^[i].alive {
			unordered_remove(arr, i)
		}
	}
}

// Drops a bomb at the player's current position.
detonate_bomb :: proc(g: ^Game) {
	g.bomb_flash_timer = BOMB_FLASH_TIME
	g.bomb_flash_pos = g.player_pos
	g.bomb_flash_radius = g.bomb_radius

	kills := 0
	for i in 0 ..< len(g.enemies) {
		enemy := &g.enemies[i]
		if !enemy.alive do continue
		if la.length(enemy.pos - g.player_pos) < g.bomb_radius + enemy.radius {
			enemy.alive = false
			register_kill(g)
			kills += 1
		}
	}

	// Enemy players take one point of damage per bomb.
	for i in 0 ..< len(g.enemy_players) {
		ep := &g.enemy_players[i]
		if !ep.alive do continue
		if la.length(ep.pos - g.player_pos) < g.bomb_radius + ep.radius {
			ep.health -= 1
			if ep.health <= 0 {
				ep.alive = false
				register_kill(g, ENEMY_PLAYER_KILL_REWARD)
				kills += 1
			}
		}
	}

	// One death sound per bomb so a big blast doesn't stack into noise.
	if kills > 0 {
		rl.PlaySound(sfx.zombie_death)
	}
}

// ---------------------------------------------------------------------
// Shop
// ---------------------------------------------------------------------
Upgrade :: enum {
	Heal,
	Speed,
	Bullet_Size,
	Cooldown,
	Bomb_Radius,
	Bomb,
}

upgrade_btn_rect :: proc(u: Upgrade) -> rl.Rectangle {
	return {PANEL_X + PANEL_W - 110, PANEL_Y + 70 + f32(u) * 60, 90, 34}
}

// Label, cost and "is maxed" for a shop row. Used by both the click
// handler and the drawing code so they can never disagree.
upgrade_info :: proc(g: ^Game, u: Upgrade) -> (label: cstring, cost: int, maxed: bool) {
	switch u {
	case .Heal:
		return rl.TextFormat("+1 HP (now %d) - %d pts", g.player_health, HEAL_COST),
			HEAL_COST, false
	case .Speed:
		return rl.TextFormat("+10 Speed (max %.0f) - now %.0f - %d pts",
			f32(MAX_PLAYER_SPEED), g.player_speed, SPEED_COST),
			SPEED_COST, g.player_speed >= MAX_PLAYER_SPEED
	case .Bullet_Size:
		return rl.TextFormat("+1 Bullet size (max %.0f) - now %.0f - %d pts",
			f32(BULLET_RADIUS_MAX), g.bullet_radius, BULLET_RADIUS_COST),
			BULLET_RADIUS_COST, g.bullet_radius >= BULLET_RADIUS_MAX
	case .Cooldown:
		return rl.TextFormat("-0.1s Cooldown (min %.1f) - now %.1f - %d pts",
			f32(COOLDOWN_MIN), g.shoot_cooldown_time, COOLDOWN_COST),
			COOLDOWN_COST, g.shoot_cooldown_time <= COOLDOWN_MIN + 0.001
	case .Bomb_Radius:
		return rl.TextFormat("+20 Bomb radius (max %.0f) - now %.0f - %d pts",
			f32(BOMB_RADIUS_MAX), g.bomb_radius, BOMB_RADIUS_COST),
			BOMB_RADIUS_COST, g.bomb_radius >= BOMB_RADIUS_MAX
	case .Bomb:
		return rl.TextFormat("Bomb (owned %d) hold B, release to drop - %d pts", g.bombs, BOMB_COST),
			BOMB_COST, false
	}
	return "", 0, true
}

buy_upgrade :: proc(g: ^Game, u: Upgrade) {
	_, cost, maxed := upgrade_info(g, u)
	if maxed || g.points < cost do return
	g.points -= cost

	switch u {
	case .Heal:
		g.player_health += 1
	case .Speed:
		g.player_speed = min(g.player_speed + SPEED_PER_PURCHASE, MAX_PLAYER_SPEED)
	case .Bullet_Size:
		g.bullet_radius = min(g.bullet_radius + BULLET_RADIUS_PER_PURCHASE, BULLET_RADIUS_MAX)
	case .Cooldown:
		g.shoot_cooldown_time = max(g.shoot_cooldown_time - COOLDOWN_PER_PURCHASE, COOLDOWN_MIN)
	case .Bomb_Radius:
		g.bomb_radius = min(g.bomb_radius + BOMB_RADIUS_PER_PURCHASE, BOMB_RADIUS_MAX)
	case .Bomb:
		g.bombs += 1
	}
}

draw_shop :: proc(g: ^Game) {
	// Dim the game behind the panel so it reads as paused.
	rl.DrawRectangle(0, 0, SCREEN_W, SCREEN_H, rl.Color{0, 0, 0, 150})

	panel := rl.Rectangle{PANEL_X, PANEL_Y, PANEL_W, PANEL_H}
	rl.DrawRectangleRec(panel, rl.Color{30, 30, 40, 255})
	rl.DrawRectangleLinesEx(panel, 2, rl.WHITE)

	rl.DrawText("Skills", i32(PANEL_X) + 16, i32(PANEL_Y) + 12, 24, rl.WHITE)
	rl.DrawText(rl.TextFormat("Points: %d", g.points), i32(PANEL_X) + 16, i32(PANEL_Y) + 44, 20, rl.YELLOW)

	for u in Upgrade {
		label, cost, maxed := upgrade_info(g, u)
		btn := upgrade_btn_rect(u)
		can_buy := g.points >= cost && !maxed

		rl.DrawText(label, i32(PANEL_X) + 16, i32(btn.y) + 8, 18, rl.WHITE)
		rl.DrawRectangleRec(btn, rl.GREEN if can_buy else rl.GRAY)
		btn_text: cstring = "MAX" if maxed else "Buy"
		rl.DrawText(btn_text, i32(btn.x) + 22, i32(btn.y) + 8, 18, rl.BLACK)
	}

	rl.DrawText("Click Skills or press P to close", i32(PANEL_X) + 16, i32(PANEL_Y + PANEL_H) - 28, 16, rl.GRAY)
}

// ---------------------------------------------------------------------
// Per-frame simulation (skipped entirely while the shop is open)
// ---------------------------------------------------------------------
update_game :: proc(g: ^Game, dt: f32) {
	// ---- Rotation / movement ----
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A)  do g.player_rot -= PLAYER_TURN_SPEED * dt
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do g.player_rot += PLAYER_TURN_SPEED * dt

	forward := forward_vec(g.player_rot)

	move: f32 = 0
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W)   do move += 1
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) do move -= 1

	g.player_pos += forward * move * g.player_speed * dt
	g.player_pos.x = clamp(g.player_pos.x, PLAYER_SIZE, SCREEN_W - PLAYER_SIZE)
	g.player_pos.y = clamp(g.player_pos.y, PLAYER_SIZE, SCREEN_H - PLAYER_SIZE)

	// ---- Shooting: hold SPACE ----
	g.shoot_cooldown -= dt
	if rl.IsKeyDown(.SPACE) && g.shoot_cooldown <= 0 {
		append(&g.bullets, Bullet{
			pos    = g.player_pos,
			dir    = forward,
			speed  = PLAYER_BULLET_SPEED,
			radius = g.bullet_radius,
			alive  = true,
		})
		rl.PlaySound(sfx.gunshot)
		g.shoot_cooldown = g.shoot_cooldown_time
	}

	// ---- Bomb: hold B to preview (drawn elsewhere), release to drop ----
	if g.bombs > 0 && rl.IsKeyReleased(.B) {
		g.bombs -= 1
		detonate_bomb(g)
	}

	// ---- Enemy spawning (just off-screen on a random edge) ----
	g.enemy_spawn_timer -= dt
	if g.enemy_spawn_timer <= 0 {
		g.enemy_spawn_timer = g.enemy_spawn_interval
		append(&g.enemies, Enemy{
			pos    = random_edge_pos(-30, SCREEN_W + 30, -30, SCREEN_H + 30),
			speed  = rand.float32_range(g.enemy_speed_min, g.enemy_speed_max),
			radius = ENEMY_RADIUS,
			alive  = true,
		})
	}

	// ---- Enemy player spawning (rolls periodically, camps near a wall) ----
	g.enemy_player_spawn_timer -= dt
	if g.enemy_player_spawn_timer <= 0 {
		g.enemy_player_spawn_timer = ENEMY_PLAYER_CHECK_INTERVAL
		if rand.float32() < ENEMY_PLAYER_SPAWN_CHANCE {
			m :: ENEMY_PLAYER_WALL_MARGIN
			append(&g.enemy_players, EnemyPlayer{
				pos      = random_edge_pos(m, SCREEN_W - m, m, SCREEN_H - m),
				radius   = ENEMY_PLAYER_RADIUS,
				health   = ENEMY_PLAYER_HEALTH,
				shoot_cd = enemy_player_interval(g.wave),
				alive    = true,
			})
		}
	}

	// ---- Enemies walk straight at the player and are consumed on contact ----
	for i in 0 ..< len(g.enemies) {
		enemy := &g.enemies[i]
		if !enemy.alive do continue

		enemy.pos += la.normalize0(g.player_pos - enemy.pos) * enemy.speed * dt

		if la.length(enemy.pos - g.player_pos) < enemy.radius + PLAYER_HIT_RADIUS {
			enemy.alive = false
			hurt_player(g, 0.25)
		}
	}

	// ---- Enemy players: track the player, telegraph, then fire ----
	for i in 0 ..< len(g.enemy_players) {
		ep := &g.enemy_players[i]
		if !ep.alive do continue

		if ep.windup > 0 {
			// Telegraphing: aim is locked, so the player can dodge the shot.
			ep.windup -= dt
			if ep.windup <= 0 {
				append(&g.bullets, Bullet{
					pos     = ep.pos,
					dir     = ep.aim_dir,
					speed   = ENEMY_PLAYER_BULLET_SPEED,
					radius  = ENEMY_PLAYER_BULLET_RADIUS,
					alive   = true,
					hostile = true,
				})
				ep.shoot_cd = enemy_player_interval(g.wave)
			}
		} else {
			// Tracking: face the player until the cooldown ends.
			to_player := g.player_pos - ep.pos
			if la.length(to_player) > 0.001 {
				ep.rot = math.atan2(to_player.x, -to_player.y)
			}

			ep.shoot_cd -= dt
			if ep.shoot_cd <= 0 {
				// Lock the aim and start the telegraph.
				ep.windup = ENEMY_PLAYER_WINDUP
				ep.aim_dir = la.normalize0(to_player)
			}
		}
	}

	if g.player_hit_timer > 0 {
		g.player_hit_timer -= dt
	}

	// ---- Bullets ----
	for bi in 0 ..< len(g.bullets) {
		bullet := &g.bullets[bi]
		if !bullet.alive do continue
		bullet.pos += bullet.dir * bullet.speed * dt

		if bullet.pos.x < 0 || bullet.pos.x > SCREEN_W ||
		   bullet.pos.y < 0 || bullet.pos.y > SCREEN_H {
			bullet.alive = false
			continue
		}

		if bullet.hostile {
			if la.length(bullet.pos - g.player_pos) < bullet.radius + PLAYER_HIT_RADIUS {
				bullet.alive = false
				hurt_player(g, 0.5)
			}
			continue
		}

		// Friendly bullet: enemies first, then enemy players.
		hit := false
		for ei in 0 ..< len(g.enemies) {
			enemy := &g.enemies[ei]
			if !enemy.alive do continue
			if la.length(bullet.pos - enemy.pos) < bullet.radius + enemy.radius {
				enemy.alive = false
				bullet.alive = false
				register_kill(g)
				rl.PlaySound(sfx.zombie_death)
				hit = true
				break
			}
		}
		if hit do continue

		for ei in 0 ..< len(g.enemy_players) {
			ep := &g.enemy_players[ei]
			if !ep.alive do continue
			if la.length(bullet.pos - ep.pos) < bullet.radius + ep.radius {
				bullet.alive = false
				ep.health -= 1
				if ep.health <= 0 {
					ep.alive = false
					register_kill(g, ENEMY_PLAYER_KILL_REWARD)
					rl.PlaySound(sfx.enemy_hurt)
				}
				break
			}
		}
	}

	remove_dead(&g.enemies)
	remove_dead(&g.bullets)
	remove_dead(&g.enemy_players)
}

// ---------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------
// Draws a texture centered on `pos`, scaled to a square of side `half*2`
// and rotated in place.
draw_sprite :: proc(tex: rl.Texture2D, pos: [2]f32, half: f32, rot_deg: f32, tint: rl.Color) {
	src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
	dst := rl.Rectangle{pos.x, pos.y, half * 2, half * 2}
	rl.DrawTexturePro(tex, src, dst, {half, half}, rot_deg, tint)
}

main :: proc() {
	rl.InitWindow(SCREEN_W, SCREEN_H, "Odin + Raylib - Square vs Circles")
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	// Sprites. The player and enemy-player art face RIGHT, so they get a
	// -90 degree offset at draw time (our 0 rotation means "up"). The
	// zombie art faces RIGHT and is rotated by its travel angle directly.
	player_tex := rl.LoadTexture("../assets/player.png")
	defer rl.UnloadTexture(player_tex)

	enemy_tex := rl.LoadTexture("../assets/enemy1.png")
	defer rl.UnloadTexture(enemy_tex)

	enemy_player_tex := rl.LoadTexture("../assets/enemy-player.png")
	defer rl.UnloadTexture(enemy_player_tex)
	enemy_player_tex_ok := enemy_player_tex.width > 0 && enemy_player_tex.height > 0

	sfx.gunshot      = rl.LoadSound("../assets/gun-shot.mp3")
	sfx.enemy_hurt   = rl.LoadSound("../assets/enemy-hurt.mp3")
	sfx.player_hurt  = rl.LoadSound("../assets/player-hurt.mp3")
	sfx.zombie_death = rl.LoadSound("../assets/zombie-death.mp3")
	defer rl.UnloadSound(sfx.gunshot)
	defer rl.UnloadSound(sfx.enemy_hurt)
	defer rl.UnloadSound(sfx.player_hurt)
	defer rl.UnloadSound(sfx.zombie_death)

	g: Game
	reset_game(&g)
	defer delete(g.enemies)
	defer delete(g.bullets)
	defer delete(g.enemy_players)

	// Opening the skills menu pauses gameplay without closing the window.
	skills_open := false

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		// ---------------- Input + simulation ----------------
		if g.game_over {
			if rl.IsKeyPressed(.R) {
				reset_game(&g)
				skills_open = false
			}
		} else {
			if rl.IsKeyPressed(.P) {
				skills_open = !skills_open
			}

			if rl.IsMouseButtonPressed(.LEFT) {
				mouse := rl.GetMousePosition()
				if rl.CheckCollisionPointRec(mouse, SKILLS_BTN) {
					skills_open = !skills_open
				} else if skills_open {
					for u in Upgrade {
						if rl.CheckCollisionPointRec(mouse, upgrade_btn_rect(u)) {
							buy_upgrade(&g, u)
						}
					}
				}
			}

			if !skills_open {
				update_game(&g, dt)
			}

			// Runs even while paused so the ring finishes fading out.
			if g.bomb_flash_timer > 0 {
				g.bomb_flash_timer -= dt
			}
		}

		// ---------------- Drawing ----------------
		rl.BeginDrawing()
		rl.ClearBackground({20, 20, 30, 255})

		if !g.game_over {
			// Zombies: rotated to face the player (art faces RIGHT).
			for enemy in g.enemies {
				dir := la.normalize0(g.player_pos - enemy.pos)
				angle := math.atan2(dir.y, dir.x) * rl.RAD2DEG
				draw_sprite(enemy_tex, enemy.pos, enemy.radius, angle, rl.WHITE)
			}

			// Enemy players (falls back to a red circle if the sprite failed to load).
			for ep in g.enemy_players {
				// Telegraph: a red line that fades in along the locked aim direction.
				if ep.windup > 0 {
					progress := 1.0 - ep.windup / ENEMY_PLAYER_WINDUP
					alpha := u8(40.0 + 215.0 * progress)
					line_end := ep.pos + ep.aim_dir * ENEMY_PLAYER_LINE_LEN
					rl.DrawLineEx(ep.pos, line_end, 2, rl.Color{255, 60, 60, alpha})
				}

				if enemy_player_tex_ok {
					draw_sprite(enemy_player_tex, ep.pos, ep.radius, ep.rot * rl.RAD2DEG - 90, rl.WHITE)
				} else {
					rl.DrawCircleV(ep.pos, ep.radius, rl.Color{220, 60, 60, 255})
					rl.DrawCircleLinesV(ep.pos, ep.radius, rl.RED)
				}
			}

			// Bullets: yellow for the player, orange-red for enemy players.
			for bullet in g.bullets {
				color := rl.YELLOW if !bullet.hostile else rl.Color{255, 100, 60, 255}
				rl.DrawCircleV(bullet.pos, bullet.radius, color)
			}

			// Aim line (drawn before the player so the sprite sits on top).
			aim_end := g.player_pos + forward_vec(g.player_rot) * AIM_LINE_LEN
			rl.DrawLineEx(g.player_pos, aim_end, 2, AIM_LINE_COLOR)

			// Player, flashing red briefly after a hit.
			tint := rl.WHITE
			if g.player_hit_timer > 0 && math.mod(g.player_hit_timer, 0.2) > 0.1 {
				tint = rl.RED
			}
			draw_sprite(player_tex, g.player_pos, PLAYER_SIZE, g.player_rot * rl.RAD2DEG - 90, tint)

			// Bomb preview: shown while B is held and a bomb is available.
			if g.bombs > 0 && !skills_open && rl.IsKeyDown(.B) {
				rl.DrawCircleV(g.player_pos, g.bomb_radius, rl.Color{255, 165, 0, 40})
				rl.DrawCircleLinesV(g.player_pos, g.bomb_radius, rl.ORANGE)
			}

			// Explosion ring, fading out right after a bomb drops.
			if g.bomb_flash_timer > 0 {
				alpha := u8(255.0 * (g.bomb_flash_timer / BOMB_FLASH_TIME))
				rl.DrawCircleLinesV(g.bomb_flash_pos, g.bomb_flash_radius, rl.Color{255, 165, 0, alpha})
			}

			// HUD
			rl.DrawText(rl.TextFormat("HP: %d", g.player_health), 10, 10, 24, rl.WHITE)
			rl.DrawText(rl.TextFormat("Score: %d", g.score), 10, 40, 24, rl.WHITE)
			rl.DrawText(rl.TextFormat("Points: %d", g.points), 10, 70, 24, rl.YELLOW)
			rl.DrawText(rl.TextFormat("Wave: %d", g.wave), 10, 100, 24, rl.SKYBLUE)
			rl.DrawText(rl.TextFormat("Bombs: %d", g.bombs), 10, 130, 24, rl.ORANGE)
			rl.DrawText("Move: W/S    Turn: A/D or left/right    Shoot: Space    Bomb: hold B, release to drop    Skills: P",
				10, SCREEN_H - 24, 10, rl.SKYBLUE)

			// Skills button (top right) + panel.
			rl.DrawRectangleRec(SKILLS_BTN, rl.DARKGRAY)
			rl.DrawRectangleLinesEx(SKILLS_BTN, 2, rl.WHITE)
			rl.DrawText("Skills", i32(SKILLS_BTN.x) + 20, i32(SKILLS_BTN.y) + 8, 20, rl.WHITE)

			if skills_open {
				draw_shop(&g)
			}
		} else {
			msg :: "GAME OVER - press R to restart"
			text_w := rl.MeasureText(msg, 30)
			rl.DrawText(msg, SCREEN_W / 2 - text_w / 2, SCREEN_H / 2 - 15, 30, rl.WHITE)

			score_msg := rl.TextFormat("Final Score: %d", g.score)
			score_w := rl.MeasureText(score_msg, 24)
			rl.DrawText(score_msg, SCREEN_W / 2 - score_w / 2, SCREEN_H / 2 + 30, 24, rl.WHITE)
		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}