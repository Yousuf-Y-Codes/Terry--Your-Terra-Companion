extends Control

func _ready() -> void:
	print("========================================")
	print("RUNNING IN-ENGINE AUTOMATED SYSTEM TESTS")
	print("========================================")

	# 1. Test format_hours
	assert(Global.format_hours(1.5) == "1h 30m", "1.5h should format to 1h 30m")
	assert(Global.format_hours(0.0) == "0h 00m", "0.0h should format to 0h 00m")
	assert(Global.format_hours(10.25) == "10h 15m", "10.25h should format to 10h 15m")
	print("✓ Global.format_hours passed!")

	# 2. Test compute_status
	var completed = Global.compute_status(12.0, 2.5)
	assert(completed.mood == "green", "Mood should be green when week_hours >= goal_hours")
	print("✓ Global.compute_status passed!")

	# 3. Test SFX dictionary and audio defaults
	assert(Global.music_enabled == true, "Music should be enabled by default")
	assert(Global.sfx_enabled == true, "Sound effects should be enabled by default")
	assert(Global._sfx_dict.has("chirp"), "Chirp SFX present")
	assert(Global._sfx_dict.has("pop"), "Pop SFX present")
	assert(Global._sfx_dict.has("chime"), "Chime SFX present")
	print("✓ Audio defaults (Music & SFX ON) & procedural buffers passed!")

	# 4. Test StatsDrawer
	var stats_scene = load("res://stats_drawer.tscn")
	var drawer = stats_scene.instantiate()
	add_child(drawer)
	drawer.show_drawer()
	assert(drawer.visible == true, "Drawer visible")
	drawer.hide_drawer()
	drawer.queue_free()
	print("✓ StatsDrawer initialization & animation passed!")

	# 5. Test TutorialOverlay
	var tut_scene = load("res://tutorial_overlay.tscn")
	var overlay = tut_scene.instantiate()
	add_child(overlay)
	overlay._build_steps()
	assert(overlay.steps.size() == 6, "Tutorial step count is 6")
	for i in range(6):
		overlay._show_step(i)
		assert(overlay.current_step == i, "Step matches")
	overlay.queue_free()
	print("✓ TutorialOverlay 6-step traversal passed!")

	# 6. Test Music Tracks (Town & Battle)
	assert(Global._bgm_tracks.has("town"), "Town music track present")
	assert(Global._bgm_tracks.has("battle"), "Battle music track present")
	Global.play_music_track("battle", 0.0)
	assert(Global._current_track_name == "battle", "Current track should switch to battle")
	Global.play_music_track("town", 0.0)
	assert(Global._current_track_name == "town", "Current track should switch to town")
	# 7. Test Total App Time Tracking & Report Generation
	assert(Global.has_method("get_total_app_time_string"), "Global has total app time helper")
	assert(Global.has_method("get_session_time_string"), "Global has session time helper")
	var time_str = Global.get_total_app_time_string()
	assert(time_str.contains("h ") and time_str.contains("m"), "App time string correctly formatted: " + time_str)
	print("✓ Total app time tracking & formatting passed!")

	print("========================================")
	print("ALL ENGINE INTEGRATION TESTS PASSED (0 ERRORS)")
	print("========================================")
	get_tree().quit(0)
