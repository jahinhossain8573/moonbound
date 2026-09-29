extends Control
var sim
var font: Font = preload("res://fonts/Audiowide-Regular.ttf")
const LIME = Color("c7ef00")
const TEXT = Color("e7ecef")
func _draw() -> void:
	if sim == null: return
	var c = size/2
	var r = minf(size.x,size.y)*.38
	draw_circle(c,r,Color("272932"))
	draw_arc(c,r,0,TAU,64,Color("515562"),2,true)
	var up = sim.attitude.inverse()*sim.radial()
	var roll = atan2(up.x,up.y)
	var pitch = asin(clampf(sim.direction().dot(sim.radial()),-1,1))
	var horizon_y = clampf(pitch/(PI/2)*r,-r*.9,r*.9)
	var a=Vector2(-r*.72,horizon_y).rotated(-roll)+c
	var b=Vector2(r*.72,horizon_y).rotated(-roll)+c
	draw_line(a,b,Color("fe5d26"),2,true)
	for offset in [-24.0,24.0]:
		var y=clampf(horizon_y+offset,-r*.8,r*.8)
		draw_line(Vector2(-18,y).rotated(-roll)+c,Vector2(18,y).rotated(-roll)+c,Color("515562"),1,true)
	draw_line(c+Vector2(-24,0),c+Vector2(-7,0),TEXT,2)
	draw_line(c+Vector2(7,0),c+Vector2(24,0),TEXT,2)
	draw_circle(c,3,TEXT)
	if sim.relative_velocity().length() > 1:
		var velocity = sim.attitude.inverse()*sim.relative_velocity().normalized()
		var marker = c+Vector2(velocity.x,-velocity.y)*r*.7
		draw_arc(marker,6,0,TAU,20,LIME,2,true)
		draw_line(marker+Vector2(-11,0),marker+Vector2(-6,0),LIME,2)
		draw_line(marker+Vector2(6,0),marker+Vector2(11,0),LIME,2)
	draw_string(font,c+Vector2(-30,r+19),"%03d°" % rad_to_deg(pitch),HORIZONTAL_ALIGNMENT_LEFT,-1,13,TEXT)
