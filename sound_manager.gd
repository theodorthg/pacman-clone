class_name SoundManager
extends Node

## Central audio manager for the Pac-Man clone. The game coordinator fires the
## one-shots (play_*) and pushes the ambient state once per frame
## (update_ambient); this node decides which background loop is audible,
## following the original arcade rules:
##
##   - normal siren        while dangerous ghosts roam the maze
##   - frightened          while the blue phase runs (fast-move loop + the
##                         power-pellet loop layered together)
##   - retreating eyes     while >=1 eaten ghost heads home (takes over the
##                         movement loop; the power-pellet loop keeps going if
##                         the blue phase is still active underneath)
##   - silence             during READY!, the death sequence, menus, level clear
##
## VOLUME MODEL. Every sound has a fixed mix-calibration offset (`_BASE_DB`,
## tuned by ear against the very different raw asset levels) plus a 0-100 %
## slider the player sets in the Sound menu. Final level =
## `_BASE_DB[key] + linear_to_db(pct/100)`, so 100 % already sounds balanced and
## the slider just trims from there. Percentages live in section "sound" of
## user://settings.cfg (with a `_ver` so an old file is ignored, not misread).
##
## The node keeps the default (pausable) process mode so the pause menu mutes
## the game mix automatically; only the dedicated `preview` player is ALWAYS.

const _DIR := "res://assets/sounds/"
const _CFG_PATH := "user://settings.cfg"
const _CFG_SECTION := "sound"
## Bump when the volume formula / calibration changes so old stored %s are
## dropped (reset to the calibrated 100 % defaults), not misread.
const SOUND_CFG_VERSION := 3

const _PILL_BASE_SPEED := 110.0

## Every adjustable sound, in menu order:  key -> [display name, default %]
const SOUNDS := {
	"start":     ["Game start", 100],
	"pill":      ["Eat dot", 100],
	"eat_item":  ["Eat fruit / power pill", 100],
	"eat_ghost": ["Eat ghost", 100],
	"death":     ["Pac-Man death", 100],
	"levelup":   ["Level clear", 100],
	"normal":    ["Ghost siren", 100],
	"fright":    ["Ghosts frightened", 100],
	"power":     ["Power-pellet loop", 100],
	"eyes":      ["Ghost eyes (return home)", 100],
}

## Mix calibration: dB applied at 100 %. Tuned by ear against the raw asset
## levels so every slider can sit at 100 % and still sound balanced.
const _BASE_DB := {
	"start":     -18.4,
	"pill":      -26.0,
	"eat_item":   -6.4,
	"eat_ghost": -16.0,
	"death":     -20.0,
	"levelup":   -14.0,
	"normal":    -25.2,
	"fright":    -23.1,
	"power":     -22.0,
	"eyes":      -20.5,
}

## key -> [file, max_polyphony]
const _ONESHOT_FILES := {
	"start":     ["starting-sound.wav", 1],
	"pill":      ["pacman-eating-pill-short.wav", 1],
	"eat_item":  ["pacman-eat-item.wav", 3],
	"eat_ghost": ["pacman-eating-ghost.wav", 2],
	"death":     ["pacman-death.wav", 1],
	"levelup":   ["win-sound.wav", 1],
}

## key -> file
const _LOOP_FILES := {
	"normal": "ghosts-move-normal.wav",
	"fright": "ghosts-move-fast.wav",
	"power":  "ghosts-catchable after eating big pill short.wav",
	"eyes":   "ghost-catched-move-home.wav",
}

var _oneshot: Dictionary = {}          ## key -> AudioStreamPlayer
var _loop: Dictionary = {}             ## key -> AudioStreamPlayer
var _loop_wanted: Dictionary = {}      ## key -> bool (survives a natural finish)
var _volume_pct: Dictionary = {}       ## key -> 0..100
var _preview: AudioStreamPlayer
var _preview_gen: int = 0


func _ready() -> void:
	for key in _ONESHOT_FILES:
		var cfg: Array = _ONESHOT_FILES[key]
		var p := AudioStreamPlayer.new()
		p.name = "oneshot_" + key
		p.stream = load(_DIR + cfg[0])
		p.max_polyphony = int(cfg[1])
		add_child(p)
		_oneshot[key] = p

	for key in _LOOP_FILES:
		var lp := AudioStreamPlayer.new()
		lp.name = "loop_" + key
		lp.stream = _looped(load(_DIR + _LOOP_FILES[key]))
		add_child(lp)
		lp.finished.connect(_on_loop_finished.bind(key))
		_loop[key] = lp
		_loop_wanted[key] = false

	_preview = AudioStreamPlayer.new()
	_preview.name = "preview"
	_preview.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_preview)

	_load_volumes()
	_apply_volumes()


## Copy the stream with looping enabled where the format allows it (our .wav
## assets import as AudioStreamWAV). The finished -> replay fallback in
## _on_loop_finished covers anything that still won't loop natively.
func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream.duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		return w
	return stream


func _on_loop_finished(key: String) -> void:
	if _loop_wanted.get(key, false):
		_loop[key].play()


# --- one-shots ------------------------------------------------------------

func play_start() -> void:      _play("start")
func play_pill() -> void:       _play("pill")
func play_eat_item() -> void:   _play("eat_item")
func play_eat_ghost() -> void:  _play("eat_ghost")
func play_levelup() -> void:    _play("levelup")


## Pac-Man's death: kill every other sound, then the death jingle alone.
func play_death() -> void:
	stop_all()
	_play("death")


func _play(key: String) -> void:
	var p: AudioStreamPlayer = _oneshot.get(key)
	if p:
		p.play()


## Keep the dot-munch tempo roughly tied to Pac-Man's speed (dots are 16 px
## apart, so faster Pac-Man = dots eaten sooner = a quicker "waka").
func set_pill_rate(pac_speed: float) -> void:
	if _oneshot.has("pill"):
		_oneshot["pill"].pitch_scale = clampf(pac_speed / _PILL_BASE_SPEED, 0.8, 1.5)


# --- background loops ---------------------------------------------------

## Called by the game every frame with the current world state.
func update_ambient(round_active: bool, ghosts_on_map: bool, frightened: bool, eyes_active: bool) -> void:
	var normal := false
	var fright := false
	var power := false
	var eyes := false
	if round_active:
		power = frightened          # power-pellet loop runs the WHOLE blue phase
		if eyes_active:
			eyes = true             # retreating-eyes loop takes priority
		elif frightened:
			fright = true
		elif ghosts_on_map:
			normal = true
	_want("eyes", eyes)
	_want("fright", fright)
	_want("power", power)
	_want("normal", normal)


func stop_all() -> void:
	for key in _loop:
		_want(key, false)
	for key in _oneshot:
		if key != "death":
			_oneshot[key].stop()


func _want(key: String, on: bool) -> void:
	_loop_wanted[key] = on
	var p: AudioStreamPlayer = _loop[key]
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()


# --- volumes ----------------------------------------------------------

## Current 0..100 volume for a sound (falls back to its default).
func get_volume_pct(key: String) -> int:
	if _volume_pct.has(key):
		return int(_volume_pct[key])
	return int(SOUNDS[key][1]) if SOUNDS.has(key) else 100


## Apply a {key: percent} map (from the Sound menu), remember it and persist it.
func set_volumes(percents: Dictionary) -> void:
	for key in percents:
		if SOUNDS.has(key):
			_volume_pct[key] = clampi(int(percents[key]), 0, 100)
	_apply_volumes()
	_save_volumes()


## Play one sound once at its current level even while the tree is paused, so the
## Sound menu can preview a slider change. Long loop sounds are clipped.
func preview(key: String) -> void:
	var st: AudioStream = null
	if _oneshot.has(key):
		st = _oneshot[key].stream
	elif _LOOP_FILES.has(key):
		st = load(_DIR + _LOOP_FILES[key])   # un-looped copy
	if st == null:
		return
	_preview.stream = st
	_preview.volume_db = _final_db(key)
	_preview.pitch_scale = _oneshot["pill"].pitch_scale if key == "pill" else 1.0
	_preview.play()
	_preview_gen += 1
	var gen := _preview_gen
	await get_tree().create_timer(1.4, true, false, true).timeout
	if gen == _preview_gen and is_instance_valid(_preview):
		_preview.stop()


func _apply_volumes() -> void:
	for key in SOUNDS:
		var db := _final_db(key)
		if _oneshot.has(key):
			_oneshot[key].volume_db = db
		if _loop.has(key):
			_loop[key].volume_db = db


func _final_db(key: String) -> float:
	var pct := get_volume_pct(key)
	if pct <= 0:
		return -60.0
	return float(_BASE_DB.get(key, 0.0)) + linear_to_db(float(pct) / 100.0)


func _load_volumes() -> void:
	for key in SOUNDS:
		_volume_pct[key] = int(SOUNDS[key][1])
	var c := ConfigFile.new()
	if c.load(_CFG_PATH) != OK:
		return
	if int(c.get_value(_CFG_SECTION, "_ver", 1)) < SOUND_CFG_VERSION:
		return   # old file used a different formula - keep the calibrated defaults
	for key in SOUNDS:
		_volume_pct[key] = clampi(int(c.get_value(_CFG_SECTION, key, _volume_pct[key])), 0, 100)


func _save_volumes() -> void:
	var c := ConfigFile.new()
	c.load(_CFG_PATH)   # keep the other sections ("s") intact
	c.set_value(_CFG_SECTION, "_ver", SOUND_CFG_VERSION)
	for key in SOUNDS:
		c.set_value(_CFG_SECTION, key, get_volume_pct(key))
	c.save(_CFG_PATH)
