@tool
extends SceneTree

func _init():
	var base_path = "res://assets/art/2d/silksong_full/Animations/Enemy/SoulMaster/"
	
	# 1. Slice StartQuake.png (1682 x 614, 4 columns x 2 rows)
	var sq_img = Image.load_from_file(base_path + "StartQuake.png")
	if sq_img:
		var sq_dir = base_path + "StartQuake/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sq_dir))
		var w = sq_img.get_width()
		var h = sq_img.get_height()
		var col_w = int(w / 4)
		var row_h = int(h / 2)
		
		for r in range(2):
			for c in range(4):
				var idx = r * 4 + c
				var fx1 = c * col_w
				var fy1 = r * row_h
				var frame_img = Image.create(col_w, row_h, false, Image.FORMAT_RGBA8)
				frame_img.blit_rect(sq_img, Rect2i(fx1, fy1, col_w, row_h), Vector2i.ZERO)
				frame_img.save_png(sq_dir + str(idx) + ".png")
		print("Successfully sliced 8 frames into StartQuake/")
		
	# 2. Slice SoulOrb.png (518 x 60)
	var orb_img = Image.load_from_file("res://assets/art/2d/silksong_full/Animations/Enemy/SoulOrb.png")
	if orb_img:
		var orb_dir = base_path + "SoulOrbFrames/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(orb_dir))
		# The glowing orb is around x=236..282, size ~ 46x46
		# Let's extract the main orb frame centered on a 64x64 canvas
		var main_orb = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		main_orb.fill(Color(0, 0, 0, 0))
		# center is x=259, y=30
		main_orb.blit_rect(orb_img, Rect2i(259 - 30, 0, 60, 60), Vector2i(2, 2))
		main_orb.save_png(orb_dir + "orb.png")
		print("Successfully saved SoulOrbFrames/orb.png")
		
	quit(0)
