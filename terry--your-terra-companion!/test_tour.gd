extends SceneTree

func _init():
	var hs = load("res://home_screen.tscn").instantiate()
	root.add_child(hs)
	await process_frame
	await process_frame
	var overlay = hs.get_node("%TutorialOverlay")
	overlay.start_tour()
	await process_frame
	var card = overlay.get_node("TourCard")
	print("TourCard pos: ", card.position, " size: ", card.size, " global_rect: ", card.get_global_rect())
	var vbox = overlay.get_node("TourCard/Margin/VBox")
	print("VBox size: ", vbox.size, " pos: ", vbox.position)
	for child in vbox.get_children():
		print("Child: ", child.name, " pos: ", child.position, " size: ", child.size, " min_size: ", child.custom_minimum_size, " visible: ", child.visible)
	quit()
