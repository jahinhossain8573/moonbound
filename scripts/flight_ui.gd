extends Control
const Flight = preload("res://scripts/flight_sim.gd")
const World = preload("res://scripts/flight_world.gd")
const Instruments = preload("res://scripts/flight_instruments.gd")
var host
var sim
var world
var viewport: SubViewport
var view_container: SubViewportContainer
var metrics: Dictionary = {}
var phase_label: Label
var message_label: Label
var plan_label: Label
var countdown_label: Label
var engine_button: Button
var stage_button: Button
var map_button: Button
var third_person_button: Button
var moon_lock_button: Button
var moon_marker: Label
var encounter_widget: Label
var transfer_button: Button
var forecast_title: Label
var forecast_detail: Label
var descent_button: Button
var pause_button: Button
var warp_label: Label
var time_rate_label: Label
var fuel_label: Label
var stage_name: Label
var throttle_label: Label
var throttle_slider: HSlider
var fuel_bar: ProgressBar
var instruments: Control
var hold_buttons: Dictionary = {}
var checkpoint_path = ""
var autosave_clock = 0.0
var awaiting_confirmation = false
var last_event_count = 0
var save_status = ""
var intro_label: Label
var completion_shown = false
var ui_clock = 0.0
var hazard_overlay: ColorRect
var hazard_title: Label
var hazard_detail: Label
var hazard_cost: Label
var hazard_safe_button: Button
var hazard_risk_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = host.theme
	sim = Flight.new()
	sim.configure(host.model)
	checkpoint_path = host.save_path.get_basename()+"-flight.json"
	load_checkpoint(false)
	build_ui()
	update_hud()

func build_ui() -> void:
	var back = ColorRect.new()
	back.color = host.BG
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var layout = host.column(10)
	margin.add_child(layout)
	var header = host.row(14)
	layout.add_child(header)
	header.add_child(host.label("MOONBOUND",28,host.LIME,host.logo_font))
	header.add_child(host.label("/  FLIGHT",15,host.MUTED,host.bold))
	time_rate_label=host.label("TIME RATE  1×",16,host.LIME,host.mono)
	header.add_child(time_rate_label)
	host.spacer(header)
	header.add_child(host.button("F5  Save",func(): save_checkpoint()))
	pause_button = host.button("Esc  Pause",toggle_pause)
	header.add_child(pause_button)
	header.add_child(host.button("Assembly",leave_flight))
	var telemetry = host.row(8)
	layout.add_child(telemetry)
	for key in ["ALTITUDE","SPEED","APOAPSIS","PERIAPSIS","DELTA-V","MISSION TIME"]:
		var c = host.panel(telemetry,host.PANEL,12)
		c.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		host.eyebrow(c,key)
		var value=host.label("—",19,host.LIME if key in ["ALTITUDE","DELTA-V"] else host.TEXT,host.mono)
		c.add_child(value)
		metrics[key]=value
	var content = host.row(10)
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(content)
	build_plan(content)
	build_view(content)
	build_propulsion(content)
	var message_panel = host.panel(layout,host.PANEL,12)
	var status_row = host.row()
	message_panel.add_child(status_row)
	phase_label = host.label("LAUNCH PAD",14,host.LIME,host.bold)
	status_row.add_child(phase_label)
	host.spacer(status_row)
	warp_label = host.label("1×  /  EARTH",13,host.ORANGE,host.mono)
	status_row.add_child(warp_label)
	message_label = host.paragraph("",13,host.TEXT)
	message_panel.add_child(message_label)
	var controls = host.row(14)
	layout.add_child(controls)
	for data in [
		["FLIGHT", "A / D or W / S  Turn in orbit plane\nSpace  Launch / Stage"],
		["PROPULSION", "Shift / Ctrl  Throttle   •   Z / X  Full / Cut\nSpace  Launch / Stage   •   T  Engine"],
		["NAVIGATION", "M  Map   •   P / R  Prograde / Retrograde\n[ / ]  Time warp   •   F5 / F9  Save / Load"],
		["CAMERA", "1  Third person   •   M  Orbital map\nRight drag: orbit / pan map   •   Wheel: zoom   •   L: Moon lock"]]:
		var c=host.column(4)
		c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		controls.add_child(c)
		host.eyebrow(c,data[0])
		c.add_child(host.label(data[1],11,host.MUTED))
	build_hazard_alert()

func build_hazard_alert() -> void:
	hazard_overlay = ColorRect.new()
	hazard_overlay.color = Color(0.04,0.05,0.07,0.84)
	hazard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hazard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hazard_overlay.visible = false
	add_child(hazard_overlay)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hazard_overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 580
	panel.add_theme_stylebox_override("panel",host.style(host.PANEL,host.ORANGE,8,24))
	center.add_child(panel)
	var content = host.column(14)
	panel.add_child(content)
	content.add_child(host.label("DESCENT ALERT  /  FLIGHT PAUSED",13,host.ORANGE,host.bold))
	hazard_title = host.label("",23,host.TEXT,host.bold)
	content.add_child(hazard_title)
	hazard_detail = host.paragraph("",14,host.TEXT)
	content.add_child(hazard_detail)
	hazard_cost = host.paragraph("",12,host.ORANGE)
	content.add_child(hazard_cost)
	var choices = host.row(10)
	content.add_child(choices)
	hazard_safe_button = host.button("",func(): choose_hazard(true),true)
	hazard_safe_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(hazard_safe_button)
	hazard_risk_button = host.button("",func(): choose_hazard(false))
	hazard_risk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(hazard_risk_button)
	content.add_child(host.paragraph("7 / 8 select a response. Flight holds here until you decide.",11,host.MUTED))

func choose_hazard(avoid: bool) -> void:
	if sim.resolve_hazard(avoid):
		save_checkpoint()
		update_hud()

func build_plan(parent: Node) -> void:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 236
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var c=host.panel(scroll,host.PANEL,14)
	c.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	host.eyebrow(c,"CHAPTER 02 / LUNAR FLIGHT")
	c.add_child(host.label("Flight plan",21,host.TEXT,host.bold))
	plan_label=host.paragraph("",12,host.TEXT)
	c.add_child(plan_label)
	host.separator(c)
	forecast_title=host.label("MOON APPROACH",13,host.ORANGE,host.bold)
	c.add_child(forecast_title)
	forecast_detail=host.paragraph("Reach Earth orbit to plan the encounter.",11,host.TEXT)
	c.add_child(forecast_detail)
	host.separator(c)
	transfer_button=host.button("Navigate to Moon",start_transfer)
	c.add_child(transfer_button)
	descent_button=host.button("Begin lunar descent",func(): sim.request_descent())
	c.add_child(descent_button)
	host.separator(c)
	host.eyebrow(c,"TIME ACCELERATION")
	var warp_row=host.row(5)
	c.add_child(warp_row)
	for entry in [["[  Slower",-1],["]  Faster",1]]:
		var b=host.button(entry[0],func(): sim.set_warp(sim.warp_index+entry[1]))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		warp_row.add_child(b)
	c.add_child(host.paragraph("Choose 1×–64× at any point in flight, including burns and descent.",11))
	host.separator(c)
	host.eyebrow(c,"MISSION CREW")
	for index in host.model.crew:
		c.add_child(host.label(host.Mission.CREW[index].name,13,host.TEXT,host.bold))
	c.add_child(host.paragraph(host.Mission.SITES[host.model.site].name+" expedition\n"+host.Mission.ORBITS[host.model.orbit_profile].name+" / qualified hardware",11))
	host.separator(c)
	c.add_child(host.button("F9  Load checkpoint",func(): load_checkpoint()))
	c.add_child(host.button("Retry launch",confirm_retry))

func build_view(parent: Node) -> void:
	var c=host.column(8)
	c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	var top=host.row(6)
	c.add_child(top)
	third_person_button=host.button("1  Third person",show_spacecraft)
	top.add_child(third_person_button)
	moon_lock_button=host.button("L  Lock Moon",toggle_moon_lock)
	top.add_child(moon_lock_button)
	host.spacer(top)
	map_button=host.button("M  Orbital map",toggle_map)
	top.add_child(map_button)
	var holder=Control.new()
	holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size=Vector2(360,300)
	c.add_child(holder)
	view_container=SubViewportContainer.new()
	view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_container.stretch=true
	holder.add_child(view_container)
	viewport=SubViewport.new()
	viewport.size=Vector2i(720,560)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view_container.add_child(viewport)
	world=World.new()
	world.model=host.model
	world.sim=sim
	viewport.add_child(world)
	view_container.gui_input.connect(world.handle_input)
	moon_marker=host.label("",14,host.ORANGE,host.bold)
	moon_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(moon_marker)
	encounter_widget=host.label("",13,host.ORANGE,host.bold)
	encounter_widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	encounter_widget.offset_top=12
	encounter_widget.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	encounter_widget.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(encounter_widget)
	countdown_label=host.label("",72,host.LIME,host.bold)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	countdown_label.offset_top=30
	countdown_label.grow_horizontal=Control.GROW_DIRECTION_BOTH
	countdown_label.grow_vertical=Control.GROW_DIRECTION_BOTH
	countdown_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(countdown_label)
	instruments=Instruments.new()
	instruments.sim=sim
	instruments.mouse_filter=Control.MOUSE_FILTER_IGNORE
	instruments.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	instruments.offset_left=14
	instruments.offset_right=170
	instruments.offset_top=-166
	instruments.offset_bottom=-10
	holder.add_child(instruments)
	intro_label=host.paragraph("SPACE  /  Start launch countdown\nShift / Ctrl  /  Adjust throttle",13,host.TEXT)
	intro_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(intro_label)

func build_propulsion(parent: Node) -> void:
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size.x=244
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var c=host.panel(scroll,host.PANEL,14)
	c.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	host.eyebrow(c,"DAWN EXPLORER / SYSTEMS")
	stage_name=host.label("",18,host.TEXT,host.bold)
	c.add_child(stage_name)
	fuel_label=host.label("",12,host.MUTED,host.mono)
	c.add_child(fuel_label)
	fuel_bar=ProgressBar.new()
	fuel_bar.show_percentage=false
	fuel_bar.custom_minimum_size.y=8
	fuel_bar.add_theme_stylebox_override("background",host.slider_track(host.CARD))
	fuel_bar.add_theme_stylebox_override("fill",host.slider_track(host.LIME))
	c.add_child(fuel_bar)
	host.separator(c)
	throttle_label=host.label("THROTTLE 100%",15,host.ORANGE,host.mono)
	c.add_child(throttle_label)
	throttle_slider=HSlider.new()
	throttle_slider.max_value=100
	throttle_slider.step=.5
	throttle_slider.custom_minimum_size.y=32
	throttle_slider.add_theme_stylebox_override("slider",host.slider_track(host.BORDER))
	throttle_slider.add_theme_stylebox_override("grabber_area",host.slider_track(host.LIME))
	throttle_slider.add_theme_stylebox_override("grabber_area_highlight",host.slider_track(host.LIME))
	throttle_slider.add_theme_icon_override("grabber",host.slider_thumb)
	throttle_slider.add_theme_icon_override("grabber_highlight",host.slider_thumb_hover)
	throttle_slider.value_changed.connect(func(v):
		set_throttle(v/100.0)
	)
	c.add_child(throttle_slider)
	var throttle_row=host.row(6)
	c.add_child(throttle_row)
	throttle_row.add_child(host.button("Z  Full",func(): set_throttle(1)))
	throttle_row.add_child(host.button("X  Cut",func(): set_throttle(0)))
	engine_button=host.button("T  Engine OFF",toggle_engine)
	c.add_child(engine_button)
	stage_button=host.button("SPACE  Launch",stage_action,true)
	c.add_child(stage_button)
	host.separator(c)
	host.eyebrow(c,"ATTITUDE HOLD")
	for mode in ["Manual","Prograde","Retrograde","Radial"]:
		var b=host.button(mode,func():
			sim.hold=mode
		)
		hold_buttons[mode]=b
		c.add_child(b)
	c.add_child(host.paragraph("Prograde adds orbital energy. Retrograde brakes. Aim along the lime velocity marker.",11))

func distance_text(value: float) -> String:
	if not is_finite(value): return "ESCAPE"
	if absf(value)>=1000: return "%.1f km" % (value/1000)
	return "%d m" % value

func clock_text(seconds: float) -> String:
	var whole = maxi(0, int(seconds))
	return "%d:%02d:%02d" % [whole / 3600, (whole / 60) % 60, whole % 60]

func update_forecast() -> void:
	if sim.body == "Moon":
		if sim.descent_requested:
			forecast_title.text="LUNAR DESCENT"
			forecast_detail.text="%s  •  %.0f m/s downward\n%s" % [distance_text(sim.indicated_altitude()),maxf(0,-sim.vertical_speed()),"RADAR UNCERTAIN — displayed altitude may be high." if "radar" in sim.hazard_risks else "Watch altitude and vertical speed; reserve fuel for the final braking burn."]
		else:
			forecast_title.text="LUNAR PARKING ORBIT" if sim.lunar_coast_started>=0 else "LUNAR APPROACH"
			forecast_detail.text="Target: %s\n%.1f km along the surface to the selected site.\n%s" % [sim.landing_site.name,sim.site_distance()/1000.0,"Completing a lunar orbit and waiting for the site approach window." if sim.lunar_coast_started>=0 else "Brake retrograde to establish lunar orbit before descent."]
		if sim.descent_requested:
			forecast_detail.text+="\n%s / %.0f m from target" % [sim.landing_site.name,sim.site_distance()]
	elif sim.transfer_done:
		var eta = maxf(0, sim.predicted_encounter_time - sim.elapsed)
		if sim.prediction_encounter and sim.closest_approach <= Flight.MOON_R:
			forecast_title.text="LUNAR INTERCEPT"
			forecast_detail.text="Moon at arrival: orange marker.\nCoast reaches surface in %s; prepare a retrograde capture burn." % clock_text(eta)
		else:
			var miss = maxf(0, sim.closest_approach - Flight.MOON_R) / 1000.0
			forecast_title.text="ENCOUNTER CONFIRMED" if sim.prediction_encounter else "COURSE CORRECTION"
			forecast_detail.text="Moon at arrival: orange marker.\nClosest pass %.0f km in %s. %s" % [miss,clock_text(eta),"Coast to lunar influence." if sim.prediction_encounter else "Adjust with small burns; watch the miss line."]
	elif sim.transfer_requested:
		var plan = sim.transfer_plan()
		forecast_title.text="BURN WINDOW OPEN" if plan.wait <= 1 else "MOON TRANSFER PLAN"
		forecast_detail.text="Burn in %s  •  Prograde %.0f m/s\nFlight %s. Orange marker = Moon at arrival." % [clock_text(plan.wait),plan.burn_dv,clock_text(plan.flight_time)]
	elif sim.earth_orbit_ready():
		forecast_title.text="READY TO PLAN"
		forecast_detail.text="Select Navigate to Moon to see the transfer arc. Circularize first for a more accurate burn window." if sim.orbit().e > 0.2 else "Select Navigate to Moon to see the future Moon and transfer arc."
	else:
		forecast_title.text="MOON APPROACH"
		forecast_detail.text="Reach Earth orbit to plan the encounter."

func update_hud() -> void:
	var orbit=sim.orbit()
	metrics["ALTITUDE"].text="0 m / LANDED" if sim.landed else (("~" if "radar" in sim.hazard_risks else "")+distance_text(sim.indicated_altitude()))
	metrics["ALTITUDE"].add_theme_color_override("font_color",host.ORANGE if "radar" in sim.hazard_risks else host.LIME)
	metrics["SPEED"].text="%.0f m/s" % sim.relative_velocity().length()
	metrics["APOAPSIS"].text="—" if sim.landed else distance_text(orbit.ap)
	metrics["PERIAPSIS"].text="—" if sim.landed else distance_text(orbit.pe)
	metrics["PERIAPSIS"].add_theme_color_override("font_color",host.ORANGE if orbit.pe<0 else host.TEXT)
	metrics["DELTA-V"].text="%d m/s" % sim.remaining_dv()
	metrics["MISSION TIME"].text="%02d:%02d:%02d" % [int(sim.elapsed)/3600,(int(sim.elapsed)/60)%60,int(sim.elapsed)%60]
	phase_label.text=("PAUSED  /  " if sim.paused else "")+sim.phase.to_upper()
	message_label.text=sim.message+("  •  "+save_status if save_status!="" else "")
	hazard_overlay.visible=sim.hazard_pending!=""
	if hazard_overlay.visible:
		var alert=sim.hazard_info()
		hazard_title.text=alert.title
		hazard_detail.text=alert.detail
		hazard_cost.text="Mitigation: %.0f m/s  •  Fuel after mitigation: %.0f m/s  •  Ascent needs %.0f m/s\nThe remaining descent also burns fuel. Risk: %s%s" % [alert.cost,sim.remaining_dv()-alert.cost,Flight.ASCENT_RESERVE,alert.risk_note,"  •  Mitigation unavailable: insufficient fuel." if not sim.can_avoid_hazard() else ""]
		hazard_safe_button.text="7  "+alert.safe
		hazard_safe_button.disabled=not sim.can_avoid_hazard()
		hazard_risk_button.text="8  "+alert.risk
	var rate=Flight.WARPS[sim.warp_index]
	time_rate_label.text="TIME RATE  PAUSED / %d× SET" % rate if sim.paused or sim.hazard_pending!="" else "TIME RATE  %d×" % rate
	warp_label.text="%d×  /  %s" % [rate,sim.body.to_upper()]
	countdown_label.text=str(ceili(sim.countdown)) if sim.countdown>0 else ("CONTACT" if sim.landed else ("SIGNAL LOST" if sim.crashed else ""))
	countdown_label.add_theme_font_size_override("font_size",34 if sim.crashed or sim.landed else 72)
	plan_label.text="%s  Launch & gravity turn\n\n%s  Safe Earth orbit\n\n%s  Lunar transfer\n\n%s  Capture at the Moon\n\n%s  Soft touchdown" % ["✓" if sim.launched else "01", "✓" if sim.orbit_achieved or sim.earth_orbit_ready() else "02", "✓" if sim.transfer_done else "03", "✓" if sim.lunar_orbit else "04", "✓" if sim.landed else "05"]
	transfer_button.disabled=not sim.earth_orbit_ready() or sim.transfer_requested or sim.transfer_done
	update_forecast()
	encounter_widget.visible=world.map_mode and sim.transfer_requested
	encounter_widget.text="MOON ENCOUNTER  /  "+clock_text(maxf(0,sim.predicted_encounter_time-sim.elapsed)) if sim.transfer_done else "MOON AT ARRIVAL"
	descent_button.disabled=not sim.lunar_orbit or sim.descent_requested
	engine_button.text="T  Engine "+("ON" if sim.engine else "OFF")
	stage_button.text="SPACE  Launch" if not sim.launched else ("Final stage" if sim.stage==2 else "SPACE  Stage %d" % (sim.stage+2))
	stage_button.disabled=sim.crashed or sim.landed or sim.stage==2 or sim.countdown>=0
	stage_name.text=["01 / Launch vehicle","02 / Service module","03 / Lunar module"][sim.stage]
	fuel_label.text="FUEL %5.1f%%  /  %.1f t" % [sim.fuel[sim.stage]/sim.capacities[sim.stage]*100,sim.mass()/1000]
	fuel_bar.value=sim.fuel[sim.stage]/sim.capacities[sim.stage]*100
	throttle_label.text="THROTTLE %3d%%" % (sim.throttle*100)
	throttle_slider.set_value_no_signal(sim.throttle*100)
	pause_button.text="Esc  Resume" if sim.paused else "Esc  Pause"
	map_button.text="M  Spacecraft" if world.map_mode else "M  Orbital map"
	map_button.add_theme_color_override("font_color",host.LIME if world.map_mode else host.TEXT)
	map_button.add_theme_stylebox_override("normal",host.style(host.CARD,host.LIME if world.map_mode else host.BORDER,5,10))
	moon_lock_button.text="L  Unlock Moon" if world.moon_locked else "L  Lock Moon"
	third_person_button.add_theme_color_override("font_color",host.TEXT if world.map_mode else host.LIME)
	third_person_button.add_theme_stylebox_override("normal",host.style(host.CARD,host.BORDER if world.map_mode else host.LIME,5,10))
	moon_lock_button.add_theme_color_override("font_color",host.ORANGE if world.moon_locked else host.TEXT)
	moon_lock_button.add_theme_stylebox_override("normal",host.style(host.CARD,host.ORANGE if world.moon_locked else host.BORDER,5,10))
	update_moon_marker()
	for mode in hold_buttons:
		hold_buttons[mode].add_theme_color_override("font_color",host.LIME if sim.hold==mode else host.TEXT)
	instruments.visible=not world.map_mode
	instruments.queue_redraw()
	if world.map_mode:
		intro_label.text="LIME  Flight path / planned burn    •    ORANGE  Moon now → Moon at arrival\nAP / PE  Orbital extremes    •    Right drag to pan    •    Scroll to zoom" if sim.body=="Earth" else "LUNAR FRAME  /  Coast prediction\nRight drag to pan; burn retrograde near periapsis to capture."
	elif sim.launched:
		intro_label.text="VERTICAL %+.1f m/s    •    HORIZONTAL %.1f m/s\n%s" % [sim.vertical_speed(),sim.horizontal_speed(),"TOUCHDOWN / "+sim.landing_condition.to_upper() if sim.landed else "MANUAL FLIGHT / A D or W S to turn"]
	if sim.transfer_requested and not sim.transfer_done and sim.body=="Earth":
		var plan = sim.transfer_plan()
		intro_label.text="%s  /  Burn in %s\nPrograde %.0f m/s  •  Orange marker = Moon at arrival" % ["BURN WINDOW OPEN" if plan.wait<=1 else "COAST TO BURN WINDOW",clock_text(plan.wait),plan.burn_dv]
	if sim.landed and not completion_shown:
		completion_shown=true
		save_checkpoint()

func _process(dt: float) -> void:
	if not is_instance_valid(world): return
	if not sim.paused and not sim.crashed and not sim.landed and (sim.hazard_pending=="" or sim.guide):
		var turn=clampf(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))+float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)),-1,1)
		if not sim.guide: sim.manual_rotate(turn,dt)
		if Input.is_physical_key_pressed(KEY_SHIFT): set_throttle(sim.throttle+dt*.35)
		if Input.is_physical_key_pressed(KEY_CTRL): set_throttle(sim.throttle-dt*.35)
		sim.step(dt)
	world.update_flight(dt if not sim.paused else 0)
	ui_clock += dt
	if ui_clock>.08:
		ui_clock=0
		update_hud()
	autosave_clock+=dt
	if autosave_clock>20 and sim.launched and not sim.crashed:
		autosave_clock=0
		save_checkpoint()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		if is_instance_valid(world): world.dragging=false
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(host.overlay) or awaiting_confirmation: return
	if event.physical_keycode==KEY_G:
		sim.toggle_autopilot()
		get_viewport().set_input_as_handled()
		return
	if sim.guide and event.physical_keycode in [KEY_SPACE,KEY_T,KEY_Z,KEY_X,KEY_P,KEY_R]: return
	if sim.hazard_pending!="":
		match event.physical_keycode:
			KEY_7: choose_hazard(true)
			KEY_8: choose_hazard(false)
			KEY_F5: save_checkpoint()
			KEY_F9: load_checkpoint()
			_: return
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_ESCAPE: toggle_pause()
		KEY_M: toggle_map()
		KEY_1: show_spacecraft()
		KEY_L: toggle_moon_lock()
		KEY_SPACE: stage_action()
		KEY_T: toggle_engine()
		KEY_Z: set_throttle(1)
		KEY_X: set_throttle(0)
		KEY_P:
			sim.hold="Prograde"
		KEY_R:
			sim.hold="Retrograde"
		KEY_BRACKETLEFT: sim.set_warp(sim.warp_index-1)
		KEY_BRACKETRIGHT: sim.set_warp(sim.warp_index+1)
		KEY_F5: save_checkpoint()
		KEY_F9: load_checkpoint()
		_: return
	get_viewport().set_input_as_handled()

func stage_action() -> void:
	if sim.paused or sim.guide: return
	sim.ignite_or_stage()

func set_throttle(value: float) -> void:
	if sim.paused or sim.guide: return
	var new_throttle=clampf(value,0,1)
	if new_throttle>0 and sim.throttle<=0 and sim.launched and sim.fuel[sim.stage]>0:
		sim.set_engine(true)
	sim.throttle=new_throttle

func toggle_engine() -> void:
	if sim.paused or sim.guide: return
	sim.set_engine(not sim.engine)

func toggle_map() -> void:
	world.map_mode=not world.map_mode
	if world.map_mode:
		world.map_zoom=150 if world.moon_locked else (920 if sim.transfer_requested else 170)
		world.map_pan=Vector3.ZERO
	world.path_clock=0
	world.dragging=false

func start_transfer() -> void:
	sim.request_transfer()
	if sim.transfer_requested:
		world.map_mode=true
		world.map_zoom=920
		world.map_pan=Vector3.ZERO
		world.path_clock=0
		world.dragging=false

func show_spacecraft() -> void:
	world.map_mode=false
	world.dragging=false
	world.update_camera()

func toggle_moon_lock() -> void:
	world.moon_locked=not world.moon_locked
	if world.map_mode: world.map_zoom=150 if world.moon_locked else (920 if sim.transfer_requested else 170)
	world.map_pan=Vector3.ZERO
	world.path_clock=0
	world.update_camera()

func update_moon_marker() -> void:
	moon_marker.visible=world.moon_locked and not world.map_mode
	if not moon_marker.visible: return
	var distance=sim.pos.distance_to(sim.moon_position())-Flight.MOON_R
	var behind=world.camera.is_position_behind(world.moon.global_position)
	moon_marker.text="MOON LOCKED  /  %.0f km" % (distance/1000) if behind else "◆ MOON  /  %.0f km" % (distance/1000)
	var size=view_container.size
	var projected=world.camera.unproject_position(world.moon.global_position)
	var position=Vector2(size.x*.5,26) if behind else Vector2(projected.x*size.x/viewport.size.x,projected.y*size.y/viewport.size.y)
	moon_marker.position=Vector2(clampf(position.x-75,10,size.x-170),clampf(position.y-22,10,size.y-40))

func toggle_pause() -> void:
	sim.paused=not sim.paused

func save_checkpoint() -> bool:
	if sim.crashed:
		save_status="Last good checkpoint preserved"
		return false
	var file=FileAccess.open(checkpoint_path+".tmp",FileAccess.WRITE)
	if file==null:
		save_status="Save failed"
		return false
	file.store_string(JSON.stringify(sim.snapshot()))
	file.close()
	var result=DirAccess.rename_absolute(checkpoint_path+".tmp",checkpoint_path)
	save_status="Checkpoint saved" if result==OK else "Save failed"
	return result==OK

func load_checkpoint(report: bool = true) -> bool:
	if not FileAccess.file_exists(checkpoint_path):
		if report: sim.log_event("No flight checkpoint yet. F5 saves one.")
		return false
	var data=JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
	if not data is Dictionary or not sim.restore(data):
		if report: sim.log_event("Checkpoint does not match this spacecraft or is invalid.")
		return false
	if is_instance_valid(world):
		world.last_stage=sim.stage
		for item in world.debris: item.node.queue_free()
		world.debris.clear()
	completion_shown=false
	return true

func leave_flight() -> void:
	save_checkpoint()
	host.ui.show()
	host.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	host.flight_screen=null
	queue_free()

func confirm_retry() -> void:
	var was_paused=sim.paused
	awaiting_confirmation=true
	sim.paused=true
	host.confirm("Retry from launch pad?","This restarts the flight with your qualified spacecraft and replaces its flight checkpoint. Your spacecraft design stays saved.",func():
		awaiting_confirmation=false
		sim=Flight.new()
		sim.configure(host.model)
		world.sim=sim
		world.last_stage=0
		world.camera_pitch=.2
		for item in world.debris: item.node.queue_free()
		world.debris.clear()
		instruments.sim=sim
		completion_shown=false
		intro_label.text="SPACE  /  Start launch countdown\nShift / Ctrl  /  Adjust throttle"
		save_checkpoint()
	)

	var dialog=host.get_child(host.get_child_count()-1)
	dialog.canceled.connect(func():
		awaiting_confirmation=false
		sim.paused=was_paused
	)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and sim!=null: save_checkpoint()
