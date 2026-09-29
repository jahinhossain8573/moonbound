extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in range(8): await process_frame
func capture(file: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/moonbound-" + file + ".png")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "/tmp/moonbound-smoke-isolated.json"
	root.add_child(game)
	await capture("assembly")
	game.model.reference_design()
	game.world.rebuild()
	game.render()
	await capture("complete-design")
	game.world.exploded = true
	game.world.rebuild()
	game.world.update_camera()
	await capture("exploded")
	game.world.exploded = false
	game.world.rebuild()
	game.world.update_camera()
	game.page = 0
	game.render()
	await capture("planning")
	game.show_research()
	await capture("research")
	game.close_modal()
	game.show_review()
	await capture("review")
	game.close_modal()
	game.model.manufacture()
	game.page = 2
	game.render()
	await capture("qualification")
	for test in ["structure", "propulsion", "systems"]: game.model.run_test(test)
	game.model.deliver()
	game.render()
	game.show_completion()
	await capture("completion")
	print("UI smoke: all screens rendered")
	quit()
