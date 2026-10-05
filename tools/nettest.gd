extends SceneTree

## Two-process LAN test on one machine (TurnsNet turn passing):
##   godot --headless --path . --script tools/nettest.gd -- host   (terminal 1)
##   godot --headless --path . --script tools/nettest.gd -- guest  (terminal 2)
## add "online" to go through the relay: PACMAN_RELAY=ws://127.0.0.1:8765
## (cd ../mario-clone/server && PORT=8765 node relay.js)
## Both "players" die as soon as it is their turn; the game must end on both
## sides with the same two scores and every turn alternating.

func _init() -> void:
	Splash.shown = true
	var role := "host" if "host" in OS.get_cmdline_user_args() else "guest"
	var sc: Node = load("res://pacman_map.tscn").instantiate()
	root.add_child(sc)
	await create_timer(0.5).timeout
	var g: Game = sc.get_node("game")
	g.start_grace = 0.1
	g.death_freeze = 0.1
	g.death_pause = 0.2
	g.respawn_ready = 0.2
	var st: SettingsMenu = sc.get_node("settings")
	st.open_start()
	var online := "online" in OS.get_cmdline_user_args()
	if role == "host":
		if online:
			st._net.room_ready.connect(func(code: String) -> void:
				var f := FileAccess.open("/tmp/pacman_code.txt", FileAccess.WRITE)
				f.store_string(code))
			st._net.host_online()
		else:
			st._net.host_lan("test")
	else:
		await create_timer(1.5).timeout
		if online:
			st._net.join_online(FileAccess.get_file_as_string("/tmp/pacman_code.txt"))
		else:
			st._net.join_lan("127.0.0.1")
	var turns := 0
	var busy := false
	var t := 0.0
	while not g._game_over and t < 60.0:
		await create_timer(0.1).timeout
		t += 0.1
		if g._net != null and g._started and not g._net_waiting and not g._dying and not busy:
			busy = true
			turns += 1
			g._add_score(100 * (turns))
			await create_timer(0.3).timeout
			g._dying = true
			g._player.died.emit()
			await create_timer(1.5).timeout
			busy = false
	print("[", role, "] game_over=", g._game_over, " my turns=", turns, " scores=", g._game_stats().get("scores"), " lives=", g.lives)
	quit()
