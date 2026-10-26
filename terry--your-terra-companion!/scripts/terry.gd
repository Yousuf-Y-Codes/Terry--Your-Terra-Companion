extends Sprite2D

@export var tex_green: Texture2D = preload("res://assets/terry_green_emerald.png")
@export var tex_yellow: Texture2D = preload("res://assets/terry_).png")
@export var tex_red: Texture2D = preload("res://assets/terry_rose.png")

@export var enable_stretch_animation: bool = true
@export var stretch_intensity: float = 0.05
@export var custom_idle_frames: Array[Texture2D] = []
@export var custom_walk_frames: Array[Texture2D] = []
@export var custom_happy_frames: Array[Texture2D] = []
@export var frame_fps: float = 6.0

var _base_scale: Vector2
var user_scale_multiplier: float = 1.0
var _tween: Tween
var _frame_timer: float = 0.0
var _current_frame_idx: int = 0
var _current_mood: String = "green"

func _ready() -> void:
	_base_scale = scale
	_scan_custom_animations()
	if custom_idle_frames.is_empty() and enable_stretch_animation:
		start_idle_stretch()
	set_process(not custom_idle_frames.is_empty())

func _process(delta: float) -> void:
	if custom_idle_frames.is_empty():
		return
	_frame_timer += delta
	var frame_dur = 1.0 / maxf(1.0, frame_fps)
	if _frame_timer >= frame_dur:
		_frame_timer -= frame_dur
		_current_frame_idx = (_current_frame_idx + 1) % custom_idle_frames.size()
		texture = custom_idle_frames[_current_frame_idx]

func _scan_custom_animations() -> void:
	var anim_dir = "res://assets/animations"
	if not DirAccess.dir_exists_absolute(anim_dir):
		return
	var dir = DirAccess.open(anim_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var found_files: Array[String] = []
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
			found_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	found_files.sort()
	for f in found_files:
		var tex = load(anim_dir.path_join(f))
		if tex is Texture2D:
			custom_idle_frames.append(tex)
	if not custom_idle_frames.is_empty():
		set_process(true)
		if _tween and _tween.is_valid():
			_tween.kill()
		texture = custom_idle_frames[0]

func set_scale_multiplier(mult: float) -> void:
	user_scale_multiplier = clampf(mult, 0.4, 2.8)
	if enable_stretch_animation:
		start_idle_stretch()
	else:
		scale = _base_scale * user_scale_multiplier

func set_facing(flip: bool) -> void:
	flip_h = flip

func set_mood(mood: String) -> void:
	_current_mood = mood.to_lower()
	if not custom_idle_frames.is_empty():
		return
	match _current_mood:
		"green":
			texture = tex_green
		"yellow":
			texture = tex_yellow
		"red":
			texture = tex_red

func start_idle_stretch() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_loops()
	var effective_base = _base_scale * user_scale_multiplier
	var squash = Vector2(effective_base.x * (1.0 + stretch_intensity), effective_base.y * (1.0 - stretch_intensity))
	var stretch = Vector2(effective_base.x * (1.0 - stretch_intensity), effective_base.y * (1.0 + stretch_intensity))

	_tween.tween_property(self, "scale", stretch, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "scale", squash, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
