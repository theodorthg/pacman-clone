class_name TurnsNet
extends Node

## Two players taking turns, each on their OWN device (online via the relay or
## Wi-Fi/LAN). Every device simulates only its own turns; what travels is small:
##   ["cfg",  {...}]         host -> guest right after connecting (game settings)
##   ["state", {score,lives,level}]   ~2x/s while one plays - the waiting side's HUD
##   ["turn_end", {score,lives,level,alive}]   a turn is over (life lost)
## Host is player 1 and begins; the guest (player 2) waits for the first turn_end.

signal room_ready(code: String)            ## online host: the 4-letter code
signal connected                           ## the other side is there
signal cfg_received(cfg: Dictionary)       ## guest only
signal state_received(d: Dictionary)
signal turn_end_received(d: Dictionary)
signal failed(text: String)                ## could not connect / lost before start
signal left                               ## the other side is gone (during a game)
signal hosts_changed(hosts: Dictionary)    ## LAN guest: ip -> name

var link: NetLink
var discovery: NetLink.Discovery
var is_host := false
var in_game := false
var _hosts_sig := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- starting ----------------------------------------------------------

func host_online() -> bool:
	_reset()
	is_host = true
	return link.host_online(NetLink.relay_url()) == OK


func join_online(code: String) -> bool:
	_reset()
	is_host = false
	return link.join_online(NetLink.relay_url(), code) == OK


func host_lan(name: String) -> bool:
	_reset()
	is_host = true
	if link.host_lan() != OK:
		return false
	discovery = NetLink.Discovery.new()
	discovery.start_host(name)
	return true


func search_lan() -> void:
	_reset()
	is_host = false
	discovery = NetLink.Discovery.new()
	discovery.start_search()


func join_lan(ip: String) -> bool:
	if discovery:
		discovery.stop()
		discovery = null
	link = NetLink.new()
	is_host = false
	return link.join_lan(ip) == OK


func _reset() -> void:
	cancel()
	link = NetLink.new()
	in_game = false


func cancel() -> void:
	if discovery:
		discovery.stop()
		discovery = null
	if link:
		link.close()
		link = null
	in_game = false


# --- messages -------------------------------------------------------------

func send_cfg(cfg: Dictionary) -> void:
	if link:
		link.send("cfg", {"cfg": cfg, "v": NetLink.version()})


func send_state(score: int, lives: int, level: int) -> void:
	if link and in_game:
		link.send("state", {"score": score, "lives": lives, "level": level})


func send_turn_end(score: int, lives: int, level: int, alive: bool) -> void:
	if link and in_game:
		link.send("turn_end", {"score": score, "lives": lives, "level": level, "alive": alive})


func _process(delta: float) -> void:
	if discovery:
		discovery.poll(delta)
		if not discovery.hosting:
			var names := {}
			for ip in discovery.found:
				names[ip] = discovery.found[ip].name
			var sig := str(names)
			if sig != _hosts_sig:
				_hosts_sig = sig
				hosts_changed.emit(names)
	if link == null:
		return
	for ev in link.poll():
		match ev[0]:
			"room":
				room_ready.emit(ev[1])
			"connect":
				if discovery and discovery.hosting:
					discovery.stop()
					discovery = null
				connected.emit()
			"msg":
				_on_msg(str(ev[1]), ev[2])
			"disconnect":
				_lost("The other player left.")
			"error", "closed":
				_lost(str(ev[1]))
				if link == null:
					return


func _lost(text: String) -> void:
	if in_game:
		in_game = false
		left.emit()
	else:
		failed.emit(text)


func _on_msg(type: String, p) -> void:
	if not (p is Dictionary):
		return
	match type:
		"cfg":
			var mine := NetLink.version().split(".")
			var theirs := str(p.get("v", "")).split(".")
			if mine.size() >= 2 and theirs.size() >= 2 and (mine[0] != theirs[0] or mine[1] != theirs[1]):
				failed.emit("The other player has version %s, you have %s." % [p.get("v", "?"), NetLink.version()])
				return
			cfg_received.emit(p.get("cfg", {}))
		"state":
			state_received.emit(p)
		"turn_end":
			turn_end_received.emit(p)
