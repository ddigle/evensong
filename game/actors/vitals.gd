class_name Vitals
extends RefCounted
## A player's health, stamina, dash, stagger and life (M4a). Part of the simulation state
## (actors/player_sim.gd): the one frame rule (PlayerSim.step) advances it for the offline player, the
## host and a client's prediction alike; damage comes from outside (PlayerSim.hurt, the combat rules).
## Values are PROVISIONAL (core/config.gd "M4a", README "임시값"). M4b: in a session the host owns them
## (its PlayerSim per member); every state batch carries them (NetProtocol's vitals block, unless they are
## at rest), and a client's prediction replays its frames from the host's.
##
## Life: ALIVE -> (0 HP) DOWN -> (Config.DOWN_TICKS, or holding F GIVE_UP_HOLD_TICKS) DEAD ->
## (Config.RESPAWN_TICKS) the caller respawns it at the altar. A revive (another player holding F,
## combat/arena.gd) takes DOWN back to ALIVE.

enum Life { ALIVE, DOWN, DEAD }

const LIFE_NAMES: PackedStringArray = ["alive", "down", "dead"]

var hp: int = Config.PLAYER_HP_MAX
var stamina: int = Config.STAMINA_MAX
## Ticks before stamina starts coming back, and the regen tick counter.
var stamina_wait: int = 0
var regen_tick: int = 0
## Dash: ticks left, its direction (8-way), ticks before another may start.
var dash_ticks: int = 0
var dash_dir: Vector2i = Vector2i.ZERO
var dash_cooldown: int = 0
## Stagger ticks left after a hit, and ticks no damage lands.
var hurt_ticks: int = 0
var invuln_ticks: int = 0
var life: int = Life.ALIVE
## Ticks since the player went down / died.
var life_ticks: int = 0
## Revive progress (ticks someone has held F next to this downed player) and F held while down.
var revive_ticks: int = 0
var give_up_ticks: int = 0
## Display only: ticks of hit flash left.
var flash_ticks: int = 0
## M6a, the effects (items/potions.gd; PlayerSim.step counts them down): the buff (walking speed percent,
## 100 = none, and ticks left) and the poison (damage per poison tick, ticks left, ticks to the next poison
## tick). M6b: on the wire after the vitals block (NetProtocol's effects block, only while one runs), and a
## running effect is a running timer (idle() false: the client's frames are the host's clock for it).
var buff_pct: int = 100
var buff_ticks: int = 0
var poison_damage: int = 0
var poison_ticks: int = 0
var poison_timer: int = 0


func copy() -> Vitals:
	var c: Vitals = Vitals.new()
	c.hp = hp
	c.stamina = stamina
	c.stamina_wait = stamina_wait
	c.regen_tick = regen_tick
	c.dash_ticks = dash_ticks
	c.dash_dir = dash_dir
	c.dash_cooldown = dash_cooldown
	c.hurt_ticks = hurt_ticks
	c.invuln_ticks = invuln_ticks
	c.life = life
	c.life_ticks = life_ticks
	c.revive_ticks = revive_ticks
	c.give_up_ticks = give_up_ticks
	c.flash_ticks = flash_ticks
	c.buff_pct = buff_pct
	c.buff_ticks = buff_ticks
	c.poison_damage = poison_damage
	c.poison_ticks = poison_ticks
	c.poison_timer = poison_timer
	return c


func same_as(o: Vitals) -> bool:
	return o != null and hp == o.hp and stamina == o.stamina and stamina_wait == o.stamina_wait \
		and regen_tick == o.regen_tick and dash_ticks == o.dash_ticks and dash_dir == o.dash_dir \
		and dash_cooldown == o.dash_cooldown and hurt_ticks == o.hurt_ticks and invuln_ticks == o.invuln_ticks \
		and life == o.life and life_ticks == o.life_ticks and revive_ticks == o.revive_ticks \
		and give_up_ticks == o.give_up_ticks and same_effects(o)


## M4b: every field the wire carries (NetProtocol.put_vitals), the hit flash included (M6b: the effects too).
func same_wire(o: Vitals) -> bool:
	return same_as(o) and flash_ticks == o.flash_ticks


## M4b: no timer runs (stamina full, no dash, cooldown, stagger, invulnerability or flash) and the player
## is up. A client records a frame every tick while this is false, so the host steps it tick by tick.
## M6b: nor a buff or a poison (they count down on the player's frames like the other timers).
func idle() -> bool:
	return life == Life.ALIVE and stamina == Config.STAMINA_MAX and stamina_wait == 0 and regen_tick == 0 \
		and dash_ticks == 0 and dash_dir == Vector2i.ZERO and dash_cooldown == 0 and hurt_ticks == 0 \
		and invuln_ticks == 0 and flash_ticks == 0 and life_ticks == 0 and revive_ticks == 0 and give_up_ticks == 0 \
		and not has_effects()


## M6b: any effect field set (a buff or a poison running; NetProtocol sends the effects block then).
func has_effects() -> bool:
	return buff_pct != 100 or buff_ticks != 0 or poison_damage != 0 or poison_ticks != 0 or poison_timer != 0


## M4b: idle and at full HP: what a fresh player has. A state batch sends no vitals block for it.
func at_rest() -> bool:
	return hp == Config.PLAYER_HP_MAX and idle()


func alive() -> bool:
	return life == Life.ALIVE


func dashing() -> bool:
	return dash_ticks > 0


func staggered() -> bool:
	return hurt_ticks > 0


## No damage lands now (after a hit, or dashing with Config.DASH_INVULNERABLE).
func invulnerable() -> bool:
	return invuln_ticks > 0 or (Config.DASH_INVULNERABLE and dash_ticks > 0)


## Back to full at a respawn (Config.RESPAWN_HP).
func reset(p_hp: int = Config.RESPAWN_HP) -> void:
	hp = p_hp
	stamina = Config.STAMINA_MAX
	stamina_wait = 0
	regen_tick = 0
	dash_ticks = 0
	dash_dir = Vector2i.ZERO
	dash_cooldown = 0
	hurt_ticks = 0
	invuln_ticks = 0
	life = Life.ALIVE
	life_ticks = 0
	revive_ticks = 0
	give_up_ticks = 0
	flash_ticks = 0
	clear_effects()


func describe() -> String:
	return "%s hp=%d st=%d dash=%d cd=%d hurt=%d inv=%d t=%d rev=%d buff=%d/%d poison=%d/%d/%d" % [LIFE_NAMES[life], hp,
		stamina, dash_ticks,
		dash_cooldown, hurt_ticks, invuln_ticks, life_ticks, revive_ticks, buff_pct, buff_ticks, poison_damage, poison_ticks,
		poison_timer]


## M6a: the same buff and poison (same_as includes it).
func same_effects(o: Vitals) -> bool:
	return buff_pct == o.buff_pct and buff_ticks == o.buff_ticks and poison_damage == o.poison_damage \
		and poison_ticks == o.poison_ticks and poison_timer == o.poison_timer


func buffed() -> bool:
	return buff_ticks > 0


func poisoned() -> bool:
	return poison_ticks > 0


## M6a: no buff, no poison (going down, a respawn: Config.EFFECTS_END_ON_DOWN).
func clear_effects() -> void:
	buff_pct = 100
	buff_ticks = 0
	poison_damage = 0
	poison_ticks = 0
	poison_timer = 0
