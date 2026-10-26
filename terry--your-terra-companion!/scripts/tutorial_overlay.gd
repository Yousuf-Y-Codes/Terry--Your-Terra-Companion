class_name TutorialOverlay
extends Control

const UIJuice = preload("res://scripts/ui_juice.gd")

signal tour_finished()
signal open_settings_requested()

@export var dim_color: Color = Color(0.06, 0.04, 0.02, 0.76)
@export var highlight_color: Color = Color(1.0, 0.88, 0.42, 0.95)

# Target highlight rectangle (in local coordinates)
var target_rect: Rect2 = Rect2()
var is_tour_active: bool = false
var current_step: int = 0

# References to nodes on HomeScreen
var _terry_node: Node2D
var _hud_node: Control
var _settings_btn_node: Control
var _speech_bubble_node: Control

# UI elements inside TutorialOverlay
@onready var welcome_modal: Control = $WelcomeModal
@onready var tour_card: Control = $TourCard
@onready var finish_modal: Control = $FinishModal

@onready var step_label: Label = $TourCard/Margin/VBox/StepLabel
@onready var title_label: Label = $TourCard/Margin/VBox/TitleLabel
@onready var desc_label: Label = $TourCard/Margin/VBox/DescLabel
@onready var prev_btn: BaseButton = $TourCard/Margin/VBox/Buttons/PrevButton
@onready var next_btn: BaseButton = $TourCard/Margin/VBox/Buttons/NextButton
@onready var skip_btn: BaseButton = $TourCard/Margin/VBox/Buttons/SkipButton

var steps: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	if welcome_modal:
		welcome_modal.visible = false
	if tour_card:
		tour_card.visible = false
	if finish_modal:
		finish_modal.visible = false

	# Wire Welcome modal buttons
	if has_node("WelcomeModal/Margin/VBox/Buttons/StartTourButton"):
		$WelcomeModal/Margin/VBox/Buttons/StartTourButton.pressed.connect(start_tour)
	if has_node("WelcomeModal/Margin/VBox/Buttons/SkipTourButton"):
		$WelcomeModal/Margin/VBox/Buttons/SkipTourButton.pressed.connect(_on_skip_pressed)

	# Wire Tour Card buttons
	if prev_btn:
		prev_btn.pressed.connect(_on_prev_pressed)
	if next_btn:
		next_btn.pressed.connect(_on_next_pressed)
	if skip_btn:
		skip_btn.pressed.connect(_on_skip_pressed)

	# Wire Finish modal buttons
	if has_node("FinishModal/Margin/VBox/Buttons/SettingsButton"):
		$FinishModal/Margin/VBox/Buttons/SettingsButton.pressed.connect(_on_finish_open_settings)
	if has_node("FinishModal/Margin/VBox/Buttons/DoneButton"):
		$FinishModal/Margin/VBox/Buttons/DoneButton.pressed.connect(_on_finish_done)

	UIJuice.apply_tree(self)

func setup_targets(terry: Node2D, hud: Control, settings_btn: Control, bubble: Control) -> void:
	_terry_node = terry
	_hud_node = hud
	_settings_btn_node = settings_btn
	_speech_bubble_node = bubble
	_build_steps()

func check_first_launch() -> void:
	if Global.trigger_tutorial_on_load:
		Global.trigger_tutorial_on_load = false
		start_tour()
	elif not Global.onboarded:
		show_welcome_prompt()

func show_welcome_prompt() -> void:
	visible = true
	is_tour_active = false
	target_rect = Rect2()
	queue_redraw()
	if welcome_modal:
		welcome_modal.visible = true
	if tour_card:
		tour_card.visible = false
	if finish_modal:
		finish_modal.visible = false

func start_tour() -> void:
	visible = true
	is_tour_active = true
	current_step = 0
	if welcome_modal:
		welcome_modal.visible = false
	if finish_modal:
		finish_modal.visible = false
	if tour_card:
		tour_card.visible = true
	_show_step(0)

func _build_steps() -> void:
	steps = [
		{
			"step_num": "1 of 6",
			"title": "Meet Terry!",
			"desc": "Terry is your personal companion to help you conquer your Hackatime weekly coding quota and keep you on track for your Terra goals!",
			"target": "terry",
			"card_pos": Vector2(380, 190)
		},
		{
			"step_num": "2 of 6",
			"title": "Terry's Reactions & Moods",
			"desc": "Terry reacts dynamically to your work! He squashes and stretches, turning Green when on track, Yellow when falling behind, and Red when an eviction notice is imminent!",
			"target": "terry_and_bubble",
			"card_pos": Vector2(670, 190)
		},
		{
			"step_num": "3 of 6",
			"title": "Glanceable Stats HUD",
			"desc": "Track your progress effortlessly: Today and Week quotas, flame streak, time left, and actionable targets. Click the HUD anytime to open your 7-day activity drawer!",
			"target": "hud",
			"card_pos": Vector2(460, 150)
		},
		{
			"step_num": "4 of 6",
			"title": "Zoom & Resize",
			"desc": "Scroll your mouse wheel up or down anywhere to zoom Terry and his speech bubble (from 40% up to 280%)! You can also drag the window borders freely.",
			"target": "none",
			"card_pos": Vector2(346, 200)
		},
		{
			"step_num": "5 of 6",
			"title": "Desktop Pet Mode",
			"desc": "In Settings, turn on Desktop Pet Mode! Terry floats borderless over your IDE and desktop. Drag him anywhere (he auto-turns with you!), right-click to flip him, and press ESC to return inside.",
			"target": "none",
			"card_pos": Vector2(346, 200)
		},
		{
			"step_num": "6 of 6",
			"title": "Settings & Projects",
			"desc": "Click Settings to paste your Hackatime API key, switch to the River Crossing background, toggle town music, or filter stats to a specific project!",
			"target": "settings_btn",
			"card_pos": Vector2(440, 140)
		}
	]

func _show_step(index: int) -> void:
	if index < 0 or index >= steps.size():
		return
	current_step = index
	var s = steps[index]

	if step_label:
		step_label.text = "STEP %s" % str(s.get("step_num", ""))
	if title_label:
		title_label.text = str(s.get("title", ""))
	if desc_label:
		desc_label.text = str(s.get("desc", ""))

	# Update button states
	if prev_btn:
		prev_btn.visible = (current_step > 0)
	if next_btn:
		var lbl = next_btn.get_node_or_null("Label")
		if lbl:
			lbl.text = "Finish" if (current_step == steps.size() - 1) else "Next"

	# Move tour card to pleasant non-overlapping position
	var pos: Vector2 = s.get("card_pos", Vector2(260, 150))
	if tour_card:
		tour_card.position = pos
		tour_card.reset_size()

	# Compute spotlight target rect
	var target_type = s.get("target", "none")
	target_rect = _calc_target_rect(target_type)
	queue_redraw()

func _calc_target_rect(target_type: String) -> Rect2:
	match target_type:
		"terry":
			if _terry_node and is_instance_valid(_terry_node):
				var center = _terry_node.global_position + Vector2(9, 33) * Global.terry_scale
				var extents = Vector2(105, 120) * Global.terry_scale
				return Rect2(center - extents, extents * 2.0)
		"terry_and_bubble":
			if _terry_node and _speech_bubble_node:
				var center = _terry_node.global_position + Vector2(9, 33) * Global.terry_scale
				var extents = Vector2(105, 120) * Global.terry_scale
				var r_terry = Rect2(center - extents, extents * 2.0)
				var r_bubble = _speech_bubble_node.get_global_rect()
				return r_terry.merge(r_bubble).grow(14.0)
		"hud":
			if _hud_node and is_instance_valid(_hud_node):
				return _hud_node.get_global_rect().grow(12.0)
		"settings_btn":
			if _settings_btn_node and is_instance_valid(_settings_btn_node):
				return _settings_btn_node.get_global_rect().grow(10.0)
		_:
			return Rect2()
	return Rect2()

func _draw() -> void:
	if not visible:
		return
	var w = size.x
	var h = size.y

	if not is_tour_active or not target_rect.has_area():
		# Fullscreen cozy dim
		draw_rect(Rect2(Vector2.ZERO, size), dim_color)
		return

	# Draw 4 dimmed bands leaving the spotlight hole in the center
	var t = target_rect
	# 1. Top band (full width, down to t.position.y)
	if t.position.y > 0:
		draw_rect(Rect2(0, 0, w, t.position.y), dim_color)
	# 2. Bottom band (full width, from t.end.y down to h)
	if t.end.y < h:
		draw_rect(Rect2(0, t.end.y, w, h - t.end.y), dim_color)
	# 3. Left band (between top and bottom, from 0 to t.position.x)
	if t.position.x > 0:
		draw_rect(Rect2(0, t.position.y, t.position.x, t.size.y), dim_color)
	# 4. Right band (between top and bottom, from t.end.x to w)
	if t.end.x < w:
		draw_rect(Rect2(t.end.x, t.position.y, w - t.end.x, t.size.y), dim_color)

	# Draw accent glowing highlight border around spotlight cutout
	draw_rect(t, highlight_color, false, 3.5)

func _on_prev_pressed() -> void:
	if current_step > 0:
		_show_step(current_step - 1)

func _on_next_pressed() -> void:
	if current_step < steps.size() - 1:
		_show_step(current_step + 1)
	else:
		_complete_tour()

func _on_skip_pressed() -> void:
	Global.set_onboarded(true)
	visible = false
	is_tour_active = false
	target_rect = Rect2()
	queue_redraw()
	tour_finished.emit()

func _complete_tour() -> void:
	Global.set_onboarded(true)
	is_tour_active = false
	target_rect = Rect2()
	queue_redraw()
	if tour_card:
		tour_card.visible = false
	if finish_modal:
		finish_modal.visible = true

func _on_finish_open_settings() -> void:
	visible = false
	finish_modal.visible = false
	open_settings_requested.emit()

func _on_finish_done() -> void:
	visible = false
	finish_modal.visible = false
	tour_finished.emit()
