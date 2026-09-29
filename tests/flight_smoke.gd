extends SceneTree
var game
var failed=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failed+=1
		push_error(text)
func key(code: Key) -> void:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func capture(name: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/moonbound-flight-"+name+".png")
func run() -> void:
	DirAccess.remove_absolute("/tmp/moonbound-flight-smoke-campaign-flight.json")
	game=load("res://scenes/main.tscn").instantiate()
	game.save_path="/tmp/moonbound-flight-smoke-campaign.json"
	root.add_child(game)
	await process_frame
	game.model.reference_design()
	game.model.manufacture()
	for test in ["structure","propulsion","systems"]: game.model.run_test(test)
	game.model.deliver()
	game.start_flight()
	var screen=game.flight_screen
	await capture("pad")
	check(screen.world.targets.size()==game.model.installed.size()+2,"Assembled module geometry loaded")
	check(screen.world.earth.get_child(0).scene_file_path=="res://assets/earth.glb","Flight Earth uses supplied GLB model")
	check(screen.world.map_earth.get_child(0).scene_file_path=="res://assets/earth.glb","Orbital map Earth uses supplied GLB model")
	check(screen.world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Third-person perspective is the default spacecraft camera")
	await key(KEY_1)
	check(screen.world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Third-person view remains available from keyboard")
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_RIGHT
	press.pressed=true
	screen.view_container.gui_input.emit(press)
	var drag=InputEventMouseMotion.new()
	drag.relative=Vector2(55,20)
	var old_angle=screen.world.orbit_angle
	screen.view_container.gui_input.emit(drag)
	check(screen.world.orbit_angle!=old_angle,"Right drag orbits third-person camera")
	press.pressed=false
	screen.view_container.gui_input.emit(press)
	await key(KEY_L)
	screen.update_hud()
	await capture("moon-lock")
	check(screen.world.moon_locked and screen.moon_marker.visible,"Moon lock marks target in flight view")
	await key(KEY_M)
	check(screen.world.map_mode and screen.world.map_zoom==150,"Moon lock focuses orbital map on Moon")
	old_angle=screen.world.orbit_angle
	var old_map_position=screen.world.camera.position
	press.pressed=true
	screen.view_container.gui_input.emit(press)
	screen.view_container.gui_input.emit(drag)
	check(screen.world.map_pan.x<0 and screen.world.map_pan.y>0,"Right drag pans the orbital map in screen space")
	check(screen.world.camera.position.distance_to(old_map_position)>0,"Map camera follows right-drag panning")
	check(screen.world.orbit_angle==old_angle,"Map drag does not orbit the spacecraft camera")
	press.pressed=false
	screen.view_container.gui_input.emit(press)
	await key(KEY_M)
	check(screen.world.moon_locked and screen.world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Third-person view retains Moon lock")
	await key(KEY_2)
	check(screen.world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Removed 2.5D shortcut leaves the camera unchanged")
	await key(KEY_L)
	check(not screen.world.moon_locked,"Moon lock toggles off")
	await key(KEY_M)
	check(screen.world.map_mode and screen.world.map_zoom==170,"M opens an Earth-orbit scale map")
	await key(KEY_M)
	await key(KEY_X)
	check(screen.sim.throttle==0,"X cuts throttle")
	screen.throttle_slider.value=55
	check(is_equal_approx(screen.sim.throttle,.55),"Mouse throttle slider works")
	await key(KEY_Z)
	check(screen.sim.throttle==1,"Z sets full throttle")
	await key(KEY_ESCAPE)
	var before=screen.sim.elapsed
	await process_frame
	check(screen.sim.paused and screen.sim.elapsed==before,"Escape pauses simulation")
	await key(KEY_ESCAPE)
	await key(KEY_G)
	check(not screen.sim.guide,"Removed guidance shortcut does not take over the craft")
	screen.throttle_slider.value=42
	check(is_equal_approx(screen.sim.throttle,.42),"Throttle slider sets manual engine output")
	await key(KEY_SPACE)
	check(screen.sim.countdown>0,"Space starts countdown")
	await capture("countdown")
	for i in range(51): screen.sim.step(.1)
	for i in range(320): screen.sim.step(.1)
	await capture("launch")
	check(screen.sim.launched and is_equal_approx(screen.sim.throttle,.42),"Manual throttle remains set during flight")
	var fuel_before=screen.sim.fuel[screen.sim.stage]
	await key(KEY_X)
	for i in range(10): screen.sim.step(.1)
	check(screen.sim.throttle==0 and is_equal_approx(screen.sim.fuel[screen.sim.stage],fuel_before),"Cut throttle stops propellant use")
	await key(KEY_Z)
	check(screen.sim.throttle==1,"Full throttle key restores manual output")
	await key(KEY_SPACE)
	check(screen.sim.stage==1,"Manual staging separates the launcher")
	check(screen.save_checkpoint(),"Flight saves")
	check(screen.load_checkpoint(),"Flight reloads")
	check(not screen.sim.guide and screen.sim.stage==1,"Checkpoint reload stays manual")
	screen.confirm_retry()
	var dialog=game.get_child(game.get_child_count()-1)
	dialog.confirmed.emit()
	await process_frame
	check(not screen.sim.launched and screen.sim.stage==0,"Retry starts a fresh launch without camera errors")
	screen.leave_flight()
	await process_frame
	check(game.ui.visible,"Return to assembly works")
	print("Flight UI playthrough complete; failures: ",failed)
	quit(1 if failed else 0)
