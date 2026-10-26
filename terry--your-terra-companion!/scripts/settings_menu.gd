extends Control

const UIJuice = preload("res://scripts/ui_juice.gd")

@export var api_key_input: LineEdit
@export var music_check: CheckButton
@export var music_track_option: OptionButton
@export var sfx_check: CheckButton
@export var river_bg_check: CheckButton
@export var save_button: BaseButton
@export var back_button: BaseButton
@export var status_label: Label
@export var pet_mode_check: CheckButton
@export var project_option: OptionButton
@export var replay_tutorial_button: BaseButton



func _ready() -> void:
	# Fallback auto-find if not assigned in inspector
	if not api_key_input and has_node("%ApiKeyInput"):
		api_key_input = %ApiKeyInput
	if not music_check and has_node("%MusicCheck"):
		music_check = %MusicCheck
	if not sfx_check and has_node("%SfxCheck"):
		sfx_check = %SfxCheck
	if not music_track_option and has_node("%MusicTrackOption"):
		music_track_option = %MusicTrackOption
	if not river_bg_check and has_node("%RiverBgCheck"):
		river_bg_check = %RiverBgCheck
	if not save_button and has_node("%SaveButton"):
		save_button = %SaveButton
	if not back_button and has_node("%BackButton"):
		back_button = %BackButton
	if not status_label and has_node("%StatusLabel"):
		status_label = %StatusLabel

	if not pet_mode_check and has_node("%PetModeCheck"):
		pet_mode_check = %PetModeCheck
	if not project_option and has_node("%ProjectOption"):
		project_option = %ProjectOption
	if pet_mode_check:
		pet_mode_check.button_pressed = Global.pet_mode_enabled
	if project_option:
		project_option.clear()
		for p in Global.available_projects:
			project_option.add_item(p)
		if not Global.selected_project.is_empty():
			var idx = Global.available_projects.find(Global.selected_project)
			if idx != -1:
				project_option.selected = idx
			else:
				project_option.add_item(Global.selected_project)
				project_option.selected = project_option.item_count - 1
		else:
			project_option.selected = 0

	# Switch up music: Play energetic battle theme in settings menu!
	Global.play_music_track("battle", 0.5)

	# Pre-fill current saved values
	if api_key_input:
		api_key_input.text = Global.api_key
	if music_check:
		music_check.button_pressed = Global.music_enabled
		music_check.toggled.connect(func(enabled: bool):
			Global.music_enabled = enabled
			Global._update_music()
		)
	if sfx_check:
		sfx_check.button_pressed = Global.sfx_enabled
		sfx_check.toggled.connect(func(enabled: bool):
			Global.sfx_enabled = enabled
			if enabled:
				Global.play_sfx("chime")
		)

	if music_track_option:
		music_track_option.clear()
		music_track_option.add_item("Dynamic (Menus)")
		music_track_option.set_item_metadata(0, "dynamic")
		music_track_option.add_item("Town (Peaceful)")
		music_track_option.set_item_metadata(1, "town")
		music_track_option.add_item("Battle (Energetic)")
		music_track_option.set_item_metadata(2, "battle")

		match Global.music_theme:
			"town":
				music_track_option.selected = 1
			"battle":
				music_track_option.selected = 2
			_:
				music_track_option.selected = 0

		music_track_option.item_selected.connect(func(idx: int):
			var meta = str(music_track_option.get_item_metadata(idx))
			Global.music_theme = meta
			if meta == "town":
				Global.play_music_track("town", 0.3)
			else:
				Global.play_music_track("battle", 0.3)
		)

	if river_bg_check:
		river_bg_check.button_pressed = (Global.background_theme == "river")

	if not replay_tutorial_button and has_node("%ReplayTutorialButton"):
		replay_tutorial_button = %ReplayTutorialButton

	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if replay_tutorial_button:
		replay_tutorial_button.pressed.connect(_on_replay_tutorial_pressed)

	UIJuice.apply_tree(self)

func _on_save_pressed() -> void:
	var key = ""
	if api_key_input:
		key = api_key_input.text.strip_edges()
	var music = true
	if music_check:
		music = music_check.button_pressed
	var sfx_val = 1 if (sfx_check and sfx_check.button_pressed) else 0
	var bg_choice = "default"
	if river_bg_check and river_bg_check.button_pressed:
		bg_choice = "river"
	var pet = pet_mode_check.button_pressed if pet_mode_check else false
	var proj = project_option.get_item_text(project_option.selected) if project_option else ""
	if proj == "All Projects":
		proj = ""
	var theme_choice = "dynamic"
	if music_track_option:
		theme_choice = str(music_track_option.get_item_metadata(music_track_option.selected))

	Global.save_settings(key, music, bg_choice, pet, proj, -1.0, -1, -1, sfx_val, theme_choice)
	Global.play_music_track("town", 0.5)
	Global.transition_to_scene("res://home_screen.tscn")

func _on_back_pressed() -> void:
	Global.play_music_track("town", 0.5)
	Global.transition_to_scene("res://home_screen.tscn")

func _on_replay_tutorial_pressed() -> void:
	Global.play_music_track("town", 0.5)
	Global.trigger_tutorial_on_load = true
	Global.transition_to_scene("res://home_screen.tscn")
