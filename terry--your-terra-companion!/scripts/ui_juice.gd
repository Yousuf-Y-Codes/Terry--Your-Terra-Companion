class_name UIJuice
extends RefCounted

static func apply_button_juice(btn: BaseButton) -> void:
	if not btn or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var g = btn.get_node_or_null("/root/Global")
		if g and g.has_method("play_sfx"):
			g.play_sfx("pop", 0.08)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		var target_scale = Vector2(1.06, 1.06) if btn.is_hovered() else Vector2.ONE
		tw.tween_property(btn, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

static func apply_tree(node: Node) -> void:
	if not node:
		return
	if node is BaseButton:
		apply_button_juice(node)
	for child in node.get_children():
		apply_tree(child)
