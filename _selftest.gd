extends SceneTree

## Headless smoke test. Run:
##   godot --headless --path . --script res://_selftest.gd
##
## Checks that every script compiles (see _all_scripts()) and sanity-checks the
## project config (portrait canvas, stretch mode, input map incl. device -1 on
## every joypad binding — RG552).

## Every game script, found automatically — a hand-kept list silently goes
## stale. Walks res:// recursively, skipping addons/, tools/, android/ (Godot's
## build template), hidden and .gdignore'd folders and _-prefixed dev scripts
## (_selftest.gd itself, local helpers like _capture.gd).
## A script only counts if it also COMPILES: in Godot 4 load() returns the
## resource even when compilation failed (incl. a broken dependency), so check
## can_instantiate() (found in mario-clone v1.1, where `load() != null` let a
## type-inference error through with "all checks passed" and exit 0).
const SKIP_DIRS := ["addons", "tools", "android"]

func _all_scripts(dir := "res://") -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and not f.begins_with("_"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		var sub := dir.path_join(d)
		if d.begins_with(".") or d in SKIP_DIRS or FileAccess.file_exists(sub.path_join(".gdignore")):
			continue
		out.append_array(_all_scripts(sub))
	return out

func _init() -> void:
	var fails := 0

	var scripts := _all_scripts()
	fails += _expect(scripts.size() >= 9, "found %d scripts (expect >= 9)" % scripts.size())
	for path in scripts:
		var s: Script = load(path)
		fails += _expect(s != null and s.can_instantiate(), "compiles: %s" % path)

	# --- project config -----------------------------------------------------
	var canvas := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	fails += _expect(canvas.y > canvas.x, "design canvas is portrait (%dx%d)" % [canvas.x, canvas.y])
	fails += _expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items",
		"stretch mode = canvas_items")
	for action in ["move_up", "move_down", "move_left", "move_right", "pause", "ui_accept", "ui_cancel"]:
		fails += _expect(InputMap.has_action(action), "input action present: %s" % action)
	for action in InputMap.get_actions():
		for e in InputMap.action_get_events(action):
			if (e is InputEventJoypadButton or e is InputEventJoypadMotion) and e.device != -1:
				fails += _expect(false, "joypad binding of %s uses device -1 (has %d)" % [action, e.device])

	if fails == 0:
		print("_selftest: all checks passed")
	else:
		printerr("_selftest: %d check(s) FAILED" % fails)
	quit(1 if fails > 0 else 0)

func _expect(cond: bool, label: String) -> int:
	if cond:
		print("  ok  ", label)
		return 0
	printerr("  FAIL ", label)
	return 1
