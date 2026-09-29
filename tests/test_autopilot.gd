extends SceneTree
const Mission = preload("res://scripts/mission.gd")
const Flight = preload("res://scripts/flight_sim.gd")
var failures = 0
func check(ok: bool, message: String):
 if not ok:
  failures += 1
  push_error(message)
func make_ship(site_index=0):
 var m=Mission.new()
 m.reference_design()
 m.site=site_index
 var s=Flight.new()
 s.configure(m)
 return s
func _initialize():
 for from_orbit in [0,1,2]:
  var s=make_ship(from_orbit)
  s.hazard_queue=["boulders","slope"]
  s.hazard_rolls=[0.0,0.0]
  if from_orbit:
   s.launched=true
   s.pos=Vector3(0,Flight.EARTH_R+65000,0)
   s.vel=Vector3(sqrt(Flight.EARTH_MU/s.pos.length()),0,0)
   s.orbit_achieved=true
   if from_orbit==2:
    var semimajor=(s.pos.length()+Flight.EARTH_R+500000)*.5
    s.vel=Vector3(sqrt(Flight.EARTH_MU*(2/s.pos.length()-1/semimajor)),0,0)
  s.set_warp(6)
  s.toggle_autopilot()
  var checked_descent=false
  for i in range(6000):
   s.step(.1)
   if s.descent_requested and not checked_descent:
    check(s.lunar_coast_started>=0 and s.elapsed-s.lunar_coast_started>=s.lunar_coast_period,"Descent must wait until a complete parking orbit")
    checked_descent=true
   if s.landed or s.crashed: break
  print("Autopilot from orbit=",from_orbit," phase=",s.phase," fuel=",s.remaining_dv()," site miss=",s.site_distance())
  check(s.site_distance()<500,"Autopilot must reach the selected landing site")
  check(s.lunar_coast_started>=0 and s.elapsed-s.lunar_coast_started>s.lunar_coast_period,"Autopilot must complete a lunar orbit before landing")
  check(s.landed,"G autopilot must finish a hands-off lunar landing")
  check(s.hazard_index==2 and s.hazard_pending=="","Autopilot must resolve landing hazards")
  check(s.warp_index==6,"Autopilot must preserve selected warp")
 var ellipse=make_ship()
 ellipse.launched=true
 ellipse.pos=Vector3(0,Flight.EARTH_R+70000,0)
 var a=(ellipse.pos.length()+Flight.EARTH_R+500000)*.5
 ellipse.vel=Vector3(sqrt(Flight.EARTH_MU*(2/ellipse.pos.length()-1/a)),0,0)
 var plan=ellipse.transfer_plan()
 var h=ellipse.pos.cross(ellipse.vel)
 var e=ellipse.vel.cross(h)/Flight.EARTH_MU-ellipse.pos.normalized()
 check(absf(plan.departure.length()*(1+e.dot(plan.departure.normalized()))-h.length_squared()/Flight.EARTH_MU)<1,"Burn point must lie on the elliptical orbit")
 ellipse.toggle_autopilot()
 ellipse.toggle_autopilot()
 check(not ellipse.guide and ellipse.throttle==0,"Second G must return manual control with thrust cut")
 print("Autopilot checks: ",failures," failures")
 quit(1 if failures else 0)
