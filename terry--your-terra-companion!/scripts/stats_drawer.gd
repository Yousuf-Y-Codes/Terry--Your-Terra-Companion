class_name StatsDrawer
extends Control

const UIJuice = preload("res://scripts/ui_juice.gd")

@export var backdrop: Control
@export var card: Control
@export var close_button: BaseButton
@export var copy_report_button: BaseButton
@export var days_container: VBoxContainer
@export var summary_label: Label

func _ready() -> void:
	visible = false
	if not backdrop and has_node("%Backdrop"):
		backdrop = %Backdrop
	if not card and has_node("%Card"):
		card = %Card
	if not close_button and has_node("%CloseButton"):
		close_button = %CloseButton
	if not copy_report_button and has_node("%CopyReportButton"):
		copy_report_button = %CopyReportButton
	if not days_container and has_node("%DaysContainer"):
		days_container = %DaysContainer
	if not summary_label and has_node("%SummaryLabel"):
		summary_label = %SummaryLabel

	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
	if close_button:
		close_button.pressed.connect(hide_drawer)
	if copy_report_button:
		copy_report_button.pressed.connect(_on_copy_report_pressed)
	UIJuice.apply_tree(self)

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_drawer()

func show_drawer() -> void:
	_populate()
	visible = true
	modulate.a = 0.0
	if card:
		card.scale = Vector2(0.92, 0.92)
		card.pivot_offset = card.size / 2.0
	var tw = create_tween()
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	if card:
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_drawer() -> void:
	var tw = create_tween()
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	if card:
		tw.parallel().tween_property(card, "scale", Vector2(0.92, 0.92), 0.15).set_trans(Tween.TRANS_QUAD)
	tw.finished.connect(func(): visible = false)

func _populate() -> void:
	if not days_container:
		return
	# Clear previous rows
	for c in days_container.get_children():
		c.queue_free()

	var history = Global.daily_history
	if history.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No weekly history logged yet."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.4, 0.25, 0.14)
		days_container.add_child(empty_lbl)
		return

	var font = preload("res://assets/augiepixel.ttf")
	for day in history:
		var date_raw = str(day.get("date", ""))
		var date_str = _format_friendly_date(date_raw)
		var hours = float(day.get("hours", 0.0))
		var hours_str = str(day.get("hours_str", "0h 00m"))

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var d_lbl = Label.new()
		d_lbl.text = date_str
		d_lbl.custom_minimum_size = Vector2(110, 0)
		d_lbl.add_theme_font_override("font", font)
		d_lbl.add_theme_font_size_override("font_size", 16)
		d_lbl.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		row.add_child(d_lbl)

		var bar = ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 10)
		bar.show_percentage = false
		bar.max_value = maxf(0.01, Global.daily_goal)
		bar.value = hours

		# Style progress bar
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.88, 0.82, 0.72, 0.7)
		bg_style.corner_radius_top_left = 3
		bg_style.corner_radius_top_right = 3
		bg_style.corner_radius_bottom_right = 3
		bg_style.corner_radius_bottom_left = 3

		var fill_style = StyleBoxFlat.new()
		if hours >= Global.daily_goal:
			fill_style.bg_color = Color(0.22, 0.68, 0.32, 1.0)
		elif hours > 0.0:
			fill_style.bg_color = Color(0.82, 0.60, 0.18, 1.0)
		else:
			fill_style.bg_color = Color(0.7, 0.7, 0.7, 0.2)
		fill_style.corner_radius_top_left = 3
		fill_style.corner_radius_top_right = 3
		fill_style.corner_radius_bottom_right = 3
		fill_style.corner_radius_bottom_left = 3

		bar.add_theme_stylebox_override("background", bg_style)
		bar.add_theme_stylebox_override("fill", fill_style)
		row.add_child(bar)

		var h_lbl = Label.new()
		h_lbl.text = hours_str
		h_lbl.custom_minimum_size = Vector2(80, 0)
		h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h_lbl.add_theme_font_override("font", font)
		h_lbl.add_theme_font_size_override("font_size", 16)
		h_lbl.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		row.add_child(h_lbl)

		days_container.add_child(row)

	if summary_label:
		var streak = Global.streak_days
		var week_h_str = Global.stats.get("week_str", "0h 00m")
		var goal_h_str = Global.stats.get("goal_hours_str", "10h 00m")
		var app_time = Global.get_total_app_time_string()
		summary_label.text = "Week: %s / %s  •  Streak: %d days  •  App Time: %s" % [week_h_str, goal_h_str, streak, app_time]

func _format_friendly_date(date_str: String) -> String:
	if date_str.is_empty():
		return ""
	var parts = date_str.split("-")
	if parts.size() == 3:
		var y = int(parts[0])
		var m = int(parts[1])
		var d = int(parts[2])
		var dt = {
			"year": y,
			"month": m,
			"day": d,
			"hour": 12,
			"minute": 0,
			"second": 0
		}
		var unix = Time.get_unix_time_from_datetime_dict(dt)
		var full_dt = Time.get_datetime_dict_from_unix_time(unix)
		var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
		var day_name = days[full_dt.weekday % 7]
		return "%s %02d/%02d" % [day_name, m, d]
	return date_str

func _on_copy_report_pressed() -> void:
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

	if copy_report_button and copy_report_button.has_node("Label"):
		var lbl = copy_report_button.get_node("Label")
		lbl.text = "✓ COPIED!"
		var tw = create_tween()
		tw.tween_interval(1.8)
		tw.tween_callback(func():
			if is_instance_valid(lbl):
				lbl.text = "📋 COPY"
		)
