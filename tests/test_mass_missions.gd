extends SceneTree
const Mission = preload("res://scripts/mission.gd")
const Flight = preload("res://scripts/flight_sim.gd")
var failures = 0

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func failed_checks(mission) -> Array:
	var result = []
	for item in mission.checks():
		if not item.passed: result.append(item.id)
	return result

func _initialize() -> void:
	var base = Mission.new()
	base.reference_design()
	var base_performance = base.flight_performance()
	var heavy = Mission.new()
	heavy.reference_design()
	heavy.research("robotics")
	heavy.equip("nomad")
	var heavy_performance = heavy.flight_performance()
	expect(heavy.totals().mass > base.totals().mass and heavy_performance.dv < base_performance.dv and heavy_performance.twr < base_performance.twr,"More instruments reduce actual flight delta-v and liftoff thrust-to-weight")
	expect("mass" in failed_checks(heavy),"Optional rover exceeds medium launcher's safe lift envelope")
	var blocked = Flight.new()
	blocked.configure(heavy)
	blocked.ignite_or_stage()
	expect(blocked.countdown < 0 and blocked.message.contains("LAUNCH SCRUBBED"),"Overweight craft cannot start countdown")
	var old_tanks=blocked.snapshot()
	old_tanks.erase("tank_balance_version")
	old_tanks.fuel=blocked.legacy_capacities.duplicate()
	var migrated=Flight.new()
	migrated.configure(heavy)
	expect(migrated.restore(old_tanks) and absf(migrated.fuel[0]-migrated.capacities[0])<1,"Earlier flight checkpoint preserves fuel fraction under fixed tank ratings")
	heavy.equip("titan")
	print("Rover: ",failed_checks(heavy)," mass=",heavy.totals().mass," dv=",heavy.flight_performance().dv," cost=",heavy.totals().cost)
	expect(heavy.valid_design(),"A rover mission can regain launch approval with heavy lift")
	expect(heavy.spent+heavy.totals().cost+36<=1000,"Rover, heavy lift, research and tests still fit the mission budget")
	var high = Mission.new()
	high.reference_design()
	high.orbit_profile = 1
	expect("landing" in failed_checks(high),"High relay orbit demands more flight energy")
	high.equip("titan")
	high.equip("vector_x")
	print("High relay: ", failed_checks(high), " mass=",high.totals().mass," dv=",high.flight_performance().dv," cost=",high.totals().cost)
	expect(high.valid_design(),"High relay orbit has a viable launcher and propulsion strategy")
	expect(high.spent+high.totals().cost+36<=1000,"High relay hardware and tests fit the campaign budget")
	var link = Mission.new()
	link.reference_design()
	link.site=2
	expect("comms" in failed_checks(link),"Low orbit at de Gerlache requires a buffered radio")
	link.orbit_profile=1
	expect("comms" not in failed_checks(link),"High relay orbit improves Earth visibility enough for the standard radio")
	var power = Mission.new()
	power.reference_design()
	var low_power=power.totals().power
	power.orbit_profile=1
	expect(power.totals().power>low_power,"High relay orbit increases power demand")
	var survey = Mission.new()
	survey.reference_design()
	survey.orbit_profile = 2
	expect("science" in failed_checks(survey),"Survey orbit demands stronger instruments")
	survey.research("robotics")
	survey.equip("prospect_x")
	survey.equip("titan")
	print("Survey: ",failed_checks(survey)," mass=",survey.totals().mass," dv=",survey.flight_performance().dv," cost=",survey.totals().cost)
	expect(survey.valid_design(),"Survey orbit has a viable science-first strategy within budget")
	expect(survey.spent+survey.totals().cost+36<=1000,"Survey hardware, research and tests fit the campaign budget")
	expect(survey.save_to("/tmp/moonbound-orbit-test.json")==OK,"Orbit mission saves")
	var restored=Mission.new()
	expect(restored.load_from("/tmp/moonbound-orbit-test.json") and restored.orbit_profile==2,"Orbit choice survives save and load")
	var legacy_campaign=Mission.new()
	legacy_campaign.reference_design()
	legacy_campaign.manufacture()
	for test_id in ["structure","propulsion","systems"]: legacy_campaign.run_test(test_id)
	legacy_campaign.deliver()
	legacy_campaign.orbit_profile=1
	expect(not legacy_campaign.valid_design(),"An older approved craft can fail the revised mission envelope")
	legacy_campaign.return_to_design()
	expect(not legacy_campaign.integrated and not legacy_campaign.delivered,"Blocked older campaign can return to design for repair")
	print("Mass and mission profiles: ",failures," failures")
	quit(1 if failures else 0)
