@tool
extends SceneTree

func _init():
	var base = "res://assets/art/2d/silksong_full/Animations/Enemy/SoulMaster/"
	var samples = [
		"Idle/0.png",
		"Teleport/0.png",
		"StartSummon/0.png",
		"Summon/0.png",
		"StartDash/0.png",
		"Dash/0.png",
		"StartStun/0.png",
		"Stun/0.png",
		"Die/0.png"
	]
	for s in samples:
		var img = Image.load_from_file(base + s)
		if img:
			print(s, " size: ", img.get_width(), "x", img.get_height())
	quit(0)
