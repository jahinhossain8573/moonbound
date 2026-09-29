extends SceneTree
const Flight = preload("res://scripts/flight_sim.gd")
var game
var failures = 0
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in range(5): await process_frame
func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found = find_button(child, caption)
		if found: return found
	return null
func find_control(node: Node, kind: String) -> Control:
	if node.is_class(kind) and node is Control and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found = find_control(child, kind)
		if found: return found
	return null
func click(caption: String) -> void:
	var target = find_button(root, caption)
	if not target:
		expect(false, "Button exists: " + caption)
		return
	target.pressed.emit()
	await settle()
func run() -> void:
	DirAccess.remove_absolute("/tmp/moonbound-ui-interaction.json")
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "/tmp/moonbound-ui-interaction.json"
	root.add_child(game)
	await settle()
	expect(game.sans.resource_path.ends_with("Unbounded.ttf"), "Unbounded drives main text")
	expect(game.bold.resource_path.ends_with("Audiowide-Regular.ttf"), "Audiowide drives controls and headings")
	expect(game.logo_font.resource_path.ends_with("Electrolize-Regular.ttf"), "Electrolize drives the wordmark")
	var selector = find_control(root, "OptionButton")
	expect(selector != null and selector.get_theme_icon("arrow") != null, "Styled dropdown has a custom arrow")
	var reserve_slider = find_control(root, "HSlider")
	expect(reserve_slider != null and reserve_slider.get_theme_stylebox("grabber_area") != null, "Styled propellant slider is present")
	expect(find_button(root, "Research to unlock  ↗") == null, "Locked variants hidden by default")
	await click("Show locked upgrades (1)  ↓")
	expect(find_button(root, "Research to unlock  ↗") != null, "Locked variant shown only on request")
	await click("Hide locked upgrades  ↑")
	expect(find_button(root, "Research to unlock  ↗") == null, "Hiding upgrades restores buildable default")
	await click("Install module  +")
	expect(game.model.installed.get("Lunar lander") == "heron", "Click installs lander")
	await click("HAB")
	expect(game.selected_slot == "Habitat", "Manifest selects module category")
	await click("Install module  +")
	expect(game.model.installed.get("Habitat") == "haven", "Click installs habitat")
	await click("Load reference design")
	expect(game.model.valid_design(), "Reference design click configures valid mission")
	reserve_slider = find_control(root, "HSlider")
	reserve_slider.value = 6
	reserve_slider.drag_ended.emit(true)
	await settle()
	expect(game.model.reserve == 6 and game.model.valid_design(), "Styled slider updates the resource budget")
	reserve_slider = find_control(root, "HSlider")
	reserve_slider.value = 4
	reserve_slider.drag_ended.emit(true)
	await settle()
	await click("01   Mission planning")
	await click("Assigned  ✓")
	expect(game.model.crew.size() == 1, "Crew toggle removes astronaut")
	await click("Assign to mission")
	expect(game.model.crew.size() == 2, "Crew toggle assigns astronaut")
	await click("02   Vehicle assembly")
	await click("Exploded view")
	expect(game.world.exploded, "Exploded view toggles")
	await click("Exploded view")
	await click("Full engineering review  ↗")
	expect(is_instance_valid(game.overlay), "Review opens")
	await click("Close  ×")
	expect(not is_instance_valid(game.overlay), "Review closes")
	await click("Manufacture vehicle  →")
	var confirmation
	for child in game.get_children():
		if child is ConfirmationDialog: confirmation = child
	expect(confirmation != null, "Manufacture opens confirmation")
	if confirmation: confirmation.confirmed.emit()
	await settle()
	expect(game.model.integrated and game.page == 2, "Confirmation manufactures and enters tests")
	for i in range(3):
		await click("Run test  ·  12 F / 1 day")
		await create_timer(1.4).timeout
		await settle()
	expect(game.model.tests.size() == 3, "All three test buttons finish")
	await click("Authorize for launch  →")
	expect(game.model.delivered, "Authorization completes chapter")
	var loaded = load("res://scripts/mission.gd").new()
	expect(loaded.load_from(game.save_path) and loaded.delivered, "UI autosave persists completion")
	game.start_flight()
	await settle()
	expect(game.flight_screen != null, "Flight screen opens")
	if game.flight_screen:
		var screen = game.flight_screen
		expect(find_button(screen, "G  Guidance: OFF") == null, "Guidance control is absent")
		var old_guided_save = screen.sim.snapshot()
		old_guided_save.guide = true
		expect(screen.sim.restore(old_guided_save) and not screen.sim.guide, "Older guided checkpoints resume in manual mode")
		screen.throttle_slider.value = 37
		await settle()
		expect(is_equal_approx(screen.sim.throttle, .37), "Throttle slider controls the craft")
		screen.sim.ignite_or_stage()
		for i in range(60): screen.sim.step(.1)
		expect(screen.sim.launched and is_equal_approx(screen.sim.throttle, .37), "Manual throttle persists through launch")
		var earth_r = Flight.EARTH_R
		var low = earth_r + 134100.0
		var high = earth_r + 1833100.0
		var current = earth_r + 155900.0
		var angular = sqrt(Flight.EARTH_MU * 2.0 * low * high / (low + high))
		var tangential = angular / current
		var speed = sqrt(Flight.EARTH_MU * (2.0 / current - 2.0 / (low + high)))
		screen.sim.pos = Vector3(0, current, 0)
		screen.sim.vel = Vector3(tangential, sqrt(maxf(0, speed * speed - tangential * tangential)), 0)
		screen.sim.engine = false
		screen.sim.fuel[0] = 0
		screen.update_hud()
		expect(not screen.transfer_button.disabled, "Navigate to Moon enables for the screenshot's safe elliptical orbit")
		screen.transfer_button.pressed.emit()
		expect(screen.sim.transfer_requested, "Navigate to Moon opens the lunar transfer plan")
	print("Interaction flow: %d failures" % failures)
	quit(1 if failures else 0)
