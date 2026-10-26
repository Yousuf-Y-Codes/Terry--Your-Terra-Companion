extends Control

const UIJuice = preload("res://scripts/ui_juice.gd")

@export var background: TextureRect
@export var terry: Sprite2D
@export var settings_button: BaseButton

# Big & Concise Glanceable HUD (Top Left)
@export var status_label: Label
@export var today_label: Label
@export var today_progress_bar: ProgressBar
@export var week_label: Label
@export var week_progress_bar: ProgressBar
@export var time_left_label: Label

# Speech Bubble coming directly from Terry
@export var speech_bubble: Control

# First-Time Onboarding & Guided Spotlight Tutorial
@export var tutorial_overlay: Control
@export var stats_drawer: Control

func _ready() -> void:
	# Fallback auto-find if not assigned in inspector
	if not background and has_node("Background"):
		background = $Background
	if not terry and has_node("Terry"):
		terry = $Terry
	if not settings_button and has_node("%SettingsButton"):
		settings_button = %SettingsButton
	if not tutorial_overlay and has_node("%TutorialOverlay"):
		tutorial_overlay = %TutorialOverlay
	_update_pet_mode_visuals(Global.pet_mode_enabled)
	_apply_scale(Global.terry_scale)

	if not status_label and has_node("%StatusLabel"):
		status_label = %StatusLabel
	if not today_label and has_node("%TodayLabel"):
		today_label = %TodayLabel
	if not today_progress_bar and has_node("%TodayProgressBar"):
		today_progress_bar = %TodayProgressBar
	if not week_label and has_node("%WeekLabel"):
		week_label = %WeekLabel
	if not week_progress_bar and has_node("%WeekProgressBar"):
		week_progress_bar = %WeekProgressBar
	if not time_left_label and has_node("%TimeLeftLabel"):
		time_left_label = %TimeLeftLabel

	if not speech_bubble and has_node("%SpeechBubble"):
		speech_bubble = %SpeechBubble

	# Set current background theme (Default vs River Crossing)
	if background:
		background.texture = Global.get_current_background_texture()

	# Switch music to chill town theme for home screen
	Global.play_music_track("town", 0.5)

	# Connect signals
	Global.stats_updated.connect(_on_stats_updated)
	Global.stats_failed.connect(_on_stats_failed)

	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
		UIJuice.apply_button_juice(settings_button)

	if not stats_drawer and has_node("%StatsDrawer"):
		stats_drawer = %StatsDrawer

	if has_node("TopLeftHUD"):
		var hud = $TopLeftHUD
		hud.mouse_filter = Control.MOUSE_FILTER_STOP
		hud.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hud.gui_input.connect(_on_hud_gui_input)
		hud.pivot_offset = hud.size / 2.0
		hud.resized.connect(func(): hud.pivot_offset = hud.size / 2.0)
		hud.mouse_entered.connect(func():
			var tw = create_tween()
			tw.tween_property(hud, "scale", Vector2(1.025, 1.025), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		)
		hud.mouse_exited.connect(func():
			var tw = create_tween()
			tw.tween_property(hud, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)

	# Setup interactive onboarding tutorial overlay
	if tutorial_overlay:
		if tutorial_overlay.has_method("setup_targets"):
			var hud_node = $TopLeftHUD if has_node("TopLeftHUD") else null
			tutorial_overlay.setup_targets(terry, hud_node, settings_button, speech_bubble)
		if tutorial_overlay.has_signal("open_settings_requested"):
			tutorial_overlay.open_settings_requested.connect(_on_settings_pressed)
		call_deferred("_check_tutorial")

	# Initial display
	if not Global.stats.is_empty():
		_on_stats_updated(Global.stats)

func _check_tutorial() -> void:
	if tutorial_overlay and tutorial_overlay.has_method("check_first_launch"):
		tutorial_overlay.check_first_launch()

func _on_stats_updated(data: Dictionary) -> void:
	# 1. Update Terry's color (green, yellow, or red)
	var mood: String = data.get("mood", "green")
	if terry and terry.has_method("set_mood"):
		terry.set_mood(mood)

	# 2. Terry's Speech Bubble: Terry shouts his current mood title ("YOU NEED TO WORK!!", "ON TRACK!", etc.)
	var title_text: String = str(data.get("title", "ON TRACK!"))
	if speech_bubble and speech_bubble.has_method("set_message"):
		speech_bubble.set_message(title_text)
	elif speech_bubble and speech_bubble.has_node("MarginContainer/MessageLabel"):
		speech_bubble.get_node("MarginContainer/MessageLabel").text = title_text

	# Color the speech bubble text to match mood
	if speech_bubble and speech_bubble.has_node("MarginContainer/MessageLabel"):
		var msg_lbl: Label = speech_bubble.get_node("MarginContainer/MessageLabel")
		match mood:
			"green":
				msg_lbl.modulate = Color(0.15, 0.55, 0.15)
			"yellow":
				msg_lbl.modulate = Color(0.70, 0.42, 0.05)
			"red":
				msg_lbl.modulate = Color(0.80, 0.15, 0.15)
			_:
				msg_lbl.modulate = Color(0.24, 0.12, 0.04)

	# 3. Top-Left HUD: Displays the target instruction message and today/week quota hours
	var today_str = data.get("today_str", "0h 00m")
	var daily_goal_str = data.get("daily_goal_str", "1h 30m")
	var week_str = data.get("week_str", "0h 00m")
	var goal_hours_str = data.get("goal_hours_str", "10h 00m")

	if status_label:
		var base_msg = str(data.get("msg", "Keep up the great work!"))
		var streak = int(data.get("streak_days", 0))
		if streak >= 2:
			status_label.text = "%s  •  🔥 %d-Day Streak!" % [base_msg, streak]
		else:
			status_label.text = base_msg
		status_label.modulate = Color(0.24, 0.12, 0.04)

	if today_label:
		today_label.text = "TODAY: %s / %s" % [today_str, daily_goal_str]
	if today_progress_bar:
		var today_h = float(data.get("today_hours", 0.0))
		var daily_g = maxf(0.01, Global.daily_goal)
		var t_pct = clampf((today_h / daily_g) * 100.0, 0.0, 100.0)
		var pt_t = create_tween()
		pt_t.tween_property(today_progress_bar, "value", t_pct, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if week_label:
		week_label.text = "WEEK:  %s / %s" % [week_str, goal_hours_str]
	if week_progress_bar:
		var week_h = float(data.get("week_hours", 0.0))
		var week_g = maxf(0.01, Global.goal_hours)
		var w_pct = clampf((week_h / week_g) * 100.0, 0.0, 100.0)
		var pt_w = create_tween()
		pt_w.tween_property(week_progress_bar, "value", w_pct, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if time_left_label:
		time_left_label.text = "Left: %s" % data.get("time_left_str", "--")

func _on_stats_failed(error_msg: String) -> void:
	if status_label:
		status_label.text = error_msg
	if speech_bubble and speech_bubble.has_method("set_message"):
		speech_bubble.set_message("OFFLINE")

func _on_settings_pressed() -> void:
	Global.transition_to_scene("res://settings_menu.tscn")

func _on_hud_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if stats_drawer and stats_drawer.has_method("show_drawer"):
			Global.play_sfx("chime")
			stats_drawer.show_drawer()

var _is_dragging: bool = false
var _is_resizing_window: bool = false
var _drag_start_mouse: Vector2i
var _drag_start_window: Vector2i
var _drag_start_size: Vector2i

func _apply_scale(s: float) -> void:
	Global.terry_scale = clampf(s, 0.4, 2.8)
	if terry and terry.has_method("set_scale_multiplier"):
		terry.set_scale_multiplier(Global.terry_scale)
	if speech_bubble:
		speech_bubble.pivot_offset = Vector2(0, speech_bubble.size.y)
		speech_bubble.scale = Vector2(Global.terry_scale, Global.terry_scale)

func _change_scale(delta: float) -> void:
	_apply_scale(Global.terry_scale + delta)
	Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, Global.pet_mode_enabled, Global.selected_project, Global.terry_scale, 1 if Global.pet_flip_h else 0)

func _update_pet_mode_visuals(is_pet: bool) -> void:
	if background:
		background.visible = not is_pet
	if has_node("TopLeftHUD"):
		$TopLeftHUD.visible = not is_pet
	if settings_button:
		settings_button.visible = not is_pet
	if terry and terry.has_method("set_facing"):
		if is_pet:
			terry.set_facing(Global.pet_flip_h)
		else:
			terry.set_facing(false) # Strictly fixed when inside!
	Global.set_pet_mode(is_pet)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if not Global.pet_mode_enabled:
		var w = size.x
		var h = size.y
		var col = Color(0.35, 0.22, 0.12, 0.45)
		draw_line(Vector2(w - 20, h - 6), Vector2(w - 6, h - 20), col, 2.0)
		draw_line(Vector2(w - 14, h - 6), Vector2(w - 6, h - 14), col, 2.0)
		draw_line(Vector2(w - 8, h - 6), Vector2(w - 6, h - 8), col, 2.0)

func _gui_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _unhandled_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _handle_input_event(event: InputEvent) -> void:
	# ESC key closes stats drawer if open, or exits Desktop Pet mode
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if stats_drawer and stats_drawer.visible:
			stats_drawer.hide_drawer()
			return
		if Global.pet_mode_enabled:
			Global.pet_mode_enabled = false
			Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, false, Global.selected_project, Global.terry_scale, 0)
			_update_pet_mode_visuals(false)
			return

	# Ignore background inputs while tutorial overlay or stats drawer is open
	if (tutorial_overlay and tutorial_overlay.visible) or (stats_drawer and stats_drawer.visible):
		return

	# Press 'R' to immediately copy coding standup report to clipboard
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and not event.echo:
		copy_coding_report()
		return

	# Mouse scroll wheel zooms Terry & speech bubble in both modes
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_scale(0.05)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_scale(-0.05)
			return

	# Corner resize handling in BOTH Window Mode and Desktop Pet Mode
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var m_local = get_viewport().get_mouse_position()
				var win_size = DisplayServer.window_get_size()
				if m_local.x >= win_size.x - 40 and m_local.y >= win_size.y - 40:
					_is_resizing_window = true
					_drag_start_mouse = DisplayServer.mouse_get_position()
					_drag_start_window = DisplayServer.window_get_position()
					_drag_start_size = win_size
					return
				elif Global.pet_mode_enabled:
					if event.double_click:
						Global.pet_mode_enabled = false
						Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, false, Global.selected_project, Global.terry_scale, 0)
						_update_pet_mode_visuals(false)
						return
					else:
						_is_dragging = true
						_drag_start_mouse = DisplayServer.mouse_get_position()
						_drag_start_window = DisplayServer.window_get_position()
						_drag_start_size = win_size
						return
			else:
				_is_resizing_window = false
				_is_dragging = false

	if event is InputEventMouseMotion:
		if _is_resizing_window:
			var delta = DisplayServer.mouse_get_position() - _drag_start_mouse
			var min_w = 400 if not Global.pet_mode_enabled else 200
			var min_h = 280 if not Global.pet_mode_enabled else 180
			var new_w = maxi(min_w, _drag_start_size.x + delta.x)
			var new_h = maxi(min_h, _drag_start_size.y + delta.y)
			DisplayServer.window_set_size(Vector2i(new_w, new_h))
			return
		elif _is_dragging and Global.pet_mode_enabled:
			var delta = DisplayServer.mouse_get_position() - _drag_start_mouse
			DisplayServer.window_set_position(_drag_start_window + delta)
			# Auto-face movement direction while dragging outside
			if terry and terry.has_method("set_facing"):
				if event.relative.x > 2.0 and terry.flip_h:
					terry.set_facing(false)
					Global.pet_flip_h = false
				elif event.relative.x < -2.0 and not terry.flip_h:
					terry.set_facing(true)
					Global.pet_flip_h = true
			return
		else:
			# Hover feedback for bottom-right corner resize
			var m_pos = get_viewport().get_mouse_position()
			var win_size = DisplayServer.window_get_size()
			if m_pos.x >= win_size.x - 40 and m_pos.y >= win_size.y - 40:
				mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW

	# Desktop Pet Mode ONLY controls (outside the background)
	if Global.pet_mode_enabled:
		# Flip Terry with keyboard ('F' or Left/Right arrows)
		if event is InputEventKey and event.pressed and terry and terry.has_method("set_facing"):
			if event.keycode == KEY_F:
				var new_flip = not terry.flip_h
				terry.set_facing(new_flip)
				Global.pet_flip_h = new_flip
				Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, true, Global.selected_project, Global.terry_scale, 1 if new_flip else 0)
				return
			elif event.keycode == KEY_LEFT:
				terry.set_facing(true)
				Global.pet_flip_h = true
				Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, true, Global.selected_project, Global.terry_scale, 1)
				return
			elif event.keycode == KEY_RIGHT:
				terry.set_facing(false)
				Global.pet_flip_h = false
				Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, true, Global.selected_project, Global.terry_scale, 0)
				return

		# Mouse buttons in Pet Mode: Right click to flip Terry direction
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				if terry and terry.has_method("set_facing"):
					var new_flip = not terry.flip_h
					terry.set_facing(new_flip)
					Global.pet_flip_h = new_flip
					Global.save_settings(Global.api_key, Global.music_enabled, Global.background_theme, true, Global.selected_project, Global.terry_scale, 1 if new_flip else 0)
				return

func copy_coding_report() -> void:
	var today = Global.stats.get("today_str", "0h 00m")
	var week = Global.stats.get("week_str", "0h 00m")
	var left = Global.stats.get("time_left_str", "--")
	var streak = Global.streak_days
	var app_total = Global.get_total_app_time_string()
	var app_session = Global.get_session_time_string()

	var text = "🚀 Terry - Your Terra Companion Update:\n"
	text += "• Today: %s\n" % today
	text += "• This Week: %s\n" % week
	text += "• Time Left: %s\n" % left
	if streak >= 2:
		text += "• Streak: 🔥 %d Days!\n" % streak
	text += "• Time with Terry: %s (Session: %s)\n" % [app_total, app_session]

	DisplayServer.clipboard_set(text)
	Global.play_sfx("chime")

	if status_label:
		var old_text = status_label.text
		status_label.text = "📋 Copied report to clipboard!"
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(status_label):
				status_label.text = old_text
		)
