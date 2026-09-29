extends SceneTree
const Mission = preload("res://scripts/mission.gd")
const Flight = preload("res://scripts/flight_sim.gd")

func _initialize() -> void:
	var mission = Mission.new()
	mission.reference_design()
	var sim = Flight.new()
	sim.configure(mission)
	sim.guide = true
	sim.ignite_or_stage()
	for i in range(60): sim.step(.1)
	for i in range(100000):
		if sim.orbit_achieved and not sim.transfer_requested: sim.request_transfer()
		if not sim.engine and sim.altitude() > 30000: sim.set_warp(4)
		else: sim.set_warp(1)
		sim.step(.1)
		if sim.transfer_done:
			sim.prediction()
			var miss = sim.closest_approach
			if miss < Flight.MOON_R + 30000 or miss > Flight.MOON_SOI:
				push_error("Transfer coast should safely enter lunar influence; closest pass was %.0f km" % (miss/1000))
				quit(1)
				return
			sim.guide=false
			sim.set_warp(3)
			sim.manual_rotate(1,.1)
			var before=sim.elapsed
			sim.step(.1)
			if sim.warp_index != 3 or sim.elapsed-before < .7:
				push_error("Manual coast should retain 8× time warp")
				quit(1)
				return
			for coast_step in range(1000):
				if sim.altitude() > 2200000 or sim.body != "Earth": break
				sim.set_warp(6)
				sim.step(.1)
			if sim.body != "Earth" or sim.altitude() < 2200000:
				push_error("Manual coast did not reach the lunar-approach range")
				quit(1)
				return
			sim.set_warp(3)
			before=sim.elapsed
			sim.step(.1)
			if sim.warp_index != 3 or sim.elapsed-before < .7:
				push_error("Time warp should still work near the Moon before lunar influence")
				quit(1)
				return
			for coast_step in range(1000):
				if sim.body == "Moon": break
				sim.set_warp(6)
				sim.step(.1)
			if sim.body != "Moon" or sim.altitude() < 8000:
				push_error("Manual coast did not enter lunar influence safely")
				quit(1)
				return
			sim.set_warp(6)
			before=sim.elapsed
			sim.step(.1)
			if sim.warp_index != 6 or sim.elapsed-before < 6.3:
				push_error("64× time warp should remain active inside lunar influence")
				quit(1)
				return
			print("Transfer pass %.0f km; manual warp works in Earth and lunar influence" % (miss/1000))
			quit(0)
			return
	push_error("Transfer was not completed")
	quit(1)
