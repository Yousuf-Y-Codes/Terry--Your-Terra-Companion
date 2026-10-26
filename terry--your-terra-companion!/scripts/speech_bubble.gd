class_name SpeechBubble
extends Control

@export var bubble_color: Color = Color(1.0, 0.98, 0.94, 0.98) # Warm cream white
@export var border_color: Color = Color(0.24, 0.14, 0.06, 1.0) # Dark brown outline
@export var border_width: float = 3.0
@export var corner_radius: float = 14.0
@export var tail_tip_offset: Vector2 = Vector2(-45, 150) # Where tip points relative to bubble top-left

@onready var message_label: Label = $MarginContainer/MessageLabel

func _ready() -> void:
	queue_redraw()

func set_message(text: String) -> void:
	if not message_label and has_node("MarginContainer/MessageLabel"):
		message_label = $MarginContainer/MessageLabel
	if message_label:
		message_label.text = text
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var r = corner_radius
	var segments: int = 8

	var points = PackedVector2Array()

	var add_arc = func(cx: float, cy: float, start_a: float, end_a: float):
		for i in range(segments + 1):
			var theta = start_a + (end_a - start_a) * (float(i) / float(segments))
			points.append(Vector2(cx + r * cos(theta), cy + r * sin(theta)))

	# 1. Top edge and top-right corner
	points.append(Vector2(r, 0))
	points.append(Vector2(w - r, 0))
	add_arc.call(w - r, r, -PI/2.0, 0.0)

	# 2. Right edge and bottom-right corner
	points.append(Vector2(w, h - r))
	add_arc.call(w - r, h - r, 0.0, PI/2.0)

	# 3. Bottom edge to tail right base
	var tail_b2_x = 95.0
	var tail_b1_x = 60.0
	points.append(Vector2(tail_b2_x, h))

	# 4. Tail tip and back to tail left base
	points.append(tail_tip_offset)
	points.append(Vector2(tail_b1_x, h))

	# 5. Bottom edge to bottom-left corner
	points.append(Vector2(r, h))
	add_arc.call(r, h - r, PI/2.0, PI)

	# 6. Left edge to top-left corner
	points.append(Vector2(0, r))
	add_arc.call(r, r, PI, 3.0 * PI / 2.0)

	# 1. Fill entire bubble + tail as one solid unified shape
	draw_colored_polygon(points, bubble_color)

	# 2. Draw one continuous, seamless closed outline
	var outline_pts = points.duplicate()
	outline_pts.append(points[0])
	draw_polyline(outline_pts, border_color, border_width, true)
