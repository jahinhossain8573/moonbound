extends SceneTree
const Mission = preload("res://scripts/mission.gd")
const Flight = preload("res://scripts/flight_sim.gd")
const FlightUI = preload("res://scripts/flight_ui.gd")
var failed=0
var checks=0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failed+=1
		push_error(text)
func make_flight(mission=null):
	var m=mission if mission!=null else Mission.new()
	if mission==null: m.reference_design()
	var s=Flight.new()
	s.configure(m)
	return s
func fly(s,frame_dt: float=.1) -> void:
	s.guide=true
	s.hazard_queue=["radar","engine"]
	s.hazard_rolls=[0.9,0.9]
	s.ignite_or_stage()
	for i in range(60): s.step(.1)
	for i in range(500000):
		if s.hazard_pending != "":
			check(s.can_avoid_hazard(),"Descent mitigation is affordable")
			s.resolve_hazard(true)
		if not s.engine and s.altitude()>30000: s.set_warp(4)
		else: s.set_warp(1)
		s.step(frame_dt)
		if s.crashed or s.landed or s.elapsed>35000: break
	check(s.orbit_achieved,"Earth orbit attainable")
	check(s.transfer_requested and s.transfer_done,"Guidance automatically plans and flies lunar transfer")
	check(s.lunar_orbit,"Lunar capture attainable")
	check(s.descent_requested,"Guidance continues into lunar descent after capture")
	check(s.landed,"Soft touchdown attainable")
	check(s.landing_condition!="Crew stranded","Guided landing preserves ascent reserve after two mitigated hazards")
	check(s.stage==2,"Guidance separates both spent stages")
	check(s.fuel[2]>0,"Landing retains reserve propellant")
	print("Flight verified: %ds elapsed, %.0f m/s reserve" % [s.elapsed,s.remaining_dv()])
func _initialize() -> void:
	var s=make_flight()
	check(absf(s.remaining_dv()-8800)<1,"Manifest delta-v preserved by rocket equation")
	var mass_before=s.mass()
	s.ignite_or_stage()
	check(not s.launched and s.countdown==5,"Countdown precedes ignition")
	s.paused=true
	s.step(1)
	check(s.countdown==5,"Pause freezes countdown")
	s.paused=false
	for i in range(60): s.step(.1)
	check(s.launched and s.pos.y>Flight.EARTH_R+12,"Thrust lifts spacecraft off pad")
	check(s.mass()<mass_before,"Burn consumes actual propellant mass")
	var guided_pad=make_flight()
	guided_pad.guide=true
	guided_pad.ignite_or_stage()
	var resumed_pad=make_flight()
	check(resumed_pad.restore(guided_pad.snapshot()) and not resumed_pad.guide and resumed_pad.countdown>0,"Old guided launch resumes manually with its countdown")
	var old_guided_pad=guided_pad.snapshot()
	old_guided_pad.erase("countdown")
	check(resumed_pad.restore(old_guided_pad) and not resumed_pad.guide and resumed_pad.countdown<0,"Older guided pad checkpoints remain idle for manual launch")
	var fast_pad=make_flight()
	fast_pad.set_warp(6)
	fast_pad.ignite_or_stage()
	fast_pad.step(.1)
	check(fast_pad.launched and fast_pad.warp_index==6,"64× time warp advances launch countdown without resetting")
	s.set_warp(6)
	var before_warp=s.elapsed
	s.step(.1)
	check(s.warp_index==6 and s.elapsed-before_warp>6.3,"Powered atmospheric flight retains 64× time warp")
	s.manual_rotate(1,1)
	check(s.warp_index==6,"Manual steering does not reset time warp")
	check(absf(s.direction().x)>.1 and absf(s.direction().z)<.000001,"Manual steering turns within the Moon orbital plane")
	check(absf(s.pos.z)<.000001 and absf(s.vel.z)<.000001,"Powered flight remains in the orbital plane")
	var before=s.mass()
	s.ignite_or_stage()
	check(s.stage==1 and s.mass()<before and s.warp_index==6,"Staging discards mass without resetting time warp")
	s.engine=false
	var f=s.fuel.duplicate()
	s.step(.1)
	check(f==s.fuel,"Engine cutoff stops fuel consumption")
	var cut_ship=make_flight()
	cut_ship.launched=true
	cut_ship.engine=true
	cut_ship.pos=Vector3(0,Flight.EARTH_R+65000,0)
	cut_ship.vel=Vector3(sqrt(Flight.EARTH_MU/cut_ship.pos.length()),0,0)
	var flight_controls=FlightUI.new()
	flight_controls.sim=cut_ship
	flight_controls.set_throttle(0)
	var fuel_before_cut=cut_ship.fuel[0]
	cut_ship.step(.1)
	check(cut_ship.fuel[0]==fuel_before_cut,"Cut stops thrust without consuming fuel")
	cut_ship.set_engine(false)
	flight_controls.set_throttle(.6)
	cut_ship.step(.1)
	check(cut_ship.engine and cut_ship.fuel[0]<fuel_before_cut,"Raising throttle after Cut relights a fueled engine")
	flight_controls.free()
	var coast=make_flight()
	coast.launched=true
	coast.pos=Vector3(0,Flight.EARTH_R+70000,0)
	coast.vel=Vector3(sqrt(Flight.EARTH_MU/coast.pos.length()),0,0)
	var plan=coast.transfer_plan()
	check(plan.wait>=0 and plan.wait<coast.orbit().period,"Transfer window is scheduled within one parking orbit")
	check(plan.moon_arrival.distance_to(coast.moon_position(plan.arrival_time))<1,"Arrival ghost follows the Moon's future orbit")
	check(plan.moon_arrival.normalized().dot(-plan.departure.normalized())>.999,"Planned transfer meets the Moon's future position")
	check(plan.burn_dv>0 and plan.flight_time>0,"Transfer preview provides burn and travel timing")
	var energy=coast.vel.length_squared()/2-Flight.EARTH_MU/coast.pos.length()
	coast.set_warp(4)
	for i in range(100): coast.step(.1)
	var energy_after=coast.vel.length_squared()/2-Flight.EARTH_MU/coast.pos.length()
	check(absf((energy_after-energy)/energy)<.001,"Coasting conserves orbital energy to 0.1 percent")
	check(coast.orbit().pe>65000,"Coasting preserves safe periapsis")
	var stable_orbit=make_flight()
	stable_orbit.launched=true
	stable_orbit.engine=true
	stable_orbit.throttle=0
	stable_orbit.pos=Vector3(0,Flight.EARTH_R+65000,0)
	stable_orbit.vel=Vector3(sqrt(Flight.EARTH_MU/stable_orbit.pos.length()),0,0)
	var original_orbit=stable_orbit.orbit()
	stable_orbit.set_warp(6)
	for i in range(1000): stable_orbit.step(.1)
	var final_orbit=stable_orbit.orbit()
	check(absf(final_orbit.pe-original_orbit.pe)<2 and absf(final_orbit.ap-original_orbit.ap)<2,"Unpowered Earth orbit remains fixed through several 64× revolutions")
	var stable_lunar_orbit=make_flight()
	stable_lunar_orbit.launched=true
	stable_lunar_orbit.body="Moon"
	stable_lunar_orbit.stage=2
	stable_lunar_orbit.throttle=0
	stable_lunar_orbit.pos=stable_lunar_orbit.moon_position()+Vector3(0,Flight.MOON_R+20000,0)
	stable_lunar_orbit.vel=stable_lunar_orbit.moon_velocity()+Vector3(sqrt(Flight.MOON_MU/(Flight.MOON_R+20000)),0,0)
	var original_lunar_orbit=stable_lunar_orbit.orbit()
	stable_lunar_orbit.set_warp(6)
	for i in range(500): stable_lunar_orbit.step(.1)
	var final_lunar_orbit=stable_lunar_orbit.orbit()
	check(absf(final_lunar_orbit.pe-original_lunar_orbit.pe)<2 and absf(final_lunar_orbit.ap-original_lunar_orbit.ap)<2,"Unpowered lunar orbit remains fixed through several 64× revolutions")
	var eccentric=make_flight()
	var low=Flight.EARTH_R+134100.0
	var high=Flight.EARTH_R+1833100.0
	var current=Flight.EARTH_R+155900.0
	var semimajor=(low+high)*.5
	var angular=sqrt(Flight.EARTH_MU*2.0*low*high/(low+high))
	var tangential=angular/current
	var speed=sqrt(Flight.EARTH_MU*(2.0/current-1.0/semimajor))
	eccentric.launched=true
	eccentric.engine=false
	eccentric.pos=Vector3(0,current,0)
	eccentric.vel=Vector3(tangential,sqrt(maxf(0,speed*speed-tangential*tangential)),0)
	check(eccentric.earth_orbit_ready() and absf(eccentric.orbit().ap-1833100)<10,"High elliptical screenshot orbit is eligible for lunar navigation")
	var stale_orbit=eccentric.snapshot()
	stale_orbit.orbit=false
	var resumed_orbit=make_flight()
	check(resumed_orbit.restore(stale_orbit) and resumed_orbit.orbit_achieved,"Old checkpoint repairs its missed Earth-orbit milestone")
	eccentric.request_transfer()
	check(eccentric.transfer_requested,"Navigate to Moon accepts a safe elliptical orbit")
	var data=coast.snapshot()
	var restored=make_flight()
	check(restored.restore(JSON.parse_string(JSON.stringify(data))),"Checkpoint JSON round trip")
	check(restored.pos.distance_to(coast.pos)<1 and restored.warp_index==4,"Checkpoint restores selected time warp")
	var old_save=data.duplicate(true)
	old_save.pos[2]=8000.0
	old_save.vel[2]=50.0
	var tilted=Basis.from_euler(Vector3(.4,.2,.1))
	old_save.attitude=[tilted.x.x,tilted.x.y,tilted.x.z,tilted.y.x,tilted.y.y,tilted.y.z,tilted.z.x,tilted.z.y,tilted.z.z]
	check(restored.restore(old_save),"Older 3D checkpoint remains loadable")
	check(absf(restored.pos.z)<.000001 and absf(restored.vel.z)<.000001 and absf(restored.direction().z)<.000001,"Older checkpoint is projected into the common orbital plane")
	check(restored.pos.distance_to(coast.pos)<1,"Checkpoint projection preserves in-plane position")
	var bad=data.duplicate(true)
	bad.fuel[0]=-1
	check(not restored.restore(bad),"Negative propellant checkpoint rejected")
	bad=data.duplicate(true)
	bad.campaign="unrelated spacecraft"
	check(not restored.restore(bad),"Different spacecraft checkpoint rejected")
	bad=data.duplicate(true)
	bad.pos[0]=NAN
	check(not restored.restore(bad),"Non-finite position rejected")
	check(restored.pos.distance_to(coast.pos)<1,"Invalid checkpoint leaves live flight untouched")
	var emergency=make_flight()
	emergency.hazard_queue=["engine"]
	emergency.hazard_rolls=[0.4]
	emergency.hazard_pending="engine"
	var emergency_save=JSON.parse_string(JSON.stringify(emergency.snapshot()))
	var resumed_emergency=make_flight()
	check(resumed_emergency.restore(emergency_save) and resumed_emergency.hazard_pending=="engine","Unresolved landing decision survives a checkpoint")
	var reserve_before=resumed_emergency.remaining_dv()
	check(resumed_emergency.resolve_hazard(true),"Pilot can mitigate a landing hazard")
	check(absf((reserve_before-resumed_emergency.remaining_dv())-680)<1,"Mitigation spends the stated delta-v")
	check(resumed_emergency.hazard_pending=="" and resumed_emergency.hazard_index==1,"Mitigation resumes descent")
	var radar=make_flight()
	radar.hazard_queue=["radar"]
	radar.hazard_rolls=[0.5]
	radar.hazard_pending="radar"
	check(radar.resolve_hazard(false) and radar.indicated_altitude()>radar.altitude(),"Unmitigated radar blackout misleads the manual altimeter")
	emergency_save.landing_hazards.pending="unknown"
	check(not resumed_emergency.restore(emergency_save),"Invalid landing hazard checkpoint rejected")
	var boulder=make_flight()
	boulder.launched=true
	boulder.body="Moon"
	boulder.stage=2
	boulder.pos=boulder.moon_position()+Vector3(0,Flight.MOON_R+8.5,0)
	boulder.vel=boulder.moon_velocity()+Vector3(0,-1,0)
	boulder.descent_requested=true
	boulder.hazard_queue=["boulders"]
	boulder.hazard_rolls=[0.1]
	boulder.hazard_index=1
	boulder.hazard_risks=["boulders"]
	for i in range(20):
		boulder.step(.1)
		if boulder.crashed: break
	check(boulder.crashed and boulder.message.contains("Boulder strike"),"Risky boulder landing can lose the vehicle despite a gentle touchdown")
	var impact=make_flight()
	impact.launched=true
	impact.pos=Vector3(0,Flight.EARTH_R+9,0)
	impact.vel=Vector3(0,-100,0)
	impact.step(.1)
	check(impact.crashed and not impact.engine,"Hard impact ends flight")
	var manual=make_flight()
	manual.launched=true
	manual.orbit_achieved=true
	manual.pos=Vector3(0,Flight.EARTH_R+65000,0)
	var a=(manual.pos.length()+Flight.MOON_D)/2
	manual.vel=Vector3(sqrt(Flight.EARTH_MU*(2/manual.pos.length()-1/a)),0,0)
	manual.request_transfer()
	manual.step(.1)
	check(manual.transfer_done,"Manual injection recognized without guidance")
	var path=manual.prediction()
	var planar_path=true
	for p in path:
		if absf(p.z)>.000001: planar_path=false
	check(planar_path,"Predicted flight path shares the Moon orbital plane")
	check(manual.closest_approach>0 and is_finite(manual.closest_approach),"Coast prediction computes encounter distance")
	check(manual.predicted_moon.distance_to(manual.moon_position(manual.predicted_encounter_time))<1,"Coast encounter uses the Moon's predicted position at arrival")
	fly(make_flight())
	fly(make_flight(),1.0/60)
	var upgraded=Mission.new()
	upgraded.reference_design()
	upgraded.orbit_profile=1
	upgraded.equip("titan")
	upgraded.equip("vector_x")
	fly(make_flight(upgraded))
	var survey=Mission.new()
	survey.reference_design()
	survey.orbit_profile=2
	survey.research("robotics")
	survey.equip("prospect_x")
	survey.equip("titan")
	fly(make_flight(survey))
	var polar=Mission.new()
	polar.reference_design()
	polar.research("energy")
	polar.equip("sol_x")
	polar.site=1
	check(polar.valid_design(),"Polar battery campaign remains launchable")
	fly(make_flight(polar))
	print("Flight model: %d checks, %d failures" % [checks,failed])
	quit(1 if failed else 0)
